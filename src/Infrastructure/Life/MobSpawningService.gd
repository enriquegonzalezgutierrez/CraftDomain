# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MobSpawningService.gd
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and hostile dynamic classes inside loaded chunks.
#              Corrected: Implemented Vertical Column Completeness Shield (Section 1.2).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobSpawningService
extends RefCounted


## Spawns procedural wildlife and themed outpost entities inside a newly loaded chunk.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	var chunk_pos: Vector3i = chunk.position
	
	# ==========================================================================
	# ESCUDO DE COLUMNA COMPLETA (Sincronización Asíncrona - Sección 1.2)
	# Si la capa superior (Y=1) aún no se ha cargado, aplazamos el spawn en Y=0
	# para evitar que las criaturas queden enterradas bajo tierra al cargar el mapa.
	# ==========================================================================
	if chunk_pos.y == 0:
		var upper_chunk := world_state.get_chunk(Vector3i(chunk_pos.x, 1, chunk_pos.z))
		if upper_chunk == null:
			return [] # Aplazar hasta que la columna vertical esté completa
	# ==========================================================================
	
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	var is_real_village := false
	var active_biome_id := 2 # Default Golden Bazaar plains
	
	var generator: WorldGenerator = null
	if is_instance_valid(world_node):
		generator = world_node.get("generator") as WorldGenerator
		
	if is_instance_valid(generator):
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x: int = chunk_pos.x * Chunk.SIZE + 8
			var center_z: int = chunk_pos.z * Chunk.SIZE + 8
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			is_real_village = (profile.landmark_id == 3)
			active_biome_id = profile.biome_id

	var biome: IBiome = BiomeService.get_biome(active_biome_id)

	# 1. BIOME-THEMED VILLAGE OUTPOST SPAWNING
	if is_real_village:
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, spawned_nodes)
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, spawned_nodes)
		
		if is_instance_valid(biome):
			var population: Array[int] = biome.get_outpost_population_ids()
			var spawn_positions: Array[Vector2] = [Vector2(6.5, 6.5), Vector2(4.5, 4.5)]
			
			for i: int in range(min(population.size(), spawn_positions.size())):
				var mob_id := population[i]
				var offset_pos: Vector2 = spawn_positions[i]
				_spawn_and_register_entity(mob_id, chunk_offset, offset_pos.x, offset_pos.y, world_state, world_node, spawned_nodes)
		
		_spawn_and_register_entity(107, chunk_offset, 8.5, 5.5, world_state, world_node, spawned_nodes)
	else:
		# 2. WILDERNESS ORGANIC SPAWNING
		var roll := randf()
		var spawn_chance := 0.12
		if is_instance_valid(biome) and biome.has_method("get_spawn_chance"):
			spawn_chance = biome.call("get_spawn_chance") as float
			
		if roll < spawn_chance:
			if is_instance_valid(biome):
				var wildlife_ids := biome.get_wilderness_wildlife_ids()
				if wildlife_ids.size() > 0:
					var rand_idx := randi() % wildlife_ids.size()
					var target_animal_id := int(wildlife_ids[rand_idx])
					_spawn_and_register_entity(target_animal_id, chunk_offset, 8.5, 8.5, world_state, world_node, spawned_nodes)

	# 3. GLOBAL MEGA-STRUCTURE GUARD SPALOCATIONS
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id := edata["mob_id"] as int
		var exact_pos := edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var spawn_pos := exact_pos
			var is_space_free := _is_physics_spawn_space_free(world_node, spawn_pos)
			
			if is_space_free:
				var block_at_pos := world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
				if BlockType.is_solid(block_at_pos):
					spawn_pos.y = world_state.get_highest_solid_y(floori(spawn_pos.x), floori(spawn_pos.z))
					
				var spawn_node := MobRegistry.create_mob(mob_id, spawn_pos)
				if spawn_node != null:
					world_node.add_child(spawn_node)
					spawned_nodes.append(spawn_node)

	return spawned_nodes


## Instantiates, places, and anchors a registered dynamic entity based on its Domain Habitat rules.
func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not MobRegistry.has_mob(spawn_id):
		return
		
	var global_x := int(offset.x + lx)
	var global_z := int(offset.z + lz)
	
	var habitat := MobRegistry.get_mob_habitat(spawn_id)
	var gy := -1.0
	
	if habitat == MobRegistry.Habitat.TERRESTRIAL:
		gy = _get_ground_surface_y(world_state, global_x, global_z)
	elif habitat == MobRegistry.Habitat.AQUATIC:
		gy = _get_water_surface_y(world_state, global_x, global_z)
	else:
		gy = _get_water_surface_y(world_state, global_x, global_z)
		if gy < 0.0:
			gy = _get_ground_surface_y(world_state, global_x, global_z)
		
	if gy < 0.0:
		return 
		
	var pos := Vector3(offset.x + lx, gy, offset.z + lz)
	
	# Symmetrical verbose telemetry logging (Section 1.2 / Core Metrics)
	print("[MobSpawning Diagnostics] Entity ID: %d | Base Offset: %s | Local lx/lz: (%.2f, %.2f) | Scanned Height Y: %.2f | Final Vector3: %s" % [
		spawn_id, offset, lx, lz, gy, pos
	])
	
	if _is_physics_spawn_space_free(world_node, pos):
		var mob := MobRegistry.create_mob(spawn_id, pos)
		if mob != null:
			world_node.add_child(mob)
			list.append(mob)


## Helper: Scans vertical columns downward from absolute sky limit (Y=31) 
## to find the absolute topmost solid ground block.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	var top_block_type := BlockType.Type.AIR
	var top_y := -1
	
	for y: int in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		if block_type != BlockType.Type.AIR:
			top_block_type = block_type
			top_y = y
			break
			
	if top_y == -1:
		return -1.0
		
	if top_block_type == BlockType.Type.WATER or top_block_type == BlockType.Type.LAVA:
		return -1.0 
	
	var hit_y := -1
	for y: int in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if block_type != BlockType.Type.AIR and block_type != BlockType.Type.WATER:
			hit_y = y
			break
			
	if hit_y == -1:
		return -1.0
		
	var surface_block := world_state.get_block(Vector3i(global_x, hit_y, global_z))
	var def := BlockLibrary.get_definition(surface_block) as BlockDefinition
	
	if def == null or not def.is_spawnable_soil:
		# Print warning to console if the terrain scanner rejects the spawn block (OCP)
		print("[MobSpawning Warning] Aborted land spawn at (X: %d, Z: %d). Soil block '%s' (ID %d) is non-spawnable." % [
			global_x, global_z, "Unknown" if def == null else def.translation_key, surface_block
		])
		return -1.0
		
	var space_above_1 := world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
	var space_above_2 := world_state.get_block(Vector3i(global_x, hit_y + 2, global_z))
	if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
		return float(hit_y) + 1.0
		
	return -1.0


## Helper: Scans vertical columns downward specifically seeking the surface of a liquid water body.
func _get_water_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	var hit_y := -1
	
	for y: int in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if block_type != BlockType.Type.AIR:
			hit_y = y
			break
			
	if hit_y == -1:
		return -1.0
		
	var surface_block := world_state.get_block(Vector3i(global_x, hit_y, global_z))
	if surface_block == BlockType.Type.WATER:
		var space_above_1 := world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
		if not BlockType.is_solid(space_above_1):
			return float(hit_y) - 1.2
			
	return -1.0


## Performs a quick 3D sphere physics sweep to ensure the spawning coordinate 
## is not already occupied by static props or solid building walls.
func _is_physics_spawn_space_free(world_node: Node, spawn_pos: Vector3) -> bool:
	if not world_node.is_inside_tree():
		return true
		
	var space_state := world_node.get_viewport().find_world_3d().direct_space_state
	if space_state == null:
		return true
		
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35 
	query.shape = sphere
	query.transform = Transform3D(Basis(), spawn_pos + Vector3(0.0, 0.4, 0.0))
	query.collision_mask = 1 
	
	var results := space_state.intersect_shape(query, 1)
	return results.is_empty()

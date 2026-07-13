# ==============================================================================
# Pathfile: res://src/Infrastructure/World/PropSpawningService.gd
# Description: Infrastructure Service responsible for calculating and spawning
#              inert scenery props and interactive decorations inside loaded chunks.
#              Corrected: Implemented Vertical Column Completeness Shield (Section 1.2).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PropSpawningService
extends RefCounted


## Spawns dynamic scenery props and interactive decorations inside a newly loaded chunk.
func spawn_props_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	
	# ==========================================================================
	# ESCUDO DE COLUMNA COMPLETA (Sincronización Asíncrona - Sección 1.2)
	# Si la capa superior (Y=1) aún no se ha cargado, aplazamos el spawn en Y=0
	# para evitar que los cofres y barriles queden enterrados bajo el césped.
	# ==========================================================================
	if chunk_pos.y == 0:
		var upper_chunk := world_state.get_chunk(Vector3i(chunk_pos.x, 1, chunk_pos.z))
		if upper_chunk == null:
			return [] # Aplazar hasta que la columna vertical esté completa
	# ==========================================================================
	
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	var is_real_village := false
	var active_biome_id := 2 # Default Golden Bazaar plains
	
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator):
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			is_real_village = (profile.landmark_id == 3)
			active_biome_id = profile.biome_id

	var biome: IBiome = BiomeService.get_biome(active_biome_id)

	# 1. VILLAGE OUTPOST DECORATION SPAWNING
	if is_real_village:
		_spawn_and_register_prop(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(202, chunk_offset, 2.5, 10.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(203, chunk_offset, 8.5, 3.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(213, chunk_offset, 10.5, 3.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(215, chunk_offset, 6.5, 9.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(215, chunk_offset, 11.5, 6.5, world_state, world_node, entities_list)
	else:
		# 2. WILDERNESS ORGANIC SCATTER SPAWNING
		var roll := randf()
		if roll < 0.12:
			var scatter_hash: int = abs(chunk_pos.x * 93856093 ^ chunk_pos.z * 29349663)
			
			var target_prop_id := 0
			if is_instance_valid(biome) and biome.has_method("get_wilderness_prop_id"):
				target_prop_id = biome.call("get_wilderness_prop_id", scatter_hash) as int
				
			if target_prop_id > 0 and PropRegistry.has_prop(target_prop_id):
				_spawn_and_register_prop(target_prop_id, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)

	# 3. HIGHWAY LIGHTING: Spawns streetlights along the paved roads shoulders
	var road_lamps := RoadGeneratorService.get_roadside_lamps_for_chunk(chunk_pos)
	for lamp_pos: Vector3 in road_lamps:
		_spawn_and_register_prop(202, Vector3.ZERO, lamp_pos.x, lamp_pos.z, world_state, world_node, entities_list)

	return entities_list


## Instantiates, places, and anchors a registered prop on the highest solid ground.
func _spawn_and_register_prop(prop_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not PropRegistry.has_prop(prop_id):
		return
		
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	if gy < 0.0:
		return 
		
	var pos := Vector3(offset.x + lx, gy, offset.z + lz)
	
	var prop := PropRegistry.create_prop(prop_id, pos)
	if prop != null:
		world_node.add_child(prop)
		list.append(prop)


## Helper: Scans vertical columns downward to find the topmost solid floor-like block.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		# OCP COMPLIANCE: Mobs and props can only spawn on blocks that explicitly declare is_spawnable_soil = true.
		var def := BlockLibrary.get_definition(block_type) as BlockDefinition
		if def != null and def.is_spawnable_soil:
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0
				
	return -1.0

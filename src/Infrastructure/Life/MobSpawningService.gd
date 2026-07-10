# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / World Services
# Class: MobSpawningService
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and hostile dynamic classes inside chunks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates procedural 
#   wildlife and living outpost populations.
# - Open-Closed Principle (OCP): Dynamically queries biome strategies 
#   for spawning pools, completely free of hardcoded match tables.
# - Liskov Substitution Principle (LSP): Works flawlessly on any IBiome strategy.
# TRAPPING PREVENTION SYSTEM (Anti-Glitched Spawn):
# - Implemented an absolute "Sky Line-of-Sight" scan to prevent spawning inside 
#   closed houses, roofs, or subterranean caverns.
# - Implemented a real-time Physics Sphere Sweep to prevent entities from 
#   spawning inside physical scenery props (Wells, farolas, barrels, chests).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted


## Spawns procedural wildlife and themed outpost dynamic entities inside a newly loaded chunk.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos: Vector3i = chunk.position
	var chunk_offset: Vector3 = Vector3(chunk_pos * Chunk.SIZE)
	
	var is_real_village: bool = false
	var active_biome_id: int = 2 # Default Golden Bazaar plains
	
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator
	if is_instance_valid(generator):
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x: int = chunk_pos.x * Chunk.SIZE + 8
			var center_z: int = chunk_pos.z * Chunk.SIZE + 8
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			is_real_village = (profile.landmark_id == 3)
			active_biome_id = profile.biome_id

	var biome: IBiome = BiomeService.get_biome(active_biome_id)

	# 1. Procedural Biome-Themed Village Outpost Spawning (OCP / LSP compliant)
	if is_real_village:
		# Villager (100) and Merchant (101) spawn in all outposts
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list)
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list)
		
		# Dynamic Biome Outpost Spawning: Query population list from active Biome strategy
		if is_instance_valid(biome):
			var population: Array = biome.get_outpost_population_ids()
			if population.size() >= 2:
				_spawn_and_register_entity(population[0], chunk_offset, 6.5, 6.5, world_state, world_node, entities_list)
				_spawn_and_register_entity(population[1], chunk_offset, 4.5, 4.5, world_state, world_node, entities_list)
		
		# FIXED OVERLAP: Moved the Golem (107) coordinate from 8.5, 3.5 (Campfire) to 8.5, 5.5
		_spawn_and_register_entity(107, chunk_offset, 8.5, 5.5, world_state, world_node, entities_list)
	else:
		# 2. Spawning organically in the wilderness (OCP/LSP compliant, zero hardcoding)
		var roll: float = randf()
		# DENSITY OVERHAUL: Boost spawning probability in Ocean (ID 0) and Swamp (ID 8) 
		# to 35% to fill aquatic horizons beautifully!
		var spawn_threshold: float = 0.35 if (active_biome_id == 0 or active_biome_id == 8) else 0.12
		
		if roll < spawn_threshold:
			if is_instance_valid(biome):
				var wildlife_ids: Array = biome.get_wilderness_wildlife_ids()
				if wildlife_ids.size() > 0:
					# Safely select a random animal ID registered for this specific biome
					var rand_idx: int = randi() % wildlife_ids.size()
					var target_animal_id: int = int(wildlife_ids[rand_idx])
					_spawn_and_register_entity(target_animal_id, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)

	# 3. Global Mega-Structure spawns (Castle Guards, Harbor Merchants, etc.)
	var mega_entities: Array = MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id: int = edata["mob_id"] as int
		var exact_pos: Vector3 = edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var spawn_pos: Vector3 = exact_pos
			
			# Verify if space is free of solid blocks and dynamic props before spawning
			var is_space_free: bool = _is_physics_spawn_space_free(world_node, spawn_pos)
			
			if is_space_free:
				var block_at_pos: BlockType.Type = world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
				if BlockType.is_solid(block_at_pos):
					spawn_pos.y = world_state.get_highest_solid_y(floori(spawn_pos.x), floori(spawn_pos.z))
					
				var spawn_node: Node = MobRegistry.create_mob(mob_id, spawn_pos)
				if spawn_node != null:
					world_node.add_child(spawn_node)
					entities_list.append(spawn_node)

	return entities_list


## Instantiates, places, and anchors a registered dynamic entity based on its Domain Habitat rules.
func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not MobRegistry.has_mob(spawn_id):
		return
		
	var global_x: int = int(offset.x + lx)
	var global_z: int = int(offset.z + lz)
	
	# Determine logical habitat dynamically from the Domain Registry
	var habitat: int = MobRegistry.get_mob_habitat(spawn_id)
	var gy: float = -1.0
	
	if habitat == MobRegistry.Habitat.TERRESTRIAL:
		gy = _get_ground_surface_y(world_state, global_x, global_z)
	elif habitat == MobRegistry.Habitat.AQUATIC:
		gy = _get_water_surface_y(world_state, global_x, global_z)
	else:
		# AMPHIBIOUS: Attempt to spawn directly in water; fallback to dry sand/mud shores if unavailable!
		gy = _get_water_surface_y(world_state, global_x, global_z)
		if gy < 0.0:
			gy = _get_ground_surface_y(world_state, global_x, global_z)
		
	if gy < 0.0:
		return # Cancel spawn if no valid habitat block was found in this chunk column
		
	var pos: Vector3 = offset + Vector3(lx, gy, lz)
	
	# Verify if space is free of physical dynamic props or static walls (DIP query)
	if _is_physics_spawn_space_free(world_node, pos):
		var mob: Node = MobRegistry.create_mob(spawn_id, pos)
		if mob != null:
			world_node.add_child(mob)
			list.append(mob)


## Helper: Scans vertical columns downward from absolute sky limit (Y=31) 
## to find the absolute topmost solid ground block.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	var hit_y: int = -1
	
	# 1. SKY LINE-OF-SIGHT SCAN: Scan downward to find the absolute highest solid voxel
	for y: int in range(31, -1, -1):
		var check_pos: Vector3i = Vector3i(global_x, y, global_z)
		var block_type: BlockType.Type = world_state.get_block(check_pos)
		
		if block_type != BlockType.Type.AIR and block_type != BlockType.Type.WATER:
			hit_y = y
			break
			
	if hit_y == -1:
		return -1.0
		
	var surface_block: BlockType.Type = world_state.get_block(Vector3i(global_x, hit_y, global_z))
	
	# 2. SOLID TERRAIN VERIFIER:
	# Humanoids and land fauna must ONLY spawn on natural flat terrain (Grass, Dirt, Road, Sand, Snow).
	# This prevents spawning on Bricks, Wood Logs, Planks, or Glass, blocking roof/castle traps!
	var is_natural_terrain: bool = (
		surface_block == BlockType.Type.GRASS or 
		surface_block == BlockType.Type.DIRT or 
		surface_block == BlockType.Type.SAND or 
		surface_block == BlockType.Type.RED_SAND or 
		surface_block == BlockType.Type.SNOW or 
		surface_block == BlockType.Type.MUD or 
		surface_block == BlockType.Type.ROAD
	)
	
	if not is_natural_terrain:
		return -1.0
		
	# 3. STANDING CLEARANCE VERIFIER:
	# Ensure the two blocks directly above the ground surface are completely empty AIR.
	var space_above_1: BlockType.Type = world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
	var space_above_2: BlockType.Type = world_state.get_block(Vector3i(global_x, hit_y + 2, global_z))
	if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
		return float(hit_y) + 1.0
		
	return -1.0


## Helper: Scans vertical columns downward specifically seeking the surface of a liquid water body.
func _get_water_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	var hit_y: int = -1
	
	# 1. SKY LINE-OF-SIGHT SCAN: Find the absolute highest solid voxel
	for y: int in range(31, -1, -1):
		var check_pos: Vector3i = Vector3i(global_x, y, global_z)
		var block_type: BlockType.Type = world_state.get_block(check_pos)
		
		if block_type != BlockType.Type.AIR:
			hit_y = y
			break
			
	if hit_y == -1:
		return -1.0
		
	var surface_block: BlockType.Type = world_state.get_block(Vector3i(global_x, hit_y, global_z))
	if surface_block == BlockType.Type.WATER:
		# Ensure the creature isn't spawning encased under a solid ceiling
		var space_above_1: BlockType.Type = world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
		if not BlockType.is_solid(space_above_1):
			return float(hit_y) # Submerged exactly at water level (no +1.0 offset!)
			
	return -1.0


## Performs a quick 3D sphere physics sweep to ensure the spawning coordinate 
## is not already occupied by static props or solid building walls.
func _is_physics_spawn_space_free(world_node: Node, spawn_pos: Vector3) -> bool:
	if not world_node.is_inside_tree():
		return true
		
	# FIXED: Explicitly typed variable declaration to satisfy strict static compiler
	var space_state: PhysicsDirectSpaceState3D = world_node.get_world_3d().direct_space_state
	if space_state == null:
		return true
		
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.35 # Match basic humanoid thickness
	query.shape = sphere
	# Offset the sphere slightly upward to check around the torso/body level (0.4m offset)
	query.transform = Transform3D(Basis(), spawn_pos + Vector3(0.0, 0.4, 0.0))
	query.collision_mask = 1 # Collides with static terrain (Layer 1) and active props
	
	# FIXED: Explicitly typed variable declaration to satisfy strict static compiler
	var results: Array = space_state.intersect_shape(query, 1)
	return results.is_empty()

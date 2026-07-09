# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and hostile dynamic classes inside chunks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates procedural 
#   wildlife and living outpost populations.
# - Open-Closed Principle (OCP): Dynamically queries the biome strategy 
#   population and wilderness wildlife registries, removing all hardcoded match maps.
# - Liskov Substitution Principle (LSP): Works flawlessly on any IBiome strategy.
# HABITAT-DRIVEN SPAWNING (DDD Compliance):
# - Retrieves the Domain `Habitat` classification before generating the mob.
# - Automatically routes the vertical surface scan to `_get_ground_surface_y` for
#   terrestrial creatures, and `_get_water_surface_y` for aquatic/amphibious species.
# ARCHITECTURAL CLEANUP (Quest Sync Decoupling):
# - Removed all hardcoded quest overwrites. The spawner now strictly spawns entities. 
#   Coordinate tracking and quest ownership is entirely delegated to the entities 
#   themselves during their initialization to preserve absolute SRP.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted


## Spawns procedural wildlife and themed outpost dynamic entities inside a newly loaded chunk.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	var is_real_village: bool = false
	var active_biome_id: int = 2 # Default Golden Bazaar plains
	
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator
	if is_instance_valid(generator):
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			is_real_village = (profile.landmark_id == 3)
			active_biome_id = profile.biome_id

	var biome := BiomeService.get_biome(active_biome_id)

	# 1. Procedural Biome-Themed Village Outpost Spawning (OCP / LSP compliant)
	if is_real_village:
		# Villager (100) and Merchant (101) spawn in all outposts
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list)
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list)
		
		# Dynamic Biome Outpost Spawning: Query population list from active Biome strategy
		if is_instance_valid(biome):
			var population := biome.get_outpost_population_ids()
			if population.size() >= 2:
				_spawn_and_register_entity(population[0], chunk_offset, 6.5, 6.5, world_state, world_node, entities_list)
				_spawn_and_register_entity(population[1], chunk_offset, 4.5, 4.5, world_state, world_node, entities_list)
		
		# Golem (107) spawns to guard the village
		_spawn_and_register_entity(107, chunk_offset, 8.5, 3.5, world_state, world_node, entities_list)
	else:
		# 2. Spawning organically in the wilderness (OCP/LSP compliant, zero hardcoding)
		var roll := randf()
		# DENSITY OVERHAUL: Boost spawning probability in Ocean (ID 0) and Swamp (ID 8) 
		# to 35% to fill aquatic horizons beautifully!
		var spawn_threshold := 0.35 if (active_biome_id == 0 or active_biome_id == 8) else 0.12
		
		if roll < spawn_threshold:
			if is_instance_valid(biome):
				var wildlife_ids := biome.get_wilderness_wildlife_ids()
				if wildlife_ids.size() > 0:
					# Safely select a random animal ID registered for this specific biome
					var rand_idx := randi() % wildlife_ids.size()
					var target_animal_id := wildlife_ids[rand_idx]
					_spawn_and_register_entity(target_animal_id, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)

	# 3. Global Mega-Structure spawns (Castle Guards, Harbor Merchants, etc.)
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id: int = edata["mob_id"] as int
		var exact_pos: Vector3 = edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var spawn_pos := exact_pos
			var block_at_pos := world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
			if BlockType.is_solid(block_at_pos):
				# Ajusta la altura dinámicamente si cae sobre bloques sólidos generados
				spawn_pos.y = world_state.get_highest_solid_y(floori(spawn_pos.x), floori(spawn_pos.z))
				
			var spawn_node := MobRegistry.create_mob(mob_id, spawn_pos)
			if spawn_node != null:
				world_node.add_child(spawn_node)
				entities_list.append(spawn_node)

	return entities_list


## Instantiates, places, and anchors a registered dynamic entity based on its Domain Habitat rules.
func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not MobRegistry.has_mob(spawn_id):
		return
		
	var global_x := int(offset.x + lx)
	var global_z := int(offset.z + lz)
	
	# Determine logical habitat dynamically from the Domain Registry
	var habitat := MobRegistry.get_mob_habitat(spawn_id)
	var gy := -1.0
	
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
		return # Cancel spawn if no valid habitat block was found in this chunk column!
		
	var pos := offset + Vector3(lx, gy, lz)
	var mob: Node = MobRegistry.create_mob(spawn_id, pos)
	if mob != null:
		world_node.add_child(mob)
		list.append(mob)


## Helper: Scans vertical columns downward to find the topmost solid land block.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		var is_valid_surface := (
			block_type == BlockType.Type.GRASS or 
			block_type == BlockType.Type.DIRT or 
			block_type == BlockType.Type.SAND or 
			block_type == BlockType.Type.RED_SAND or 
			block_type == BlockType.Type.SNOW or 
			block_type == BlockType.Type.ICE or 
			block_type == BlockType.Type.MUD or 
			block_type == BlockType.Type.ROAD or
			block_type == BlockType.Type.STONE or   
			block_type == BlockType.Type.BRICKS
		)
		
		if is_valid_surface:
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0
				
	return -1.0


## Helper: Scans vertical columns downward specifically seeking the surface of a liquid water body.
func _get_water_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if block_type == BlockType.Type.WATER:
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			# Ensure the creature isn't spawning encased under a solid ice/stone ceiling over the water
			if not BlockType.is_solid(space_above_1):
				return float(y) # Submerged exactly at water level (no +1.0 offset!)
				
	return -1.0

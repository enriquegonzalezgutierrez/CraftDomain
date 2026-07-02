# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and interactive prop classes dynamically inside chunks.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Exclusively coordinates 
#                procedural wildlife and outpost population placements.
#              - Open-Closed Principle (OCP): Dynamically queries the biome strategy 
#                population registry, removing hardcoded match maps.
#              - Liskov Substitution Principle (LSP): Works flawlessly on any IBiome.
#              UPDATED:
#              - Integrated the new 3D Streetlight Entity (ID 202) Spawning.
#                Replaced the buggy voxel-based lamppost with robust 3D physical 
#                entities. Spawns village lamps at caminos and organic wilderness 
#                lamps scattered at safe ground levels in plains and forests.
#              WARNING FIX:
#              - Added explicit static typing `bool` to `should_spawn_organic_light` 
#                variable to resolve the dynamic type inference warning.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/MobSpawningService.gd
# ==============================================================================
class_name MobSpawningService
extends RefCounted


## Spawns procedural wildlife, themed outposts, and physical streetlights inside a newly loaded chunk.
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

	# 1. Procedural Biome-Themed Village Outpost Spawning (OCP / LSP compliant)
	if is_real_village:
		# Villager (100) and Merchant (101) spawn in all outposts
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list, "lost_bazaar")
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list, "fuel_fryer")
		
		# Loot chest spawns in all outposts
		_spawn_and_register_entity(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list, "")
		
		# ---> PHYSICAL 3D VILLAGE STREETLIGHT SPAWN <---
		# Spawns 1 gorgeous, non-floating, 100% solid 3D Streetlight Entity (ID 202) at the road side
		_spawn_and_register_entity(202, chunk_offset, 2.5, 10.5, world_state, world_node, entities_list, "")
		
		# DYNAMIC BIOME OUTPOST SPAWNING: Query population list from active Biome strategy
		var biome := BiomeService.get_biome(active_biome_id)
		if is_instance_valid(biome):
			var population := biome.get_outpost_population_ids()
			if population.size() >= 2:
				_spawn_and_register_entity(population[0], chunk_offset, 2.5, 12.5, world_state, world_node, entities_list, "")
				_spawn_and_register_entity(population[1], chunk_offset, 10.5, 10.5, world_state, world_node, entities_list, "plains_defender")
				
		# Spawn a heavy, persistent Golem (107) to guard the village
		_spawn_and_register_entity(107, chunk_offset, 12.5, 12.5, world_state, world_node, entities_list, "")
			
	else:
		# ---> PHYSICAL 3D ORGANIC WILDERNESS STREETLIGHT SPAWN <---
		# If we are in civilized plains (2) or Redwood forest (5), we have a deterministic 
		# 1/35 chance per chunk to spawn a majestic 3D lamppost exactly at safe ground levels
		if active_biome_id == 2 or active_biome_id == 5:
			# WARNING FIX: Explicit static typing as bool prevents compiler warnings
			var should_spawn_organic_light: bool = (abs(chunk_pos.x) * 11 + abs(chunk_pos.z) * 17) % 35 == 3
			if should_spawn_organic_light:
				_spawn_and_register_entity(202, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")

		# Fauna Spawning (Sea Turtles paddle exclusively inside ocean bays)
		var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
		if should_spawn_animal:
			if active_biome_id == 0: # Bay of Sails (Spawn Ocean)
				_spawn_and_register_entity(201, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")
			else:
				var spawn_roll: int = int(abs(chunk_pos.x + chunk_pos.z)) % 4
				_spawn_and_register_entity(spawn_roll, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")

	# 2. Global Mega-Structure spawns (Castle Guards, Harbor Merchants, etc.)
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id: int = edata["mob_id"] as int
		var exact_pos: Vector3 = edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var entity: Node = MobRegistry.create_mob(mob_id, exact_pos)
			if entity != null:
				world_node.add_child(entity)
				entities_list.append(entity)

	return entities_list


## Spawns, registers, and tracks coordinates for quests if applicable.
func _spawn_and_register_entity(mob_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node], quest_sync_id: String) -> void:
	if not MobRegistry.has_mob(mob_id): 
		return
		
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	if gy < 0.0:
		return # Abort spawning if no valid ground surface is compiled yet (prevents underground spawning)
		
	var pos := offset + Vector3(lx, gy, lz)
	var entity: Node = MobRegistry.create_mob(mob_id, pos)
	if entity != null:
		world_node.add_child(entity)
		list.append(entity)
		if quest_sync_id != "":
			var quest: Quest = QuestService.get_quest(quest_sync_id) as Quest
			if quest != null:
				quest.target_position = pos


## Helper: Scans vertical columns downward to find the topmost solid floor-like block.
## Skips tree foliage canopies and artificial ceilings. Returns -1.0 centinel if not ready.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		# Only allow spawning on true floor-like blocks, ignoring leaves and trunks
		if block_type == BlockType.Type.GRASS or block_type == BlockType.Type.DIRT or \
		   block_type == BlockType.Type.STONE or block_type == BlockType.Type.SAND or \
		   block_type == BlockType.Type.RED_SAND or block_type == BlockType.Type.MUD or \
		   block_type == BlockType.Type.SNOW or block_type == BlockType.Type.ICE:
			
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0 
				
	return -1.0 # Sentinel value indicating terrain data is not populated yet

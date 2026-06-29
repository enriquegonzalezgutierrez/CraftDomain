# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              NPC, Fauna, and interactive prop classes dynamically inside chunks.
#              MEGA-STRUCTURES UPGRADE: Safely pulls and spawns predefined 
#              entities from massive handcrafted POIs (like Castle Guards).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name MobSpawningService
extends RefCounted

func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	
	var is_real_village: bool = false
	var generator = world_node.get("generator")
	
	if is_instance_valid(generator):
		var terrain_noise = generator.get("_terrain_noise")
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			var profile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise)
			is_real_village = (profile.landmark_id == 3)

	# 1. Procedural Village Spawning
	if is_real_village:
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list, "lost_bazaar") # Villager
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list, "fuel_fryer") # Merchant
		_spawn_and_register_entity(102, chunk_offset, 10.5, 10.5, world_state, world_node, entities_list, "plains_defender") # Guard
		_spawn_and_register_entity(103, chunk_offset, 2.5, 12.5, world_state, world_node, entities_list, "") # Farmer
		_spawn_and_register_entity(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list, "") # Chest
			
	# 2. Fauna Spawning
	var should_spawn_animal: bool = (abs(chunk_pos.x) * 7 + abs(chunk_pos.z) * 13) % 5 < 2
	if should_spawn_animal:
		var spawn_roll: int = int(abs(chunk_pos.x + chunk_pos.z)) % 4
		_spawn_and_register_entity(spawn_roll, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")

	# 3. GLOBAL MEGA-STRUCTURE SPAWNS (Castle Guards, Harbor Merchants, etc.)
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata in mega_entities:
		var mob_id: int = edata["mob_id"]
		var exact_pos: Vector3 = edata["pos"]
		
		if MobRegistry.has_mob(mob_id):
			var entity: Node = MobRegistry.create_mob(mob_id, exact_pos)
			if entity != null:
				world_node.add_child(entity)
				entities_list.append(entity)
				print("[MobSpawningService] Spawned MegaStructure NPC (ID:", mob_id, ") at ", exact_pos)

	return entities_list

func _spawn_and_register_entity(mob_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node], quest_sync_id: String) -> void:
	if not MobRegistry.has_mob(mob_id): return
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	var pos := offset + Vector3(lx, gy, lz)
	
	var entity: Node = MobRegistry.create_mob(mob_id, pos)
	if entity != null:
		world_node.add_child(entity)
		list.append(entity)
		if quest_sync_id != "":
			var quest := QuestService.get_quest(quest_sync_id)
			if quest != null:
				quest.target_position = pos

func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		if BlockType.is_solid(world_state.get_block(check_pos)):
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0 
	return 11.0

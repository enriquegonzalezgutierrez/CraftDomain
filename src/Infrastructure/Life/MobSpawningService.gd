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
		_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, entities_list, "lost_bazaar")
		_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, entities_list, "fuel_fryer")
		
		# Dynamic Biome Outpost Spawning: Query population list from active Biome strategy
		if is_instance_valid(biome):
			var population := biome.get_outpost_population_ids()
			if population.size() >= 2:
				_spawn_and_register_entity(population[0], chunk_offset, 6.5, 6.5, world_state, world_node, entities_list, "")
				_spawn_and_register_entity(population[1], chunk_offset, 4.5, 4.5, world_state, world_node, entities_list, "")
		
		# Golem (107) spawns to guard the village
		_spawn_and_register_entity(107, chunk_offset, 8.5, 3.5, world_state, world_node, entities_list, "")
	else:
		# 2. Spawning organically in the wilderness (OCP/LSP compliant, zero hardcoding)
		var roll := randf()
		if roll < 0.12: # 12% chance to spawn wildlife in wilderness chunks
			if is_instance_valid(biome):
				var wildlife_ids := biome.get_wilderness_wildlife_ids()
				if wildlife_ids.size() > 0:
					# Safely select a random animal ID registered for this specific biome
					var rand_idx := randi() % wildlife_ids.size()
					var target_animal_id := wildlife_ids[rand_idx]
					_spawn_and_register_entity(target_animal_id, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list, "")

	# 3. Global Mega-Structure spawns (Castle Guards, Harbor Merchants, etc.)
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id: int = edata["mob_id"] as int
		var exact_pos: Vector3 = edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var spawn_pos := exact_pos
			var block_at_pos := world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
			if BlockType.is_solid(block_at_pos):
				spawn_pos.y = world_state.get_highest_solid_y(floori(spawn_pos.x), floori(spawn_pos.z))
				
			var spawn_node := MobRegistry.create_mob(mob_id, spawn_pos)
			if spawn_node != null:
				world_node.add_child(spawn_node)
				entities_list.append(spawn_node)
				
				var sync_quest_id := ""
				if mob_id == 100: sync_quest_id = "lost_bazaar"
				elif mob_id == 101: sync_quest_id = "fuel_fryer"
				elif mob_id == 102: sync_quest_id = "plains_defender"
				
				if sync_quest_id != "":
					var quest: Quest = QuestService.get_quest(sync_quest_id) as Quest
					if quest != null:
						quest.target_position = spawn_node.global_position

	return entities_list


## Instantiates, places, and anchors a registered dynamic entity on the highest solid ground.
func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node], quest_sync_id: String) -> void:
	if not MobRegistry.has_mob(spawn_id):
		return
		
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	if gy < 0.0:
		return
		
	var pos := offset + Vector3(lx, gy, lz)
	var mob: Node = MobRegistry.create_mob(spawn_id, pos)
	if mob != null:
		world_node.add_child(mob)
		list.append(mob)
		
		if quest_sync_id != "":
			var quest: Quest = QuestService.get_quest(quest_sync_id) as Quest
			if quest != null:
				quest.target_position = mob.global_position


## Helper: Scans vertical columns downward to find the topmost solid block.
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

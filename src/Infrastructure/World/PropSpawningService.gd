# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              inert scenery props and interactive decorations inside newly loaded chunks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively coordinates procedural 
#   decorative prop placements.
# - Open-Closed Principle (OCP): Works dynamically based on the global PropRegistry.
# CLEANUP NOTE:
#              - Removed RitualStoneEntity (ID 214) from the redwood forest 
#                procedural spawning pool, re-balancing the remaining prop probabilities.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/PropSpawningService.gd
# ==============================================================================
class_name PropSpawningService
extends RefCounted


## Spawns dynamic scenery props and interactive decorations inside a newly loaded chunk.
func spawn_props_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
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

	# 1. Spawning inside Village Outposts (Chests, streetlights, campfires, wells, and loot barrels)
	if is_real_village:
		# Loot chest spawns in all outposts (ID 200)
		_spawn_and_register_prop(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list)
		
		# Streetlight spawns in all village outposts (ID 202)
		_spawn_and_register_prop(202, chunk_offset, 2.5, 10.5, world_state, world_node, entities_list)
		
		# Campfire spawns at the heart of the village outpost (ID 203)
		_spawn_and_register_prop(203, chunk_offset, 8.5, 3.5, world_state, world_node, entities_list)
		
		# Wishing well spawns in the village plaza (ID 213)
		_spawn_and_register_prop(213, chunk_offset, 10.5, 3.5, world_state, world_node, entities_list)
		
		# Loot barrels spawn around the village perimeter (ID 215)
		_spawn_and_register_prop(215, chunk_offset, 6.5, 9.5, world_state, world_node, entities_list)
		_spawn_and_register_prop(215, chunk_offset, 11.5, 6.5, world_state, world_node, entities_list)
	else:
		# 2. Spawning organically in the wilderness (Out of villages)
		var roll := randf()
		if roll < 0.12:
			if active_biome_id == 2: # Plains (Rare Wishing Wells and Wild Barrels)
				if roll < 0.03:
					_spawn_and_register_prop(213, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)
				elif roll < 0.06: 
					_spawn_and_register_prop(215, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)
			elif active_biome_id == 5: # Redwood Forest (Wishing Wells and Barrels)
				if roll < 0.03: # 3% chance for a wishing well (Adjusted)
					_spawn_and_register_prop(213, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)
				elif roll < 0.06: # 3% chance for a hidden loot barrel
					_spawn_and_register_prop(215, chunk_offset, 8.5, 8.5, world_state, world_node, entities_list)

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
		
	var pos := offset + Vector3(lx, gy, lz)
	var prop: Node = PropRegistry.create_prop(prop_id, pos)
	if prop != null:
		world_node.add_child(prop)
		list.append(prop)


## Helper: Scans vertical columns downward to find the topmost solid floor-like block.
func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		if block_type == BlockType.Type.GRASS or block_type == BlockType.Type.DIRT or \
		   block_type == BlockType.Type.STONE or block_type == BlockType.Type.SAND or \
		   block_type == BlockType.Type.RED_SAND or block_type == BlockType.Type.MUD or \
		   block_type == BlockType.Type.SNOW or block_type == BlockType.Type.ICE or \
		   block_type == BlockType.Type.BRICKS: 
			
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0
				
	return -1.0

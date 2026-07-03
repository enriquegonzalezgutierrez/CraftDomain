# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service responsible for calculating and spawning
#              inert interactive scenery props (chests, streetlights) inside chunks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively handles the spawning and
#   placement of inanimate/interactive world decorations, completely freeing
#   MobSpawningService from managing non-living objects.
# - Open-Closed Principle (OCP): Queries PropRegistry dynamically, allowing new 
#   decorations to be placed without modifying this service's internal registration mappings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/PropSpawningService.gd
# ==============================================================================
class_name PropSpawningService
extends RefCounted

## Spawns village loot chests and streetlights inside a newly loaded chunk.
func spawn_props_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var props_list: Array[Node] = []
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

	# 1. Spawning inside Village Outposts
	if is_real_village:
		# Loot chest spawns in all village outposts (ID 200)
		_spawn_and_register_prop(200, chunk_offset, 4.5, 8.5, world_state, world_node, props_list)
		
		# Streetlight spawns in all village outposts (ID 202)
		_spawn_and_register_prop(202, chunk_offset, 2.5, 10.5, world_state, world_node, props_list)
	else:
		# 2. Spawning organically in the wilderness
		# We spawn streetlights organically in ALL land-based biomes, skipping only 
		# deep oceans (0) and floating sky islands (9).
		if active_biome_id != 0 and active_biome_id != 9:
			var should_spawn_organic_light: bool = (abs(chunk_pos.x) * 11 + abs(chunk_pos.z) * 17) % 35 == 3
			if should_spawn_organic_light:
				_spawn_and_register_prop(202, chunk_offset, 8.5, 8.5, world_state, world_node, props_list)

	return props_list


## Instantiates, places, and anchors a registered prop on the highest solid ground.
func _spawn_and_register_prop(prop_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not PropRegistry.has_prop(prop_id):
		return
		
	var gy := _get_ground_surface_y(world_state, int(offset.x + lx), int(offset.z + lz))
	if gy < 0.0:
		return # Abort if ground is not populated yet (prevents clipping/underground spawns)
		
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
		
		# Spawns props only on valid load-bearing blocks
		if block_type == BlockType.Type.GRASS or block_type == BlockType.Type.DIRT or \
		   block_type == BlockType.Type.STONE or block_type == BlockType.Type.SAND or \
		   block_type == BlockType.Type.RED_SAND or block_type == BlockType.Type.MUD or \
		   block_type == BlockType.Type.SNOW or block_type == BlockType.Type.ICE:
			
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
				return float(y) + 1.0
				
	return -1.0

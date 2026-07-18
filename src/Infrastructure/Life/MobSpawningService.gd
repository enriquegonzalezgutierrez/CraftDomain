# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MobSpawningService.gd
# Description: Infrastructure Service responsible for managing dynamic herd
#              spawning, local chunk populating, and threat patrols (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobSpawningService
extends RefCounted


## Spawns procedural wildlife and themed outpost entities inside a newly loaded chunk.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	var chunk_pos: Vector3i = chunk.position
	
	if chunk_pos.y == 0:
		var upper_chunk := world_state.get_chunk(Vector3i(chunk_pos.x, 1, chunk_pos.z))
		if upper_chunk == null:
			return [] 
			
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	_process_chunk_spawning(chunk, chunk_offset, world_state, world_node, spawned_nodes)
	return spawned_nodes


func _process_chunk_spawning(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var biome_id := _detect_chunk_biome_id(chunk.position, world_node)
	var biome := BiomeService.get_biome(biome_id)
	var is_real_village := _is_village_chunk(chunk.position, world_node)

	if is_real_village:
		_spawn_village_mobs(chunk_offset, world_state, world_node, spawned_nodes)
	else:
		_spawn_wilderness_wildlife(chunk_offset, world_state, world_node, biome, spawned_nodes)

	_spawn_megastructure_defenders(chunk.position, world_state, world_node, spawned_nodes)


func _spawn_village_mobs(chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	# Symmetrical Village Spawning: Allows any solid block (foundation/road/floor) for NPCs
	_spawn_and_register_entity(100, chunk_offset, 7.5, 5.5, world_state, world_node, spawned_nodes, true)
	_spawn_and_register_entity(101, chunk_offset, 5.5, 7.5, world_state, world_node, spawned_nodes, true)
	_spawn_and_register_entity(107, chunk_offset, 8.5, 5.5, world_state, world_node, spawned_nodes, true)


func _spawn_wilderness_wildlife(chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, spawned_nodes: Array[Node]) -> void:
	var roll := randf()
	var spawn_chance := 0.28 
	if is_instance_valid(biome) and biome.has_method("get_spawn_chance"):
		spawn_chance = biome.call("get_spawn_chance") as float
		
	if roll < spawn_chance and is_instance_valid(biome):
		var wildlife_ids := biome.get_wilderness_wildlife_ids()
		if wildlife_ids.size() > 0:
			_spawn_wildlife_group(wildlife_ids, chunk_offset, world_state, world_node, spawned_nodes)


func _spawn_wildlife_group(wildlife_ids: Array[int], chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var rand_idx := randi() % wildlife_ids.size()
	var spawn_id := int(wildlife_ids[rand_idx])
	
	var group_size := randi_range(2, 4)
	for i: int in range(group_size):
		var rx := randf_range(2.0, 14.0)
		var rz := randf_range(2.0, 14.0)
		_spawn_and_register_entity(spawn_id, chunk_offset, rx, rz, world_state, world_node, spawned_nodes, false)


func _spawn_megastructure_defenders(chunk_pos: Vector3i, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id := edata["mob_id"] as int
		var exact_pos := edata["pos"] as Vector3
		
		if MobRegistry.has_mob(mob_id):
			var spawn_pos := exact_pos
			if _is_voxel_spawn_space_free(world_state, spawn_pos):
				var block_at_pos := world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
				if BlockType.is_solid(block_at_pos):
					spawn_pos.y = world_state.get_highest_solid_y(floori(spawn_pos.x), floori(spawn_pos.z))
					
				var spawn_node := MobRegistry.create_mob(mob_id, spawn_pos)
				if spawn_node != null:
					world_node.add_child(spawn_node)
					spawned_nodes.append(spawn_node)


func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node], allow_any_solid: bool = false) -> void:
	if not MobRegistry.has_mob(spawn_id): return
		
	var global_x := int(offset.x + lx)
	var global_z := int(offset.z + lz)
	var habitat := MobRegistry.get_mob_habitat(spawn_id)
	var gy := _resolve_habitat_ground_y(world_state, global_x, global_z, habitat, allow_any_solid)
	
	if gy < 0.0: return 
		
	var pos := Vector3(offset.x + lx, gy, offset.z + lz)
	if _is_voxel_spawn_space_free(world_state, pos):
		var mob := MobRegistry.create_mob(spawn_id, pos)
		if mob != null:
			world_node.add_child(mob)
			list.append(mob)


func _resolve_habitat_ground_y(world_state: WorldState, global_x: int, global_z: int, habitat: int, allow_any_solid: bool) -> float:
	var gy := -1.0
	if habitat == MobRegistry.Habitat.TERRESTRIAL:
		gy = _get_ground_surface_y(world_state, global_x, global_z, allow_any_solid)
	elif habitat == MobRegistry.Habitat.AQUATIC:
		gy = _get_water_surface_y(world_state, global_x, global_z)
	else:
		gy = _get_water_surface_y(world_state, global_x, global_z)
		if gy < 0.0:
			gy = _get_ground_surface_y(world_state, global_x, global_z, allow_any_solid)
	return gy


func _get_ground_surface_y(world_state: WorldState, global_x: int, global_z: int, allow_any_solid: bool) -> float:
	var top_block_type := BlockType.Type.AIR
	var top_y := -1
	
	for y: int in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		if block_type != BlockType.Type.AIR:
			top_block_type = block_type
			top_y = y
			break
			
	if top_y == -1 or top_block_type == BlockType.Type.WATER or top_block_type == BlockType.Type.LAVA:
		return -1.0 
	
	return _solve_solid_ground_height(world_state, global_x, global_z, top_y, allow_any_solid)


func _solve_solid_ground_height(world_state: WorldState, global_x: int, global_z: int, top_y: int, allow_any_solid: bool) -> float:
	var hit_y := -1
	for y: int in range(top_y, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		if block_type != BlockType.Type.AIR and block_type != BlockType.Type.WATER:
			hit_y = y
			break
			
	if hit_y == -1: return -1.0
		
	var surface_block := world_state.get_block(Vector3i(global_x, hit_y, global_z))
	var def := BlockLibrary.get_definition(surface_block) as BlockDefinition
	
	if def == null or (not allow_any_solid and not def.is_spawnable_soil) or (allow_any_solid and not def.is_solid):
		return -1.0
		
	var space_above_1 := world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
	var space_above_2 := world_state.get_block(Vector3i(global_x, hit_y + 2, global_z))
	if not BlockType.is_solid(space_above_1) and not BlockType.is_solid(space_above_2):
		return float(hit_y) + 1.0
		
	return -1.0


func _get_water_surface_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	var hit_y := -1
	
	for y: int in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		if block_type != BlockType.Type.AIR:
			hit_y = y
			break
			
	if hit_y == -1: return -1.0
		
	var surface_block := world_state.get_block(Vector3i(global_x, hit_y, global_z))
	if surface_block == BlockType.Type.WATER:
		var space_above_1 := world_state.get_block(Vector3i(global_x, hit_y + 1, global_z))
		if not BlockType.is_solid(space_above_1):
			return float(hit_y) - 1.2
			
	return -1.0


func _is_voxel_spawn_space_free(world_state: WorldState, spawn_pos: Vector3) -> bool:
	var base_coord := Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z))
	
	var feet_block := world_state.get_block(base_coord)
	var chest_block := world_state.get_block(base_coord + Vector3i(0, 1, 0))
	
	return not BlockType.is_solid(feet_block) and not BlockType.is_solid(chest_block)


func _detect_chunk_biome_id(chunk_pos: Vector3i, world_node: Node) -> int:
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			return profile.biome_id
	return 2


func _is_village_chunk(chunk_pos: Vector3i, world_node: Node) -> bool:
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + 8
			var center_z := chunk_pos.z * Chunk.SIZE + 8
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			return profile.landmark_id == 3
	return false

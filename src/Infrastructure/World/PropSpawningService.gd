# ==============================================================================
# Pathfile: res://src/Infrastructure/World/PropSpawningService.gd
# Description: Infrastructure Service responsible for calculating and spawning
#              inert scenery props and interactive decorations inside loaded chunks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates all static prop instantiations.
# - Thread-Safe Physics (DDD Inversion): Removed direct physics server space queries 
#   (which caused thread locks during idle frames) in favor of pure, 
#   high-performance, and thread-safe WorldState voxel occupancy checks.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PropSpawningService
extends RefCounted


func spawn_props_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var entities_list: Array[Node] = []
	var chunk_pos := chunk.position
	
	if chunk_pos.y == 0:
		var upper_chunk := world_state.get_chunk(Vector3i(chunk_pos.x, 1, chunk_pos.z))
		if upper_chunk == null:
			return [] 
			
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	_process_chunk_spawning(chunk, chunk_offset, world_state, world_node, entities_list)
	return entities_list


func _process_chunk_spawning(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, entities_list: Array[Node]) -> void:
	var biome_id := _detect_chunk_biome_id(chunk.position, world_node)
	var biome := BiomeService.get_biome(biome_id)
	var is_real_village := _is_village_chunk(chunk.position, world_node)

	if is_real_village:
		_spawn_village_props(chunk_offset, world_state, world_node, entities_list)
	else:
		_scatter_wilderness_vegetation(chunk, chunk_offset, world_state, world_node, biome, entities_list)

	_spawn_megastructure_props(chunk.position, world_state, world_node, entities_list)
	_spawn_roadside_streetlights(chunk.position, world_state, world_node, entities_list)


func _spawn_village_props(chunk_offset: Vector3, world_state: WorldState, world_node: Node, entities_list: Array[Node]) -> void:
	_spawn_and_register_prop(200, chunk_offset, 4.5, 8.5, world_state, world_node, entities_list)
	_spawn_and_register_prop(202, chunk_offset, 2.5, 10.5, world_state, world_node, entities_list)
	_spawn_and_register_prop(203, chunk_offset, 8.5, 3.5, world_state, world_node, entities_list)
	_spawn_and_register_prop(213, chunk_offset, 10.5, 3.5, world_state, world_node, entities_list)
	_spawn_and_register_prop(215, chunk_offset, 6.5, 9.5, world_state, world_node, entities_list)
	_spawn_and_register_prop(215, chunk_offset, 11.5, 6.5, world_state, world_node, entities_list)


func _scatter_wilderness_vegetation(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, entities_list: Array[Node]) -> void:
	var chunk_pos := chunk.position
	var scatter_hash: int = abs(chunk_pos.x * 93856093 ^ chunk_pos.z * 29349663)
	var rng := RandomNumberGenerator.new()
	rng.seed = scatter_hash
	
	var plants_count := rng.randi_range(4, 8)
	for i in range(plants_count):
		_spawn_random_vegetation_prop(chunk_offset, world_state, world_node, biome, rng, entities_list)


func _spawn_random_vegetation_prop(chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, rng: RandomNumberGenerator, entities_list: Array[Node]) -> void:
	var rx: float = rng.randf_range(1.5, 14.5)
	var rz: float = rng.randf_range(1.5, 14.5)
	var local_hash: int = int(abs(int(rx) * 3121 ^ int(rz) * 1933))
	
	var global_x: float = chunk_offset.x + rx
	var global_z: float = chunk_offset.z + rz
	
	if RoadGeneratorService.is_on_road(global_x, global_z):
		return
		
	var target_prop_id := 0
	if is_instance_valid(biome) and biome.has_method("get_wilderness_prop_id"):
		target_prop_id = biome.call("get_wilderness_prop_id", local_hash) as int
		
	if target_prop_id > 0 and PropRegistry.has_prop(target_prop_id):
		_spawn_and_register_prop(target_prop_id, chunk_offset, rx, rz, world_state, world_node, entities_list)


func _spawn_megastructure_props(chunk_pos: Vector3i, world_state: WorldState, world_node: Node, entities_list: Array[Node]) -> void:
	var mega_entities := MegaStructureService.get_entities_for_chunk(chunk_pos)
	for edata: Dictionary in mega_entities:
		var mob_id := edata["mob_id"] as int
		var exact_pos := edata["pos"] as Vector3
		
		if PropRegistry.has_prop(mob_id):
			var spawn_pos := exact_pos
			if _is_voxel_spawn_space_free(world_state, spawn_pos):
				var block_at_pos := world_state.get_block(Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z)))
				if BlockType.is_solid(block_at_pos):
					spawn_pos.y = _get_structural_ground_y(world_state, floori(spawn_pos.x), floori(spawn_pos.z))
					
				var prop := PropRegistry.create_prop(mob_id, spawn_pos)
				if prop != null:
					world_node.add_child(prop)
					entities_list.append(prop)


func _spawn_roadside_streetlights(chunk_pos: Vector3i, world_state: WorldState, world_node: Node, entities_list: Array[Node]) -> void:
	var lamps := RoadGeneratorService.get_roadside_lamps_for_chunk(chunk_pos)
	for lamp_pos: Vector3 in lamps:
		_evaluate_and_spawn_streetlight(lamp_pos, chunk_pos, world_state, world_node, entities_list)


func _evaluate_and_spawn_streetlight(lamp_pos: Vector3, chunk_pos: Vector3i, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	var gx := floori(lamp_pos.x)
	var gz := floori(lamp_pos.z)
	
	var gy := _get_structural_ground_y(world_state, gx, gz)
	if gy <= 0.0: 
		return
	
	var floor_block := world_state.get_block(Vector3i(gx, floori(gy - 1.0), gz))
	if floor_block == BlockType.Type.WATER or floor_block == BlockType.Type.LAVA:
		return
		
	var spawn_pos := Vector3(lamp_pos.x, gy, lamp_pos.z)
	_instantiate_streetlight(spawn_pos, chunk_pos, world_state, world_node, list)


func _instantiate_streetlight(spawn_pos: Vector3, chunk_pos: Vector3i, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if _is_voxel_spawn_space_free(world_state, spawn_pos):
		var prop := PropRegistry.create_prop(202, spawn_pos) 
		if prop != null:
			_apply_streetlight_theme(prop, chunk_pos, world_node)
			world_node.add_child(prop)
			list.append(prop)


func _apply_streetlight_theme(prop: Node, chunk_pos: Vector3i, world_node: Node) -> void:
	if prop.has_method("apply_biome_theme"):
		var biome_id := _detect_chunk_biome_id(chunk_pos, world_node)
		var biome := BiomeService.get_biome(biome_id)
		if biome != null and biome.has_method("get_streetlight_theme"):
			prop.call("apply_biome_theme", biome.get_streetlight_theme())


func _spawn_and_register_prop(prop_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not PropRegistry.has_prop(prop_id): return
		
	var gy := _get_biological_ground_y(world_state, int(offset.x + lx), int(offset.z + lz))
	if gy < 0.0: return 
		
	var pos := Vector3(offset.x + lx, gy, offset.z + lz)
	var prop := PropRegistry.create_prop(prop_id, pos)
	if prop != null:
		world_node.add_child(prop)
		list.append(prop)


func _get_structural_ground_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		if BlockType.is_solid(world_state.get_block(check_pos)):
			var above1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var above2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			if not BlockType.is_solid(above1) and not BlockType.is_solid(above2):
				return float(y) + 1.0
	return -1.0


func _get_biological_ground_y(world_state: WorldState, global_x: int, global_z: int) -> float:
	for y in range(31, -1, -1):
		var check_pos := Vector3i(global_x, y, global_z)
		var block_type := world_state.get_block(check_pos)
		
		var def := BlockLibrary.get_definition(block_type) as BlockDefinition
		if def != null and def.is_spawnable_soil:
			var space_above_1 := world_state.get_block(check_pos + Vector3i(0, 1, 0))
			var space_above_2 := world_state.get_block(check_pos + Vector3i(0, 2, 0))
			
			if space_above_1 == BlockType.Type.AIR and space_above_2 == BlockType.Type.AIR:
				return float(y) + 1.0
				
	return -1.0


## Symmetrical Voxel Occupancy Solver: Pure, thread-safe memory lookup replacing 
## expensive and non-thread-safe C++ physics direct space state queries.
func _is_voxel_spawn_space_free(world_state: WorldState, spawn_pos: Vector3) -> bool:
	var base_coord := Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z))
	
	var feet_block := world_state.get_block(base_coord)
	var chest_block := world_state.get_block(base_coord + Vector3i(0, 1, 0))
	
	# The coordinate is legally free if both feet and chest spaces are non-solid
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

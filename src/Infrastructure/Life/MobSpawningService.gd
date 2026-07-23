# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MobSpawningService.gd
# Description: Infrastructure Service managing dynamic entity spawning, local
#              chunk population, spatial mob separation, and quest objectives.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobSpawningService
extends RefCounted

const QUEST_TARGET_MOBS: Dictionary = {
	"lost_bazaar": 100,       
	"fuel_fryer": 101,        
	"plains_defender": 10,    
	"bazaar_return": 100      
}

const MOB_ID_PIG: int = 0
const MOB_ID_CHICKEN: int = 1
const MOB_ID_SHEEP: int = 2
const MOB_ID_COW: int = 3
const MOB_ID_SHARK: int = 11
const MOB_ID_TURTLE: int = 201
const MOB_ID_OCTOPUS: int = 210

const OFFSET_D: float = 11.5
const OFFSET_HALF_CHUNK: float = 8.0
const HEIGHT_MAX_TERRAIN_LIMIT: int = 31
const STRAY_PROBABILITY_THRESHOLD: float = 0.20
const MIN_MOB_SEPARATION_SQ: float = 144.0


## Spawns procedural wildlife and themed outpost entities inside a loaded chunk.
func spawn_mobs_for_chunk(chunk: Chunk, world_node: Node, world_state: WorldState) -> Array[Node]:
	var spawned_nodes: Array[Node] = []
	var chunk_pos: Vector3i = chunk.position
	
	if chunk_pos.y == 0 and world_state.get_chunk(Vector3i(chunk_pos.x, 1, chunk_pos.z)) == null:
		return [] 
			
	var chunk_offset := Vector3(chunk_pos * Chunk.SIZE)
	_process_chunk_spawning(chunk, chunk_offset, world_state, world_node, spawned_nodes)
	return spawned_nodes


func _process_chunk_spawning(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var biome_id := _detect_chunk_biome_id(chunk.position, world_node)
	var biome := BiomeService.get_biome(biome_id)
	var is_real_village := _is_village_chunk(chunk.position, world_node)

	if is_real_village:
		_spawn_village_mobs(chunk_offset, world_state, world_node, biome, spawned_nodes)
		_spawn_village_stray_animals(chunk_offset, world_state, world_node, spawned_nodes)
	else:
		_spawn_wilderness_wildlife(chunk_offset, world_state, world_node, biome, spawned_nodes)

	_spawn_megastructure_defenders(chunk.position, world_state, world_node, spawned_nodes)
	_spawn_active_quest_objectives(chunk, chunk_offset, world_state, world_node, spawned_nodes)


func _spawn_village_mobs(chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, spawned_nodes: Array[Node]) -> void:
	var civilian_ids := biome.get_village_civilian_ids()
	if civilian_ids.is_empty(): return
		
	var spawn_id: int = civilian_ids[randi() % civilian_ids.size()]
	_spawn_and_register_entity(spawn_id, chunk_offset, randf_range(2.0, 14.0), randf_range(2.0, 14.0), world_state, world_node, spawned_nodes)


func _spawn_village_stray_animals(chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	if randf() < STRAY_PROBABILITY_THRESHOLD:
		var stray_ids: Array[int] = [MOB_ID_PIG, MOB_ID_CHICKEN, MOB_ID_SHEEP, MOB_ID_COW] 
		var spawn_id: int = stray_ids[randi() % stray_ids.size()]
		_spawn_and_register_entity(spawn_id, chunk_offset, OFFSET_D, OFFSET_D, world_state, world_node, spawned_nodes)


func _spawn_wilderness_wildlife(chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, spawned_nodes: Array[Node]) -> void:
	if randf() < biome.get_spawn_probability():
		var wildlife_ids := _get_dynamic_wildlife_table(biome, chunk_offset, world_state)
		if wildlife_ids.size() > 0:
			_spawn_individual_wildlife(wildlife_ids, chunk_offset, world_state, world_node, spawned_nodes)


func _get_dynamic_wildlife_table(biome: IBiome, chunk_offset: Vector3, world_state: WorldState) -> Array[int]:
	var list := biome.get_wilderness_wildlife_ids()
	var sample_pos := chunk_offset + Vector3(OFFSET_HALF_CHUNK, 0.0, OFFSET_HALF_CHUNK)
	
	if _get_water_surface_y(world_state, floori(sample_pos.x), floori(sample_pos.z)) > 0.0:
		for id: int in [MOB_ID_SHARK, MOB_ID_TURTLE, MOB_ID_OCTOPUS]:
			if not list.has(id): list.append(id)
				
	return list


func _spawn_individual_wildlife(wildlife_ids: Array[int], chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var spawn_id := int(wildlife_ids[randi() % wildlife_ids.size()])
	_spawn_and_register_entity(spawn_id, chunk_offset, randf_range(2.0, 14.0), randf_range(2.0, 14.0), world_state, world_node, spawned_nodes)


func _spawn_megastructure_defenders(chunk_pos: Vector3i, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	for point in StructurePopulationService.get_population_for_chunk(chunk_pos):
		if not point.is_prop and MobRegistry.has_mob(point.spawn_id):
			_spawn_decoupled_landmark_mob(point, world_state, world_node, spawned_nodes)


func _spawn_decoupled_landmark_mob(point: StructurePopulationService.PopulationPoint, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var spawn_pos := point.global_pos
	var player_node := world_node.get("player") as CharacterBody3D if is_instance_valid(world_node) else null
	
	if is_instance_valid(player_node) and spawn_pos.distance_to(player_node.global_position) < 1.2:
		spawn_pos += Vector3(1.2, 0.0, 1.2) 
		
	if _is_voxel_spawn_space_free(world_state, spawn_pos):
		var spawn_node := MobRegistry.create_mob(point.spawn_id, spawn_pos)
		if spawn_node != null:
			spawn_node.set_meta("spawn_id", point.spawn_id)
			world_node.add_child(spawn_node)
			spawned_nodes.append(spawn_node)


func _spawn_active_quest_objectives(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var active_q := QuestService.get_active_quest() as Quest
	if active_q == null or not QUEST_TARGET_MOBS.has(active_q.quest_id): return
		
	var target_pos := active_q.target_position
	if world_state.global_to_chunk_pos(Vector3i(target_pos)).x == chunk.position.x and world_state.global_to_chunk_pos(Vector3i(target_pos)).z == chunk.position.z:
		var mob_id: int = QUEST_TARGET_MOBS[active_q.quest_id]
		# DETECTOR FIX: Scan both integrated nodes and current frame spawned_nodes array to prevent duplicates
		var existing := _find_eligible_entity_in_list(world_node, spawned_nodes, mob_id, target_pos)
		
		if existing != null:
			existing.quest_target_id = active_q.quest_id
		else:
			_spawn_exact_quest_mob(mob_id, target_pos, chunk_offset, world_state, world_node, spawned_nodes, active_q.quest_id)


func _find_eligible_entity_in_list(world_node: Node, spawned_nodes: Array[Node], mob_id: int, target_pos: Vector3) -> CharacterBody3D:
	if is_instance_valid(world_node):
		for child in world_node.get_children():
			if child is CharacterBody3D and child.has_meta("spawn_id") and int(child.get_meta("spawn_id")) == mob_id:
				if child.global_position.distance_squared_to(target_pos) <= 625.0: # 25m squared
					return child as CharacterBody3D
					
	for child in spawned_nodes:
		if child is CharacterBody3D and child.has_meta("spawn_id") and int(child.get_meta("spawn_id")) == mob_id:
			if child.global_position.distance_squared_to(target_pos) <= 625.0:
				return child as CharacterBody3D
				
	return null


func _spawn_exact_quest_mob(mob_id: int, target_pos: Vector3, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node], quest_id: String) -> void:
	var spawn_pos := target_pos
	if _is_voxel_spawn_space_free(world_state, spawn_pos):
		var mob := MobRegistry.create_mob(mob_id, spawn_pos)
		if mob != null:
			mob.set_meta("spawn_id", mob_id)
			mob.quest_target_id = quest_id
			world_node.add_child(mob)
			spawned_nodes.append(mob)
	else:
		_spawn_and_register_entity(mob_id, chunk_offset, OFFSET_HALF_CHUNK, OFFSET_HALF_CHUNK, world_state, world_node, spawned_nodes)


func _spawn_and_register_entity(spawn_id: int, offset: Vector3, lx: float, lz: float, world_state: WorldState, world_node: Node, list: Array[Node]) -> void:
	if not MobRegistry.has_mob(spawn_id): return
		
	var global_x := int(offset.x + lx)
	var global_z := int(offset.z + lz)
	var gy := _resolve_habitat_ground_y(world_state, global_x, global_z, spawn_id)
	if gy < 0.0: return 
		
	var pos := Vector3(offset.x + lx, gy, offset.z + lz)
	if _is_spawn_point_too_close(world_node, pos): return
		
	if _is_voxel_spawn_space_free(world_state, pos):
		var mob := MobRegistry.create_mob(spawn_id, pos)
		if mob != null:
			mob.set_meta("spawn_id", spawn_id)
			world_node.add_child(mob)
			list.append(mob)


static func _is_spawn_point_too_close(world_node: Node, pos: Vector3) -> bool:
	if not is_instance_valid(world_node): return false
	for child in world_node.get_children():
		if child is CharacterBody3D and child.has_meta("spawn_id"):
			if child.global_position.distance_squared_to(pos) < MIN_MOB_SEPARATION_SQ:
				return true
	return false


func _resolve_habitat_ground_y(world_state_ref: WorldState, global_x: int, global_z: int, spawn_id: int) -> float:
	var zone := MobRegistry.get_mob_spawn_zone(spawn_id)
	match zone:
		MobRegistry.SpawnZone.AQUATIC:
			return _get_water_surface_y(world_state_ref, global_x, global_z)
		MobRegistry.SpawnZone.SUBTERRANEAN:
			return SpawnCoordinateSolver.solve_cave_y(world_state_ref, global_x, global_z)
		_:
			return SpawnCoordinateSolver.solve_surface_y(world_state_ref, global_x, global_z)


func _get_water_surface_y(world_state_ref: WorldState, global_x: int, global_z: int) -> float:
	var hit_y := -1
	for y: int in range(HEIGHT_MAX_TERRAIN_LIMIT, -1, -1):
		if world_state_ref.get_block(Vector3i(global_x, y, global_z)) != BlockType.Type.AIR:
			hit_y = y
			break
			
	if hit_y == -1: return -1.0
	if world_state_ref.get_block(Vector3i(global_x, hit_y, global_z)) == BlockType.Type.WATER:
		if not BlockLibrary.is_solid(world_state_ref.get_block(Vector3i(global_x, hit_y + 1, global_z))):
			return float(hit_y) - 0.35
			
	return -1.0


func _is_voxel_spawn_space_free(world_state_ref: WorldState, spawn_pos: Vector3) -> bool:
	var base_coord := Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z))
	var feet_block := world_state_ref.get_block(base_coord)
	var chest_block := world_state_ref.get_block(base_coord + Vector3i(0, 1, 0))
	return not BlockLibrary.is_solid(feet_block) and not BlockLibrary.is_solid(chest_block)


func _detect_chunk_biome_id(chunk_pos: Vector3i, world_node: Node) -> int:
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(chunk_pos.x * Chunk.SIZE + 8, chunk_pos.z * Chunk.SIZE + 8, noise) as BiomeService.BiomeProfile
			return profile.biome_id
	return 2


func _is_village_chunk(chunk_pos: Vector3i, world_node: Node) -> bool:
	var generator: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(chunk_pos.x * Chunk.SIZE + 8, chunk_pos.z * Chunk.SIZE + 8, noise) as BiomeService.BiomeProfile
			return profile.landmark_id == 3
	return false

# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/MobSpawningService.gd
# Description: Infrastructure Service responsible for managing dynamic herd
#              spawning, local chunk populating, and mission objective targets.
#              SOLID COMPLIANCE: Decomposed into highly cohesive, short sub-methods.
#              Introduced an OCP-compliant Quest Objective Spawner with explicit
#              target allocation to eliminate duplicates and double arrows.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobSpawningService
extends RefCounted

# --- SOLID OCP CONFIGURATIONS (Section 3.2 / 5.3) ---
const QUEST_TARGET_MOBS: Dictionary = {
	"lost_bazaar": 100,       # Villager Entity ID (Act I)
	"fuel_fryer": 101,        # Merchant Entity ID (Act I)
	"plains_defender": 10,    # Cave Zombie ID (The plains threat!)
	"bazaar_return": 100      # Villager Entity ID (Act IV Epilogue)
}

# --- STATIC CONSTANTS FOR ELIMINATING MAGIC NUMBERS (Section 5.3) ---
const MOB_ID_PIG: int = 0
const MOB_ID_CHICKEN: int = 1
const MOB_ID_SHEEP: int = 2
const MOB_ID_COW: int = 3
const MOB_ID_ZOMBIE: int = 10
const MOB_ID_SHARK: int = 11
const MOB_ID_VILLAGER: int = 100
const MOB_ID_MERCHANT: int = 101
const MOB_ID_GUARD: int = 102
const MOB_ID_GOLEM: int = 107
const MOB_ID_TURTLE: int = 201
const MOB_ID_OCTOPUS: int = 210

# Spawn coordinate offsets inside 16x16 chunk spaces
const OFFSET_A: float = 7.5
const OFFSET_B: float = 5.5
const OFFSET_C: float = 8.5
const OFFSET_D: float = 11.5
const OFFSET_E: float = 6.5
const OFFSET_HALF_CHUNK: float = 8.0

# Probability bounds and heights
const WILD_SPAWN_PROBABILITY_THRESHOLD: float = 0.25
const DEFAULT_WILDERNESS_SPAWN_CHANCE: float = 0.28
const HEIGHT_MAX_TERRAIN_LIMIT: int = 31
const VERTICAL_SENSORY_LIMIT: float = 12.0
const STRAY_PROBABILITY_THRESHOLD: float = 0.25


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
		_spawn_village_stray_animals(chunk_offset, world_state, world_node, spawned_nodes)
	else:
		_spawn_wilderness_wildlife(chunk_offset, world_state, world_node, biome, spawned_nodes)

	_spawn_megastructure_defenders(chunk.position, world_state, world_node, spawned_nodes)
	
	# SOLID UPGRADE: Ensure active quest targets are dynamically spawned in this chunk
	_spawn_active_quest_objectives(chunk, chunk_offset, world_state, world_node, spawned_nodes)


func _spawn_village_mobs(chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	_spawn_and_register_entity(MOB_ID_VILLAGER, chunk_offset, OFFSET_A, OFFSET_B, world_state, world_node, spawned_nodes, true)
	_spawn_and_register_entity(MOB_ID_MERCHANT, chunk_offset, OFFSET_B, OFFSET_A, world_state, world_node, spawned_nodes, true)
	_spawn_and_register_entity(MOB_ID_GOLEM, chunk_offset, OFFSET_C, OFFSET_B, world_state, world_node, spawned_nodes, true)


func _spawn_village_stray_animals(chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	if randf() < STRAY_PROBABILITY_THRESHOLD:
		var stray_ids: Array[int] = [MOB_ID_PIG, MOB_ID_CHICKEN, MOB_ID_SHEEP, MOB_ID_COW] 
		var spawn_id: int = stray_ids[randi() % stray_ids.size()]
		_spawn_and_register_entity(spawn_id, chunk_offset, OFFSET_D, OFFSET_D, world_state, world_node, spawned_nodes, false)


func _spawn_wilderness_wildlife(chunk_offset: Vector3, world_state: WorldState, world_node: Node, biome: IBiome, spawned_nodes: Array[Node]) -> void:
	var roll := randf()
	var spawn_chance := DEFAULT_WILDERNESS_SPAWN_CHANCE
	if is_instance_valid(biome) and biome.has_method("get_spawn_chance"):
		spawn_chance = biome.call("get_spawn_chance") as float
		
	if roll < spawn_chance and is_instance_valid(biome):
		var wildlife_ids := _get_dynamic_wildlife_table(biome, chunk_offset, world_state)
		if wildlife_ids.size() > 0:
			_spawn_wildlife_group(wildlife_ids, chunk_offset, world_state, world_node, spawned_nodes)


func _get_dynamic_wildlife_table(biome: IBiome, chunk_offset: Vector3, world_state: WorldState) -> Array[int]:
	var list := biome.get_wilderness_wildlife_ids()
	var sample_pos := chunk_offset + Vector3(OFFSET_HALF_CHUNK, 0.0, OFFSET_HALF_CHUNK)
	var hit_y := _get_water_surface_y(world_state, floori(sample_pos.x), floori(sample_pos.z))
	
	if hit_y > 0.0:
		var marine_life: Array[int] = [MOB_ID_SHARK, MOB_ID_TURTLE, MOB_ID_OCTOPUS] 
		for id: int in marine_life:
			if not list.has(id):
				list.append(id)
				
	return list


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
					spawn_node.set_meta("spawn_id", mob_id) # Metadata tag injected for O(1) tracking
					world_node.add_child(spawn_node)
					spawned_nodes.append(spawn_node)


# ==============================================================================
# SOLID QUEST OBJECTIVE GUARANTOR PIPELINE (SRP / OCP Compliant)
# ==============================================================================

func _spawn_active_quest_objectives(chunk: Chunk, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node]) -> void:
	var active_q := QuestService.get_active_quest() as Quest
	if active_q == null or not QUEST_TARGET_MOBS.has(active_q.quest_id):
		return
		
	var target_pos := active_q.target_position
	var target_chunk_pos := world_state.global_to_chunk_pos(Vector3i(target_pos))
	
	# Verifies if the active mission's target coordinates fall inside the loading chunk
	if target_chunk_pos == chunk.position:
		var mob_id: int = QUEST_TARGET_MOBS[active_q.quest_id]
		
		# 1. Search if an eligible entity has ALREADY been spawned in this chunk (Prevents double merchants)
		var existing_target := _find_eligible_entity_in_list(spawned_nodes, mob_id)
		if existing_target != null:
			existing_target.quest_target_id = active_q.quest_id
			print("[MobSpawning] Existing entity %s designated as unique Quest Target for %s" % [existing_target.name, active_q.quest_id])
			return
			
		# 2. If none exists, spawn a new unique one
		_spawn_exact_quest_mob(mob_id, target_pos, chunk_offset, world_state, world_node, spawned_nodes, active_q.quest_id)


func _find_eligible_entity_in_list(nodes: Array[Node], mob_id: int) -> CharacterBody3D:
	for node: Node in nodes:
		if node is CharacterBody3D and node.has_meta("spawn_id"):
			if int(node.get_meta("spawn_id")) == mob_id:
				return node as CharacterBody3D
	return null


func _spawn_exact_quest_mob(mob_id: int, target_pos: Vector3, chunk_offset: Vector3, world_state: WorldState, world_node: Node, spawned_nodes: Array[Node], quest_id: String) -> void:
	var spawn_pos := target_pos
	var block_coord := Vector3i(spawn_pos)
	
	# Ground Alignment check: prevent vertical clipping inside basalt rocks or air
	var block := world_state.get_block(block_coord)
	if BlockType.is_solid(block) or block == BlockType.Type.AIR:
		spawn_pos.y = world_state.get_highest_solid_y(block_coord.x, block_coord.z)
		
	if _is_voxel_spawn_space_free(world_state, spawn_pos):
		var mob := MobRegistry.create_mob(mob_id, spawn_pos)
		if mob != null:
			mob.set_meta("spawn_id", mob_id) # Metadata tag injected for O(1) tracking
			mob.quest_target_id = quest_id  # Explicit unique quest mapping
			world_node.add_child(mob)
			spawned_nodes.append(mob)
			print("[MobSpawning] Successfully spawned Quest Target Mob ID %d at %s" % [mob_id, spawn_pos])
	else:
		_spawn_and_register_entity(mob_id, chunk_offset, OFFSET_HALF_CHUNK, OFFSET_HALF_CHUNK, world_state, world_node, spawned_nodes, true)


# ==============================================================================
# SPATIAL ALIGNMENTS & UTILITIES (Strict Static Typing & void Returns)
# ==============================================================================

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
			mob.set_meta("spawn_id", spawn_id) # Metadata tag injected for O(1) tracking
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
	
	for y: int in range(HEIGHT_MAX_TERRAIN_LIMIT, -1, -1):
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
	
	for y: int in range(HEIGHT_MAX_TERRAIN_LIMIT, -1, -1):
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
			return float(hit_y) - 0.35
			
	return -1.0


func _is_voxel_spawn_space_free(world_state: WorldState, spawn_pos: Vector3) -> bool:
	var base_coord := Vector3i(floori(spawn_pos.x), floori(spawn_pos.y), floori(spawn_pos.z))
	var feet_block := world_state.get_block(base_coord)
	var chest_block := world_state.get_block(base_coord + Vector3i(0, 1, 0))
	return not BlockType.is_solid(feet_block) and not BlockType.is_solid(chest_block)


func _detect_chunk_biome_id(chunk_pos: Vector3i, world_node: Node) -> int:
	var generator_node: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator_node) and "_terrain_noise" in generator_node:
		var terrain_noise: FastNoiseLite = generator_node.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + int(OFFSET_HALF_CHUNK)
			var center_z := chunk_pos.z * Chunk.SIZE + int(OFFSET_HALF_CHUNK)
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			return profile.biome_id
	return 2


func _is_village_chunk(chunk_pos: Vector3i, world_node: Node) -> bool:
	var generator_node: WorldGenerator = world_node.get("generator") as WorldGenerator if is_instance_valid(world_node) else null
	if is_instance_valid(generator_node) and "_terrain_noise" in generator_node:
		var terrain_noise: FastNoiseLite = generator_node.get("_terrain_noise") as FastNoiseLite
		if terrain_noise != null:
			var center_x := chunk_pos.x * Chunk.SIZE + int(OFFSET_HALF_CHUNK)
			var center_z := chunk_pos.z * Chunk.SIZE + int(OFFSET_HALF_CHUNK)
			var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(center_x, center_z, terrain_noise) as BiomeService.BiomeProfile
			return profile.landmark_id == 3
	return false

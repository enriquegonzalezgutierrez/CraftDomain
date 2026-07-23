# ==============================================================================
# Pathfile: res://src/Infrastructure/World/FluidSimulationService.gd
# Description: Infrastructure Service responsible for simulating high-performance
#              cellular automata fluid dynamics (Water & Lava flow and fusion).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FluidSimulationService
extends RefCounted

const UPDATE_INTERVAL: float = 0.25
const MAX_WATER_SPREAD: int = 4
const MAX_LAVA_SPREAD: int = 2

# TIME-SLICING BUDGETS: Strict limits to prevent CPU frame-pacing spikes
const MAX_UPDATES_PER_TICK: int = 12
const MAX_SORT_POOL_SIZE: int = 128

var world_controller: Node3D
var world_state: WorldState
var _active_fluids: Dictionary = {}
var _tick_timer: float = UPDATE_INTERVAL

class FluidState:
	var type: BlockType.Type
	var remaining_spread: int
	
	func _init(p_type: BlockType.Type, p_spread: int) -> void:
		type = p_type
		remaining_spread = p_spread


func _init(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state


func register_fluid_block(global_pos: Vector3i, type: BlockType.Type, max_spread: int = -1) -> void:
	if type != BlockType.Type.WATER and type != BlockType.Type.LAVA:
		return
		
	var default_spread := MAX_WATER_SPREAD if type == BlockType.Type.WATER else MAX_LAVA_SPREAD
	var spread := default_spread if max_spread == -1 else max_spread
	_active_fluids[global_pos] = FluidState.new(type, spread)


func unregister_fluid_block(global_pos: Vector3i) -> void:
	if _active_fluids.has(global_pos):
		_active_fluids.erase(global_pos)


func _on_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	if type == BlockType.Type.WATER or type == BlockType.Type.LAVA:
		register_fluid_block(global_pos, type)
	else:
		unregister_fluid_block(global_pos)
		if type == BlockType.Type.AIR:
			_reactivate_adjacent_fluids(global_pos)


func _reactivate_adjacent_fluids(global_pos: Vector3i) -> void:
	if world_state == null: return
		
	var offsets: Array[Vector3i] = [
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1)
	]
	
	for offset: Vector3i in offsets:
		var neighbor_pos := global_pos + offset
		var neighbor_type := world_state.get_block(neighbor_pos)
		
		if (neighbor_type == BlockType.Type.WATER or neighbor_type == BlockType.Type.LAVA) and _should_fluid_flow_into_air(global_pos, neighbor_pos, neighbor_type):
			register_fluid_block(neighbor_pos, neighbor_type, 1)


func _should_fluid_flow_into_air(air_pos: Vector3i, fluid_pos: Vector3i, fluid_type: BlockType.Type) -> bool:
	if fluid_pos.y > air_pos.y:
		return true
		
	var block_above_fluid := world_state.get_block(fluid_pos + Vector3i(0, 1, 0))
	return block_above_fluid == fluid_type


func process_fluid_simulation(delta: float) -> void:
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = UPDATE_INTERVAL
		_simulate_cellular_tick()


## SPATIAL TIME-SLICING: Prioritizes fluid updates closest to the player camera.
func _simulate_cellular_tick() -> void:
	if _active_fluids.size() == 0 or world_state == null or not is_instance_valid(world_controller):
		return
		
	var active_keys := _active_fluids.keys()
	_sort_active_keys_by_proximity(active_keys)
	
	var processed_count := 0
	var next_tick_additions: Dictionary = {}
	var current_tick_removals: Array[Vector3i] = []
	
	for pos: Vector3i in active_keys:
		if processed_count >= MAX_UPDATES_PER_TICK: break
		processed_count += 1
		_process_active_fluid_block(pos, next_tick_additions, current_tick_removals)
			
	_apply_tick_mutations(next_tick_additions, current_tick_removals)


func _sort_active_keys_by_proximity(active_keys: Array) -> void:
	var player_node := world_controller.get("player") as CharacterBody3D
	if not is_instance_valid(player_node): return
		
	var player_pos: Vector3 = player_node.global_position
	if active_keys.size() > MAX_SORT_POOL_SIZE:
		# Slice to prevent high sorting CPU overhead
		active_keys = active_keys.slice(0, MAX_SORT_POOL_SIZE)
		
	active_keys.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return Vector3(a).distance_squared_to(player_pos) < Vector3(b).distance_squared_to(player_pos)
	)


func _process_active_fluid_block(pos: Vector3i, next_additions: Dictionary, current_removals: Array[Vector3i]) -> void:
	var state: FluidState = _active_fluids[pos] as FluidState
	if world_state.get_block(pos) != state.type:
		current_removals.append(pos)
		return
		
	var is_stable := _flow_downward(pos, state, next_additions, current_removals)
	if is_stable and state.remaining_spread > 0:
		is_stable = _spread_laterally(pos, state, next_additions)
		
	if is_stable:
		current_removals.append(pos)


func _flow_downward(pos: Vector3i, state: FluidState, next_additions: Dictionary, current_removals: Array[Vector3i]) -> bool:
	var below_pos := pos + Vector3i(0, -1, 0)
	if below_pos.y <= 0: return true
		
	var below_block := world_state.get_block(below_pos)
	if _check_and_apply_fusion(pos, state.type, below_pos, below_block):
		current_removals.append(pos)
		return false
		
	if below_block == BlockType.Type.AIR:
		var default_spread := MAX_WATER_SPREAD if state.type == BlockType.Type.WATER else MAX_LAVA_SPREAD
		world_controller.call("set_block_globally_async", below_pos, state.type)
		next_additions[below_pos] = FluidState.new(state.type, default_spread)
		return false
		
	return true


func _spread_laterally(pos: Vector3i, state: FluidState, next_additions: Dictionary) -> bool:
	var is_stable := true
	var directions: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
	
	for dir: Vector3i in directions:
		var side_pos := pos + dir
		var side_block := world_state.get_block(side_pos)
		if _check_and_apply_fusion(pos, state.type, side_pos, side_block): continue
			
		if side_block == BlockType.Type.AIR:
			world_controller.call("set_block_globally_async", side_pos, state.type)
			next_additions[side_pos] = FluidState.new(state.type, state.remaining_spread - 1)
			is_stable = false
			
	return is_stable


func _check_and_apply_fusion(source_pos: Vector3i, source_type: BlockType.Type, target_pos: Vector3i, target_type: BlockType.Type) -> bool:
	var is_water_lava_clash := (
		(source_type == BlockType.Type.WATER and target_type == BlockType.Type.LAVA) or
		(source_type == BlockType.Type.LAVA and target_type == BlockType.Type.WATER)
	)
	
	if is_water_lava_clash:
		world_controller.call("set_block_globally_async", source_pos, BlockType.Type.STONE)
		world_controller.call("set_block_globally_async", target_pos, BlockType.Type.STONE)
		AudioService.play_sfx_static("block_break", Vector3(target_pos))
		return true
		
	return false


func _apply_tick_mutations(next_additions: Dictionary, current_removals: Array[Vector3i]) -> void:
	for rm_pos: Vector3i in current_removals: _active_fluids.erase(rm_pos)
	for add_pos: Vector3i in next_additions.keys(): _active_fluids[add_pos] = next_additions[add_pos]

# ==============================================================================
# Pathfile: res://src/Domain/Life/FaunaAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Generic Passive Wildlife with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FaunaAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5

const SPEED_PANIC: float = 5.2
const SPEED_WANDER: float = 2.2
const SENSORY_RANGE_SQ: float = 64.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(FaunaPanicAction.new())
	_actions.append(FaunaRestAction.new())
	_actions.append(FaunaWanderAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadeThreats", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var rest_goal := GOAPGoal.new("RestPeriod", 1.0)
	rest_goal.add_desired_state("is_resting", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([evade_goal, rest_goal, wander_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_timers(delta)
	
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("panic_timer", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("stuck_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var panic := _blackboard.get_float("panic_timer") - delta
	_blackboard.set_memory("panic_timer", maxf(0.0, panic))
	
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		for goal: GOAPGoal in sorted_goals:
			if goal.is_valid(_blackboard):
				_active_plan = GOAPPlanner.plan(goal, _actions, initial_state)
				if not _active_plan.is_empty():
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["is_resting"] = false
	state["is_wandering"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
		
	var closest := _scan_for_hostiles(host)
	if is_instance_valid(closest):
		_blackboard.set_memory("panic_timer", 4.5)
		
		var host_pos := host.global_position
		var escape_dir := (host_pos - closest.global_position).normalized()
		escape_dir.y = 0.0 
		_blackboard.set_memory("wander_direction", escape_dir)
		return true
		
	return _blackboard.get_float("panic_timer") > 0.0


func _scan_for_hostiles(host: CharacterBody3D) -> Node3D:
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	var host_pos := host.global_position
	
	for child: Node in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq <= SENSORY_RANGE_SQ:
					return child as Node3D
	return null


func _get_sorted_goals() -> Array[GOAPGoal]:
	var sorted := _goals.duplicate()
	sorted.sort_custom(func(a: GOAPGoal, b: GOAPGoal) -> bool:
		return a.get_priority(_blackboard) > b.get_priority(_blackboard)
	)
	return sorted


func _execute_current_action(delta: float) -> void:
	if _active_plan.is_empty():
		return
		
	var current_action := _active_plan[0]
	if not current_action.is_contextually_valid(_blackboard):
		current_action.on_exit(_blackboard)
		_active_plan.clear()
		return
		
	var is_finished := current_action.execute_step(_blackboard, delta)
	if is_finished:
		current_action.on_exit(_blackboard)
		_active_plan.pop_front()
		if not _active_plan.is_empty():
			_active_plan[0].on_enter(_blackboard)


func get_active_state_name(host: Object) -> String:
	var _h := host
	if _active_plan.size() > 0:
		var action_name := _active_plan[0].action_name
		if action_name == "Wander": return "WANDERING"
		elif action_name == "Rest": return "IDLE"
		elif action_name == "FaunaPanic": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled generic wildlife behaviors)
# ==============================================================================

class FaunaPanicAction extends GOAPAction:
	func _init() -> void:
		super("FaunaPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host):
			return true 
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", FaunaAIBehavior.TASK_PANIC)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(0.3, 0.8)
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			if FaunaAIBehavior._is_direction_safe_fauna(host, candidate):
				wander_dir = candidate
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, FaunaAIBehavior.SPEED_PANIC)
		return bb.get_float("panic_timer") <= 0.0


class FaunaRestAction extends GOAPAction:
	func _init() -> void:
		super("Rest", 1.0)
		add_effect("is_resting", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("rest_timer") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", randf_range(3.0, 6.0))
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", FaunaAIBehavior.TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("rest_timer", randf_range(12.0, 24.0))
			return true
		return false


class FaunaWanderAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_wandering", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host):
			return true 
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", FaunaAIBehavior.TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			wander_dir = _find_safe_wander_direction(host)
			timer = randf_range(3.0, 6.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, FaunaAIBehavior.SPEED_WANDER)
		return false

	func _find_safe_wander_direction(host: CharacterBody3D) -> Vector3:
		for i: int in range(12):
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle)).normalized()
			if _is_direction_clear(host, candidate):
				return candidate
				
		var current_facing := -host.global_transform.basis.z.normalized()
		current_facing.y = 0.0
		if current_facing != Vector3.ZERO and _is_direction_clear(host, -current_facing):
			return -current_facing
			
		return Vector3.ZERO

	func _is_direction_clear(host: CharacterBody3D, dir: Vector3) -> bool:
		var parent := host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent:
			return true
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null:
			return true
			
		var distances: Array[float] = [1.0, 2.0]
		for dist: float in distances:
			var check_pos: Vector3 = host.global_position + dir * dist
			var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
			var below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y - 1.0), floori(check_pos.z))
			
			if BlockLibrary.is_solid(ws.get_block(feet_coord)) or BlockLibrary.is_solid(ws.get_block(chest_coord)):
				return false
			if not BlockLibrary.is_solid(ws.get_block(below_coord)):
				return false
				
		return true

	func _check_and_resolve_wall_impact(bb: AIBlackboard, host: CharacterBody3D, wander_dir: Vector3, delta: float) -> void:
		var stuck: float = bb.get_float("stuck_timer")
		var is_colliding: bool = host.is_on_wall() or not _is_direction_clear(host, wander_dir)
		
		if wander_dir != Vector3.ZERO and is_colliding:
			stuck += delta
			if stuck > 0.2:
				stuck = 0.0
				var new_dir: Vector3 = _find_safe_wander_direction(host)
				if new_dir == Vector3.ZERO:
					if host.is_on_wall():
						var normal: Vector3 = host.get_wall_normal()
						new_dir = Vector3(normal.x, 0.0, normal.z).normalized()
					else:
						new_dir = -wander_dir
				bb.set_memory("wander_direction", new_dir)
				bb.set_memory("wander_timer", randf_range(2.0, 5.0))
		else:
			stuck = 0.0
			
		bb.set_memory("stuck_timer", stuck)


# ==============================================================================
# SPATIAL TERRAIN FILTER HELPER (Horizontal XZ Plane Checks)
# ==============================================================================

static func _is_direction_safe_fauna(host: CharacterBody3D, dir: Vector3) -> bool:
	var parent := host.get_parent() as Node
	if not is_instance_valid(parent) or not "world_state" in parent: return true
	var ws: WorldState = parent.get("world_state") as WorldState
	if ws == null: return true
		
	var check_pos := host.global_position + dir * 1.5
	var b_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var b_feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
	
	var b_below := ws.get_block(b_below_coord)
	var b_at := ws.get_block(b_feet_coord)
	
	if BlockLibrary.is_solid(b_at): return false
	return _evaluate_liquid_and_void(ws, b_below_coord, b_below, b_at)


static func _evaluate_liquid_and_void(ws: WorldState, b_below_coord: Vector3i, b_below: int, b_at: int) -> bool:
	var is_liquid := (b_below == BlockType.Type.WATER or b_below == BlockType.Type.LAVA or b_at == BlockType.Type.WATER)
	var is_void := (b_below == BlockType.Type.AIR)
	
	if is_void:
		var b_2_below := ws.get_block(b_below_coord + Vector3i(0, -1, 0))
		if b_2_below != BlockType.Type.AIR and b_2_below != BlockType.Type.WATER and b_2_below != BlockType.Type.LAVA:
			is_void = false
		
	return not is_liquid and not is_void

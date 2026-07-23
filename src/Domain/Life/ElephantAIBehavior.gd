# ==============================================================================
# Pathfile: res://src/Domain/Life/ElephantAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Colossal Elephant with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ElephantAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5

const SPEED_WALK: float = 1.0
const STRIDE_INTERVAL_SEC: float = 0.9
const RANGE_SIGHT_SQ: float = 144.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true 
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ElephantPanicAction.new())
	_actions.append(HeavyStrollAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadeThreats", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var stroll_goal := GOAPGoal.new("HeavyStroll", 0.5)
	stroll_goal.add_desired_state("is_strolling", true)
	
	_goals.append_array([evade_goal, stroll_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("wander_timer", 0.0)
		_blackboard.set_memory("stride_timer", 0.4)


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		var usable_actions: Array[GOAPAction] = []
		for action: GOAPAction in _actions:
			if action.is_contextually_valid(_blackboard):
				usable_actions.append(action)
		
		for goal in sorted_goals:
			if goal.is_valid(_blackboard):
				var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
				if not candidate_plan.is_empty():
					_active_plan = candidate_plan
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["is_strolling"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= RANGE_SIGHT_SQ:
					return true
	return false


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
		if action_name == "HeavyStroll": return "PATROLLING"
		elif action_name == "ElephantPanic": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled colossal behaviors)
# ==============================================================================

class ElephantPanicAction extends GOAPAction:
	func _init() -> void:
		super("ElephantPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			timer = randf_range(0.8, 1.5)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_apply_heavy_panic_locomotion(bb, host, ai, wander_dir, delta)
		return not ElephantAIBehavior.new()._detect_threat_proximity(host)
		
	func _apply_heavy_panic_locomotion(bb: AIBlackboard, host: CharacterBody3D, ai: Object, wander_dir: Vector3, delta: float) -> void:
		var vel := host.velocity
		vel.x = wander_dir.x * SPEED_WALK * 1.6
		vel.z = wander_dir.z * SPEED_WALK * 1.6
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)
		ElephantAIBehavior._process_stride_impacts(bb, host, delta)


class HeavyStrollAction extends GOAPAction:
	func _init() -> void:
		super("HeavyStroll", 1.0)
		add_effect("is_strolling", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			wander_dir = _find_safe_wander_direction(host)
			timer = randf_range(4.0, 8.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		_apply_heavy_stroll_locomotion(bb, host, ai, wander_dir, delta)
		return false

	func _find_safe_wander_direction(host: CharacterBody3D) -> Vector3:
		var start_angle := randf() * TAU
		for i: int in range(16):
			var angle := start_angle + (float(i) / 16.0) * TAU
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
			
		# Larger 1.5m and 2.5m scanning bounds specific to colossal elephant scale
		var distances: Array[float] = [1.5, 2.5]
		for dist: float in distances:
			var check_pos: Vector3 = host.global_position + dir * dist
			var feet_y := floori(check_pos.y + 0.5)
			var feet_coord := Vector3i(floori(check_pos.x), feet_y, floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), feet_y + 1, floori(check_pos.z))
			var below_coord := Vector3i(floori(check_pos.x), feet_y - 1, floori(check_pos.z))
			
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
		
	func _apply_heavy_stroll_locomotion(bb: AIBlackboard, host: CharacterBody3D, ai: Object, wander_dir: Vector3, delta: float) -> void:
		var vel := host.velocity
		if wander_dir != Vector3.ZERO:
			vel.x = wander_dir.x * SPEED_WALK
			vel.z = wander_dir.z * SPEED_WALK
			ElephantAIBehavior._process_stride_impacts(bb, host, delta)
		else:
			vel.x = move_toward(vel.x, 0.0, SPEED_WALK)
			vel.z = move_toward(vel.z, 0.0, SPEED_WALK)
			bb.set_memory("stride_timer", 0.4) 
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)


static func _process_stride_impacts(bb: AIBlackboard, host: CharacterBody3D, delta: float) -> void:
	var stride_timer := bb.get_float("stride_timer") if bb.has_memory("stride_timer") else 0.4
	stride_timer -= delta
	if stride_timer <= 0.0:
		stride_timer = STRIDE_INTERVAL_SEC
		if host.has_method("_play_heavy_step_impact"):
			host.call("_play_heavy_step_impact") 
	bb.set_memory("stride_timer", stride_timer)

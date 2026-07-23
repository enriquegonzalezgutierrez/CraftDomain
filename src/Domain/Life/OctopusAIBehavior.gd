# ==============================================================================
# Pathfile: res://src/Domain/Life/OctopusAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Deep-water Octopus.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OctopusAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_JET: float = 3.6
const SPEED_DRIFT: float = 0.5
const SPEED_PANIC_JET: float = 5.2

const COOLDOWN_INK_SEC: float = 5.0
const JET_CYCLE_DURATION_SEC: float = 2.0
const RANGE_ATTRACTION_SQ: float = 100.0
const RANGE_ZOMBIE_SQ: float = 64.0
const RANGE_CAMPFIRE_SQ: float = 144.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(InkFleeAction.new())
	_actions.append(SwimPulseAction.new())


func _setup_goals() -> void:
	var escape_goal := GOAPGoal.new("EscapeThreats", 10.0)
	escape_goal.add_desired_state("is_safe", true)
	
	var swim_goal := GOAPGoal.new("PulsingSwim", 0.5)
	swim_goal.add_desired_state("is_swimming", true)
	
	_goals.append_array([escape_goal, swim_goal])


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
		_blackboard.set_memory("ink_cooldown", 0.0)
		_blackboard.set_memory("flee_timer", 0.0)
		_blackboard.set_memory("jet_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var ink := _blackboard.get_float("ink_cooldown") - delta
	_blackboard.set_memory("ink_cooldown", maxf(0.0, ink))
	
	var flee := _blackboard.get_float("flee_timer") - delta
	_blackboard.set_memory("flee_timer", maxf(0.0, flee))


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		for goal in sorted_goals:
			if goal.is_valid(_blackboard):
				_active_plan = GOAPPlanner.plan(goal, _actions, initial_state)
				if not _active_plan.is_empty():
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["is_swimming"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= 64.0:
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
		if action_name == "SwimPulse": return "WORKING"
		elif action_name == "InkFlee": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled marine behaviors)
# ==============================================================================

class InkFleeAction extends GOAPAction:
	func _init() -> void:
		super("InkFlee", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		_trigger_ink_shroud(bb, host, delta)
		_apply_escape_propulsion(bb, host, ai, delta)
		
		return bb.get_float("flee_timer") <= 0.0
		
	func _trigger_ink_shroud(bb: AIBlackboard, host: CharacterBody3D, _delta: float) -> void:
		var cd := bb.get_float("ink_cooldown")
		if cd <= 0.0:
			bb.set_memory("ink_cooldown", COOLDOWN_INK_SEC)
			bb.set_memory("flee_timer", 3.5)
			if host.has_method("_play_ink_spray"):
				host.call("_play_ink_spray")
				
	func _apply_escape_propulsion(bb: AIBlackboard, host: CharacterBody3D, ai: Object, _delta: float) -> void:
		var wander_dir := bb.get_vector3("wander_direction")
		if wander_dir == Vector3.ZERO:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		var vel := host.velocity
		vel.x = wander_dir.x * SPEED_PANIC_JET
		vel.z = wander_dir.z * SPEED_PANIC_JET
		var in_liquid: bool = host.call("is_in_liquid") as bool if host.has_method("is_in_liquid") else true
		if in_liquid:
			vel.y = randf_range(-0.5, 0.5)
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)


class SwimPulseAction extends GOAPAction:
	func _init() -> void:
		super("SwimPulse", 1.0)
		add_effect("is_swimming", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var jet_timer := bb.get_float("jet_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if jet_timer <= 0.0 or wander_dir == Vector3.ZERO:
			jet_timer = JET_CYCLE_DURATION_SEC
			wander_dir = _find_safe_wander_direction(host)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("jet_timer", jet_timer)
		_apply_pulsing_swim_physics(host, ai, wander_dir, jet_timer, delta)
		return false
		
	func _apply_pulsing_swim_physics(host: CharacterBody3D, ai: Object, wander_dir: Vector3, jet_timer: float, delta: float) -> void:
		var vel := host.velocity
		var speed_coef := SPEED_DRIFT
		var time_elapsed := JET_CYCLE_DURATION_SEC - jet_timer
		
		if time_elapsed <= 0.6:
			var t := time_elapsed / 0.6
			speed_coef = lerp(SPEED_JET, SPEED_DRIFT, t)
			
		var in_liquid: bool = host.call("is_in_liquid") as bool if host.has_method("is_in_liquid") else true
		if wander_dir != Vector3.ZERO:
			vel.x = wander_dir.x * speed_coef
			vel.z = wander_dir.z * speed_coef
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.15, delta * 3.0)
		else:
			vel.x = move_toward(vel.x, 0.0, SPEED_DRIFT)
			vel.z = move_toward(vel.z, 0.0, SPEED_DRIFT)
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 1.5) * 0.08, delta * 3.0)
			
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)

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
			
		var distances: Array[float] = [1.0, 2.0]
		for dist: float in distances:
			var check_pos: Vector3 = host.global_position + dir * dist
			var feet_y := floori(check_pos.y + 0.5)
			var feet_coord := Vector3i(floori(check_pos.x), feet_y, floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), feet_y + 1, floori(check_pos.z))
			
			var feet_block := ws.get_block(feet_coord)
			var chest_block := ws.get_block(chest_coord)
			
			if BlockLibrary.is_solid(feet_block) or BlockLibrary.is_solid(chest_block):
				return false
				
			var below_coord := Vector3i(floori(check_pos.x), feet_y - 1, floori(check_pos.z))
			var below_block := ws.get_block(below_coord)
			var is_liquid := below_block == 6 or below_block == 15 or feet_block == 6
			if not is_liquid:
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
				bb.set_memory("jet_timer", JET_CYCLE_DURATION_SEC)
		else:
			stuck = 0.0
			
		bb.set_memory("stuck_timer", stuck)

	func _is_pushing_into_wall(host: CharacterBody3D, wander_dir: Vector3) -> bool:
		if not host.is_on_wall() or wander_dir == Vector3.ZERO:
			return false
		var wall_normal := host.get_wall_normal()
		var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
		return flat_normal != Vector3.ZERO and wander_dir.normalized().dot(-flat_normal) > 0.25

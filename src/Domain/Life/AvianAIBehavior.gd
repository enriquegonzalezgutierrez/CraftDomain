# ==============================================================================
# Pathfile: res://src/Domain/Life/AvianAIBehavior.gd
# Description: Pure Domain GOAP AI behavior strategy for Avian Mobs (Birds, Parrots).
#              Manages thermal soaring, tree scanning, and roost gliding.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AvianAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const STATE_SOARING: int = 0
const STATE_LANDING: int = 1
const STATE_PERCHED: int = 2

const FLIGHT_SPEED_SOAR: float = 3.2
const FLIGHT_SPEED_GLIDE: float = 4.8
const PERCH_DURATION_SEC: float = 5.0
const THREAT_SENSORY_RANGE_SQ: float = 64.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(AvianPanicAction.new())
	_actions.append(ScanLeavesAction.new())
	_actions.append(GlideToRoostAction.new())
	_actions.append(SoarAction.new())


func _setup_goals() -> void:
	var panic_goal := GOAPGoal.new("EvadeThreats", 10.0)
	panic_goal.add_desired_state("is_safe", true)
	
	var roost_goal := GOAPGoal.new("RoostInNest", 1.5)
	roost_goal.add_desired_state("is_roosted", true)
	
	var soar_goal := GOAPGoal.new("ThermalSoar", 0.5)
	soar_goal.add_desired_state("is_soaring", true)
	
	_goals.append_array([panic_goal, roost_goal, soar_goal])


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
		_blackboard.set_memory("wander_timer", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("roost_scan_cooldown", 0.0)
		
		if not host.has_meta("avian_flight_state"):
			host.set_meta("avian_flight_state", STATE_SOARING)


func _update_blackboard_timers(delta: float) -> void:
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))
	
	var r_cd := _blackboard.get_float("roost_scan_cooldown") - delta
	_blackboard.set_memory("roost_scan_cooldown", maxf(0.0, r_cd))


func _evaluate_active_plan(_host: Object) -> void:
	if not _active_plan.is_empty():
		return
		
	var initial_state := _build_initial_state()
	var usable_actions: Array[GOAPAction] = []
	for action: GOAPAction in _actions:
		if action.is_contextually_valid(_blackboard):
			usable_actions.append(action)
			
	for goal in _get_sorted_goals():
		if goal.is_valid(_blackboard):
			var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
			if not candidate_plan.is_empty():
				_active_plan = candidate_plan
				_active_plan[0].on_enter(_blackboard)
				break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host"))
	state["is_roosted"] = (_blackboard.get_float("rest_timer") > 0.0)
	state["is_soaring"] = false
	return state


func _detect_threat_proximity(host: Object) -> bool:
	if not is_instance_valid(host) or not host.call("is_inside_tree"):
		return false
		
	var tree: SceneTree = host.call("get_tree") as SceneTree
	if tree == null:
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in tree.get_nodes_in_group("hostiles"):
		if is_instance_valid(child):
			var domain: Object = child.get("domain_entity")
			var is_dead: bool = domain.get("is_dead") as bool if is_instance_valid(domain) else true
			if not is_dead and host_pos.distance_squared_to(child.get("global_position") as Vector3) <= THREAT_SENSORY_RANGE_SQ:
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
		
	if current_action.execute_step(_blackboard, delta):
		current_action.on_exit(_blackboard)
		_active_plan.pop_front()
		if not _active_plan.is_empty():
			_active_plan[0].on_enter(_blackboard)


func get_active_state_name(host: Object) -> String:
	var _h := host
	if _active_plan.size() > 0:
		var action_name := _active_plan[0].action_name
		if action_name == "ScanLeaves": return "SCANNING_TREES"
		elif action_name == "GlideToRoost": return "WANDERING"
		elif action_name == "AvianPanic" or action_name == "Soar": return "LAUNCH_ATTACK"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled aerial behaviors)
# ==============================================================================

class AvianPanicAction extends GOAPAction:
	func _init() -> void:
		super("AvianPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host")
		if is_instance_valid(host):
			host.set_meta("avian_flight_state", STATE_SOARING)
			var ai: Object = host.get("ai_component")
			if is_instance_valid(ai):
				ai.set("current_task", TASK_PANIC)
				
		bb.erase_memory("roost_target")
		bb.erase_memory("has_roost_target")
		bb.set_memory("rest_timer", 0.0)
		return true


class ScanLeavesAction extends GOAPAction:
	func _init() -> void:
		super("ScanLeaves", 1.0)
		add_effect("has_roost_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("rest_timer") <= 0.0 and bb.get_float("roost_scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host")
		var leaf_coord := _scan_for_leaves(host) if is_instance_valid(host) else Vector3i(0, -999, 0)
		
		if leaf_coord != Vector3i(0, -999, 0):
			bb.set_memory("roost_target", leaf_coord)
			return true
			
		bb.set_memory("roost_scan_cooldown", 8.0)
		return true
		
	func _scan_for_leaves(host: Object) -> Vector3i:
		var parent: Object = host.call("get_parent")
		if not is_instance_valid(parent) or not "world_state" in parent: return Vector3i(0, -999, 0)
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null: return Vector3i(0, -999, 0)
			
		var host_pos: Vector3 = host.get("global_position")
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		
		for x in range(-5, 6):
			for y in range(-4, 5):
				for z in range(-5, 6):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == 5 and ws.get_block(c + Vector3i(0, 1, 0)) == 0:
						return c
		return Vector3i(0, -999, 0)


class GlideToRoostAction extends GOAPAction:
	func _init() -> void:
		super("GlideToRoost", 1.0)
		add_precondition("has_roost_target", true)
		add_effect("is_roosted", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("roost_target")
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host")
		if not is_instance_valid(host): return true
		
		var target := bb.get_vector3i("roost_target")
		var target_pos := Vector3(target) + Vector3(0.5, 1.05, 0.5)
		var host_pos: Vector3 = host.get("global_position")
		var diff := target_pos - host_pos
		
		if diff.length_squared() <= 0.4:
			host.set("velocity", Vector3.ZERO)
			host.set_meta("avian_flight_state", STATE_PERCHED)
			bb.set_memory("rest_timer", PERCH_DURATION_SEC)
			return true
			
		_apply_glide_physics(host, diff, delta)
		return false
		
	func _apply_glide_physics(host: Object, diff: Vector3, delta: float) -> void:
		var glide_dir := diff.normalized()
		var vel: Vector3 = host.get("velocity")
		vel.x = glide_dir.x * FLIGHT_SPEED_GLIDE
		vel.z = glide_dir.z * FLIGHT_SPEED_GLIDE
		vel.y = lerp(vel.y, glide_dir.y * FLIGHT_SPEED_GLIDE, delta * 6.0)
		host.set("velocity", vel)
		
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("wander_direction", glide_dir)
			ai.set("current_task", TASK_WORKING)


class SoarAction extends GOAPAction:
	func _init() -> void:
		super("Soar", 1.0)
		add_effect("is_soaring", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host")
		if not is_instance_valid(host): return true
		
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			timer = randf_range(3.0, 6.0)
			var time_sec := float(Time.get_ticks_msec()) / 1000.0
			wander_dir = Vector3(sin(time_sec * 0.45), 0.0, cos(time_sec * 0.45)).normalized()
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_apply_soar_physics(host, ai, wander_dir, delta)
		return false
		
	func _apply_soar_physics(host: Object, ai: Object, soar_dir: Vector3, delta: float) -> void:
		var vel: Vector3 = host.get("velocity")
		vel.x = soar_dir.x * FLIGHT_SPEED_SOAR
		vel.z = soar_dir.z * FLIGHT_SPEED_SOAR
		
		var host_pos: Vector3 = host.get("global_position")
		var vertical_drift := (18.0 - host_pos.y) * 0.15
		var wave_offset := sin(float(Time.get_ticks_msec()) / 1000.0 * 2.5) * 0.25
		vel.y = lerp(vel.y, vertical_drift + wave_offset, delta * 4.0)
		
		host.set("velocity", vel)
		if is_instance_valid(ai):
			ai.set("wander_direction", soar_dir)

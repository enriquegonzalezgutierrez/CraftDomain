# ==============================================================================
# Pathfile: res://src/Domain/Life/OctopusAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Deep-water Octopus.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates defensive ink spraying 
#   and hydrodynamic, gravity-safe jet propulsion into independent actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   marine behaviors (such as camouflage/cloaking) dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OctopusAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA PROPULSIÓN ACUÁTICA ÁGIL
const SPEED_JET: float = 5.6
const SPEED_DRIFT: float = 0.8
const SPEED_PANIC_JET: float = 8.4

const COOLDOWN_INK_SEC: float = 5.0
const JET_CYCLE_DURATION_SEC: float = 2.0

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
			bb.set_memory("flee_timer", 3.5) # Force panic flight for 3.5s
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
			vel.y = randf_range(-0.5, 0.5) # Dynamic depth dive
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
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.6 else Vector3.ZERO
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
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.08, delta * 3.0)
		else:
			vel.x = move_toward(vel.x, 0.0, SPEED_DRIFT)
			vel.z = move_toward(vel.z, 0.0, SPEED_DRIFT)
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 1.5) * 0.08, delta * 3.0)
			
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)

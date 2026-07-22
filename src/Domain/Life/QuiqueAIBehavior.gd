# ==============================================================================
# Pathfile: res://src/Domain/Life/QuiqueAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Quique, the unique Castle Resident.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates royal strolling, elegant 
#   resting, and absolute panic into decoupled, cohesive GOAP actions.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuiqueAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5

const SPEED_STROLL: float = 1.8
const SPEED_PANIC: float = 6.5
const SENSORY_RANGE_SQ: float = 144.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(QuiquePanicAction.new())
	_actions.append(QuiqueRestAction.new())
	_actions.append(QuiqueStrollAction.new())


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("SurvivePanic", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var rest_goal := GOAPGoal.new("RoyalRest", 0.8)
	rest_goal.add_desired_state("is_resting", true)
	
	var stroll_goal := GOAPGoal.new("RoyalStroll", 0.5)
	stroll_goal.add_desired_state("is_strolling", true)
	
	_goals.append_array([survive_goal, rest_goal, stroll_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_timers(delta)
	
	if host.get("is_talking") == true:
		_handle_conversation_interrupt(host)
		return
		
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("panic_timer", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var panic := _blackboard.get_float("panic_timer") - delta
	_blackboard.set_memory("panic_timer", maxf(0.0, panic))
	
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))


func _handle_conversation_interrupt(host: Object) -> void:
	_active_plan.clear()
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		# Filter usable actions dynamically by contextual validity
		var usable_actions: Array[GOAPAction] = []
		for action: GOAPAction in _actions:
			if action.is_contextually_valid(_blackboard):
				usable_actions.append(action)
		
		for goal: GOAPGoal in sorted_goals:
			if goal.is_valid(_blackboard):
				var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
				if not candidate_plan.is_empty():
					_active_plan = candidate_plan
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["is_resting"] = false
	state["is_strolling"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
		
	var closest := _scan_for_hostiles(host)
	if is_instance_valid(closest):
		_blackboard.set_memory("panic_timer", 5.0)
		var escape_dir := (host.global_position - closest.global_position).normalized()
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
		if action_name == "QuiquePanic": return "PANIC"
		elif action_name == "QuiqueRest": return "IDLE"
		elif action_name == "QuiqueStroll": return "WANDERING"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Quique's Custom Behaviors)
# ==============================================================================

class QuiquePanicAction extends GOAPAction:
	func _init() -> void:
		super("QuiquePanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host): return true 
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", QuiqueAIBehavior.TASK_PANIC)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(0.4, 1.2) 
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			wander_dir = candidate
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, QuiqueAIBehavior.SPEED_PANIC)
		return bb.get_float("panic_timer") <= 0.0


class QuiqueRestAction extends GOAPAction:
	func _init() -> void:
		super("QuiqueRest", 1.0)
		add_effect("is_resting", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("rest_timer") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", randf_range(4.0, 8.0))
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", QuiqueAIBehavior.TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("rest_timer", randf_range(15.0, 25.0))
			return true
		return false


class QuiqueStrollAction extends GOAPAction:
	func _init() -> void:
		super("QuiqueStroll", 1.0)
		add_effect("is_strolling", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("stroll_duration", randf_range(12.0, 20.0))
		bb.set_memory("wander_timer", 0.0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", QuiqueAIBehavior.TASK_WANDERING)
			
		var duration := bb.get_float("stroll_duration") - delta
		bb.set_memory("stroll_duration", duration)
		if duration <= 0.0:
			return true
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(2.0, 6.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) 
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_resolve_wall_bounce(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, QuiqueAIBehavior.SPEED_STROLL)
		return false
		
	func _resolve_wall_bounce(bb: AIBlackboard, host: CharacterBody3D, wander_dir: Vector3, delta: float) -> void:
		var stuck := bb.get_float("stuck_timer")
		if wander_dir != Vector3.ZERO and host.is_on_wall():
			stuck += delta
			if stuck > 0.4:
				stuck = 0.0
				var normal := host.get_wall_normal()
				var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					var bounce := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					bounce.y = 0.0
					bb.set_memory("wander_direction", bounce)
		else:
			stuck = 0.0
		bb.set_memory("stuck_timer", stuck)

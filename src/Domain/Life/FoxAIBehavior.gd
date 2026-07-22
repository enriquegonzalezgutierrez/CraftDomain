# ==============================================================================
# Pathfile: res://src/Domain/Life/FoxAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Forest Red Fox.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates woodland exploration, 
#   stealth creeping, crouch scaling, and pounce leaps into distinct actions.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FoxAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_PATROL: float = 1.1
const SPEED_SNEAK: float = 0.7
const SPEED_POUNCE: float = 4.5
const COOLDOWN_POUNCE_SEC: float = 4.0

const RANGE_SIGHT_SQ: float = 144.0
const RANGE_POUNCE_SQ: float = 20.25

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ScanPreyAction.new())
	_actions.append(SneakToPreyAction.new())
	_actions.append(PounceLeapAction.new())
	_actions.append(FoxPatrolAction.new())


func _setup_goals() -> void:
	var hunt_goal := GOAPGoal.new("HuntWoodlandPrey", 2.0)
	hunt_goal.add_desired_state("prey_eliminated", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([hunt_goal, wander_goal])


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
		_blackboard.set_memory("pounce_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("pounce_cooldown") - delta
	_blackboard.set_memory("pounce_cooldown", maxf(0.0, cd))


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		# Filter usable actions dynamically by contextual validity
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
	state["prey_eliminated"] = not _is_target_active()
	state["is_wandering"] = false
	return state


func _is_target_active() -> bool:
	var target := _blackboard.get_object("prey_target") as Node3D
	if is_instance_valid(target):
		var domain := target.get("domain_entity") as VoxelEntity
		return is_instance_valid(domain) and not domain.is_dead
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
		if action_name == "SneakToPrey": return "WANDERING"
		elif action_name == "PounceLeap": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled fox predator behaviors)
# ==============================================================================

class ScanPreyAction extends GOAPAction:
	func _init() -> void:
		super("ScanPrey", 1.0)
		add_effect("has_prey_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("pounce_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_peaceful_prey(host)
		if is_instance_valid(target):
			bb.set_memory("prey_target", target)
			return true
			
		bb.set_memory("pounce_cooldown", 6.0)
		return true
		
	func _scan_for_peaceful_prey(host: CharacterBody3D) -> Node3D:
		var passives := host.get_tree().get_nodes_in_group("passives")
		var closest: Node3D = null
		var min_dist_sq := RANGE_SIGHT_SQ
		
		for child in passives:
			if is_instance_valid(child) and child != host and child is Node3D:
				var name_str: String = child.name
				if name_str.contains("CHICKEN") or name_str.contains("BIRD"):
					var domain := child.get("domain_entity") as VoxelEntity
					if is_instance_valid(domain) and not domain.is_dead:
						var dist_sq := host.global_position.distance_squared_to(child.global_position)
						if dist_sq < min_dist_sq:
							min_dist_sq = dist_sq
							closest = child as Node3D
		return closest


class SneakToPreyAction extends GOAPAction:
	func _init() -> void:
		super("SneakToPrey", 1.0)
		add_precondition("has_prey_target", true)
		add_effect("is_at_prey", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("prey_target") as Node3D
		return is_instance_valid(target)
		
	func on_enter(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_set_crouch_height"):
			host.call("_set_crouch_height", true)
			
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("prey_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= RANGE_POUNCE_SQ:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_SNEAK)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class PounceLeapAction extends GOAPAction:
	func _init() -> void:
		super("PounceLeap", 1.0)
		add_precondition("is_at_prey", true)
		add_effect("prey_eliminated", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("prey_target") as Node3D
		return is_instance_valid(target)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("prey_target") as Node3D
		
		if host.call("is_on_floor") and bb.get_float("pounce_cooldown") <= 0.0:
			bb.set_memory("pounce_cooldown", COOLDOWN_POUNCE_SEC)
			_execute_aerial_pounce(host, target)
			return true
			
		return false
		
	func _execute_aerial_pounce(host: CharacterBody3D, target: Node3D) -> void:
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		var leap_dir := diff.normalized()
		
		var vel := host.velocity
		vel.x = leap_dir.x * SPEED_POUNCE
		vel.z = leap_dir.z * SPEED_POUNCE
		vel.y = 5.8
		host.velocity = vel
		
		if host.has_method("_execute_pounce_strike"):
			host.call("_execute_pounce_strike", target)
			
		_restore_crouch_state(host)
		
	func _restore_crouch_state(host: CharacterBody3D) -> void:
		if host.has_method("_set_crouch_height"):
			host.call("_set_crouch_height", false)


class FoxPatrolAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_wandering", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(1.5, 4.5)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
		return false

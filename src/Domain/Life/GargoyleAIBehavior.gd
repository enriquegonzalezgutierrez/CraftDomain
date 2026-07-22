# ==============================================================================
# Pathfile: res://src/Domain/Life/GargoyleAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Hostile Nocturnal Gargoyle.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates daytime petrification, 
#   nocturnal target spotting, aerial pursuit, and close biting into distinct actions.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GargoyleAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_CHASE: float = 6.0
const SPEED_WANDER: float = 3.0

const RANGE_SIGHT_SQ: float = 256.0
const RANGE_ATTACK_SQ: float = 3.0
const COOLDOWN_ATTACK_SEC: float = 1.5

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(DayPetrifyAction.new())
	_actions.append(NightLocateAction.new())
	_actions.append(SoarChaseAction.new())
	_actions.append(BiteAttackAction.new())
	_actions.append(SoarPatrolAction.new())


func _setup_goals() -> void:
	var petrify_goal := GOAPGoal.new("PetrifyDay", 10.0)
	petrify_goal.add_desired_state("is_petrified", true)
	
	var hunt_goal := GOAPGoal.new("NocturnalHunt", 2.0)
	hunt_goal.add_desired_state("prey_eliminated", true)
	
	var soar_goal := GOAPGoal.new("SoarPatrol", 0.5)
	soar_goal.add_desired_state("is_soaring", true)
	
	_goals.append_array([petrify_goal, hunt_goal, soar_goal])


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
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("locate_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var is_night := CelestialService.is_night_time_static()
	_blackboard.set_memory("is_night", is_night)
	
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var loc_cd := _blackboard.get_float("locate_cooldown") - delta
	_blackboard.set_memory("locate_cooldown", maxf(0.0, loc_cd))


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
	state["is_petrified"] = not _blackboard.get_bool("is_night")
	state["prey_eliminated"] = not _is_target_active()
	state["is_soaring"] = false
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
		if action_name == "SoarChase": return "WANDERING"
		elif action_name == "BiteAttack": return "WORKING"
		elif action_name == "Soar": return "SOARING"
		elif action_name == "DayPetrify": return "PETRIFIED"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled gargoyle behaviors)
# ==============================================================================

class DayPetrifyAction extends GOAPAction:
	func _init() -> void:
		super("DayPetrify", 1.0)
		add_effect("is_petrified", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", true)
			
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		return bb.get_bool("is_night")
		
	func on_exit(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_set_gargoyle_stone_appearance"):
			host.call("_set_gargoyle_stone_appearance", false)


class NightLocateAction extends GOAPAction:
	func _init() -> void:
		super("NightLocate", 1.0)
		add_effect("has_prey_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_bool("is_night") and bb.get_float("locate_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_prey_target(host)
		if is_instance_valid(target):
			bb.set_memory("prey_target", target)
			return true
			
		bb.set_memory("locate_cooldown", 5.0)
		return true
		
	func _scan_for_prey_target(host: CharacterBody3D) -> Node3D:
		var parent := host.get_parent() as Node
		var player_node := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player_node) and player_node.get("is_active"):
			var dist_sq := host.global_position.distance_squared_to(player_node.global_position)
			if dist_sq <= RANGE_SIGHT_SQ:
				var domain := player_node.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					return player_node
		return null


class SoarChaseAction extends GOAPAction:
	func _init() -> void:
		super("SoarChase", 1.0)
		add_precondition("has_prey_target", true)
		add_effect("is_at_prey", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("prey_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("prey_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= RANGE_ATTACK_SQ:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_CHASE)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class BiteAttackAction extends GOAPAction:
	func _init() -> void:
		super("BiteAttack", 1.0)
		add_precondition("is_at_prey", true)
		add_effect("prey_eliminated", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("prey_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("prey_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		if diff.length_squared() > RANGE_ATTACK_SQ:
			return true
			
		_execute_bite(bb, host, ai, diff.normalized())
		return false
		
	func _execute_bite(bb: AIBlackboard, host: CharacterBody3D, ai: Object, dir: Vector3) -> void:
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("wander_direction", dir)
			
		var cooldown := bb.get_float("attack_cooldown")
		if cooldown <= 0.0:
			bb.set_memory("attack_cooldown", COOLDOWN_ATTACK_SEC)
			if host.has_method("_bite_player"):
				host.call("_bite_player")
				
			var vis := host.get("visual_representation") as IEntityVisualRepresentation
			if is_instance_valid(vis): vis.trigger_attack_visuals()


class SoarPatrolAction extends GOAPAction:
	func _init() -> void:
		super("Soar", 1.0)
		add_effect("is_soaring", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			wander_dir = _find_valid_soar_direction(host)
			timer = randf_range(2.0, 5.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WANDER)
		return false
		
	func _find_valid_soar_direction(host: CharacterBody3D) -> Vector3:
		for i: int in range(6):
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			if FaunaAIBehavior._is_direction_safe_fauna(host, candidate):
				return candidate
		var fallback_angle := randf() * TAU
		return Vector3(cos(fallback_angle), 0.0, sin(fallback_angle))

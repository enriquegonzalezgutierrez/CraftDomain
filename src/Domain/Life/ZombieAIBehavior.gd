# ==============================================================================
# Pathfile: res://src/Domain/Life/ZombieAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing hostile zombie routines,
#              including player tracking, glitched spotted roars, and wall flanking.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates sensory spotting, path 
#   pursuit, and close-proximity attack actions into decoupled inner classes.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows custom zombie 
#   mutation types (e.g., runners, tanks) to be added without code rewrites.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ZombieAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA COMPORTAMIENTO AGRESIVO EQUILIBRADO
const SPEED_CHASE: float = 4.4
const SPEED_WANDER: float = 2.2

const RANGE_CHASE_SQ: float = 256.0
const RANGE_ATTACK_SQ: float = 1.44
const COOLDOWN_ATTACK_SEC: float = 1.5
const ALERT_DURATION_SEC: float = 0.8

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(SpotTargetAction.new())
	_actions.append(ChaseTargetAction.new())
	_actions.append(AttackTargetAction.new())
	_actions.append(ZombieWanderAction.new())


func _setup_goals() -> void:
	var hunt_goal := GOAPGoal.new("HuntPrey", 2.0)
	hunt_goal.add_desired_state("did_eliminate", true)
	
	var wander_goal := GOAPGoal.new("IdleWander", 0.5)
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
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("alert_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)
		_blackboard.set_memory("has_spotted", false)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var alert := _blackboard.get_float("alert_timer") - delta
	_blackboard.set_memory("alert_timer", maxf(0.0, alert))


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
	state["did_eliminate"] = not _is_target_active()
	state["is_wandering"] = false
	return state


func _is_target_active() -> bool:
	var target := _blackboard.get_object("threat_target") as Node3D
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
		_blackboard.set_memory("has_spotted", false)
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
		if action_name == "SpotTarget": return "EXAMINE"
		elif action_name == "ChaseTarget": return "CHASING"
		elif action_name == "AttackTarget": return "ATTACKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled hostile behaviors)
# ==============================================================================

class SpotTargetAction extends GOAPAction:
	func _init() -> void:
		super("SpotTarget", 1.0)
		add_effect("has_target", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_prey(host)
		if is_instance_valid(target):
			bb.set_memory("threat_target", target)
			if not bb.get_bool("has_spotted"):
				bb.set_memory("has_spotted", true)
				bb.set_memory("alert_timer", ALERT_DURATION_SEC)
				if host.has_method("_play_spotted_roar"):
					host.call("_play_spotted_roar", target)
			return true
		return false
		
	func _scan_for_prey(host: CharacterBody3D) -> Node3D:
		var host_pos := host.global_position
		var closest: Node3D = null
		var min_dist_sq := RANGE_CHASE_SQ
		var targets := _gather_prey_population(host)
		
		for child in targets:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child
		return closest
		
	func _gather_prey_population(host: CharacterBody3D) -> Array[Node3D]:
		var list: Array[Node3D] = []
		var passives := host.get_tree().get_nodes_in_group("passives")
		for child in passives:
			if child is CharacterBody3D and child.name != host.name:
				list.append(child as Node3D)
				
		var parent := host.get_parent()
		if is_instance_valid(parent):
			var player_node := parent.get_node_or_null("Player") as Node3D
			if is_instance_valid(player_node) and player_node.get("is_active"):
				list.append(player_node)
		return list


class ChaseTargetAction extends GOAPAction:
	func _init() -> void:
		super("ChaseTarget", 1.0)
		add_precondition("has_target", true)
		add_effect("is_at_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("threat_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("threat_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if bb.get_float("alert_timer") > 0.0:
			_freeze_and_look(host, ai, diff.normalized())
			return false
			
		if diff.length_squared() <= RANGE_ATTACK_SQ:
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_CHASE)
		return false
		
	func _freeze_and_look(host: CharacterBody3D, ai: Object, dir: Vector3) -> void:
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai):
			ai.set("wander_direction", dir)
			ai.set("current_task", TASK_WORKING)


class AttackTargetAction extends GOAPAction:
	func _init() -> void:
		super("AttackTarget", 1.0)
		add_precondition("is_at_target", true)
		add_effect("did_eliminate", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("threat_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("threat_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		if diff.length_squared() > RANGE_ATTACK_SQ:
			return true # Target moved; re-plan to chase
			
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


class ZombieWanderAction extends GOAPAction:
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
			timer = randf_range(2.0, 5.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.4 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WANDER)
		return false

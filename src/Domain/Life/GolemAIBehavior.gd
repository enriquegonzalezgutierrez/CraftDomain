# ==============================================================================
# Pathfile: res://src/Domain/Life/GolemAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Colossus Iron Golem.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates defensive threat scans, 
#   sprint interceptions, and colossal slam attacks into distinct actions.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GolemAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_CHASE_MULT: float = 1.3
const SPEED_PATROL: float = 2.0

const RANGE_SIGHT_SQ: float = 400.0
const RANGE_ATTACK_SQ: float = 4.84
const COOLDOWN_ATTACK_SEC: float = 1.8
const SCAN_INTERVAL_SEC: float = 0.25

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ScanForThreatsAction.new())
	_actions.append(SprintToThreatAction.new())
	_actions.append(SlamAttackAction.new())
	_actions.append(OverwatchPatrolAction.new())


func _setup_goals() -> void:
	var protect_goal := GOAPGoal.new("ProtectVillage", 2.0)
	protect_goal.add_desired_state("village_secured", true)
	
	var overwatch_goal := GOAPGoal.new("OverwatchPatrol", 0.5)
	overwatch_goal.add_desired_state("is_patrolling", true)
	
	_goals.append_array([protect_goal, overwatch_goal])


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
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("scan_timer", SCAN_INTERVAL_SEC)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var scan := _blackboard.get_float("scan_timer") - delta
	_blackboard.set_memory("scan_timer", maxf(0.0, scan))


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
		
		for goal in sorted_goals:
			if goal.is_valid(_blackboard):
				var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
				if not candidate_plan.is_empty():
					_active_plan = candidate_plan
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["village_secured"] = not _is_threat_active()
	state["is_patrolling"] = false
	return state


func _is_threat_active() -> bool:
	var target := _blackboard.get_object("combat_target") as Node3D
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
		if action_name == "SprintToThreat": return "CHARGE_TO_TARGET"
		elif action_name == "SlamAttack": return "LAUNCH_ATTACK"
		elif action_name == "OverwatchPatrol": return "OVERWATCH_PATROL"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Golem combat and defense mechanics)
# ==============================================================================

class ScanForThreatsAction extends GOAPAction:
	func _init() -> void:
		super("ScanForThreats", 1.0)
		add_effect("has_threat_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("scan_timer") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		bb.set_memory("scan_timer", SCAN_INTERVAL_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_active_hostile_target(host)
		
		if is_instance_valid(target):
			bb.set_memory("combat_target", target)
			return true
		return true
		
	func _scan_for_active_hostile_target(host: CharacterBody3D) -> Node3D:
		var host_pos := host.global_position
		var closest: Node3D = null
		var min_dist_sq := RANGE_SIGHT_SQ
		
		var rep := VillageReputationService.instance
		if is_instance_valid(rep) and rep.is_player_wanted():
			closest = _get_player_target(host)
			if is_instance_valid(closest):
				min_dist_sq = host_pos.distance_squared_to(closest.global_position)
				
		return _scan_for_zombies(host, closest, min_dist_sq)
		
	func _get_player_target(host: CharacterBody3D) -> Node3D:
		var parent := host.get_parent()
		if is_instance_valid(parent):
			var player_node := parent.get_node_or_null("Player") as Node3D
			if is_instance_valid(player_node):
				var p_domain := player_node.get("domain_entity") as VoxelEntity
				if is_instance_valid(p_domain) and not p_domain.is_dead:
					return player_node
		return null
		
	func _scan_for_zombies(host: CharacterBody3D, current_closest: Node3D, min_dist_sq: float) -> Node3D:
		var closest := current_closest
		var hostiles := host.get_tree().get_nodes_in_group("hostiles")
		
		for child in hostiles:
			if is_instance_valid(child) and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest


class SprintToThreatAction extends GOAPAction:
	func _init() -> void:
		super("SprintToThreat", 1.0)
		add_precondition("has_threat_target", true)
		add_effect("is_at_threat", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("combat_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("combat_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= RANGE_ATTACK_SQ:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		var base_speed: float = host.get("BASE_SPEED") as float if "BASE_SPEED" in host else 1.3
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), base_speed * SPEED_CHASE_MULT)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class SlamAttackAction extends GOAPAction:
	func _init() -> void:
		super("SlamAttack", 1.0)
		add_precondition("is_at_threat", true)
		add_effect("village_secured", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("combat_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("combat_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() > RANGE_ATTACK_SQ:
			return true
			
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
			
		var cooldown := bb.get_float("attack_cooldown")
		if cooldown <= 0.0:
			bb.set_memory("attack_cooldown", COOLDOWN_ATTACK_SEC)
			if host.has_method("_execute_heavy_combat_strike"):
				host.call("_execute_heavy_combat_strike", target)
				
			var vis := host.get("visual_representation") as IEntityVisualRepresentation
			if is_instance_valid(vis): vis.trigger_attack_visuals()
		return false


class OverwatchPatrolAction extends GOAPAction:
	func _init() -> void:
		super("OverwatchPatrol", 1.0)
		add_effect("is_patrolling", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(3.0, 7.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
		return false

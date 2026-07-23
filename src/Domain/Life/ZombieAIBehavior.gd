# ==============================================================================
# Pathfile: res://src/Domain/Life/ZombieAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing hostile zombie routines
#              with instant reactive prey detection and smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ZombieAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_CHASE: float = 2.8
const SPEED_WANDER: float = 1.0

const RANGE_CHASE_SQ: float = 400.0
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
	_actions.append(ZombieRestAction.new())
	_actions.append(ZombieWanderAction.new())


func _setup_goals() -> void:
	var hunt_goal := GOAPGoal.new("HuntPrey", 2.0)
	hunt_goal.add_desired_state("did_eliminate", true)
	
	var lurk_goal := GOAPGoal.new("Lurk", 1.0)
	lurk_goal.add_desired_state("is_lurking", true)
	
	var wander_goal := GOAPGoal.new("IdleWander", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([hunt_goal, lurk_goal, wander_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_timers(delta)
	
	_check_and_interrupt_wander_if_prey_detected(host as CharacterBody3D)
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _check_and_interrupt_wander_if_prey_detected(host: CharacterBody3D) -> void:
	if not _active_plan.is_empty() and _active_plan[0] is ZombieWanderAction:
		var prey := SpotTargetAction._scan_for_prey_static(host)
		if is_instance_valid(prey):
			_active_plan.clear()
			_blackboard.set_memory("threat_target", prey)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("spot_cooldown", 0.0)
		_blackboard.set_memory("alert_timer", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)
		_blackboard.set_memory("has_spotted", false)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var spot_cd := _blackboard.get_float("spot_cooldown") - delta
	_blackboard.set_memory("spot_cooldown", maxf(0.0, spot_cd))
	
	var alert := _blackboard.get_float("alert_timer") - delta
	_blackboard.set_memory("alert_timer", maxf(0.0, alert))
	
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
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
	state["did_eliminate"] = not _is_target_active()
	state["is_lurking"] = false
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
		elif action_name == "ZombieRest": return "IDLE"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled hostile behaviors)
# ==============================================================================

class SpotTargetAction extends GOAPAction:
	func _init() -> void:
		super("SpotTarget", 1.0)
		add_effect("has_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("spot_cooldown") <= 0.0 or bb.has_memory("threat_target")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_prey_static(host)
		if is_instance_valid(target):
			bb.set_memory("threat_target", target)
			if not bb.get_bool("has_spotted"):
				bb.set_memory("has_spotted", true)
				bb.set_memory("alert_timer", ZombieAIBehavior.ALERT_DURATION_SEC)
				if host.has_method("_play_spotted_roar"):
					host.call("_play_spotted_roar", target)
			return true
			
		bb.set_memory("spot_cooldown", 3.0)
		return true
		
	static func _scan_for_prey_static(host: CharacterBody3D) -> Node3D:
		var host_pos := host.global_position
		var closest: Node3D = null
		var min_dist_sq := ZombieAIBehavior.RANGE_CHASE_SQ
		var targets := _gather_prey_population_static(host)
		
		for child: Node in targets:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as Node3D
		return closest
		
	static func _gather_prey_population_static(host: CharacterBody3D) -> Array[Node3D]:
		var list: Array[Node3D] = []
		var passives := host.get_tree().get_nodes_in_group("passives")
		for child: Node in passives:
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
			
		if diff.length_squared() <= ZombieAIBehavior.RANGE_ATTACK_SQ:
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), ZombieAIBehavior.SPEED_CHASE)
		return false
		
	func _freeze_and_look(host: CharacterBody3D, ai: Object, dir: Vector3) -> void:
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai):
			ai.set("wander_direction", dir)
			ai.set("current_task", ZombieAIBehavior.TASK_WORKING)


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
		if diff.length_squared() > ZombieAIBehavior.RANGE_ATTACK_SQ:
			return true
			
		_execute_bite(bb, host, ai, diff.normalized())
		return false
		
	func _execute_bite(bb: AIBlackboard, host: CharacterBody3D, ai: Object, dir: Vector3) -> void:
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("wander_direction", dir)
			
		var cooldown := bb.get_float("attack_cooldown")
		if cooldown <= 0.0:
			bb.set_memory("attack_cooldown", ZombieAIBehavior.COOLDOWN_ATTACK_SEC)
			if host.has_method("_bite_player"):
				host.call("_bite_player")
				
			var vis := host.get("visual_representation") as IEntityVisualRepresentation
			if is_instance_valid(vis): vis.trigger_attack_visuals()


class ZombieRestAction extends GOAPAction:
	func _init() -> void:
		super("ZombieRest", 1.0)
		add_effect("is_lurking", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("rest_timer") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", randf_range(3.0, 7.0))
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("rest_timer", randf_range(10.0, 20.0))
			return true
		return false


class ZombieWanderAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_wandering", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("patrol_duration", randf_range(10.0, 18.0))
		bb.set_memory("wander_timer", 0.0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var duration := bb.get_float("patrol_duration") - delta
		bb.set_memory("patrol_duration", duration)
		if duration <= 0.0:
			return true
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			wander_dir = _find_safe_wander_direction(host)
			timer = randf_range(3.0, 6.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, ZombieAIBehavior.SPEED_WANDER)
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

	func _is_pushing_into_wall(host: CharacterBody3D, wander_dir: Vector3) -> bool:
		if not host.is_on_wall() or wander_dir == Vector3.ZERO:
			return false
		var wall_normal := host.get_wall_normal()
		var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
		return flat_normal != Vector3.ZERO and wander_dir.normalized().dot(-flat_normal) > 0.25

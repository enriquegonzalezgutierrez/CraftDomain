# ==============================================================================
# Pathfile: res://src/Domain/Life/GargoyleAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Hostile Nocturnal Gargoyle with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GargoyleAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_CHASE: float = 4.0
const SPEED_WANDER: float = 1.6

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
		if action_name == "SoarChase": return "CHASING"
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
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			wander_dir = _find_safe_wander_direction(host)
			timer = randf_range(3.0, 6.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WANDER)
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
			
		var distances: Array[float] = [1.0, 2.0]
		for dist: float in distances:
			var check_pos: Vector3 = host.global_position + dir * dist
			var feet_y := floori(check_pos.y + 0.5)
			var feet_coord := Vector3i(floori(check_pos.x), feet_y, floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), feet_y + 1, floori(check_pos.z))
			
			var feet_block := ws.get_block(feet_coord)
			var chest_block := ws.get_block(chest_coord)
			
			# Gargoyles fly safely through empty air, water, and lava
			if BlockLibrary.is_solid(feet_block) or BlockLibrary.is_solid(chest_block):
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

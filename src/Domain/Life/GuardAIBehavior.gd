# ==============================================================================
# Pathfile: res://src/Domain/Life/GuardAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Armored Guard Knight with A* Path Navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GuardAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_PATROL: float = 1.6
const SPEED_CHASE: float = 3.6

const RANGE_SIGHT_SQ: float = 400.0
const RANGE_ATTACK_SQ: float = 2.56
const COOLDOWN_ATTACK_SEC: float = 1.2
const PATH_RECALC_INTERVAL_SEC: float = 0.4

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(FindThreatAction.new())
	_actions.append(ChaseThreatAction.new())
	_actions.append(EliminateThreatAction.new())
	_actions.append(GuardPatrolAction.new())


func _setup_goals() -> void:
	var secure_goal := GOAPGoal.new("SecureVillage", 2.0)
	secure_goal.add_desired_state("is_secure", true)
	
	var patrol_goal := GOAPGoal.new("PatrolBorders", 0.5)
	patrol_goal.add_desired_state("is_patrolling", true)
	
	_goals.append_array([secure_goal, patrol_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host): return
		
	_initialize_agent(host)
	_update_blackboard_cooldowns(delta)
	
	if host.get("is_talking") == true:
		_handle_conversation_interrupt(host)
		return
		
	_check_and_interrupt_patrol_if_threat_detected(host as CharacterBody3D)
	_evaluate_active_plan()
	_execute_current_action(delta)


func _check_and_interrupt_patrol_if_threat_detected(host: CharacterBody3D) -> void:
	if not _active_plan.is_empty() and _active_plan[0] is GuardPatrolAction:
		var threat := FindThreatAction._scan_for_active_targets_static(host)
		if is_instance_valid(threat):
			_active_plan.clear()
			_blackboard.set_memory("combat_target", threat)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("threat_scan_cooldown", 0.0)
		_blackboard.set_memory("path_recalc_timer", 0.0)
		_blackboard.set_memory("guard_active_path", [])
		_blackboard.set_memory("path_index", 0)


func _update_blackboard_cooldowns(delta: float) -> void:
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var t_cd := _blackboard.get_float("threat_scan_cooldown") - delta
	_blackboard.set_memory("threat_scan_cooldown", maxf(0.0, t_cd))
	
	var recalc := _blackboard.get_float("path_recalc_timer") - delta
	_blackboard.set_memory("path_recalc_timer", maxf(0.0, recalc))


func _handle_conversation_interrupt(host: Object) -> void:
	_active_plan.clear()
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)


func _evaluate_active_plan() -> void:
	if not _active_plan.is_empty(): return
		
	var initial_state := _build_initial_state()
	var sorted_goals := _get_sorted_goals()
	
	var usable_actions: Array[GOAPAction] = []
	for action: GOAPAction in _actions:
		if action.is_contextually_valid(_blackboard):
			usable_actions.append(action)
	
	for goal in sorted_goals:
		if not goal.is_valid(_blackboard): continue
		if goal.is_satisfied(initial_state): continue
			
		var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
		if not candidate_plan.is_empty():
			_active_plan = candidate_plan
			_active_plan[0].on_enter(_blackboard)
			break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_secure"] = not _is_threat_active()
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
	if _active_plan.is_empty(): return
		
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
		if action_name == "ChaseThreat": return "SPRINTING_TO_THREAT"
		elif action_name == "EliminateThreat": return "ENGAGING_THREAT"
		elif action_name == "GuardPatrol": return "OVERWATCH_PATROL"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS
# ==============================================================================

class FindThreatAction extends GOAPAction:
	func _init() -> void:
		super("FindThreat", 1.0)
		add_effect("has_threat", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("threat_scan_cooldown") <= 0.0 or bb.has_memory("combat_target")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var threat := _scan_for_active_targets_static(host)
		if is_instance_valid(threat):
			bb.set_memory("combat_target", threat)
			return true
			
		bb.set_memory("threat_scan_cooldown", 3.0)
		return true
		
	static func _scan_for_active_targets_static(host: CharacterBody3D) -> Node3D:
		var host_pos := host.global_position
		var closest: Node3D = null
		var min_dist_sq := RANGE_SIGHT_SQ
		var rep := VillageReputationService.instance
		
		if is_instance_valid(rep) and rep.is_player_wanted():
			closest = _get_player_target_static(host)
			if is_instance_valid(closest):
				min_dist_sq = host_pos.distance_squared_to(closest.global_position)
				
		return _scan_for_zombies_static(host, closest, min_dist_sq)
		
	static func _get_player_target_static(host: CharacterBody3D) -> Node3D:
		var parent := host.get_parent()
		if is_instance_valid(parent):
			var player := parent.get_node_or_null("Player") as Node3D
			if is_instance_valid(player):
				var p_domain := player.get("domain_entity") as VoxelEntity
				if is_instance_valid(p_domain) and not p_domain.is_dead:
					return player
		return null
		
	static func _scan_for_zombies_static(host: CharacterBody3D, current_closest: Node3D, min_dist_sq: float) -> Node3D:
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


class ChaseThreatAction extends GOAPAction:
	func _init() -> void:
		super("ChaseThreat", 1.0)
		add_precondition("has_threat", true)
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
		var diff := target.global_position - host.global_position
		
		if diff.length_squared() <= RANGE_ATTACK_SQ:
			bb.set_memory("guard_active_path", [])
			bb.set_memory("path_index", 0)
			return true
			
		_execute_astar_navigation(bb, host, target.global_position)
		return false
		
	func _execute_astar_navigation(bb: AIBlackboard, host: CharacterBody3D, target_pos: Vector3) -> void:
		var path: Array = bb.get_memory("guard_active_path", []) as Array
		var p_idx := bb.get_int("path_index")
		
		if bb.get_float("path_recalc_timer") <= 0.0 or path.is_empty():
			bb.set_memory("path_recalc_timer", PATH_RECALC_INTERVAL_SEC)
			var parent := host.get_parent() as Node
			if is_instance_valid(parent) and "navigation_service" in parent:
				var nav := parent.get("navigation_service") as VoxelNavigationService
				path = nav.find_path(host.global_position, target_pos) if is_instance_valid(nav) else []
			p_idx = 0
			bb.set_memory("guard_active_path", path)
			
		var ai: Object = host.get("ai_component")
		p_idx = VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, SPEED_CHASE, "path_index")
		bb.set_memory("path_index", p_idx)


class EliminateThreatAction extends GOAPAction:
	func _init() -> void:
		super("EliminateThreat", 1.0)
		add_precondition("is_at_threat", true)
		add_effect("is_secure", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("combat_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("combat_target") as Node3D
		var diff := target.global_position - host.global_position
		
		if diff.length_squared() > RANGE_ATTACK_SQ:
			return true
			
		_execute_proximity_strike(bb, host, target, diff.normalized())
		return false
		
	func _execute_proximity_strike(bb: AIBlackboard, host: CharacterBody3D, target: Node3D, dir: Vector3) -> void:
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("wander_direction", dir)
			
		if bb.get_float("attack_cooldown") <= 0.0:
			bb.set_memory("attack_cooldown", COOLDOWN_ATTACK_SEC)
			var kb := dir * 4.5
			kb.y = 2.0
			if target.has_method("take_damage"):
				target.call("take_damage", 1, kb, host)
				
			var vis := host.get("visual_representation") as IEntityVisualRepresentation
			if is_instance_valid(vis): vis.trigger_attack_visuals()


class GuardPatrolAction extends GOAPAction:
	func _init() -> void:
		super("GuardPatrol", 1.0)
		add_effect("is_patrolling", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("patrol_duration", randf_range(15.0, 30.0))
		bb.set_memory("guard_active_path", [])
		bb.set_memory("path_index", 0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host): return true
		
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var duration := bb.get_float("patrol_duration") - delta
		bb.set_memory("patrol_duration", duration)
		if duration <= 0.0:
			return true
			
		_execute_astar_guard_patrol(bb, host, ai)
		return false

	func _execute_astar_guard_patrol(bb: AIBlackboard, host: CharacterBody3D, ai: Object) -> void:
		var path: Array = bb.get_memory("guard_active_path", []) as Array
		var p_idx := bb.get_int("path_index")
		
		if path.is_empty() or p_idx >= path.size():
			path = _calculate_guard_destination_path(host)
			p_idx = 0
			bb.set_memory("guard_active_path", path)
			
		if not path.is_empty():
			p_idx = VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, SPEED_PATROL, "path_index")
			bb.set_memory("path_index", p_idx)
		else:
			var parent := host.get_parent()
			var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) and "world_state" in parent else null
			var wander_dir := VoxelKinematicService.get_safe_fallback_wander_direction(host, ws)
			VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)

	func _calculate_guard_destination_path(host: CharacterBody3D) -> Array[Vector3]:
		var parent := host.get_parent()
		if not is_instance_valid(parent) or not "navigation_service" in parent:
			return []
			
		var nav: VoxelNavigationService = parent.get("navigation_service") as VoxelNavigationService
		if not is_instance_valid(nav):
			return []
			
		var is_inside := _check_if_confined_inside(host, nav)
		if is_inside:
			var door_target := nav.find_closest_doorway_node(host.global_position)
			if door_target != Vector3.ZERO:
				var path_to_door := nav.find_path(host.global_position, door_target)
				if not path_to_door.is_empty():
					_extend_path_beyond_doorway(path_to_door, nav)
					return path_to_door
					
		var target_pos := nav.get_random_walkable_node_near(host.global_position, 10.0, 25.0)
		if target_pos != Vector3.ZERO:
			return nav.find_path(host.global_position, target_pos)
			
		var random_target := _select_random_target_offset(host)
		return nav.find_path(host.global_position, random_target)

	func _check_if_confined_inside(host: CharacterBody3D, nav: VoxelNavigationService) -> bool:
		var parent := host.get_parent()
		if not is_instance_valid(parent) or not "world_state" in parent:
			return false
			
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null:
			return false
			
		var h_pos := host.global_position
		var feet_y := floori(h_pos.y + 0.5)
		var center_coord := Vector3i(floori(h_pos.x), feet_y, floori(h_pos.z))
		
		if nav != null and "_indoor_nodes" in nav and (nav.get("_indoor_nodes") as Array).has(center_coord):
			return true
			
		var blocked_count := 0
		var offsets: Array[Vector3i] = [Vector3i(2, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 0, 2), Vector3i(0, 0, -2)]
		
		for offset: Vector3i in offsets:
			var check_coord := center_coord + offset
			if BlockLibrary.is_solid(ws.get_block(check_coord)) or BlockLibrary.is_solid(ws.get_block(check_coord + Vector3i(0, 1, 0))):
				blocked_count += 1
				
		return blocked_count >= 2

	func _extend_path_beyond_doorway(path: Array[Vector3], nav: VoxelNavigationService) -> void:
		if path.size() >= 2:
			var door_node: Vector3 = path.back()
			var prev_node: Vector3 = path[path.size() - 2]
			var exit_dir: Vector3 = (door_node - prev_node).normalized()
			var exit_pos: Vector3 = door_node + (exit_dir * 4.0)
			
			var extended_path := nav.find_path(door_node, exit_pos)
			if extended_path.size() > 1:
				for i: int in range(1, extended_path.size()):
					path.append(extended_path[i])

	func _select_random_target_offset(host: CharacterBody3D) -> Vector3:
		var angle := randf() * TAU
		var dist := randf_range(10.0, 20.0)
		var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		return host.global_position + offset

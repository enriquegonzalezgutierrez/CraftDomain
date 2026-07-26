# ==============================================================================
# Pathfile: res://src/Domain/Life/QuiqueAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Quique with A* Path Navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name QuiqueAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5

const SPEED_STROLL: float = 1.4
const SPEED_PANIC: float = 4.5
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
		_blackboard.set_memory("quique_active_path", [])
		_blackboard.set_memory("path_index", 0)


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
			timer = randf_range(0.8, 1.8) 
			var candidate := Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
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
		bb.set_memory("stroll_duration", randf_range(15.0, 30.0))
		bb.set_memory("quique_active_path", [])
		bb.set_memory("path_index", 0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host): return true
		
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var duration := bb.get_float("stroll_duration") - delta
		bb.set_memory("stroll_duration", duration)
		if duration <= 0.0:
			return true
			
		_execute_astar_quique_navigation(bb, host, ai)
		return false

	func _execute_astar_quique_navigation(bb: AIBlackboard, host: CharacterBody3D, ai: Object) -> void:
		var path: Array = bb.get_memory("quique_active_path", []) as Array
		var p_idx := bb.get_int("path_index")
		
		if path.is_empty() or p_idx >= path.size():
			path = _calculate_quique_destination_path(host)
			p_idx = 0
			bb.set_memory("quique_active_path", path)
			
		if not path.is_empty():
			p_idx = VoxelKinematicService.navigate_along_path(host, ai, path, p_idx, SPEED_STROLL, "path_index")
			bb.set_memory("path_index", p_idx)
		else:
			var parent := host.get_parent()
			var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) and "world_state" in parent else null
			var wander_dir := VoxelKinematicService.get_safe_fallback_wander_direction(host, ws)
			VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_STROLL)

	func _calculate_quique_destination_path(host: CharacterBody3D) -> Array[Vector3]:
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

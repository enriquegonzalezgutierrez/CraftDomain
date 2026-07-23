# ==============================================================================
# Pathfile: res://src/Domain/Life/CyberCitizenAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Cyber Citizen Android NPC with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CyberCitizenAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_PATROL: float = 2.6
const SPEED_RETREAT: float = 3.6

const SCAN_INTERVAL_SEC: float = 4.0
const SCAN_DURATION_SEC: float = 1.6
const UPLOAD_INTERVAL_SEC: float = 15.0
const UPLOAD_DURATION_SEC: float = 3.0
const SENSORY_RANGE_SQ: float = 100.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(TacticalFleeAction.new())
	_actions.append(ScanTerminalsAction.new())
	_actions.append(UploadDataAction.new())
	_actions.append(Perform360ScanAction.new())
	_actions.append(RoadPatrolAction.new())


func _setup_goals() -> void:
	var defend_goal := GOAPGoal.new("TacticalDefend", 10.0)
	defend_goal.add_desired_state("is_safe", true)
	
	var upload_goal := GOAPGoal.new("TransmitData", 2.0)
	upload_goal.add_desired_state("data_uploaded", true)
	
	var sweep_goal := GOAPGoal.new("SecuritySweep", 1.0)
	sweep_goal.add_desired_state("area_swept", true)
	
	var patrol_goal := GOAPGoal.new("PatrolHighways", 0.5)
	patrol_goal.add_desired_state("is_patrolling", true)
	
	_goals.append_array([defend_goal, upload_goal, sweep_goal, patrol_goal])


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
		_blackboard.set_memory("scan_timer", SCAN_INTERVAL_SEC)
		_blackboard.set_memory("upload_cooldown", 5.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var scan_timer := _blackboard.get_float("scan_timer") - delta
	_blackboard.set_memory("scan_timer", maxf(0.0, scan_timer))
	
	var upload_cd := _blackboard.get_float("upload_cooldown") - delta
	_blackboard.set_memory("upload_cooldown", maxf(0.0, upload_cd))


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
		
		for goal in sorted_goals:
			if goal.is_valid(_blackboard):
				var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
				if not candidate_plan.is_empty():
					_active_plan = candidate_plan
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["data_uploaded"] = false
	state["area_swept"] = false
	state["is_patrolling"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= SENSORY_RANGE_SQ:
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
		if action_name == "RoadPatrol": return "WANDER"
		elif action_name == "Perform360Scan" or action_name == "UploadData": return "WORKING"
		elif action_name == "TacticalFlee": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled robotic behaviors)
# ==============================================================================

class TacticalFleeAction extends GOAPAction:
	func _init() -> void:
		super("TacticalFlee", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var threat := _scan_for_closest_threat(host)
		if not is_instance_valid(threat): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var run_dir := (host.global_position - threat.global_position).normalized()
		run_dir.y = 0.0
		
		if host.is_on_wall():
			var normal := host.get_wall_normal()
			var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				run_dir = run_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
				run_dir.y = 0.0
				
		VoxelKinematicService.apply_motion_vectors(host, ai, run_dir, SPEED_RETREAT)
		return false
		
	func _scan_for_closest_threat(host: CharacterBody3D) -> Node3D:
		var hostiles := host.get_tree().get_nodes_in_group("hostiles")
		var closest: Node3D = null
		var min_dist_sq := SENSORY_RANGE_SQ
		
		for child in hostiles:
			if is_instance_valid(child) and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest


class ScanTerminalsAction extends GOAPAction:
	func _init() -> void:
		super("ScanTerminals", 1.0)
		add_effect("has_terminal_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("upload_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null:
			var terminal := _scan_for_nearby_terminal(host.global_position, ws)
			if terminal != Vector3i(0, -999, 0):
				bb.set_memory("target_terminal", terminal)
				return true
				
		bb.set_memory("upload_cooldown", UPLOAD_INTERVAL_SEC)
		return true
		
	func _scan_for_nearby_terminal(host_pos: Vector3, ws: WorldState) -> Vector3i:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		for x in range(-3, 4):
			for y in range(-2, 3):
				for z in range(-3, 4):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == 13:
						return c
		return Vector3i(0, -999, 0)


class UploadDataAction extends GOAPAction:
	func _init() -> void:
		super("UploadData", 1.0)
		add_precondition("has_terminal_target", true)
		add_effect("data_uploaded", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_terminal")
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("upload_timer", UPLOAD_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		var terminal: Vector3i = bb.get_vector3i("target_terminal")
		
		var term_pos := Vector3(terminal) + Vector3(0.5, 0.5, 0.5)
		var diff := (term_pos - host.global_position).normalized()
		if is_instance_valid(ai): ai.set("wander_direction", diff)
		
		if host.has_method("_play_security_scan"):
			host.call("_play_security_scan")
			
		var timer := bb.get_float("upload_timer") - delta
		bb.set_memory("upload_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("upload_cooldown", UPLOAD_INTERVAL_SEC)
			bb.erase_memory("target_terminal")
			bb.erase_memory("has_terminal_target")
			return true
		return false


class Perform360ScanAction extends GOAPAction:
	var _sub_timer: float = 0.0
	var _rot_step: int = 0
	
	func _init() -> void:
		super("Perform360Scan", 1.0)
		add_effect("area_swept", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("scan_timer") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		_sub_timer = SCAN_DURATION_SEC
		_rot_step = 0
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		_sub_timer -= delta
		if _sub_timer <= 0.0:
			_sub_timer = SCAN_DURATION_SEC / 4.0
			_rot_step += 1
			if _rot_step >= 4:
				bb.set_memory("scan_timer", SCAN_INTERVAL_SEC)
				return true
				
			var angle := float(_rot_step) * (PI / 2.0)
			if is_instance_valid(ai): ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
			if host.has_method("_play_security_scan"):
				host.call("_play_security_scan")
				
		return false


class RoadPatrolAction extends GOAPAction:
	func _init() -> void:
		super("RoadPatrol", 1.0)
		add_effect("is_patrolling", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			var parent := host.get_parent() as Node
			var road_vector := _scan_for_paved_roads(host.global_position, parent)
			wander_dir = road_vector if road_vector != Vector3.ZERO else _find_safe_wander_direction(host)
			timer = randf_range(3.0, 6.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, CyberCitizenAIBehavior.SPEED_PATROL)
		return false

	func _scan_for_paved_roads(host_pos: Vector3, world_node: Node) -> Vector3:
		if not is_instance_valid(world_node) or not "world_state" in world_node: return Vector3.ZERO
		var ws: WorldState = world_node.get("world_state") as WorldState
		if ws == null: return Vector3.ZERO
		
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		for x in range(-2, 3):
			for z in range(-2, 3):
				var c := my_coord + Vector3i(x, -1, z)
				if ws.get_block(c) == 25:
					var diff := (Vector3(c) + Vector3(0.5, 1.0, 0.5)) - host_pos
					diff.y = 0.0
					if diff.length() > 0.8: return diff.normalized()
		return Vector3.ZERO

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
			var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 1.0), floori(check_pos.z))
			var below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y - 1.0), floori(check_pos.z))
			
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

# ==============================================================================
# Pathfile: res://src/Domain/Life/CanineAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Fiery Growlithe dog with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CanineAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_WALK: float = 1.4
const SPEED_TROT: float = 2.4
const COOLDOWN_BARK_SEC: float = 4.0
const INVALID_COORD := Vector3i(0, -999, 0)

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ScanMagmaAction.new())
	_actions.append(TrotToMagmaAction.new())
	_actions.append(FlameBarkAction.new())
	_actions.append(TailChaseAction.new())
	_actions.append(SniffWanderAction.new())


func _setup_goals() -> void:
	var magma_goal := GOAPGoal.new("LocateGeothermalMagma", 2.0)
	magma_goal.add_desired_state("magma_located", true)
	
	var play_goal := GOAPGoal.new("PlayfulLeisure", 0.5)
	play_goal.add_desired_state("is_playing", true)
	
	_goals.append_array([magma_goal, play_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_cooldowns(delta)
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("bark_cooldown", 0.0)
		_blackboard.set_memory("magma_scan_cooldown", 0.0)
		_blackboard.set_memory("tail_chase_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_cooldowns(delta: float) -> void:
	var cd := _blackboard.get_float("bark_cooldown") - delta
	_blackboard.set_memory("bark_cooldown", maxf(0.0, cd))
	
	var m_cd := _blackboard.get_float("magma_scan_cooldown") - delta
	_blackboard.set_memory("magma_scan_cooldown", maxf(0.0, m_cd))
	
	var t_cd := _blackboard.get_float("tail_chase_cooldown") - delta
	_blackboard.set_memory("tail_chase_cooldown", maxf(0.0, t_cd))


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
	state["magma_located"] = false
	state["is_playing"] = false
	return state


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
		if action_name == "TrotToMagma": return "WANDERING"
		elif action_name == "FlameBark" or action_name == "TailChase": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled canine behaviors)
# ==============================================================================

class ScanMagmaAction extends GOAPAction:
	func _init() -> void:
		super("ScanMagma", 1.0)
		add_effect("has_magma_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("magma_scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var lava_coord := _scan_for_nearby_lava(host)
		
		if lava_coord != INVALID_COORD:
			bb.set_memory("target_lava", lava_coord)
			return true
			
		bb.set_memory("magma_scan_cooldown", 10.0)
		return true
		
	func _scan_for_nearby_lava(host: CharacterBody3D) -> Vector3i:
		var parent := host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent:
			return INVALID_COORD
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null:
			return INVALID_COORD
			
		var my_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
		for x in range(-5, 6):
			for y in range(-2, 3):
				for z in range(-5, 6):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == BlockType.Type.LAVA:
						return c
		return INVALID_COORD


class TrotToMagmaAction extends GOAPAction:
	func _init() -> void:
		super("TrotToMagma", 1.0)
		add_precondition("has_magma_target", true)
		add_effect("is_at_magma", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_lava")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_lava")
		var ai: Object = host.get("ai_component")
		
		var target_pos := Vector3(target) + Vector3(0.5, 0.0, 0.5)
		var diff := target_pos - host.global_position
		diff.y = 0.0
		
		if diff.length() <= 2.0:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_TROT)
		if is_instance_valid(ai):
			ai.set("current_task", TASK_WORKING)
		return false


class FlameBarkAction extends GOAPAction:
	func _init() -> void:
		super("FlameBark", 1.0)
		add_precondition("is_at_magma", true)
		add_effect("magma_located", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		
		var cd := bb.get_float("bark_cooldown") - delta
		bb.set_memory("bark_cooldown", cd)
		
		if cd <= 0.0:
			bb.set_memory("bark_cooldown", COOLDOWN_BARK_SEC)
			if host.has_method("_play_flame_bark"):
				host.call("_play_flame_bark")
				
		bb.erase_memory("target_lava")
		bb.erase_memory("has_magma_target")
		bb.erase_memory("is_at_magma")
		return true


class TailChaseAction extends GOAPAction:
	func _init() -> void:
		super("TailChase", 1.0)
		add_effect("is_playing", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("tail_chase_cooldown") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", 3.0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("current_task", TASK_WORKING)
			
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		var elapsed := float(Time.get_ticks_msec()) / 100.0
		var spin_dir := Vector3(cos(elapsed), 0.0, sin(elapsed)).normalized()
		VoxelKinematicService.apply_motion_vectors(host, ai, spin_dir, SPEED_WALK)
		
		if timer <= 0.0:
			bb.set_memory("tail_chase_cooldown", 15.0)
			return true
		return false


class SniffWanderAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_playing", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("current_task", TASK_WANDERING)
		
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			wander_dir = _find_safe_wander_direction(host)
			timer = randf_range(3.0, 6.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_impact(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WALK)
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

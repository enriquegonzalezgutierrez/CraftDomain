# ==============================================================================
# Pathfile: res://src/Domain/World/AmphibiousAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Amphibious Fauna (Turtles and Crabs) with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AmphibiousAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5

const SPEED_CRAWL: float = 1.0
const SPEED_SWIM: float = 2.0
const SPEED_PANIC_MULTIPLIER: float = 2.2
const SENSORY_RANGE_SQ: float = 64.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(AmphibiousPanicAction.new())
	_actions.append(CrawlShoreAction.new())
	_actions.append(SwimWaterAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadeThreats", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var navigate_goal := GOAPGoal.new("AmphibiousNavigate", 0.5)
	navigate_goal.add_desired_state("is_navigating", true)
	
	_goals.append_array([evade_goal, navigate_goal])


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
		_blackboard.set_memory("panic_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var panic := _blackboard.get_float("panic_timer") - delta
	_blackboard.set_memory("panic_timer", maxf(0.0, panic))


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
	state["is_navigating"] = false
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
		if action_name == "SwimWater": return "WORKING"
		elif action_name == "CrawlShore": return "WANDER"
		elif action_name == "AmphibiousPanic": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled amphibious behaviors)
# ==============================================================================

class AmphibiousPanicAction extends GOAPAction:
	func _init() -> void:
		super("AmphibiousPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var timer := bb.get_float("panic_timer")
		if timer <= 0.0:
			bb.set_memory("panic_timer", 3.0)
			
		var wander_dir := bb.get_vector3("wander_direction")
		if wander_dir == Vector3.ZERO:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		var is_in_water := _detect_water_state(host)
		var speed := (SPEED_SWIM if is_in_water else SPEED_CRAWL) * SPEED_PANIC_MULTIPLIER
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, speed)
		
		return bb.get_float("panic_timer") - delta <= 0.0
		
	func _detect_water_state(host: CharacterBody3D) -> bool:
		var parent := host.get_parent() as Node
		if is_instance_valid(parent) and "world_state" in parent:
			var ws: WorldState = parent.world_state
			if ws != null:
				var feet_y := floori(host.global_position.y + 0.5)
				var feet := Vector3i(floori(host.global_position.x), feet_y, floori(host.global_position.z))
				var below := Vector3i(floori(host.global_position.x), feet_y - 1, floori(host.global_position.z))
				return ws.get_block(feet) == 6 or ws.get_block(below) == 6
		return false


class CrawlShoreAction extends GOAPAction:
	func _init() -> void:
		super("CrawlShore", 1.0)
		add_effect("is_navigating", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		return not AmphibiousPanicAction.new()._detect_water_state(host)
		
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
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_CRAWL)
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


class SwimWaterAction extends GOAPAction:
	func _init() -> void:
		super("SwimWater", 1.0)
		add_effect("is_navigating", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		return AmphibiousPanicAction.new()._detect_water_state(host)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			timer = randf_range(3.0, 6.0)
			wander_dir = CrawlShoreAction.new()._find_safe_wander_direction(host)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_apply_swim_physics(host, ai, wander_dir, delta)
		return false
		
	func _apply_swim_physics(host: CharacterBody3D, ai: Object, wander_dir: Vector3, delta: float) -> void:
		var vel := host.velocity
		var in_liquid: bool = host.call("is_in_liquid") as bool if host.has_method("is_in_liquid") else true
		
		if wander_dir != Vector3.ZERO:
			vel.x = wander_dir.x * SPEED_SWIM
			vel.z = wander_dir.z * SPEED_SWIM
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 2.0) * 0.15, delta * 3.0)
		else:
			vel.x = move_toward(vel.x, 0.0, SPEED_SWIM)
			vel.z = move_toward(vel.z, 0.0, SPEED_SWIM)
			if in_liquid: vel.y = lerp(vel.y, sin(Time.get_ticks_msec() / 1000.0 * 1.5) * 0.08, delta * 3.0)
			
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)

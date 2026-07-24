# ==============================================================================
# Pathfile: res://src/Domain/Life/FarmerAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Farmer NPC with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FarmerAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_WANDER: float = 1.4
const SPEED_WORK: float = 1.8
const HARVEST_DURATION_SEC: float = 1.8
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
	_actions.append(ScanCropsAction.new())
	_actions.append(MoveToCropAction.new())
	_actions.append(HarvestCropAction.new())
	_actions.append(FarmerWanderAction.new())


func _setup_goals() -> void:
	var harvest_goal := GOAPGoal.new("KeepFarmHarvested", 2.0)
	harvest_goal.add_desired_state("did_harvest", true)
	
	var wander_goal := GOAPGoal.new("PatrolFarm", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([harvest_goal, wander_goal])


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
		_blackboard.set_memory("crop_scan_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("crop_scan_cooldown") - delta
	_blackboard.set_memory("crop_scan_cooldown", maxf(0.0, cd))


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
	state["did_harvest"] = false
	state["is_wandering"] = false
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
		if action_name == "ScanCrops": return "SCANNING_CROPS"
		elif action_name == "MoveToCrop" or action_name == "Wander": return "WANDERING"
		elif action_name == "Harvest": return "HARVESTING"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled atomic behaviors)
# ==============================================================================

class ScanCropsAction extends GOAPAction:
	func _init() -> void:
		super("ScanCrops", 1.0)
		add_effect("has_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("crop_scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var crop_coord := _scan_for_ripe_crops(host)
		
		if crop_coord != INVALID_COORD:
			if JobReservationService.instance.claim_job(crop_coord, host.get_instance_id()):
				bb.set_memory("target_crop", crop_coord)
				return true
				
		bb.set_memory("crop_scan_cooldown", 8.0)
		return false
		
	func _scan_for_ripe_crops(host: CharacterBody3D) -> Vector3i:
		var parent: Node = host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent: return INVALID_COORD
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null: return INVALID_COORD
			
		var my_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
		var job_service := JobReservationService.instance
		
		for x in range(-6, 7):
			for y in range(-2, 3):
				for z in range(-6, 7):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == BlockType.Type.CROP_RIPE:
						if not job_service.is_job_claimed(c): return c
		return INVALID_COORD


class MoveToCropAction extends GOAPAction:
	func _init() -> void:
		super("MoveToCrop", 1.0)
		add_precondition("has_target", true)
		add_effect("is_at_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_crop")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		var target: Vector3i = bb.get_vector3i("target_crop")
		
		var target_pos := Vector3(target) + Vector3(0.5, 0.0, 0.5)
		var diff := target_pos - host.global_position
		diff.y = 0.0
		
		if diff.length() < 1.1:
			VoxelKinematicService.halt_movement(host, ai)
			if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), FarmerAIBehavior.SPEED_WORK)
		if is_instance_valid(ai): ai.set("current_task", FarmerAIBehavior.TASK_WANDERING)
		return false


class HarvestCropAction extends GOAPAction:
	func _init() -> void:
		super("Harvest", 1.0)
		add_precondition("is_at_target", true)
		add_effect("did_harvest", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("harvest_timer", FarmerAIBehavior.HARVEST_DURATION_SEC)
		var host := bb.get_object("host") as Node3D
		var ai: Object = host.get("ai_component")
		
		VoxelKinematicService.halt_movement(host as CharacterBody3D, ai)
		if is_instance_valid(ai): ai.set("current_task", FarmerAIBehavior.TASK_WORKING)
		
		var vis: Resource = host.get("visual_representation") as Resource
		if is_instance_valid(vis) and vis.has_method("trigger_attack_visuals"):
			vis.call("trigger_attack_visuals")
			
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("harvest_timer") - delta
		bb.set_memory("harvest_timer", timer)
		
		if timer <= 0.0:
			_execute_harvest(bb)
			return true
		return false
		
	func _execute_harvest(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		var target: Vector3i = bb.get_vector3i("target_crop")
		
		JobReservationService.instance.release_job(target, host.get_instance_id())
		var parent := host.get_parent() as Node
		
		if is_instance_valid(parent) and parent.has_method("set_block_globally"):
			parent.call("set_block_globally", target, BlockType.Type.AIR)
			parent.call("set_block_globally", target, BlockType.Type.CROP_SEED)
			
		host.velocity.y = 4.5
		AudioService.play_sfx_static("block_break", host.global_position)
		
		bb.erase_memory("target_crop")
		bb.erase_memory("has_target")
		bb.erase_memory("is_at_target")


class FarmerWanderAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_wandering", true)
		
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
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, FarmerAIBehavior.SPEED_WANDER)
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

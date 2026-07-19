# ==============================================================================
# Pathfile: res://src/Domain/Life/PigAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Wild Pig.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates predator evasion, crop 
#   eating, and dynamic soil tilling into highly decoupled actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new crop types 
#   or soil parameters to be registered without modifying core loops.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PigAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_WALK: float = 0.8
const SPEED_PANIC: float = 2.4
const SPEED_TROT: float = 1.3
const SENSORY_RANGE_SQ: float = 64.0

const SNIFF_DURATION_SEC: float = 1.5
const TILL_DURATION_SEC: float = 2.0
const EAT_DURATION_SEC: float = 2.5
const COOLDOWN_TILL_MIN_SEC: float = 15.0
const COOLDOWN_TILL_MAX_SEC: float = 30.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(FleePredatorAction.new())
	_actions.append(ScanCropsAction.new())
	_actions.append(TrotToCropAction.new())
	_actions.append(EatCropAction.new())
	_actions.append(SniffSoilAction.new())
	_actions.append(TillSoilAction.new())
	_actions.append(PigWanderAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadePredators", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var eat_crops_goal := GOAPGoal.new("EatCrops", 3.0)
	eat_crops_goal.add_desired_state("crop_eaten", true)
	
	var till_goal := GOAPGoal.new("TillFallowSoil", 1.0)
	till_goal.add_desired_state("soil_tilled", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([evade_goal, eat_crops_goal, till_goal, wander_goal])


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
		_blackboard.set_memory("till_cooldown", 5.0) # Initial grace period
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("till_cooldown") - delta
	_blackboard.set_memory("till_cooldown", maxf(0.0, cd))


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
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["crop_eaten"] = false
	state["soil_tilled"] = false
	state["is_wandering"] = false
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
		if action_name == "EatCrop": return "SCANNING_CROPS"
		elif action_name == "TrotToCrop": return "WANDERING"
		elif action_name == "SniffSoil": return "EXAMINE"
		elif action_name == "TillSoil": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled porcine behaviors)
# ==============================================================================

class FleePredatorAction extends GOAPAction:
	func _init() -> void:
		super("FleePredator", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var threat := _scan_for_threat(host)
		if not is_instance_valid(threat): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var run_dir := (host.global_position - threat.global_position).normalized()
		run_dir.y = 0.0
		run_dir = run_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		
		VoxelKinematicService.apply_motion_vectors(host, ai, run_dir, SPEED_PANIC)
		return false
		
	func _scan_for_threat(host: CharacterBody3D) -> Node3D:
		var hostiles := host.get_tree().get_nodes_in_group("hostiles")
		for child in hostiles:
			if is_instance_valid(child) and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					if host.global_position.distance_squared_to(child.global_position) <= SENSORY_RANGE_SQ:
						return child as Node3D
		return null


class ScanCropsAction extends GOAPAction:
	func _init() -> void:
		super("ScanCrops", 1.0)
		add_effect("has_crop_target", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null:
			var crop_coord := _scan_for_nearby_crops(host.global_position, ws)
			if crop_coord != Vector3i(0, -999, 0):
				bb.set_memory("target_crop", crop_coord)
				return true
				
		return false
		
	func _scan_for_nearby_crops(host_pos: Vector3, ws: WorldState) -> Vector3i:
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		for x in range(-3, 4):
			for y in range(-1, 2):
				for z in range(-3, 4):
					var c := my_coord + Vector3i(x, y, z)
					var block_type := ws.get_block(c)
					if block_type == 20 or block_type == 19: # Ripe or Growing crops
						return c
		return Vector3i(0, -999, 0)


class TrotToCropAction extends GOAPAction:
	func _init() -> void:
		super("TrotToCrop", 1.0)
		add_precondition("has_crop_target", true)
		add_effect("is_at_crop", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_crop")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_crop")
		var ai: Object = host.get("ai_component")
		
		var target_pos := Vector3(target) + Vector3(0.5, 0.0, 0.5)
		var diff := target_pos - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 0.8:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_TROT)
		return false


class EatCropAction extends GOAPAction:
	func _init() -> void:
		super("EatCrop", 1.0)
		add_precondition("is_at_crop", true)
		add_effect("crop_eaten", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", EAT_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			_complete_eating(bb)
			return true
		return false
		
	func _complete_eating(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_crop")
		var parent := host.get_parent() as Node
		
		if is_instance_valid(parent) and parent.has_method("set_block_globally"):
			parent.call("set_block_globally", target, 0) # Clear crop to AIR
			
			var domain_entity := host.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain_entity):
				domain_entity.health = min(4, domain_entity.health + 1) # Heal self
				
			if host.has_method("_play_tilling_joy_hop"):
				host.call("_play_tilling_joy_hop")
				
		bb.set_memory("till_cooldown", randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
		bb.erase_memory("target_crop")
		bb.erase_memory("has_crop_target")
		bb.erase_memory("is_at_crop")


class SniffSoilAction extends GOAPAction:
	func _init() -> void:
		super("SniffSoil", 1.0)
		add_effect("is_on_grass", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("till_cooldown") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", SNIFF_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			var host := bb.get_object("host") as CharacterBody3D
			var parent := host.get_parent() as Node
			var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
			if ws != null:
				var h_pos := host.global_position
				var coord := Vector3i(floori(h_pos.x), floori(h_pos.y - 0.5), floori(h_pos.z))
				if ws.get_block(coord) == 3: # Grass
					return true
			bb.set_memory("till_cooldown", randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
			return false
		return false


class TillSoilAction extends GOAPAction:
	func _init() -> void:
		super("TillSoil", 1.0)
		add_precondition("is_on_grass", true)
		add_effect("soil_tilled", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", TILL_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			_complete_tilling(bb)
			return true
		return false
		
	func _complete_tilling(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null and parent.has_method("set_block_globally"):
			var coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y - 0.5), floori(host.global_position.z))
			if ws.get_block(coord) == 3 and randf() < 0.40:
				parent.call("set_block_globally", coord, 2) # GRASS -> DIRT
				if host.has_method("_play_tilling_joy_hop"):
					host.call("_play_tilling_joy_hop")
					
		bb.set_memory("till_cooldown", randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
		bb.erase_memory("is_on_grass")


class PigWanderAction extends GOAPAction:
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
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.5 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WALK)
		return false

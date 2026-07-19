# ==============================================================================
# Pathfile: res://src/Domain/Life/RaccoonAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Forest Raccoon.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates daytime sleep, nighttime 
#   scanning, and interactive barrel breakout behaviors into independent actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new lootable 
#   props (such as food crates) to be registered without code rewrites.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RaccoonAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_SNEAK: float = 1.1
const SPEED_RUN: float = 2.4
const SCAVENGE_DURATION_SEC: float = 3.0
const RANGE_SENSORY_SQ: float = 225.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(DaySleepAction.new())
	_actions.append(ScanBarrelsAction.new())
	_actions.append(SneakToBarrelAction.new())
	_actions.append(ScratchBarrelAction.new())
	_actions.append(RaccoonWanderAction.new())


func _setup_goals() -> void:
	var sleep_goal := GOAPGoal.new("DaytimeSleep", 10.0)
	sleep_goal.add_desired_state("is_sleeping", true)
	
	var scavenge_goal := GOAPGoal.new("ScavengeBarrels", 2.0)
	scavenge_goal.add_desired_state("barrel_depleted", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([sleep_goal, scavenge_goal, wander_goal])


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
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(_delta: float) -> void:
	var is_night := CelestialService.is_night_time_static()
	_blackboard.set_memory("is_night", is_night)


func _evaluate_active_plan(host: Object) -> void:
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
	state["is_sleeping"] = not _blackboard.get_bool("is_night")
	state["barrel_depleted"] = false
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
		if action_name == "SneakToBarrel": return "WANDERING"
		elif action_name == "ScratchBarrel": return "WORKING"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled nocturnal scavenger behaviors)
# ==============================================================================

class DaySleepAction extends GOAPAction:
	func _init() -> void:
		super("DaySleep", 1.0)
		add_effect("is_sleeping", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return not bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		return bb.get_bool("is_night") # Awake when night falls


class ScanBarrelsAction extends GOAPAction:
	func _init() -> void:
		super("ScanBarrels", 1.0)
		add_effect("has_scavenge_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		
		if is_instance_valid(parent):
			var closest := _detect_closest_barrel(host.global_position, parent)
			if is_instance_valid(closest):
				bb.set_memory("scavenge_target", closest)
				return true
				
		return false
		
	func _detect_closest_barrel(host_pos: Vector3, world_node: Node) -> Node3D:
		var closest: Node3D = null
		var min_dist_sq := RANGE_SENSORY_SQ
		for child in world_node.get_children():
			if is_instance_valid(child) and (child.name.begins_with("Prop_BARREL") or child.name.begins_with("Prop_CHEST")):
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as Node3D
		return closest


class SneakToBarrelAction extends GOAPAction:
	func _init() -> void:
		super("SneakToBarrel", 1.0)
		add_precondition("has_scavenge_target", true)
		add_effect("is_at_barrel", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("scavenge_target") as Node3D
		return is_instance_valid(target)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("scavenge_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 1.44: # 1.2m range
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_SNEAK)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class ScratchBarrelAction extends GOAPAction:
	func _init() -> void:
		super("ScratchBarrel", 1.0)
		add_precondition("is_at_barrel", true)
		add_effect("barrel_depleted", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("scavenge_target") as Node3D
		return is_instance_valid(target)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("scratch_timer", SCAVENGE_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("scratch_timer") - delta
		bb.set_memory("scratch_timer", timer)
		
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("scavenge_target") as Node3D
		if not is_instance_valid(target) or not is_instance_valid(host): return true
			
		if host.has_method("_play_scratching_effect"):
			host.call("_play_scratching_effect", target)
			
		if timer <= 0.0:
			_shatter_barrel(bb, host, target)
			return true
		return false
		
	func _shatter_barrel(bb: AIBlackboard, host: CharacterBody3D, target: Node3D) -> void:
		if target.has_method("interact"):
			target.call("interact", host) # Interacting shatters barrel & gives loot
			
		host.velocity.y = 5.0 # Joy Hop
		bb.erase_memory("scavenge_target")
		bb.erase_memory("has_scavenge_target")
		bb.erase_memory("is_at_barrel")


class RaccoonWanderAction extends GOAPAction:
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
			timer = randf_range(1.5, 4.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.4 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_SNEAK)
		return false

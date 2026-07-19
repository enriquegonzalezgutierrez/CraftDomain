# ==============================================================================
# Pathfile: res://src/Domain/Life/MonkeyAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Acrobatic Tropical Monkey.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates canopy climbing, ground 
#   acrobatics, and vocal chatters into independent, testable actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   acrobatic stunts (e.g., branch swings) dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MonkeyAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_PATROL: float = 2.2
const SPEED_CLIMB: float = 2.8
const COOLDOWN_FLIP_SEC: float = 5.0
const RANGE_SIGHT_SQ: float = 100.0

const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ScanTreesAction.new())
	_actions.append(ClamberToTreeAction.new())
	_actions.append(ClimbBranchAction.new())
	_actions.append(GroundFlipAction.new())
	_actions.append(MonkeyWanderAction.new())


func _setup_goals() -> void:
	var rest_goal := GOAPGoal.new("ArborealRest", 1.5)
	rest_goal.add_desired_state("is_resting_on_tree", true)
	
	var play_goal := GOAPGoal.new("AcrobaticPlay", 1.0)
	play_goal.add_desired_state("is_playing", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([rest_goal, play_goal, wander_goal])


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
		_blackboard.set_memory("flip_cooldown", 0.0)
		_blackboard.set_memory("chat_timer", randf_range(5.0, 15.0))
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var flip := _blackboard.get_float("flip_cooldown") - delta
	_blackboard.set_memory("flip_cooldown", maxf(0.0, flip))
	
	var chat := _blackboard.get_float("chat_timer") - delta
	_blackboard.set_memory("chat_timer", chat)
	if chat <= 0.0:
		_blackboard.set_memory("chat_timer", randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC))
		var host := _blackboard.get_object("host") as CharacterBody3D
		if is_instance_valid(host) and host.has_method("_play_monkey_chatter"):
			host.call("_play_monkey_chatter")


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
	state["is_resting_on_tree"] = false
	state["is_playing"] = false
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
		if action_name == "ClamberToTree": return "SCANNING_TREES"
		elif action_name == "ClimbBranch": return "CLAMBERING_BRANCHES"
		elif action_name == "GroundFlip": return "BACKFLIP_PLAY"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled simian acrobatics behaviors)
# ==============================================================================

class ScanTreesAction extends GOAPAction:
	func _init() -> void:
		super("ScanTrees", 1.0)
		add_effect("has_tree_target", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var leaves_coord := _scan_for_nearby_leaves(host.global_position, host)
		
		if leaves_coord != Vector3i(0, -999, 0):
			bb.set_memory("target_leaves", leaves_coord)
			return true
		return false
		
	func _scan_for_nearby_leaves(host_pos: Vector3, host: CharacterBody3D) -> Vector3i:
		var parent := host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent: return Vector3i(0, -999, 0)
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null: return Vector3i(0, -999, 0)
			
		var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
		for x in range(-4, 5):
			for y in range(-1, 4):
				for z in range(-4, 5):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == 5: # 5 = BlockType.Type.LEAVES
						return c
		return Vector3i(0, -999, 0)


class ClamberToTreeAction extends GOAPAction:
	func _init() -> void:
		super("ClamberToTree", 1.0)
		add_precondition("has_tree_target", true)
		add_effect("is_at_tree_trunk", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_leaves")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_leaves")
		var ai: Object = host.get("ai_component")
		
		var tree_pos := Vector3(target) + Vector3(0.5, 1.0, 0.5)
		var diff := tree_pos - host.global_position
		var dist_flat := Vector2(diff.x, diff.z).length()
		
		if dist_flat <= 1.2:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
		VoxelKinematicService.apply_motion_vectors(host, ai, climb_dir, SPEED_CLIMB)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class ClimbBranchAction extends GOAPAction:
	func _init() -> void:
		super("ClimbBranch", 1.0)
		add_precondition("is_at_tree_trunk", true)
		add_effect("is_resting_on_tree", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_leaves")
		var ai: Object = host.get("ai_component")
		
		var tree_pos := Vector3(target) + Vector3(0.5, 1.0, 0.5)
		var diff := tree_pos - host.global_position
		var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
		
		if is_instance_valid(ai): ai.set("wander_direction", climb_dir)
		
		if host.is_on_floor():
			host.velocity.y = 5.5 # Vertical climb leap
			host.velocity.x = climb_dir.x * (SPEED_CLIMB * 0.6)
			host.velocity.z = climb_dir.z * (SPEED_CLIMB * 0.6)
			return false
			
		_process_climb_acrobatics(bb, host, climb_dir, delta)
		return true
		
	func _process_climb_acrobatics(bb: AIBlackboard, host: CharacterBody3D, climb_dir: Vector3, _delta: float) -> void:
		host.velocity.x = climb_dir.x * (SPEED_CLIMB * 0.4)
		host.velocity.z = climb_dir.z * (SPEED_CLIMB * 0.4)
		
		bb.set_memory("flip_cooldown", COOLDOWN_FLIP_SEC)
		if host.has_method("_play_backflip_effect"):
			host.call("_play_backflip_effect")
			
		bb.erase_memory("target_leaves")
		bb.erase_memory("has_tree_target")
		bb.erase_memory("is_at_tree_trunk")


class GroundFlipAction extends GOAPAction:
	func _init() -> void:
		super("GroundFlip", 1.0)
		add_effect("is_playing", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("flip_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		
		bb.set_memory("flip_cooldown", COOLDOWN_FLIP_SEC)
		if host.has_method("_play_backflip_effect"):
			host.call("_play_backflip_effect")
			
		return true


class MonkeyWanderAction extends GOAPAction:
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
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.45 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
		return false

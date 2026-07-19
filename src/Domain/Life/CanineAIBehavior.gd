# ==============================================================================
# Pathfile: res://src/Domain/Life/CanineAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Fiery Growlithe dog.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates magma sniffing, lava 
#   tracking, and playful tail-chasing behaviors into independent actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new tricks 
#   and lures (e.g. bone items) to be registered dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CanineAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_WALK: float = 1.0
const SPEED_TROT: float = 1.6
const COOLDOWN_BARK_SEC: float = 4.0

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
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_cooldowns(delta: float) -> void:
	var cd := _blackboard.get_float("bark_cooldown") - delta
	_blackboard.set_memory("bark_cooldown", maxf(0.0, cd))


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
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var lava_coord := _scan_for_nearby_lava(host)
		
		if lava_coord != Vector3i(0, -999, 0):
			bb.set_memory("target_lava", lava_coord)
			return true
		return false
		
	func _scan_for_nearby_lava(host: CharacterBody3D) -> Vector3i:
		var parent := host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent: return Vector3i(0, -999, 0)
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null: return Vector3i(0, -999, 0)
			
		var my_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
		for x in range(-5, 6):
			for y in range(-2, 3):
				for z in range(-5, 6):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == 15: # 15 = BlockType.Type.LAVA
						return c
		return Vector3i(0, -999, 0)


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
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
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
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
			
		var timer := bb.get_float("wander_timer") - delta
		bb.set_memory("wander_timer", timer)
		
		var elapsed := float(Time.get_ticks_msec()) / 100.0
		var spin_dir := Vector3(cos(elapsed), 0.0, sin(elapsed)).normalized()
		VoxelKinematicService.apply_motion_vectors(host, ai, spin_dir, SPEED_WALK)
		
		return timer <= 0.0


class SniffWanderAction extends GOAPAction:
	func _init() -> void:
		super("Wander", 1.0)
		add_effect("is_playing", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
		
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			var roll := randf()
			if roll < 0.4:
				var angle := randf() * TAU
				wander_dir = Vector3(cos(angle), 0.0, sin(angle))
				timer = randf_range(1.5, 4.0)
			elif roll < 0.65:
				bb.set_memory("wander_timer", 1.5) # Time-slice tail chase trigger
				return true # End action to re-evaluate and trigger TailChase Goal!
			else:
				wander_dir = Vector3.ZERO
				timer = randf_range(1.5, 4.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WALK)
		return false

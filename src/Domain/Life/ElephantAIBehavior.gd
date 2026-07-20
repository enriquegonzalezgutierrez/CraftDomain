# ==============================================================================
# Pathfile: res://src/Domain/Life/ElephantAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Colossal Elephant.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates colossal panic flight 
#   and slow ponderous heavy-stomp locomotion into independent actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   heavy-impact triggers (such as trunk slaps) dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ElephantAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5

# VELOCIDADES ESCALADAS AL DOBLE Y RITMO DE PASO SINCRONIZADO
const SPEED_WALK: float = 1.2
const STRIDE_INTERVAL_SEC: float = 0.9
const RANGE_SIGHT_SQ: float = 144.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true 
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ElephantPanicAction.new())
	_actions.append(HeavyStrollAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadeThreats", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var stroll_goal := GOAPGoal.new("HeavyStroll", 0.5)
	stroll_goal.add_desired_state("is_strolling", true)
	
	_goals.append_array([evade_goal, stroll_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("wander_timer", 0.0)
		_blackboard.set_memory("stride_timer", 0.4)


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
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["is_strolling"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= RANGE_SIGHT_SQ:
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
		if action_name == "HeavyStroll": return "PATROLLING"
		elif action_name == "ElephantPanic": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled colossal behaviors)
# ==============================================================================

class ElephantPanicAction extends GOAPAction:
	func _init() -> void:
		super("ElephantPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0 or wander_dir == Vector3.ZERO:
			timer = randf_range(0.8, 1.5)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_apply_heavy_panic_locomotion(bb, host, ai, wander_dir, delta)
		return not ElephantAIBehavior.new()._detect_threat_proximity(host)
		
	func _apply_heavy_panic_locomotion(bb: AIBlackboard, host: CharacterBody3D, ai: Object, wander_dir: Vector3, delta: float) -> void:
		var vel := host.velocity
		vel.x = wander_dir.x * SPEED_WALK * 1.6
		vel.z = wander_dir.z * SPEED_WALK * 1.6
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)
		ElephantAIBehavior._process_stride_impacts(bb, host, delta)


class HeavyStrollAction extends GOAPAction:
	func _init() -> void:
		super("HeavyStroll", 1.0)
		add_effect("is_strolling", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			var parent := host.get_parent() as Node
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			var is_safe := _is_direction_safe_elephant(host, candidate, parent)
			wander_dir = candidate if is_safe else Vector3.ZERO
			timer = randf_range(4.0, 8.0) if is_safe else randf_range(2.0, 5.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_apply_heavy_stroll_locomotion(bb, host, ai, wander_dir, delta)
		return false
		
	func _apply_heavy_stroll_locomotion(bb: AIBlackboard, host: CharacterBody3D, ai: Object, wander_dir: Vector3, delta: float) -> void:
		var vel := host.velocity
		if wander_dir != Vector3.ZERO:
			vel.x = wander_dir.x * SPEED_WALK
			vel.z = wander_dir.z * SPEED_WALK
			ElephantAIBehavior._process_stride_impacts(bb, host, delta)
			_apply_heavy_wall_rebound(bb, host, wander_dir)
		else:
			vel.x = move_toward(vel.x, 0.0, SPEED_WALK)
			vel.z = move_toward(vel.z, 0.0, SPEED_WALK)
			bb.set_memory("stride_timer", 0.4) 
		host.velocity = vel
		if is_instance_valid(ai): ai.set("wander_direction", wander_dir)
		
	func _apply_heavy_wall_rebound(bb: AIBlackboard, host: CharacterBody3D, wander_dir: Vector3) -> void:
		if host.is_on_wall():
			var normal := host.get_wall_normal()
			var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
			if flat_normal != Vector3.ZERO:
				var bounce := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.2, 0.2)).normalized()
				bb.set_memory("wander_direction", bounce)
				
	func _is_direction_safe_elephant(host: CharacterBody3D, dir: Vector3, world_node: Node) -> bool:
		if not is_instance_valid(world_node) or not "world_state" in world_node: return true
		var ws: WorldState = world_node.get("world_state") as WorldState
		if ws == null: return true
		var check_pos := host.global_position + dir * 2.5
		var below := ws.get_block(Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z)))
		var at := ws.get_block(Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z)))
		return below != 6 and at != 6 and below != 0


# ==============================================================================
# COMBINED HELPER FUNCTION
# ==============================================================================

static func _process_stride_impacts(bb: AIBlackboard, host: CharacterBody3D, delta: float) -> void:
	var stride_timer := bb.get_float("stride_timer") - delta
	if stride_timer <= 0.0:
		stride_timer = STRIDE_INTERVAL_SEC
		if host.has_method("_play_heavy_step_impact"):
			host.call("_play_heavy_step_impact") 
	bb.set_memory("stride_timer", stride_timer)

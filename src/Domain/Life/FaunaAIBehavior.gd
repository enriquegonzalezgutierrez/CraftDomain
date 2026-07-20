# ==============================================================================
# Pathfile: res://src/Domain/Life/FaunaAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Generic Passive Wildlife and herd animals.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates generic grazing, 
#   stuck recovery wall bounces, and threat panic escapes into distinct actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   ecological goals (such as drinking water) dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# - BUG FIX: Redirected all physics queries to the uncoupled BlockLibrary.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FaunaAIBehavior
extends IAIBehavior

const TASK_WANDERING = 1
const TASK_PANIC = 5

# VELOCIDADES ESCALADAS AL DOBLE PARA MANADAS ÁGILES Y REALISTAS
const SPEED_PANIC: float = 5.0
const SPEED_GRAZE: float = 1.6
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
	_actions.append(FaunaPanicAction.new())
	_actions.append(FaunaGrazeAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadeThreats", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var graze_goal := GOAPGoal.new("PeacefulGraze", 0.5)
	graze_goal.add_desired_state("is_grazing", true)
	
	_goals.append_array([evade_goal, graze_goal])


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
		_blackboard.set_memory("stuck_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var panic := _blackboard.get_float("panic_timer") - delta
	_blackboard.set_memory("panic_timer", maxf(0.0, panic))


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
	state["is_grazing"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
		
	var closest := _scan_for_hostiles(host)
	if is_instance_valid(closest):
		_blackboard.set_memory("panic_timer", 4.5)
		
		var host_pos := host.global_position
		var escape_dir := (host_pos - closest.global_position).normalized()
		escape_dir.y = 0.0
		_blackboard.set_memory("wander_direction", escape_dir)
		return true
		
	return _blackboard.get_float("panic_timer") > 0.0


func _scan_for_hostiles(host: CharacterBody3D) -> Node3D:
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	var host_pos := host.global_position
	
	for child in hostiles:
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
		if action_name == "FaunaGraze": return "WANDER"
		elif action_name == "FaunaPanic": return "PANIC"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled generic wildlife behaviors)
# ==============================================================================

class FaunaPanicAction extends GOAPAction:
	func _init() -> void:
		super("FaunaPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host):
			return true 
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(0.3, 0.8) 
			var angle := randf() * TAU
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			if FaunaAIBehavior._is_direction_safe_fauna(host, candidate):
				wander_dir = candidate
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PANIC)
		return bb.get_float("panic_timer") <= 0.0


class FaunaGrazeAction extends GOAPAction:
	func _init() -> void:
		super("FaunaGraze", 1.0)
		add_effect("is_grazing", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host):
			return true 
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			if randf() < 0.45:
				var angle := randf() * TAU
				var candidate := Vector3(cos(angle), 0.0, sin(angle))
				wander_dir = candidate if FaunaAIBehavior._is_direction_safe_fauna(host, candidate) else Vector3.ZERO
				timer = randf_range(2.0, 5.0)
			else:
				wander_dir = Vector3.ZERO
				timer = randf_range(1.5, 4.0)
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_collisions(bb, host, wander_dir, delta)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_GRAZE)
		return false
		
	func _check_and_resolve_wall_collisions(bb: AIBlackboard, host: CharacterBody3D, wander_dir: Vector3, delta: float) -> void:
		var stuck := bb.get_float("stuck_timer")
		if wander_dir != Vector3.ZERO and host.is_on_wall():
			stuck += delta
			if stuck > 0.4:
				stuck = 0.0
				var normal := host.get_wall_normal()
				var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					var bounce := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					bb.set_memory("wander_direction", bounce)
		else:
			stuck = 0.0
		bb.set_memory("stuck_timer", stuck)


# ==============================================================================
# SPATIAL TERRAIN FILTER HELPER 
# ==============================================================================

static func _is_direction_safe_fauna(host: CharacterBody3D, dir: Vector3) -> bool:
	var parent := host.get_parent() as Node
	if not is_instance_valid(parent) or not "world_state" in parent: return true
	var ws: WorldState = parent.world_state
	if ws == null: return true
		
	var check_pos := host.global_position + dir * 1.5
	var b_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var b_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var b_below := ws.get_block(b_below_coord)
	var b_at := ws.get_block(b_at_coord)
	
	if BlockLibrary.is_solid(b_at): return false
	
	var is_liquid := b_below == 6 or b_below == 15 or b_at == 6
	var is_void := b_below == 0
	
	if is_void:
		var b_2_below := ws.get_block(b_below_coord + Vector3i(0, -1, 0))
		if b_2_below != 0 and b_2_below != 6 and b_2_below != 15: is_void = false
		
	return not is_liquid and not is_void

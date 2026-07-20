# ==============================================================================
# Pathfile: res://src/Domain/Life/GoblinAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Hostile Skirmisher Goblin.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates guerrilla retreating, 
#   player stalking, and interactive item thievery into distinct action classes.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   thievery types (such as stealing coins or food) dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GoblinAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA GUERRILLAS DINÁMICAS Y ÁGILES
const SPEED_CHASE: float = 7.0
const SPEED_WANDER: float = 3.2
const SPEED_RETREAT: float = 9.0

const RANGE_CHASE_SQ: float = 256.0
const RANGE_ATTACK_SQ: float = 1.44
const COOLDOWN_ATTACK_SEC: float = 1.2
const RETREAT_DURATION_SEC: float = 1.4

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(GuerrillaFleeAction.new())
	_actions.append(StalkPlayerAction.new())
	_actions.append(ThieveBiteAction.new())
	_actions.append(GoblinWanderAction.new())


func _setup_goals() -> void:
	var flee_goal := GOAPGoal.new("GuerrillaRetreat", 10.0)
	flee_goal.add_desired_state("is_safe", true)
	
	var skirmish_goal := GOAPGoal.new("SkirmishPlayer", 2.0)
	skirmish_goal.add_desired_state("player_skirmished", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([flee_goal, skirmish_goal, wander_goal])


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
		_blackboard.set_memory("attack_cooldown", 0.0)
		_blackboard.set_memory("retreat_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("attack_cooldown") - delta
	_blackboard.set_memory("attack_cooldown", maxf(0.0, cd))
	
	var retreat := _blackboard.get_float("retreat_timer") - delta
	_blackboard.set_memory("retreat_timer", maxf(0.0, retreat))


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
	state["is_safe"] = (_blackboard.get_float("retreat_timer") <= 0.0)
	state["player_skirmished"] = false
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
		if action_name == "StalkPlayer": return "CHASING"
		elif action_name == "ThieveBite": return "ATTACKING"
		elif action_name == "GuerrillaFlee": return "PANIC"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled goblin behaviors)
# ==============================================================================

class GuerrillaFleeAction extends GOAPAction:
	func _init() -> void:
		super("GuerrillaFlee", 1.0)
		add_effect("is_safe", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("retreat_timer") > 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING) # Fast running anims
			
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var opposite_dir := (host.global_position - player.global_position).normalized()
			opposite_dir.y = 0.0
			
			if host.is_on_wall():
				var normal := host.get_wall_normal()
				var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					opposite_dir = opposite_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					
			VoxelKinematicService.apply_motion_vectors(host, ai, opposite_dir, SPEED_RETREAT)
			
		return bb.get_float("retreat_timer") <= 0.0


class StalkPlayerAction extends GOAPAction:
	func _init() -> void:
		super("StalkPlayer", 1.0)
		add_effect("is_at_player", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var diff := player.global_position - host.global_position
			diff.y = 0.0
			var dist_sq := diff.length_squared()
			
			if dist_sq <= RANGE_CHASE_SQ:
				if dist_sq <= RANGE_ATTACK_SQ:
					VoxelKinematicService.halt_movement(host, host.get("ai_component"))
					return true
					
				var ai: Object = host.get("ai_component")
				VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_CHASE)
				if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
				
		return false


class ThieveBiteAction extends GOAPAction:
	func _init() -> void:
		super("ThieveBite", 1.0)
		add_precondition("is_at_player", true)
		add_effect("player_skirmished", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		var ai: Object = host.get("ai_component")
		
		if is_instance_valid(player) and is_instance_valid(host):
			var diff := player.global_position - host.global_position
			diff.y = 0.0
			VoxelKinematicService.halt_movement(host, ai)
			if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
				
			var cooldown := bb.get_float("attack_cooldown")
			if cooldown <= 0.0:
				bb.set_memory("attack_cooldown", COOLDOWN_ATTACK_SEC)
				_execute_robbery(bb, host, player)
				return true
				
		return false
		
	func _execute_robbery(bb: AIBlackboard, host: CharacterBody3D, _player: CharacterBody3D) -> void:
		if host.has_method("_bite_player"):
			host.call("_bite_player") # Bites, giggles & steals 1x Stone Block (ID 1)
			
		var vis := host.get("visual_representation") as IEntityVisualRepresentation
		if is_instance_valid(vis): vis.trigger_attack_visuals()
		
		# Immediately initiate high-velocity tactical retreat for 1.4s
		bb.set_memory("retreat_timer", RETREAT_DURATION_SEC)
		bb.erase_memory("is_at_player")


class GoblinWanderAction extends GOAPAction:
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
			var parent := host.get_parent() as Node
			var candidate := Vector3(cos(angle), 0.0, sin(angle))
			wander_dir = candidate if _is_direction_safe_goblin(host, candidate, parent) else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WANDER)
		return false
		
	func _is_direction_safe_goblin(host: CharacterBody3D, dir: Vector3, world_node: Node) -> bool:
		if not is_instance_valid(world_node) or not "world_state" in world_node: return true
		var ws: WorldState = world_node.get("world_state") as WorldState
		if ws == null: return true
			
		var check_pos := host.global_position + dir * 1.5
		var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
		var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
		
		return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0

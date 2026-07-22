# ==============================================================================
# Pathfile: res://src/Domain/Life/CatAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Domestic Cat.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates predator evasion, food 
#   luring, and campfire snuggling into distinct, cohesive actions.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CatAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_RUN: float = 4.4
const SPEED_WALK: float = 2.0
const SPEED_CREEP: float = 1.2

const RANGE_ATTRACTION_SQ: float = 100.0
const RANGE_ZOMBIE_SQ: float = 64.0
const RANGE_CAMPFIRE_SQ: float = 144.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(CatPanicAction.new())
	_actions.append(LureFoodAction.new())
	_actions.append(FollowPlayerAction.new())
	_actions.append(FindWarmthAction.new())
	_actions.append(SnuggleAction.new())
	_actions.append(DefaultWanderAction.new())


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("SurviveZombies", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var beg_food_goal := GOAPGoal.new("BegForFood", 2.0)
	beg_food_goal.add_desired_state("is_fed", true)
	
	var cozy_goal := GOAPGoal.new("CozyUp", 1.5)
	cozy_goal.add_desired_state("is_warm", true)
	
	var wander_goal := GOAPGoal.new("LazyStroll", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([survive_goal, beg_food_goal, cozy_goal, wander_goal])


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
		_blackboard.set_memory("hiss_cooldown", 0.0)
		_blackboard.set_memory("food_scan_cooldown", 0.0)
		_blackboard.set_memory("warmth_scan_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("hiss_cooldown") - delta
	_blackboard.set_memory("hiss_cooldown", maxf(0.0, cd))
	
	var f_cd := _blackboard.get_float("food_scan_cooldown") - delta
	_blackboard.set_memory("food_scan_cooldown", maxf(0.0, f_cd))
	
	var w_cd := _blackboard.get_float("warmth_scan_cooldown") - delta
	_blackboard.set_memory("warmth_scan_cooldown", maxf(0.0, w_cd))


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
		# Filter usable actions dynamically by contextual validity
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
	state["is_fed"] = false
	state["is_warm"] = false
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


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= RANGE_ZOMBIE_SQ:
					return true
	return false


func get_active_state_name(host: Object) -> String:
	var _h := host
	if _active_plan.size() > 0:
		var action_name := _active_plan[0].action_name
		if action_name == "CatPanic": return "PANIC"
		elif action_name == "FollowPlayer" or action_name == "Snuggle": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled feline behaviors)
# ==============================================================================

class CatPanicAction extends GOAPAction:
	func _init() -> void:
		super("CatPanic", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var zombie := _scan_for_zombie(host)
		if not is_instance_valid(zombie): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		_trigger_hiss_alarm(bb, host, zombie, delta)
		
		var diff := host.global_position - zombie.global_position
		diff.y = 0.0
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_RUN)
		return false
		
	func _scan_for_zombie(host: CharacterBody3D) -> Node3D:
		var hostiles := host.get_tree().get_nodes_in_group("hostiles")
		for child in hostiles:
			if is_instance_valid(child) and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					if host.global_position.distance_squared_to(child.global_position) <= RANGE_ZOMBIE_SQ:
						return child as Node3D
		return null
		
	func _trigger_hiss_alarm(bb: AIBlackboard, host: CharacterBody3D, zombie: Node3D, delta: float) -> void:
		var cd := bb.get_float("hiss_cooldown") - delta
		bb.set_memory("hiss_cooldown", cd)
		if cd <= 0.0:
			bb.set_memory("hiss_cooldown", 4.0)
			if host.has_method("_play_alarm_hiss"):
				host.call("_play_alarm_hiss", zombie)


class LureFoodAction extends GOAPAction:
	func _init() -> void:
		super("LureFood", 1.0)
		add_effect("has_food_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("food_scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var dist_sq := host.global_position.distance_squared_to(player.global_position)
			if dist_sq <= RANGE_ATTRACTION_SQ and _is_player_holding_chicken(player):
				bb.set_memory("food_lure_player", player)
				return true
				
		bb.set_memory("food_scan_cooldown", 8.0)
		return true
		
	func _is_player_holding_chicken(player_node: CharacterBody3D) -> bool:
		var inventory := player_node.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			var active_slot: int = player_node.get("active_slot_index") as int
			var slot := inventory.get_slot_data(active_slot)
			return slot != null and slot.item_id == 16
		return false


class FollowPlayerAction extends GOAPAction:
	func _init() -> void:
		super("FollowPlayer", 1.0)
		add_precondition("has_food_target", true)
		add_effect("is_fed", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var player := bb.get_object("food_lure_player") as CharacterBody3D
		return is_instance_valid(player) and player.get("is_active")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("food_lure_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 2.25:
			VoxelKinematicService.halt_movement(host, ai)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_WALK * 1.5)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class FindWarmthAction extends GOAPAction:
	func _init() -> void:
		super("FindWarmth", 1.0)
		add_effect("has_warmth_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("warmth_scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		
		if is_instance_valid(parent):
			var fire := _detect_closest_campfire(host.global_position, parent)
			if is_instance_valid(fire):
				bb.set_memory("campfire_target", fire)
				return true
				
		bb.set_memory("warmth_scan_cooldown", 12.0)
		return true
		
	func _detect_closest_campfire(host_pos: Vector3, world_node: Node) -> Node3D:
		var closest: Node3D = null
		var min_dist_sq := RANGE_CAMPFIRE_SQ
		for child in world_node.get_children():
			if is_instance_valid(child) and child.name.begins_with("Prop_CAMPFIRE"):
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as Node3D
		return closest


class SnuggleAction extends GOAPAction:
	func _init() -> void:
		super("Snuggle", 1.0)
		add_precondition("has_warmth_target", true)
		add_effect("is_warm", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return is_instance_valid(bb.get_object("campfire_target"))
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var fire := bb.get_object("campfire_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := fire.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 3.24:
			VoxelKinematicService.halt_movement(host, ai)
			if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_CREEP)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		return false


class DefaultWanderAction extends GOAPAction:
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
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WALK)
		return false

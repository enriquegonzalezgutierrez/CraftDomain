# ==============================================================================
# Pathfile: res://src/Domain/Life/CatAIBehavior.gd
# Description: Pure Domain GOAP AI behavior strategy for the domestic Cat 
#              with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CatAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_RUN: float = 4.8
const SPEED_WALK: float = 2.4
const SPEED_CREEP: float = 1.4

const RANGE_ATTRACTION_SQ: float = 100.0
const RANGE_ZOMBIE_SQ: float = 64.0
const RANGE_CAMPFIRE_SQ: float = 144.0
const CHICKEN_MEAT_ITEM_ID: int = 16

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
	if not _active_plan.is_empty():
		return
		
	var initial_state := _build_initial_state()
	var usable_actions: Array[GOAPAction] = []
	for action: GOAPAction in _actions:
		if action.is_contextually_valid(_blackboard):
			usable_actions.append(action)
			
	for goal in _get_sorted_goals():
		if goal.is_valid(_blackboard):
			var candidate_plan := GOAPPlanner.plan(goal, usable_actions, initial_state)
			if not candidate_plan.is_empty():
				_active_plan = candidate_plan
				_active_plan[0].on_enter(_blackboard)
				break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host"))
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
		
	if current_action.execute_step(_blackboard, delta):
		current_action.on_exit(_blackboard)
		_active_plan.pop_front()
		if not _active_plan.is_empty():
			_active_plan[0].on_enter(_blackboard)


func _detect_threat_proximity(host: Object) -> bool:
	if not is_instance_valid(host) or not host.call("is_inside_tree"):
		return false
		
	var tree: SceneTree = host.call("get_tree") as SceneTree
	if tree == null:
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in tree.get_nodes_in_group("hostiles"):
		if is_instance_valid(child):
			var domain: Object = child.get("domain_entity")
			var is_dead: bool = domain.get("is_dead") as bool if is_instance_valid(domain) else true
			if not is_dead and host_pos.distance_squared_to(child.get("global_position") as Vector3) <= RANGE_ZOMBIE_SQ:
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
		var host := bb.get_object("host")
		if not is_instance_valid(host): return true
		
		var zombie := _scan_for_zombie(host)
		if not is_instance_valid(zombie): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		_trigger_hiss_alarm(bb, host, zombie, delta)
		
		var diff: Vector3 = (host.get("global_position") as Vector3) - (zombie.get("global_position") as Vector3)
		diff.y = 0.0
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_RUN)
		return false
		
	func _scan_for_zombie(host: Object) -> Object:
		var tree: SceneTree = host.call("get_tree") as SceneTree
		if tree == null: return null
		
		var host_pos: Vector3 = host.get("global_position")
		for child: Object in tree.get_nodes_in_group("hostiles"):
			if is_instance_valid(child):
				var domain: Object = child.get("domain_entity")
				var is_dead: bool = domain.get("is_dead") as bool if is_instance_valid(domain) else true
				if not is_dead and host_pos.distance_squared_to(child.get("global_position") as Vector3) <= RANGE_ZOMBIE_SQ:
					return child
		return null
		
	func _trigger_hiss_alarm(bb: AIBlackboard, host: Object, zombie: Object, delta: float) -> void:
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
		var host := bb.get_object("host")
		if not is_instance_valid(host): return true
		
		var parent: Object = host.call("get_parent")
		var player: Object = parent.call("get_node_or_null", "Player") if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and bool(player.get("is_active")):
			var host_pos: Vector3 = host.get("global_position")
			var p_pos: Vector3 = player.get("global_position")
			if host_pos.distance_squared_to(p_pos) <= RANGE_ATTRACTION_SQ and _is_player_holding_chicken(player):
				bb.set_memory("food_lure_player", player)
				return true
				
		bb.set_memory("food_scan_cooldown", 8.0)
		return true
		
	func _is_player_holding_chicken(player_node: Object) -> bool:
		var inventory: Object = player_node.get("inventory")
		if is_instance_valid(inventory):
			var active_slot: int = player_node.get("active_slot_index") as int
			var slot: Object = inventory.call("get_slot_data", active_slot)
			return slot != null and int(slot.get("item_id")) == CHICKEN_MEAT_ITEM_ID
		return false


class FollowPlayerAction extends GOAPAction:
	func _init() -> void:
		super("FollowPlayer", 1.0)
		add_precondition("has_food_target", true)
		add_effect("is_fed", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var player := bb.get_object("food_lure_player")
		return is_instance_valid(player) and bool(player.get("is_active"))
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host")
		var player := bb.get_object("food_lure_player")
		if not is_instance_valid(host) or not is_instance_valid(player): return true
		
		var ai: Object = host.get("ai_component")
		var diff: Vector3 = (player.get("global_position") as Vector3) - (host.get("global_position") as Vector3)
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
		var host := bb.get_object("host")
		if not is_instance_valid(host): return true
		
		var parent: Object = host.call("get_parent")
		if is_instance_valid(parent):
			var fire := _detect_closest_campfire(host.get("global_position"), parent)
			if is_instance_valid(fire):
				bb.set_memory("campfire_target", fire)
				return true
				
		bb.set_memory("warmth_scan_cooldown", 12.0)
		return true
		
	func _detect_closest_campfire(host_pos: Vector3, world_node: Object) -> Object:
		var closest: Object = null
		var min_dist_sq := RANGE_CAMPFIRE_SQ
		for child: Object in world_node.call("get_children"):
			if is_instance_valid(child) and str(child.get("name")).begins_with("Prop_CAMPFIRE"):
				var dist_sq := host_pos.distance_squared_to(child.get("global_position") as Vector3)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child
		return closest


class SnuggleAction extends GOAPAction:
	func _init() -> void:
		super("Snuggle", 1.0)
		add_precondition("has_warmth_target", true)
		add_effect("is_warm", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return is_instance_valid(bb.get_object("campfire_target"))
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host")
		var fire := bb.get_object("campfire_target")
		if not is_instance_valid(host) or not is_instance_valid(fire): return true
		
		var ai: Object = host.get("ai_component")
		var diff: Vector3 = (fire.get("global_position") as Vector3) - (host.get("global_position") as Vector3)
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
		if not is_instance_valid(host): return true
		
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
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, CatAIBehavior.SPEED_WALK)
		return false

	func _find_safe_wander_direction(host: CharacterBody3D) -> Vector3:
		for i: int in range(12):
			var angle := randf() * TAU
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
			var feet_coord := Vector3i(floori(check_pos.x), floori(check_pos.y), floori(check_pos.z))
			var chest_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
			var below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y - 1.0), floori(check_pos.z))
			
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

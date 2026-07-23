# ==============================================================================
# Pathfile: res://src/Domain/Life/MerchantAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Shopkeeper Merchant NPC with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_PATROL: float = 1.4
const SPEED_RETREAT: float = 3.8
const SPEED_PANIC: float = 4.2

const COOLDOWN_COINS_SEC: float = 2.5
const COOLDOWN_SHOUT_MIN: float = 10.0
const COOLDOWN_SHOUT_MAX: float = 20.0
const SHIFT_DURATION_SEC: float = 15.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(MerchantFleeAction.new())
	_actions.append(GoToShelterAction.new())
	_actions.append(CountCoinsAction.new())
	_actions.append(GoToStallAction.new())
	_actions.append(OpenShopAction.new())
	_actions.append(MerchantWanderAction.new())


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("Survive", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var accounting_goal := GOAPGoal.new("CountEarnings", 2.0)
	accounting_goal.add_desired_state("coins_counted", true)
	
	var trade_goal := GOAPGoal.new("OperateShop", 1.0)
	trade_goal.add_desired_state("did_trade", true)
	
	var wander_goal := GOAPGoal.new("WanderMarket", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([survive_goal, accounting_goal, trade_goal, wander_goal])


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
		_blackboard.set_memory("gold_cooldown", 0.0)
		_blackboard.set_memory("shout_cooldown", 5.0)
		_blackboard.set_memory("shop_cooldown", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var is_night := CelestialService.is_night_time_static()
	_blackboard.set_memory("is_night", is_night)
	
	var shout_cd := _blackboard.get_float("shout_cooldown") - delta
	_blackboard.set_memory("shout_cooldown", maxf(0.0, shout_cd))
	
	var shop_cd := _blackboard.get_float("shop_cooldown") - delta
	_blackboard.set_memory("shop_cooldown", maxf(0.0, shop_cd))


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
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["coins_counted"] = false
	state["did_trade"] = false
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
				if host.global_position.distance_squared_to(child.global_position) <= 64.0:
					return true
	return false


func _get_sorted_goals() -> Array[GOAPGoal]:
	var is_night := _blackboard.get_bool("is_night")
	var on_cooldown := _blackboard.get_float("shop_cooldown") > 0.0
	
	var sorted := _goals.duplicate()
	for i in range(sorted.size() - 1, -1, -1):
		var g: GOAPGoal = sorted[i]
		if g.goal_name == "OperateShop" and (is_night or on_cooldown):
			sorted.remove_at(i)
			
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
		if action_name == "CountCoins": return "IDLE"
		elif action_name == "GoToStall" or action_name == "GoToShelter" or action_name == "Wander": return "WANDERING"
		elif action_name == "OpenShop": return "CHAT"
		elif action_name == "MerchantFlee": return "PANIC"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled mercantile behaviors)
# ==============================================================================

class MerchantFleeAction extends GOAPAction:
	func _init() -> void:
		super("MerchantFlee", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var protector := _scan_for_protector(host)
		if is_instance_valid(protector):
			var diff := protector.global_position - host.global_position
			diff.y = 0.0
			if diff.length() > 3.0:
				VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_PANIC)
				return false
		return true
		
	func _scan_for_protector(host: CharacterBody3D) -> Node3D:
		var passives := host.get_tree().get_nodes_in_group("passives")
		var closest: Node3D = null
		var min_dist_sq := 900.0
		
		for child in passives:
			if is_instance_valid(child) and child != host and child is Node3D:
				if child.name.contains("GUARD") or child.name.contains("GOLEM"):
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest


class GoToShelterAction extends GOAPAction:
	func _init() -> void:
		super("GoToShelter", 1.0)
		add_effect("is_sheltered", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var nav := parent.get("navigation_service") as VoxelNavigationService if is_instance_valid(parent) else null
		
		if is_instance_valid(nav):
			var shelter_pos := nav.find_closest_shelter_node(host.global_position)
			if shortcut_distance_check(host, shelter_pos):
				return true
				
		return true
		
	func shortcut_distance_check(host: CharacterBody3D, shelter_pos: Vector3) -> bool:
		if shelter_pos != Vector3.ZERO:
			var diff := shelter_pos - host.global_position
			diff.y = 0.0
			if diff.length() > 0.8:
				var ai: Object = host.get("ai_component")
				VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_RETREAT)
				if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
				return false
		return true


class CountCoinsAction extends GOAPAction:
	func _init() -> void:
		super("CountCoins", 1.0)
		add_precondition("is_sheltered", true)
		add_effect("coins_counted", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		
		var cooldown := bb.get_float("gold_cooldown") - delta
		bb.set_memory("gold_cooldown", cooldown)
		
		if cooldown <= 0.0:
			bb.set_memory("gold_cooldown", COOLDOWN_COINS_SEC)
			if host.has_method("_play_counting_coins"):
				host.call("_play_counting_coins")
				
		return not bb.get_bool("is_night")


class GoToStallAction extends GOAPAction:
	func _init() -> void:
		super("GoToStall", 1.0)
		add_effect("is_at_stall", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return not bb.get_bool("is_night") and bb.get_float("shop_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var spawn_point: Vector3 = host.get("_spawn_point") as Vector3 if "_spawn_point" in host else host.global_position
		var diff := spawn_point - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 4.0:
			return true
			
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_PATROL)
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
		return false


class OpenShopAction extends GOAPAction:
	func _init() -> void:
		super("OpenShop", 1.0)
		add_precondition("is_at_stall", true)
		add_effect("did_trade", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return not bb.get_bool("is_night")
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("shift_timer", MerchantAIBehavior.SHIFT_DURATION_SEC)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		
		var shout_cd := bb.get_float("shout_cooldown")
		if shout_cd <= 0.0:
			bb.set_memory("shout_cooldown", randf_range(COOLDOWN_SHOUT_MIN, COOLDOWN_SHOUT_MAX))
			_execute_advertise_spin(host, ai)
		else:
			if is_instance_valid(ai):
				ai.set("current_task", TASK_WORKING)
				
		var shift := bb.get_float("shift_timer") - delta
		bb.set_memory("shift_timer", shift)
		
		if shift <= 0.0 or bb.get_bool("is_night"):
			_finish_shift(bb)
			return true
			
		return false
		
	func _finish_shift(bb: AIBlackboard) -> void:
		bb.set_memory("shop_cooldown", randf_range(20.0, 45.0))
		bb.erase_memory("is_at_stall")
		
	func _execute_advertise_spin(host: CharacterBody3D, ai: Object) -> void:
		var angle := float(Time.get_ticks_msec() / 150.0)
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
			ai.set("current_task", TASK_WORKING)
			
		if host.has_method("_play_advertising_shout"):
			host.call("_play_advertising_shout")


class MerchantWanderAction extends GOAPAction:
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
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
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

	func _is_pushing_into_wall(host: CharacterBody3D, wander_dir: Vector3) -> bool:
		if not host.is_on_wall() or wander_dir == Vector3.ZERO:
			return false
		var wall_normal := host.get_wall_normal()
		var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
		return flat_normal != Vector3.ZERO and wander_dir.normalized().dot(-flat_normal) > 0.25

# ==============================================================================
# Pathfile: res://src/Domain/Life/MerchantAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Shopkeeper Merchant NPC.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates marketing shoutouts, 
#   nightly accounting, and guard seeking into independent action packages.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows shop inventories 
#   and trade offers to be modified dynamically without touching the planner.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MerchantAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_PATROL: float = 1.0
const SPEED_RETREAT: float = 1.6
const SPEED_PANIC: float = 2.4

const COOLDOWN_COINS_SEC: float = 2.5
const COOLDOWN_SHOUT_MIN: float = 10.0
const COOLDOWN_SHOUT_MAX: float = 20.0

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


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("Survive", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var accounting_goal := GOAPGoal.new("CountEarnings", 2.0)
	accounting_goal.add_desired_state("coins_counted", true)
	
	var trade_goal := GOAPGoal.new("OpenShop", 1.0)
	trade_goal.add_desired_state("is_trading", true)
	
	_goals.append_array([survive_goal, accounting_goal, trade_goal])


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
		_blackboard.set_memory("gold_cooldown", 0.0)
		_blackboard.set_memory("shout_cooldown", 5.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var is_night := CelestialService.is_night_time_static()
	_blackboard.set_memory("is_night", is_night)
	
	var shout_cd := _blackboard.get_float("shout_cooldown") - delta
	_blackboard.set_memory("shout_cooldown", maxf(0.0, shout_cd))


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
		
		for goal in sorted_goals:
			if goal.is_valid(_blackboard):
				_active_plan = GOAPPlanner.plan(goal, _actions, initial_state)
				if not _active_plan.is_empty():
					_active_plan[0].on_enter(_blackboard)
					break


func _build_initial_state() -> Dictionary:
	var state: Dictionary = {}
	state["is_safe"] = not _detect_threat_proximity(_blackboard.get_object("host") as CharacterBody3D)
	state["coins_counted"] = false
	state["is_trading"] = false
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
		if action_name == "CountCoins": return "IDLE"
		elif action_name == "GoToStall" or action_name == "GoToShelter": return "WANDERING"
		elif action_name == "OpenShop": return "CHAT"
		elif action_name == "MerchantFlee": return "PANIC"
	return "IDLE"


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
				if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
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
				
		return not bb.get_bool("is_night") # Done when daytime returns


class GoToStallAction extends GOAPAction:
	func _init() -> void:
		super("GoToStall", 1.0)
		add_effect("is_at_stall", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return not bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var spawn_point := host.get("_spawn_point") as Vector3
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
		add_effect("is_trading", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return not bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		
		var shout_cd := bb.get_float("shout_cooldown")
		if shout_cd <= 0.0:
			bb.set_memory("shout_cooldown", randf_range(COOLDOWN_SHOUT_MIN, COOLDOWN_SHOUT_MAX))
			_execute_advertise_spin(host, ai)
		else:
			if is_instance_valid(ai):
				ai.set("current_task", TASK_WORKING) # Stands actively trading
				
		return bb.get_bool("is_night") # Close shop when night returns
		
	func _execute_advertise_spin(host: CharacterBody3D, ai: Object) -> void:
		var angle := float(Time.get_ticks_msec() / 150.0)
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
			ai.set("current_task", TASK_WORKING)
			
		if host.has_method("_play_advertising_shout"):
			host.call("_play_advertising_shout")

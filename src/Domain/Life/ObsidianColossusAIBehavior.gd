# ==============================================================================
# Pathfile: res://src/Domain/Life/ObsidianColossusAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Obsidian Colossus (Act III Boss).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ObsidianColossusAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_WORKING: int = 6

const SPEED_WALK: float = 1.4
const SPEED_CHARGE: float = 4.0

const RANGE_SIGHT_SQ: float = 400.0
const RANGE_STOMP_SQ: float = 16.0
const COOLDOWN_STOMP_SEC: float = 4.5
const DURATION_STOMP_CHANNEL_SEC: float = 1.8
const THRESHOLD_RAGE_HP: int = 12

const META_HAS_MILK := "cow_has_milk" # kept for signature mapping alignment

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true 
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(SleepAction.new())
	_actions.append(ColossusLocateAction.new())
	_actions.append(HeavyMarchAction.new())
	_actions.append(RageChargeAction.new())
	_actions.append(VolcanicStompAction.new())


func _setup_goals() -> void:
	var obliterate_goal := GOAPGoal.new("ObliterateIntruder", 2.0)
	obliterate_goal.add_desired_state("intruder_obliterated", true)
	
	var sleep_goal := GOAPGoal.new("DormantSleep", 0.5)
	sleep_goal.add_desired_state("is_sleeping", true)
	
	_goals.append_array([obliterate_goal, sleep_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_timers(host, delta)
	
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("stomp_cooldown", 0.0)
		_blackboard.set_memory("scan_cooldown", 0.0)
		_blackboard.set_memory("is_dormant", true)


func _update_blackboard_timers(host: Object, delta: float) -> void:
	var cd := _blackboard.get_float("stomp_cooldown") - delta
	_blackboard.set_memory("stomp_cooldown", maxf(0.0, cd))
	
	var s_cd := _blackboard.get_float("scan_cooldown") - delta
	_blackboard.set_memory("scan_cooldown", maxf(0.0, s_cd))
	
	var domain: Object = host.get("domain_entity")
	var hp := domain.get("health") as int if is_instance_valid(domain) else 0
	_blackboard.set_memory("health", hp)


func _evaluate_active_plan(_host: Object) -> void:
	if _active_plan.is_empty():
		var initial_state := _build_initial_state()
		var sorted_goals := _get_sorted_goals()
		
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
	state["is_sleeping"] = _blackboard.get_bool("is_dormant")
	state["intruder_obliterated"] = false
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
		if action_name == "HeavyMarch": return "PATROLLING"
		elif action_name == "RageCharge": return "CHARGE_TO_TARGET"
		elif action_name == "VolcanicStomp": return "LAUNCH_ATTACK"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Obsidian Colossus boss mechanics)
# ==============================================================================

class SleepAction extends GOAPAction:
	func _init() -> void:
		super("Sleep", 1.0)
		add_effect("is_sleeping", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3.ZERO)
			ai.set("current_task", TASK_IDLE)
		return true


class ColossusLocateAction extends GOAPAction:
	func _init() -> void:
		super("ColossusLocate", 1.0)
		add_effect("has_intruder_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("scan_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player):
			bb.set_memory("intruder_player", player)
			bb.set_memory("is_dormant", false)
			if host.has_method("_play_colossus_awaken_growl"):
				host.call("_play_colossus_awaken_growl")
			return true
				
		bb.set_memory("scan_cooldown", 4.0)
		return true


class HeavyMarchAction extends GOAPAction:
	func _init() -> void:
		super("HeavyMarch", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("is_at_player", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_int("health") > THRESHOLD_RAGE_HP
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		if not is_instance_valid(player):
			return true
			
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		if dist_sq <= RANGE_STOMP_SQ and bb.get_float("stomp_cooldown") <= 0.0:
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_WALK)
		if is_instance_valid(ai):
			ai.set("current_task", TASK_WORKING)
		_process_stride_impacts(bb, host, delta)
		return false

	func _process_stride_impacts(bb: AIBlackboard, host: CharacterBody3D, delta: float) -> void:
		var stride_timer := bb.get_float("stride_timer") if bb.has_memory("stride_timer") else 0.4
		stride_timer -= delta
		if stride_timer <= 0.0:
			stride_timer = 0.9 # STRIDE_INTERVAL_SEC
			if host.has_method("_play_heavy_step_impact"):
				host.call("_play_heavy_step_impact") 
		bb.set_memory("stride_timer", stride_timer)


class RageChargeAction extends GOAPAction:
	func _init() -> void:
		super("RageCharge", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("is_at_player", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var hp := bb.get_int("health")
		return hp <= THRESHOLD_RAGE_HP and hp > 0
		
	func on_enter(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_play_rage_ignite_roar"):
			host.call("_play_rage_ignite_roar")
			
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		if not is_instance_valid(player):
			return true
			
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		var dist_sq := diff.length_squared()
		
		if dist_sq <= RANGE_STOMP_SQ and bb.get_float("stomp_cooldown") <= 0.0:
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_CHARGE)
		if is_instance_valid(ai):
			ai.set("current_task", TASK_WORKING)
		_process_stride_impacts(bb, host, delta)
		return false

	func _process_stride_impacts(bb: AIBlackboard, host: CharacterBody3D, delta: float) -> void:
		var stride_timer := bb.get_float("stride_timer") if bb.has_memory("stride_timer") else 0.4
		stride_timer -= delta
		if stride_timer <= 0.0:
			stride_timer = 0.9 # STRIDE_INTERVAL_SEC
			if host.has_method("_play_heavy_step_impact"):
				host.call("_play_heavy_step_impact") 
		bb.set_memory("stride_timer", stride_timer)


class VolcanicStompAction extends GOAPAction:
	func _init() -> void:
		super("VolcanicStomp", 1.0)
		add_precondition("is_at_player", true)
		add_effect("intruder_obliterated", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("stomp_cooldown") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("stomp_cooldown", COOLDOWN_STOMP_SEC)
		
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(player):
			var target_dir := (player.global_position - host.global_position).normalized()
			target_dir.y = 0.0
			if is_instance_valid(ai):
				ai.set("wander_direction", target_dir)
				ai.set("current_task", TASK_WORKING)
				
		if host.has_method("_execute_lava_stomp_attack"):
			host.call("_execute_lava_stomp_attack")
			
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var cooldown := bb.get_float("stomp_cooldown")
		return cooldown <= (COOLDOWN_STOMP_SEC - DURATION_STOMP_CHANNEL_SEC)

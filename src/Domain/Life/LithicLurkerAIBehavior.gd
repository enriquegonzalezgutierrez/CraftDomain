# ==============================================================================
# Pathfile: res://src/Domain/Life/LithicLurkerAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Lithic Lurker (Act I Boss).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates sleep dormancy, heavy chase, 
#   and leap-slam ground pounds into decoupled action strategies.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Restores clean, 
#   reusable planners without modifying the structural chasm or entities.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name LithicLurkerAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WORKING = 6

const SPEED_CHASE: float = 2.6
const RANGE_SIGHT_SQ: float = 400.0
const RANGE_POUND_SQ: float = 25.0

const COOLDOWN_POUND_SEC: float = 6.0
const DURATION_STUN_SEC: float = 3.5

# Multi-Phase State IDs (LSP Compliant)
enum Phase {
	DORMANT,
	ACTIVE,
	STUNNED
}

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true # Bosses do not wander, they hunt or sleep
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(SleepAction.new())
	_actions.append(LurkLocateAction.new())
	_actions.append(ChasePlayerAction.new())
	_actions.append(GroundPoundAction.new())


func _setup_goals() -> void:
	var sleep_goal := GOAPGoal.new("DormantSleep", 10.0)
	sleep_goal.add_desired_state("is_sleeping", true)
	
	var smash_goal := GOAPGoal.new("SmashIntruder", 2.0)
	smash_goal.add_desired_state("intruder_smashed", true)
	
	_goals.append_array([sleep_goal, smash_goal])


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
		_blackboard.set_memory("pound_cooldown", 0.0)
		_blackboard.set_memory("stun_timer", 0.0)
		_blackboard.set_memory("hang_timer", 0.0)
		_blackboard.set_memory("phase_state", Phase.DORMANT)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("pound_cooldown") - delta
	_blackboard.set_memory("pound_cooldown", maxf(0.0, cd))
	
	var stun := _blackboard.get_float("stun_timer") - delta
	_blackboard.set_memory("stun_timer", maxf(0.0, stun))


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
	state["is_sleeping"] = (_blackboard.get_int("phase_state") == Phase.DORMANT)
	state["intruder_smashed"] = false
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
		if action_name == "ChasePlayer": return "CHARGE_TO_TARGET"
		elif action_name == "GroundPound": return "LAUNCH_ATTACK"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Lithic Lurker boss mechanics)
# ==============================================================================

class SleepAction extends GOAPAction:
	func _init() -> void:
		super("Sleep", 1.0)
		add_effect("is_sleeping", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		host.velocity.x = 0.0; host.velocity.z = 0.0
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3.ZERO)
			ai.set("current_task", TASK_IDLE)
		return true


class LurkLocateAction extends GOAPAction:
	func _init() -> void:
		super("LurkLocate", 1.0)
		add_effect("has_intruder_target", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var dist_sq := host.global_position.distance_squared_to(player.global_position)
			if dist_sq <= RANGE_SIGHT_SQ:
				bb.set_memory("intruder_player", player)
				bb.set_memory("phase_state", Phase.ACTIVE)
				if host.has_method("_play_boss_awaken_roar"):
					host.call("_play_boss_awaken_roar")
				return true
		return false


class ChasePlayerAction extends GOAPAction:
	func _init() -> void:
		super("ChasePlayer", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("is_at_player", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_int("phase_state") == Phase.ACTIVE
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= RANGE_POUND_SQ and bb.get_float("pound_cooldown") <= 0.0:
			return true # Within range and cooldown is clear; ready to pound!
			
		var vel := host.velocity
		var chase_dir := diff.normalized()
		vel.x = chase_dir.x * SPEED_CHASE
		vel.z = chase_dir.z * SPEED_CHASE
		host.velocity = vel
		
		if is_instance_valid(ai):
			ai.set("wander_direction", chase_dir)
			ai.set("current_task", TASK_WORKING)
		return false


class GroundPoundAction extends GOAPAction:
	var _sub_state: int = 0 # 0 = Launch/Hang, 1 = Vulnerable Stunned
	
	func _init() -> void:
		super("GroundPound", 1.0)
		add_precondition("is_at_player", true)
		add_effect("intruder_smashed", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		_sub_state = 0
		bb.set_memory("hang_timer", 0.4) # Apex hang time
		
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var forward_dir := (player.global_position - host.global_position).normalized()
		forward_dir.y = 0.0
		if is_instance_valid(ai): ai.set("wander_direction", forward_dir)
			
		var vel := host.velocity
		vel.y = 9.5 # High heavy leap
		vel.x = forward_dir.x * (SPEED_CHASE * 1.8)
		vel.z = forward_dir.z * (SPEED_CHASE * 1.8)
		host.velocity = vel
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if _sub_state == 0:
			_process_launching_physics(bb, host, delta)
		else:
			_process_stunned_vulnerability(bb, host, delta)
		return bb.get_int("phase_state") == Phase.ACTIVE # Completed when stun clears and returns to Active
		
	func _process_launching_physics(bb: AIBlackboard, host: CharacterBody3D, delta: float) -> void:
		var vel := host.velocity
		
		if vel.y <= 1.0 and vel.y >= -1.0:
			var hang := bb.get_float("hang_timer") - delta
			bb.set_memory("hang_timer", hang)
			if hang > 0.0:
				host.velocity = Vector3.ZERO # Freeze at apex
				return
				
		if vel.y < 0.0:
			vel.y -= 12.0 * delta # Heavy acceleration smash downward
			host.velocity = vel
			
		if host.is_on_floor():
			_sub_state = 1
			bb.set_memory("pound_cooldown", COOLDOWN_POUND_SEC)
			bb.set_memory("stun_timer", DURATION_STUN_SEC)
			bb.set_memory("phase_state", Phase.STUNNED)
			host.velocity = Vector3.ZERO
			if host.has_method("_execute_ground_pound_impact"):
				host.call("_execute_ground_pound_impact")
				
	func _process_stunned_vulnerability(bb: AIBlackboard, _host: CharacterBody3D, _delta: float) -> void:
		_host.velocity = Vector3.ZERO
		var stun_timer := bb.get_float("stun_timer")
		if stun_timer <= 0.0:
			bb.set_memory("phase_state", Phase.ACTIVE)
			if _host.has_method("_restore_chasing_armor"):
				_host.call("_restore_chasing_armor")

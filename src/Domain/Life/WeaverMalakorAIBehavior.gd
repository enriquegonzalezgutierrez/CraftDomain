# ==============================================================================
# Pathfile: res://src/Domain/Life/WeaverMalakorAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for Weaver Malakor, the final campaign boss (Act IV).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates distinct boss stages 
#   (Static Beams, Gravity Inversions, and Arena Fracture) into decoupled actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new cinematic 
#   phase transitions or scripts to be added without modifying the core FSM.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeaverMalakorAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA UN COMBATE FINAL FLUIDO Y EXIGENTE
const SPEED_HOVER: float = 3.2
const SPEED_ORBIT: float = 7.0
const RANGE_SIGHT_SQ: float = 576.0

const COOLDOWN_BEAM_SEC: float = 3.5
const COOLDOWN_SUMMON_SEC: float = 7.0
const COOLDOWN_MUTATION_SEC: float = 5.0

const THRESHOLD_PHASE_2_HP: int = 16
const THRESHOLD_PHASE_3_HP: int = 8

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true # The final weaver remains bound to the Chrono-Loom
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(SleepAction.new())
	_actions.append(LocateIntruderAction.new())
	_actions.append(HoverShootBeamAction.new())
	_actions.append(InvertGravityOrbitAction.new())
	_actions.append(FractureArenaAction.new())


func _setup_goals() -> void:
	var sleep_goal := GOAPGoal.new("DormantSleep", 10.0)
	sleep_goal.add_desired_state("is_sleeping", true)
	
	var destroy_goal := GOAPGoal.new("DestroyIntruder", 2.0)
	destroy_goal.add_desired_state("intruder_destroyed", true)
	
	_goals.append_array([sleep_goal, destroy_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_timers(host, delta)
	
	_evaluate_active_plan(host)
	_current_action_execution(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("beam_cooldown", 0.0)
		_blackboard.set_memory("summon_cooldown", 0.0)
		_blackboard.set_memory("mutation_cooldown", 0.0)


func _update_blackboard_timers(host: Object, delta: float) -> void:
	var b_cd := _blackboard.get_float("beam_cooldown") - delta
	_blackboard.set_memory("beam_cooldown", maxf(0.0, b_cd))
	
	var s_cd := _blackboard.get_float("summon_cooldown") - delta
	_blackboard.set_memory("summon_cooldown", maxf(0.0, s_cd))
	
	var m_cd := _blackboard.get_float("mutation_cooldown") - delta
	_blackboard.set_memory("mutation_cooldown", maxf(0.0, m_cd))
	
	var domain: Object = host.get("domain_entity")
	var hp := domain.get("health") as int if is_instance_valid(domain) else 0
	_blackboard.set_memory("health", hp)


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
	state["is_sleeping"] = not _detect_intruder_proximity()
	state["intruder_destroyed"] = false
	return state


func _detect_intruder_proximity() -> bool:
	var host := _blackboard.get_object("host") as CharacterBody3D
	var parent := host.get_parent() as Node
	var player_node := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
	
	if is_instance_valid(player_node) and player_node.get("is_active"):
		var dist_sq := host.global_position.distance_squared_to(player_node.global_position)
		return dist_sq <= RANGE_SIGHT_SQ
	return false


func _get_sorted_goals() -> Array[GOAPGoal]:
	var sorted := _goals.duplicate()
	sorted.sort_custom(func(a: GOAPGoal, b: GOAPGoal) -> bool:
		return a.get_priority(_blackboard) > b.get_priority(_blackboard)
	)
	return sorted


func _current_action_execution(delta: float) -> void:
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
		if action_name == "HoverShootBeam": return "SCANNING_TREES"
		elif action_name == "InvertGravityOrbit": return "BACKFLIP_PLAY"  
		elif action_name == "FractureArena": return "LAUNCH_ATTACK"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Weaver Malakor campaign phases)
# ==============================================================================

class SleepAction extends GOAPAction:
	func _init() -> void:
		super("Sleep", 1.0)
		add_effect("is_sleeping", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		_halt_movement(host)
		return true
		
	func _halt_movement(host: CharacterBody3D) -> void:
		host.velocity.x = 0.0; host.velocity.z = 0.0
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("wander_direction", Vector3.ZERO)
			ai.set("current_task", TASK_IDLE)


class LocateIntruderAction extends GOAPAction:
	func _init() -> void:
		super("LocateIntruder", 1.0)
		add_effect("has_intruder_target", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player_node := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player_node) and player_node.get("is_active"):
			bb.set_memory("intruder_player", player_node)
			if host.has_method("_play_malakor_awaken_voice"):
				host.call("_play_malakor_awaken_voice")
			return true
		return false


class HoverShootBeamAction extends GOAPAction:
	func _init() -> void:
		super("HoverShootBeam", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("intruder_destroyed", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_int("health") > THRESHOLD_PHASE_2_HP
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player_node := bb.get_object("intruder_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var diff := player_node.global_position - host.global_position
		diff.y = 0.0
		
		_apply_hover_movement(host, ai, diff.normalized())
		_process_laser_fire(bb, player_node, delta)
		return player_node.domain_entity.is_dead
		
	func _apply_hover_movement(host: CharacterBody3D, ai: Object, chase_dir: Vector3) -> void:
		var velocity := host.velocity
		velocity.x = chase_dir.x * SPEED_HOVER
		velocity.z = chase_dir.z * SPEED_HOVER
		var drift := (23.5 - host.global_position.y) * 0.12
		velocity.y = lerp(velocity.y, drift, 0.12)
		host.velocity = velocity
		if is_instance_valid(ai):
			ai.set("wander_direction", chase_dir)
			ai.set("current_task", TASK_WORKING)
			
	func _process_laser_fire(bb: AIBlackboard, player_node: CharacterBody3D, _delta: float) -> void:
		var beam_cd := bb.get_float("beam_cooldown")
		if beam_cd <= 0.0:
			bb.set_memory("beam_cooldown", COOLDOWN_BEAM_SEC)
			var host := bb.get_object("host") as CharacterBody3D
			if host.has_method("_fire_static_laser_beam"):
				host.call("_fire_static_laser_beam", player_node)


class InvertGravityOrbitAction extends GOAPAction:
	func _init() -> void:
		super("InvertGravityOrbit", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("intruder_destroyed", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_trigger_gravity_inversion"):
			host.call("_trigger_gravity_inversion")
			
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var hp := bb.get_int("health")
		return hp <= THRESHOLD_PHASE_2_HP and hp > THRESHOLD_PHASE_3_HP
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player_node := bb.get_object("intruder_player") as CharacterBody3D
		
		_apply_orbit_flight_mechanic(host, delta)
		_process_gargoyle_summons(bb, player_node, delta)
		return player_node.domain_entity.is_dead
		
	func _apply_orbit_flight_mechanic(host: CharacterBody3D, _delta: float) -> void:
		var time := Time.get_ticks_msec() / 1000.0
		var orbit_dir := Vector3(sin(time * 0.5), 0.0, cos(time * 0.5)).normalized()
		var drift := (24.5 - host.global_position.y) * 0.12
		
		var velocity := host.velocity
		velocity.x = orbit_dir.x * SPEED_ORBIT
		velocity.z = orbit_dir.z * SPEED_ORBIT
		velocity.y = lerp(velocity.y, drift, 0.12)
		host.velocity = velocity
		
	func _process_gargoyle_summons(bb: AIBlackboard, player_node: CharacterBody3D, _delta: float) -> void:
		var summon_cd := bb.get_float("summon_cooldown")
		if summon_cd <= 0.0:
			bb.set_memory("summon_cooldown", COOLDOWN_SUMMON_SEC)
			var host := bb.get_object("host") as CharacterBody3D
			if host.has_method("_spawn_gargoyle_servant"):
				host.call("_spawn_gargoyle_servant", player_node)


class FractureArenaAction extends GOAPAction:
	func _init() -> void:
		super("FractureArena", 1.0)
		add_precondition("has_intruder_target", true)
		add_effect("intruder_destroyed", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		if host.has_method("_trigger_arena_fracture"):
			host.call("_trigger_arena_fracture")
			
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var hp := bb.get_int("health")
		return hp <= THRESHOLD_PHASE_3_HP and hp > 0
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player_node := bb.get_object("intruder_player") as CharacterBody3D
		
		_apply_unstable_shaking(host, delta)
		_process_floor_mutations(bb, delta)
		return player_node.domain_entity.is_dead
		
	func _apply_unstable_shaking(host: CharacterBody3D, _delta: float) -> void:
		var time := Time.get_ticks_msec() / 1000.0
		var velocity := host.velocity
		velocity.x = sin(time * 25.0) * 0.25
		velocity.z = cos(time * 25.0) * 0.25
		velocity.y = sin(time * 4.0) * 0.08
		host.velocity = velocity
		
	func _process_floor_mutations(bb: AIBlackboard, _delta: float) -> void:
		var mutation_cd := bb.get_float("mutation_cooldown")
		if mutation_cd <= 0.0:
			bb.set_memory("mutation_cooldown", COOLDOWN_MUTATION_SEC)
			var host := bb.get_object("host") as CharacterBody3D
			if host.has_method("_trigger_arena_voxel_shift"):
				host.call("_trigger_arena_voxel_shift")

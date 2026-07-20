# ==============================================================================
# Pathfile: res://src/Domain/Life/MinerAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Cavern Miner NPC.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates ore scanning, tunneling, 
#   and extraction processes into highly cohesive, decoupled action classes.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   mineable resource types (such as iron or diamonds) without altering the planner.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MinerAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA LABORES SUBTERRÁNEAS EFICIENTES
const SPEED_WANDER: float = 2.2
const SPEED_TUNNEL: float = 2.6

const SCAN_INTERVAL_SEC: float = 3.0
const MINE_DURATION_SEC: float = 2.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(ScanVeinsAction.new())
	_actions.append(MoveToVeinAction.new())
	_actions.append(ExtractOreAction.new())
	_actions.append(RestAction.new())


func _setup_goals() -> void:
	var mine_goal := GOAPGoal.new("SupplyCavernOre", 1.0)
	mine_goal.add_desired_state("did_mine", true)
	
	var rest_goal := GOAPGoal.new("TakeBreak", 0.5)
	rest_goal.add_desired_state("is_resting", true)
	
	_goals.append_array([mine_goal, rest_goal])


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
		_blackboard.set_memory("scan_timer", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("scan_timer") - delta
	_blackboard.set_memory("scan_timer", maxf(0.0, cd))
	
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))


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
	state["did_mine"] = false
	state["is_resting"] = false
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
		if action_name == "ScanVeins": return "SCANNING_ORE"
		elif action_name == "MoveToVein": return "WANDERING"
		elif action_name == "ExtractOre": return "EXTRACTING_COAL"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled mineral extraction behaviors)
# ==============================================================================

class ScanVeinsAction extends GOAPAction:
	func _init() -> void:
		super("ScanVeins", 1.0)
		add_effect("has_ore_target", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var ore_coord := _scan_for_coal_veins(host)
		if ore_coord != Vector3i(0, -999, 0):
			if JobReservationService.instance.claim_job(ore_coord, host.get_instance_id()):
				bb.set_memory("target_ore", ore_coord)
				return true
				
		_wander_randomly(host, ai, bb, delta)
		return false
		
	func _scan_for_coal_veins(host: CharacterBody3D) -> Vector3i:
		var parent := host.get_parent() as Node
		if not is_instance_valid(parent) or not "world_state" in parent: return Vector3i(0, -999, 0)
		var ws: WorldState = parent.get("world_state") as WorldState
		if ws == null: return Vector3i(0, -999, 0)
			
		var my_coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
		var job_service := JobReservationService.instance
		
		for x in range(-3, 4):
			for y in range(-1, 2):
				for z in range(-3, 4):
					var c := my_coord + Vector3i(x, y, z)
					if ws.get_block(c) == 21: # 21 = BlockType.Type.COAL_ORE
						if not job_service.is_job_claimed(c): return c
		return Vector3i(0, -999, 0)
		
	func _wander_randomly(_host: CharacterBody3D, ai: Object, bb: AIBlackboard, delta: float) -> void:
		var timer := bb.get_float("wander_timer") - delta
		if timer <= 0.0:
			timer = randf_range(2.0, 5.0)
			var angle := randf() * TAU
			if is_instance_valid(ai): ai.set("wander_direction", Vector3(cos(angle), 0.0, sin(angle)))
		bb.set_memory("wander_timer", timer)


class MoveToVeinAction extends GOAPAction:
	func _init() -> void:
		super("MoveToVein", 1.0)
		add_precondition("has_ore_target", true)
		add_effect("is_at_ore", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.has_memory("target_ore")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		var target := bb.get_vector3i("target_ore")
		
		var target_pos := Vector3(target) + Vector3(0.5, 0.0, 0.5)
		var diff := target_pos - host.global_position
		diff.y = 0.0
		
		if diff.length() < 1.3:
			if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
			host.velocity.x = 0.0; host.velocity.z = 0.0
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_TUNNEL)
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
		return false


class ExtractOreAction extends GOAPAction:
	func _init() -> void:
		super("ExtractOre", 1.0)
		add_precondition("is_at_ore", true)
		add_effect("did_mine", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("mine_timer", MINE_DURATION_SEC)
		var host := bb.get_object("host") as Node3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
		var vis := host.get("visual_representation") as Resource
		if is_instance_valid(vis) and vis.has_method("trigger_attack_visuals"):
			vis.call("trigger_attack_visuals") # Play pickaxe swing
			
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("mine_timer") - delta
		bb.set_memory("mine_timer", timer)
		
		if timer <= 0.0:
			_execute_extraction(bb)
			return true
		return false
		
	func _execute_extraction(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_vector3i("target_ore")
		
		JobReservationService.instance.release_job(target, host.get_instance_id())
		var parent := host.get_parent() as Node
		
		if is_instance_valid(parent) and parent.has_method("set_block_globally"):
			parent.call("set_block_globally", target, 1) # STONE
			AudioService.play_sfx_static("block_break", Vector3(target))
			
		host.velocity.y = 5.0 # Joy Hop
		bb.erase_memory("target_ore")
		bb.erase_memory("has_ore_target")
		bb.erase_memory("is_at_ore")


class RestAction extends GOAPAction:
	func _init() -> void:
		super("Rest", 1.0)
		add_effect("is_resting", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("rest_timer", 3.0) # Rest for 3 seconds
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		if is_instance_valid(ai):
			ai.set("current_task", TASK_IDLE)
			VoxelKinematicService.halt_movement(host, ai)
			
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("rest_timer") - delta
		bb.set_memory("rest_timer", timer)
		return timer <= 0.0

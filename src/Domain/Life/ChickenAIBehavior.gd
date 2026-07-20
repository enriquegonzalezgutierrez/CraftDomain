# ==============================================================================
# Pathfile: res://src/Domain/Life/ChickenAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Prairie Chicken.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates predator evasion, seed 
#   luring, and organic soil pecking into highly decoupled actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new seed/bait 
#   types to be registered dynamically without modifying core state machines.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChickenAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA COMPORTAMIENTO AVÍCOLA ÁGIL
const SPEED_WANDER: float = 1.8
const SPEED_FOLLOW: float = 2.8
const SPEED_PANIC: float = 4.8

const SENSORY_RANGE_SQ: float = 64.0
const LURE_RANGE_SQ: float = 100.0

const PECK_INTERVAL_MIN_SEC: float = 10.0
const PECK_INTERVAL_MAX_SEC: float = 20.0
const PECK_DURATION_SEC: float = 1.6

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(FleePredatorAction.new())
	_actions.append(LureSeedsAction.new())
	_actions.append(FollowSeedsAction.new())
	_actions.append(CheckSoilAction.new())
	_actions.append(PeckGroundAction.new())
	_actions.append(ChickenWanderAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadePredators", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var feed_goal := GOAPGoal.new("FollowBait", 2.0)
	feed_goal.add_desired_state("is_lured", true)
	
	var peck_goal := GOAPGoal.new("OrganicGrazing", 1.0)
	peck_goal.add_desired_state("did_peck", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([evade_goal, feed_goal, peck_goal, wander_goal])


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
		_blackboard.set_memory("peck_cooldown", 4.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("peck_cooldown") - delta
	_blackboard.set_memory("peck_cooldown", maxf(0.0, cd))


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
	state["is_lured"] = false
	state["did_peck"] = false
	state["is_wandering"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var closest := _scan_for_predator_node(host)
	return is_instance_valid(closest)


static func _scan_for_predator_node(host: CharacterBody3D) -> Node3D:
	var host_pos := host.global_position
	var closest: Node3D = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	closest = _evaluate_group_threats(hostiles, host_pos, min_dist_sq, closest, "")
	
	if closest == null:
		var passives := host.get_tree().get_nodes_in_group("passives")
		closest = _evaluate_group_threats(passives, host_pos, min_dist_sq, closest, "FOX")
		
	return closest


static func _evaluate_group_threats(group: Array, host_pos: Vector3, min_dist_sq: float, current: Node3D, req_name: String) -> Node3D:
	var closest := current
	for child: Object in group:
		if is_instance_valid(child) and child is Node3D:
			if req_name != "" and not child.name.contains(req_name):
				continue
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as Node3D
	return closest


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
		if action_name == "FleePredator": return "PANIC"
		elif action_name == "FollowSeeds": return "WANDERING"
		elif action_name == "PeckGround": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled avian behaviors)
# ==============================================================================

class FleePredatorAction extends GOAPAction:
	func _init() -> void:
		super("FleePredator", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var threat := ChickenAIBehavior._scan_for_predator_node(host)
		if not is_instance_valid(threat): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var run_dir := (host.global_position - threat.global_position).normalized()
		run_dir.y = 0.0
		run_dir = run_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		
		VoxelKinematicService.apply_motion_vectors(host, ai, run_dir, SPEED_PANIC)
		return false


class LureSeedsAction extends GOAPAction:
	func _init() -> void:
		super("LureSeeds", 1.0)
		add_effect("has_seed_lure", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var dist_sq := host.global_position.distance_squared_to(player.global_position)
			if dist_sq <= LURE_RANGE_SQ and _is_player_holding_seeds(player):
				bb.set_memory("seed_lure_player", player)
				return true
				
		return false
		
	func _is_player_holding_seeds(player_node: CharacterBody3D) -> bool:
		var inventory := player_node.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			var active_slot: int = player_node.get("active_slot_index") as int
			var slot := inventory.get_slot_data(active_slot)
			return slot != null and slot.item_id == 18 # 18 = Crop Seeds (BlockType.Type.CROP_SEED)
		return false


class FollowSeedsAction extends GOAPAction:
	func _init() -> void:
		super("FollowSeeds", 1.0)
		add_precondition("has_seed_lure", true)
		add_effect("is_lured", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var player := bb.get_object("seed_lure_player") as CharacterBody3D
		return is_instance_valid(player) and player.get("is_active")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("seed_lure_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 1.5:
			VoxelKinematicService.halt_movement(host, ai)
			return true # Sowing range reached
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_FOLLOW)
		return false


class CheckSoilAction extends GOAPAction:
	func _init() -> void:
		super("CheckSoil", 1.0)
		add_effect("is_on_fertile_soil", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("peck_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null:
			var h_pos := host.global_position
			var coord := Vector3i(floori(h_pos.x), floori(h_pos.y - 0.5), floori(h_pos.z))
			var block := ws.get_block(coord)
			if block == 3 or block == 2: # 3 = Grass, 2 = Dirt
				return true
				
		return false


class PeckGroundAction extends GOAPAction:
	func _init() -> void:
		super("PeckGround", 1.0)
		add_precondition("is_on_fertile_soil", true)
		add_effect("did_peck", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("peck_timer", PECK_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("peck_timer") - delta
		bb.set_memory("peck_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("peck_cooldown", randf_range(PECK_INTERVAL_MIN_SEC, PECK_INTERVAL_MAX_SEC))
			bb.erase_memory("is_on_fertile_soil")
			return true
		return false


class ChickenWanderAction extends GOAPAction:
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
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.6 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WANDER)
		return false

# ==============================================================================
# Pathfile: res://src/Domain/World/CowAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Clay Cow.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates predator evasion, wheat 
#   luring, and organic soil-grazing into highly decoupled actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   grain/lure types dynamically without modifying core state machines.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CowAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA MANADAS DE VACAS MÁS FLUIDAS
const SPEED_WALK: float = 1.2
const SPEED_TROT: float = 2.0
const SPEED_PANIC: float = 3.6

const SENSORY_RANGE_SQ: float = 64.0
const LURE_RANGE_SQ: float = 144.0

const GRAZE_INTERVAL_MIN: float = 15.0
const GRAZE_INTERVAL_MAX: float = 30.0
const GRAZE_DURATION: float = 3.0

const META_HAS_MILK := "cow_has_milk"

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
	_actions.append(LureWheatAction.new())
	_actions.append(FollowWheatAction.new())
	_actions.append(CheckGrassAction.new())
	_actions.append(GrazeGrassAction.new())
	_actions.append(CowWanderAction.new())


func _setup_goals() -> void:
	var evade_goal := GOAPGoal.new("EvadePredators", 10.0)
	evade_goal.add_desired_state("is_safe", true)
	
	var feed_goal := GOAPGoal.new("FollowBait", 2.0)
	feed_goal.add_desired_state("is_lured", true)
	
	var graze_goal := GOAPGoal.new("RegrowMilk", 1.0)
	graze_goal.add_desired_state("did_graze", true)
	
	var wander_goal := GOAPGoal.new("SimpleRoam", 0.5)
	wander_goal.add_desired_state("is_wandering", true)
	
	_goals.append_array([evade_goal, feed_goal, graze_goal, wander_goal])


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
		_blackboard.set_memory("graze_cooldown", 6.0) # Initial grace period
		_blackboard.set_memory("wander_timer", 0.0)
		
		if not host.has_meta(META_HAS_MILK):
			host.set_meta(META_HAS_MILK, true)


func _update_blackboard_timers(delta: float) -> void:
	var cd := _blackboard.get_float("graze_cooldown") - delta
	_blackboard.set_memory("graze_cooldown", maxf(0.0, cd))


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
	state["did_graze"] = false
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
				if host.global_position.distance_squared_to(child.global_position) <= SENSORY_RANGE_SQ:
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
		if action_name == "FleePredator": return "PANIC"
		elif action_name == "FollowWheat": return "WANDERING"
		elif action_name == "GrazeGrass": return "WORKING"
	return "WANDER"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled bovine behaviors)
# ==============================================================================

class FleePredatorAction extends GOAPAction:
	func _init() -> void:
		super("FleePredator", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var threat := _scan_for_threat(host)
		if not is_instance_valid(threat): return true
			
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var run_dir := (host.global_position - threat.global_position).normalized()
		run_dir.y = 0.0
		run_dir = run_dir.rotated(Vector3.UP, randf_range(-0.4, 0.4))
		
		VoxelKinematicService.apply_motion_vectors(host, ai, run_dir, SPEED_PANIC)
		return false
		
	func _scan_for_threat(host: CharacterBody3D) -> Node3D:
		var hostiles := host.get_tree().get_nodes_in_group("hostiles")
		for child in hostiles:
			if is_instance_valid(child) and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead:
					if host.global_position.distance_squared_to(child.global_position) <= SENSORY_RANGE_SQ:
						return child as Node3D
		return null


class LureWheatAction extends GOAPAction:
	func _init() -> void:
		super("LureWheat", 1.0)
		add_effect("has_wheat_lure", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var player := parent.get_node_or_null("Player") as CharacterBody3D if is_instance_valid(parent) else null
		
		if is_instance_valid(player) and player.get("is_active"):
			var dist_sq := host.global_position.distance_squared_to(player.global_position)
			if dist_sq <= LURE_RANGE_SQ and _is_player_holding_wheat(player):
				bb.set_memory("wheat_lure_player", player)
				return true
				
		return false
		
	func _is_player_holding_wheat(player_node: CharacterBody3D) -> bool:
		var inventory := player_node.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			var active_slot: int = player_node.get("active_slot_index") as int
			var slot := inventory.get_slot_data(active_slot)
			return slot != null and slot.item_id == 20 # 20 = Mature Golden Wheat (BlockType.Type.CROP_RIPE)
		return false


class FollowWheatAction extends GOAPAction:
	func _init() -> void:
		super("FollowWheat", 1.0)
		add_precondition("has_wheat_lure", true)
		add_effect("is_lured", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var player := bb.get_object("wheat_lure_player") as CharacterBody3D
		return is_instance_valid(player) and player.get("is_active")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var player := bb.get_object("wheat_lure_player") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		
		var diff := player.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= 2.25:
			VoxelKinematicService.halt_movement(host, ai)
			return true # Reached player, luring complete!
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_TROT)
		return false


class CheckGrassAction extends GOAPAction:
	func _init() -> void:
		super("CheckGrass", 1.0)
		add_effect("is_on_grass", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var has_milk := host.get_meta(META_HAS_MILK) as bool if host.has_meta(META_HAS_MILK) else true
		return bb.get_float("graze_cooldown") <= 0.0 and not has_milk
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null:
			var h_pos := host.global_position
			var coord := Vector3i(floori(h_pos.x), floori(h_pos.y - 0.5), floori(h_pos.z))
			if ws.get_block(coord) == 3: # 3 = Grass Block
				return true
				
		return false


class GrazeGrassAction extends GOAPAction:
	func _init() -> void:
		super("GrazeGrass", 1.0)
		add_precondition("is_on_grass", true)
		add_effect("did_graze", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("graze_timer", GRAZE_DURATION)
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_WORKING)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("graze_timer") - delta
		bb.set_memory("graze_timer", timer)
		
		if timer <= 0.0:
			_complete_grazing(bb)
			return true
		return false
		
	func _complete_grazing(bb: AIBlackboard) -> void:
		var host := bb.get_object("host") as CharacterBody3D
		var parent := host.get_parent() as Node
		var ws := parent.get("world_state") as WorldState if is_instance_valid(parent) else null
		
		if ws != null and parent.has_method("set_block_globally"):
			var below := Vector3i(floori(host.global_position.x), floori(host.global_position.y - 0.5), floori(host.global_position.z))
			if ws.get_block(below) == 3: # Grass
				parent.call("set_block_globally", below, 2) # Convert Grass to Dirt
				host.set_meta(META_HAS_MILK, true) # Milk regenerated!
				if host.has_method("_play_grazing_joy_hop"):
					host.call("_play_grazing_joy_hop")
					
		bb.set_memory("graze_cooldown", randf_range(GRAZE_INTERVAL_MIN, GRAZE_INTERVAL_MAX))
		bb.erase_memory("is_on_grass")


class CowWanderAction extends GOAPAction:
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
			timer = randf_range(3.0, 6.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.4 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_WALK)
		return false

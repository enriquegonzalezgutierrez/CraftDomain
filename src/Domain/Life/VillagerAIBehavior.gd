# ==============================================================================
# Pathfile: res://src/Domain/Life/VillagerAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Common Villager NPC with smart wall navigation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerAIBehavior
extends IAIBehavior

const TASK_IDLE: int = 0
const TASK_WANDERING: int = 1
const TASK_PANIC: int = 5
const TASK_WORKING: int = 6

const SPEED_PATROL: float = 1.4
const SPEED_RETREAT: float = 3.8
const SPEED_PANIC: float = 4.2

const COOLDOWN_CHAT_SEC: float = 8.0
const CHAT_DURATION_SEC: float = 4.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(FleeToGuardAction.new())
	_actions.append(SeekShelterAction.new())
	_actions.append(FindPeerAction.new())
	_actions.append(GossipAction.new())
	_actions.append(VillagerRestAction.new())
	_actions.append(PatrolAction.new())


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("Survive", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var sleep_goal := VillagerSleepGoal.new("Sleep", 2.0)
	sleep_goal.add_desired_state("is_sheltered", true)
	
	var socialize_goal := GOAPGoal.new("Socialize", 1.0)
	socialize_goal.add_desired_state("did_gossip", true)
	
	var rest_goal := GOAPGoal.new("LeisureRest", 0.8)
	rest_goal.add_desired_state("is_resting", true)
	
	var patrol_goal := GOAPGoal.new("Patrol", 0.5)
	patrol_goal.add_desired_state("is_patrolling", true)
	
	_goals.append_array([survive_goal, sleep_goal, socialize_goal, rest_goal, patrol_goal])


func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_agent(host)
	_update_blackboard_climatology(delta)
	
	if host.get("is_talking") == true:
		_handle_conversation_interrupt(host)
		return
		
	_evaluate_active_plan(host)
	_execute_current_action(delta)


func _initialize_agent(host: Object) -> void:
	if _blackboard == null:
		_blackboard = AIBlackboard.new()
		_blackboard.set_memory("host", host)
		_blackboard.set_memory("chat_cooldown", 0.0)
		_blackboard.set_memory("rest_timer", 0.0)
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_climatology(delta: float) -> void:
	var cd := _blackboard.get_float("chat_cooldown") - delta
	_blackboard.set_memory("chat_cooldown", maxf(0.0, cd))
	
	var rest := _blackboard.get_float("rest_timer") - delta
	_blackboard.set_memory("rest_timer", maxf(0.0, rest))
	
	var is_night := CelestialService.is_night_time_static()
	_blackboard.set_memory("is_night", is_night)


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
	state["is_sheltered"] = _is_inside_shelter()
	state["did_gossip"] = false
	state["is_resting"] = false
	state["is_patrolling"] = false
	return state


func _is_inside_shelter() -> bool:
	var host := _blackboard.get_object("host") as CharacterBody3D
	var parent := host.get_parent() as Node
	var nav := parent.get("navigation_service") as VoxelNavigationService if is_instance_valid(parent) else null
	
	if is_instance_valid(nav) and "_indoor_nodes" in nav:
		var feet_y := floori(host.global_position.y + 0.5)
		var coord := Vector3i(floori(host.global_position.x), feet_y, floori(host.global_position.z))
		return (nav.get("_indoor_nodes") as Array).has(coord)
	return false


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child: Node in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= 36.0:
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
		if action_name == "FleeToGuard": return "SPRINTING_TO_THREAT"
		elif action_name == "SeekShelter" or action_name == "Patrol": return "WANDERING"
		elif action_name == "Gossip": return "CHATTING"
		elif action_name == "Rest": return "IDLE"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP GOALS & ACTIONS
# ==============================================================================

class VillagerSleepGoal extends GOAPGoal:
	func is_valid(bb: AIBlackboard) -> bool:
		return bb.get_bool("is_night")


class FleeToGuardAction extends GOAPAction:
	func _init() -> void:
		super("FleeToGuard", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var protector := _scan_for_closest_protector(host)
		if is_instance_valid(protector):
			var diff := protector.global_position - host.global_position
			diff.y = 0.0
			if diff.length() > 3.0:
				VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_PANIC)
				return false
		return true
		
	func _scan_for_closest_protector(host: CharacterBody3D) -> Node3D:
		var passives := host.get_tree().get_nodes_in_group("passives")
		var closest: Node3D = null
		var min_dist_sq := 900.0
		
		for child: Node in passives:
			if is_instance_valid(child) and child != host and child is Node3D:
				if child.name.contains("GUARD") or child.name.contains("GOLEM"):
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest


class SeekShelterAction extends GOAPAction:
	func _init() -> void:
		super("SeekShelter", 1.0)
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


class FindPeerAction extends GOAPAction:
	func _init() -> void:
		super("FindPeer", 1.0)
		add_effect("has_gossip_partner", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("chat_cooldown") <= 0.0 and not bb.get_bool("is_night")
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var peer := _scan_for_nearby_peer(host)
		if is_instance_valid(peer):
			bb.set_memory("gossip_partner", peer)
			return true
			
		bb.set_memory("chat_cooldown", 6.0)
		return true
		
	func _scan_for_nearby_peer(host: CharacterBody3D) -> Node3D:
		var passives := host.get_tree().get_nodes_in_group("passives")
		var closest: Node3D = null
		var min_dist_sq := 36.0
		
		for child: Node in passives:
			if is_instance_valid(child) and child != host and child is Node3D:
				var name_str: String = child.name
				if name_str.contains("VILLAGER") or name_str.contains("MERCHANT") or name_str.contains("FARMER") or name_str.contains("MINER"):
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest


class GossipAction extends GOAPAction:
	func _init() -> void:
		super("Gossip", 1.0)
		add_precondition("has_gossip_partner", true)
		add_effect("did_gossip", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("gossip_timer", 4.0)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return is_instance_valid(bb.get_object("gossip_partner"))
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var partner := bb.get_object("gossip_partner") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := partner.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() > 1.5:
			VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_PATROL)
			if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			return false
			
		return _perform_active_chat(bb, ai, diff.normalized(), delta)
		
	func _perform_active_chat(bb: AIBlackboard, ai: Object, look_dir: Vector3, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai):
			ai.set("wander_direction", look_dir)
			ai.set("current_task", 4)
			
		var timer := bb.get_float("gossip_timer") - delta
		bb.set_memory("gossip_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("chat_cooldown", 8.0)
			bb.erase_memory("gossip_partner")
			bb.erase_memory("has_gossip_partner")
			return true
			
		if int(round(timer * 10.0)) % 15 == 0:
			if host.has_method("_play_gossip_chatter"):
				host.call("_play_gossip_chatter")
		return false


class VillagerRestAction extends GOAPAction:
	func _init() -> void:
		super("Rest", 1.0)
		add_effect("is_resting", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("rest_timer") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("action_timer", randf_range(3.0, 6.0))
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("rest_timer", randf_range(12.0, 20.0))
			return true
		return false


class PatrolAction extends GOAPAction:
	func _init() -> void:
		super("Patrol", 1.0)
		add_effect("is_patrolling", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("patrol_duration", randf_range(12.0, 20.0))
		bb.set_memory("wander_timer", 0.0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		if not is_instance_valid(host): return true
		
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var duration := bb.get_float("patrol_duration") - delta
		bb.set_memory("patrol_duration", duration)
		if duration <= 0.0:
			return true
			
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

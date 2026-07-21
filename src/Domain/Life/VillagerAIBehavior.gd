# ==============================================================================
# Pathfile: res://src/Domain/Life/VillagerAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Common Villager NPC.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Decouples social, survival, shelter,
#   active patrolling, and idle resting into strictly distinct goals and actions.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Allows new interactions
#   to be registered without modifying the planner or movement systems.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VillagerAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# VELOCIDADES ESCALADAS AL DOBLE PARA FLUIDEZ DE TRASLACIÓN
const SPEED_PATROL: float = 2.0
const SPEED_RETREAT: float = 3.2
const SPEED_PANIC: float = 4.8

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
	
	var sleep_goal := GOAPGoal.new("Sleep", 2.0)
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
		
		for goal: GOAPGoal in sorted_goals:
			if goal.is_valid(_blackboard):
				_active_plan = GOAPPlanner.plan(goal, _actions, initial_state)
				if not _active_plan.is_empty():
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
		var coord := Vector3i(floori(host.global_position.x), floori(host.global_position.y), floori(host.global_position.z))
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
# INNER CLASSES: GOAP ACTIONS (Decoupled civilian behaviors)
# ==============================================================================

class FleeToGuardAction extends GOAPAction:
	func _init() -> void:
		super("FleeToGuard", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
			
		var guard := _scan_for_closest_protector(host)
		if is_instance_valid(guard):
			var diff := guard.global_position - host.global_position
			diff.y = 0.0
			if diff.length() > 3.0:
				if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
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
				
		return false
		
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
		return false
		
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
			ai.set("current_task", 4) # TASK_CHATTING (mapped to CHAT in UI)
			
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
		bb.set_memory("action_timer", randf_range(4.0, 8.0))
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", TASK_IDLE)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var timer := bb.get_float("action_timer") - delta
		bb.set_memory("action_timer", timer)
		
		if timer <= 0.0:
			bb.set_memory("rest_timer", randf_range(15.0, 30.0))
			return true
		return false


class PatrolAction extends GOAPAction:
	func _init() -> void:
		super("Patrol", 1.0)
		add_effect("is_patrolling", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		# Establece un turno de patrullaje finito para asegurar que se detenga a descansar eventualmente
		bb.set_memory("patrol_duration", randf_range(10.0, 20.0))
		bb.set_memory("wander_timer", 0.0)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", TASK_WANDERING)
			
		var duration := bb.get_float("patrol_duration") - delta
		bb.set_memory("patrol_duration", duration)
		if duration <= 0.0:
			return true # Termina el turno de patrulla, re-evaluará metas (y probablemente elija Rest)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(2.0, 5.0)
			var angle := randf() * TAU
			# SRP FIX: ¡Nunca asigna Vector3.ZERO! Si está patrullando, siempre se mueve.
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) 
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		_check_and_resolve_wall_collisions(bb, host, wander_dir, delta)
		
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
		return false
		
	func _check_and_resolve_wall_collisions(bb: AIBlackboard, host: CharacterBody3D, wander_dir: Vector3, delta: float) -> void:
		var stuck := bb.get_float("stuck_timer")
		if wander_dir != Vector3.ZERO and host.is_on_wall():
			stuck += delta
			if stuck > 0.4:
				stuck = 0.0
				var normal := host.get_wall_normal()
				var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
				if flat_normal != Vector3.ZERO:
					var bounce := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.3, 0.3)).normalized()
					bb.set_memory("wander_direction", bounce)
		else:
			stuck = 0.0
		bb.set_memory("stuck_timer", stuck)

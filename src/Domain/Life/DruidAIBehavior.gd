# ==============================================================================
# Pathfile: res://src/Domain/Life/DruidAIBehavior.gd
# Description: Concrete AI behavior strategy implementing Goal-Oriented Action 
#              Planning (GOAP) for the Forest Druid NPC.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Segregates protective retreats, 
#   animal healing, and natural shrine meditations into cohesive action classes.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. Supports adding new 
#   magical spell types dynamically.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DruidAIBehavior
extends IAIBehavior

const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

const SPEED_PATROL: float = 1.1
const SPEED_PANIC: float = 2.4

const COOLDOWN_SPELL_SEC: float = 6.0
const CAST_DURATION_SEC: float = 2.0
const RANGE_SENSE_SQ: float = 64.0
const RANGE_HEAL_ATTACK_SQ: float = 2.25

const COOLDOWN_MEDITATE_SEC: float = 15.0
const MEDITATE_DURATION_SEC: float = 4.0

var _blackboard: AIBlackboard
var _goals: Array[GOAPGoal] = []
var _actions: Array[GOAPAction] = []
var _active_plan: Array[GOAPAction] = []


func _init() -> void:
	overrides_wandering = true
	_setup_goap_profile()


func _setup_goap_profile() -> void:
	_setup_goals()
	_actions.append(DruidFleeAction.new())
	_actions.append(ScanFaunaAction.new())
	_actions.append(MoveToAnimalAction.new())
	_actions.append(CastHealAction.new())
	_actions.append(MeditateAction.new())
	_actions.append(DruidPatrolAction.new())


func _setup_goals() -> void:
	var survive_goal := GOAPGoal.new("Survive", 10.0)
	survive_goal.add_desired_state("is_safe", true)
	
	var heal_goal := GOAPGoal.new("HealInjuredWildlife", 2.0)
	heal_goal.add_desired_state("fauna_healed", true)
	
	var meditate_goal := GOAPGoal.new("SacredGroveMeditation", 1.5)
	meditate_goal.add_desired_state("is_meditating", true)
	
	var patrol_goal := GOAPGoal.new("PatrolGrove", 0.5)
	patrol_goal.add_desired_state("is_patrolling", true)
	
	_goals.append_array([survive_goal, heal_goal, meditate_goal, patrol_goal])


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
		_blackboard.set_memory("spell_cooldown", 0.0)
		_blackboard.set_memory("meditate_cooldown", 5.0) # Initial grace period
		_blackboard.set_memory("wander_timer", 0.0)


func _update_blackboard_timers(delta: float) -> void:
	var spell_cd := _blackboard.get_float("spell_cooldown") - delta
	_blackboard.set_memory("spell_cooldown", maxf(0.0, spell_cd))
	
	var med_cd := _blackboard.get_float("meditate_cooldown") - delta
	_blackboard.set_memory("meditate_cooldown", maxf(0.0, med_cd))


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
	state["fauna_healed"] = false
	state["is_meditating"] = false
	state["is_patrolling"] = false
	return state


func _detect_threat_proximity(host: CharacterBody3D) -> bool:
	if not is_instance_valid(host) or not host.is_inside_tree():
		return false
	var hostiles := host.get_tree().get_nodes_in_group("hostiles")
	for child in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain := child.get("domain_entity") as VoxelEntity
			if is_instance_valid(domain) and not domain.is_dead:
				if host.global_position.distance_squared_to(child.global_position) <= RANGE_SENSE_SQ:
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
		if action_name == "ScanFauna": return "SCANNING_CROPS"
		elif action_name == "MoveToAnimal" or action_name == "DruidFlee": return "WANDERING"
		elif action_name == "CastHeal" or action_name == "Meditate": return "WORKING"
		elif action_name == "Patrol": return "PATROLLING"
	return "IDLE"


# ==============================================================================
# INNER CLASSES: GOAP ACTIONS (Decoupled forest protection behaviors)
# ==============================================================================

class DruidFleeAction extends GOAPAction:
	func _init() -> void:
		super("DruidFlee", 1.0)
		add_effect("is_safe", true)
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", DruidAIBehavior.TASK_PANIC)
			
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


class ScanFaunaAction extends GOAPAction:
	func _init() -> void:
		super("ScanFauna", 1.0)
		add_effect("has_heal_target", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("spell_cooldown") <= 0.0
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := _scan_for_injured_animals(host)
		if is_instance_valid(target):
			bb.set_memory("heal_target", target)
			return true
		return false
		
	func _scan_for_injured_animals(host: CharacterBody3D) -> Node3D:
		var passives := host.get_tree().get_nodes_in_group("passives")
		var closest: Node3D = null
		var min_dist_sq := RANGE_SENSE_SQ
		
		for child in passives:
			if is_instance_valid(child) and child != host and child is Node3D:
				var domain := child.get("domain_entity") as VoxelEntity
				if is_instance_valid(domain) and not domain.is_dead and _is_animal_injured(child, domain):
					var dist_sq := host.global_position.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest = child as Node3D
		return closest
		
	func _is_animal_injured(child: Node3D, domain: VoxelEntity) -> bool:
		var hp := domain.health
		var name_str := child.name
		if name_str.contains("PIG") or name_str.contains("SHEEP") or name_str.contains("CHICKEN"):
			return hp < 2
		elif name_str.contains("COW") or name_str.contains("GROWLITHE") or name_str.contains("OCTOPUS"):
			return hp < 6
		return hp < 4


class MoveToAnimalAction extends GOAPAction:
	func _init() -> void:
		super("MoveToAnimal", 1.0)
		add_precondition("has_heal_target", true)
		add_effect("is_at_animal", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("heal_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, _delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("heal_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		
		if diff.length_squared() <= RANGE_HEAL_ATTACK_SQ:
			host.velocity.x = 0.0; host.velocity.z = 0.0
			return true
			
		VoxelKinematicService.apply_motion_vectors(host, ai, diff.normalized(), SPEED_PATROL)
		if is_instance_valid(ai): ai.set("current_task", DruidAIBehavior.TASK_WANDERING)
		return false


class CastHealAction extends GOAPAction:
	func _init() -> void:
		super("CastHeal", 1.0)
		add_precondition("is_at_animal", true)
		add_effect("fauna_healed", true)
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("cast_timer", CAST_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", DruidAIBehavior.TASK_WORKING)
			
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		var target := bb.get_object("heal_target") as Node3D
		if is_instance_valid(target):
			var domain := target.get("domain_entity") as VoxelEntity
			return is_instance_valid(domain) and not domain.is_dead
		return false
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var target := bb.get_object("heal_target") as Node3D
		var ai: Object = host.get("ai_component")
		
		var diff := target.global_position - host.global_position
		diff.y = 0.0
		if is_instance_valid(ai): ai.set("wander_direction", diff.normalized())
			
		var timer := bb.get_float("cast_timer") - delta
		bb.set_memory("cast_timer", timer)
		
		if host.has_method("_play_healing_visuals"):
			host.call("_play_healing_visuals", target)
			
		if timer <= 0.0:
			_complete_healing(bb, host, target)
			return true
		return false
		
	func _complete_healing(bb: AIBlackboard, host: CharacterBody3D, target: Node3D) -> void:
		var domain := target.get("domain_entity") as VoxelEntity
		if is_instance_valid(domain):
			domain.health = 6 # Fully restored
			
		var vis := host.get("visual_representation") as IEntityVisualRepresentation
		if is_instance_valid(vis): vis.trigger_attack_visuals()
		
		host.velocity.y = 4.0 # Hop with joy
		bb.set_memory("spell_cooldown", COOLDOWN_SPELL_SEC)
		bb.erase_memory("heal_target")
		bb.erase_memory("has_heal_target")
		bb.erase_memory("is_at_animal")


class MeditateAction extends GOAPAction:
	func _init() -> void:
		super("Meditate", 1.0)
		add_effect("is_meditating", true)
		
	func is_contextually_valid(bb: AIBlackboard) -> bool:
		return bb.get_float("meditate_cooldown") <= 0.0
		
	func on_enter(bb: AIBlackboard) -> void:
		bb.set_memory("meditate_timer", MEDITATE_DURATION_SEC)
		var host := bb.get_object("host") as CharacterBody3D
		var ai := host.get("ai_component")
		VoxelKinematicService.halt_movement(host, ai)
		if is_instance_valid(ai): ai.set("current_task", DruidAIBehavior.TASK_WORKING)
			
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var timer := bb.get_float("meditate_timer") - delta
		bb.set_memory("meditate_timer", timer)
		
		if host.has_method("_play_healing_visuals"):
			host.call("_play_healing_visuals", host)
			
		if timer <= 0.0:
			bb.set_memory("meditate_cooldown", COOLDOWN_MEDITATE_SEC)
			return true
		return false


class DruidPatrolAction extends GOAPAction:
	func _init() -> void:
		super("Patrol", 1.0)
		add_effect("is_patrolling", true)
		
	func execute_step(bb: AIBlackboard, delta: float) -> bool:
		var host := bb.get_object("host") as CharacterBody3D
		var ai: Object = host.get("ai_component")
		if is_instance_valid(ai): ai.set("current_task", DruidAIBehavior.TASK_WANDERING)
			
		var timer := bb.get_float("wander_timer") - delta
		var wander_dir := bb.get_vector3("wander_direction")
		
		if timer <= 0.0:
			timer = randf_range(2.0, 5.0)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle)) if randf() > 0.3 else Vector3.ZERO
			bb.set_memory("wander_direction", wander_dir)
			
		bb.set_memory("wander_timer", timer)
		VoxelKinematicService.apply_motion_vectors(host, ai, wander_dir, SPEED_PATROL)
		return false

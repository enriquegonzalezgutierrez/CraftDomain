# ==============================================================================
# Pathfile: res://src/Domain/Life/DruidAIBehavior.gd
# Description: Specialized AI behavior strategy implementing the Forest Druid's 
#              mystical protector routines.
#              UPGRADE: Implemented Localized State Machine, Tactical Panic Routing
#              to protectors, and a Sacred Grove Meditation ritual.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively wildlife healing,
#   meditation cycles, and defensive retreats. All methods kept strictly < 20 lines.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior, closing existing
#   controllers to core modifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DruidAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,         # Resting / Standing still
	PATROLLING,   # Walking around the giant redwoods
	CHANNELING,   # Casting active healing spells on injured wildlife
	MEDITATING,   # Channeling emerald particle streams to natural shrines
	FLEEING       # Running towards nearest Guard/Golem for safety
}

const SPEED_PATROL: float = 1.1
const SPEED_PANIC: float = 2.4

const COOLDOWN_SPELL_SEC: float = 6.0
const CAST_DURATION_SEC: float = 2.0
const RANGE_SENSE_SQ: float = 64.0 
const RANGE_GUARD_SEEK_SQ: float = 900.0

const COOLDOWN_MEDITATE_SEC: float = 15.0
const MEDITATE_DURATION_SEC: float = 4.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "druid_local_state"
const META_WANDER_TIMER := "druid_wander_timer"
const META_WANDER_DIR := "druid_wander_dir"
const META_COOLDOWN := "druid_spell_cooldown"
const META_TARGET_ANIMAL := "druid_heal_target"
const META_CAST_TIMER := "druid_cast_timer"
const META_MEDITATE_COOLDOWN := "druid_meditate_cooldown"
const META_MEDITATE_TIMER := "druid_meditate_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives the wildlife scanning, channeling, and meditation
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_druid_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_spell_cooldowns(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	# Priority 1: Survival (Fleeing to nearest defender)
	if _process_threat_panic(host, ai, delta):
		return
		
	# Priority 2: Healing (Casting active restorative spells)
	var target_ref: Object = _get_metadata_object(host, META_TARGET_ANIMAL)
	if is_instance_valid(target_ref):
		_process_healing_ritual(host, ai, target_ref, delta)
		return
		
	_process_fauna_scanning(host)
	
	# Priority 3: Meditation (Channeling emerald particles at shrines)
	if _process_shrine_meditation(host, ai, delta):
		return
		
	# Priority 4: Default Patrol
	_process_default_patrol(host, ai, delta)


func _update_spell_cooldowns(host: Object, delta: float) -> void:
	var spell_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if spell_cooldown > 0.0:
		host.set_meta(META_COOLDOWN, spell_cooldown - delta)
		
	var med_cooldown: float = host.get_meta(META_MEDITATE_COOLDOWN) as float
	if med_cooldown > 0.0:
		host.set_meta(META_MEDITATE_COOLDOWN, med_cooldown - delta)


# ==============================================================================
# TACTICAL PANIC & PROTECTION SEEKING
# ==============================================================================

func _process_threat_panic(host: Object, ai: Object, delta: float) -> bool:
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	if not is_panicking and _detect_threat_proximity(host):
		is_panicking = true
		ai.set("current_task", TASK_PANIC)
		
	if not is_panicking:
		return false
		
	host.set_meta(META_STATE, State.FLEEING)
	_execute_tactical_panic(host, ai, delta)
	return true


func _execute_tactical_panic(host: Object, ai: Object, delta: float) -> void:
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	var wander_dir := host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.4, 1.0)
		var guard := _scan_for_closest_protector(host)
		if is_instance_valid(guard):
			# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
			var host_pos: Vector3 = host.get("global_position")
			wander_dir = (guard.global_position - host_pos).normalized()
			wander_dir.y = 0.0
		else:
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
			
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_WANDER_DIR, wander_dir)
	_apply_movement_vectors(host, ai, wander_dir, SPEED_PANIC)


func _detect_threat_proximity(host: Object) -> bool:
	if not host.call("is_inside_tree"): return false
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	for child: Object in hostiles:
		if is_instance_valid(child):
			var zombie_domain: Object = child.get("domain_entity")
			if zombie_domain != null and not zombie_domain.get("is_dead"):
				var dist_sq := host_pos.distance_squared_to(child.get("global_position"))
				if dist_sq <= RANGE_SENSE_SQ:
					return true
	return false


func _scan_for_closest_protector(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_protector: Node3D = null
	var min_dist_sq := RANGE_GUARD_SEEK_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var name_str: String = child.get("name")
			if name_str.contains("GUARD") or name_str.contains("GOLEM"):
				var domain: Object = child.get("domain_entity")
				if domain != null and not domain.get("is_dead"):
					var dist_sq := host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_protector = child as Node3D
	return closest_protector


# ==============================================================================
# WILDLIFE RESTORATIVE HEALING RITUALS
# ==============================================================================

func _process_healing_ritual(host: Object, ai: Object, target_ref: Object, delta: float) -> void:
	var target_node := target_ref as Node3D
	var target_domain: Object = target_node.get("domain_entity") if is_instance_valid(target_node) else null
	
	if target_domain == null or target_domain.get("is_dead") == true:
		_reset_druid_state(host)
		return
		
	host.set_meta(META_STATE, State.CHANNELING)
	ai.set("current_task", TASK_WORKING)
	
	# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
	var host_pos: Vector3 = host.get("global_position")
	var diff: Vector3 = target_node.global_position - host_pos
	diff.y = 0.0
	
	if diff.length_squared() > 2.25:
		_apply_movement_vectors(host, ai, diff.normalized(), SPEED_PATROL)
	else:
		_execute_healing_channel(host, ai, target_node, diff, delta)


func _execute_healing_channel(host: Object, ai: Object, target_node: Node3D, diff: Vector3, delta: float) -> void:
	_halt_movement(host, ai)
	ai.set("wander_direction", diff.normalized())
	
	var vis_rep: Object = host.get("visual_representation")
	if is_instance_valid(vis_rep) and vis_rep.has_method("trigger_attack_visuals"):
		vis_rep.call("trigger_attack_visuals")
		
	if host.has_method("_play_healing_visuals"):
		host.call("_play_healing_visuals", target_node)
		
	var cast_timer: float = host.get_meta(META_CAST_TIMER) as float
	cast_timer -= delta
	if cast_timer <= 0.0:
		_complete_healing_spell(host, target_node)
	else:
		host.set_meta(META_CAST_TIMER, cast_timer)


func _complete_healing_spell(host: Object, target_node: Node3D) -> void:
	var target_domain: Object = target_node.get("domain_entity")
	if target_domain != null:
		target_domain.set("health", 6) 
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.y = 4.0 
	host.set("velocity", velocity)
	
	host.set_meta(META_COOLDOWN, COOLDOWN_SPELL_SEC)
	_reset_druid_state(host)


func _process_fauna_scanning(host: Object) -> void:
	var spell_cooldown: float = host.get_meta(META_COOLDOWN) as float
	if spell_cooldown <= 0.0:
		var injured_creature := _scan_for_injured_animals(host)
		if injured_creature != null:
			host.set_meta(META_TARGET_ANIMAL, injured_creature)
			host.set_meta(META_CAST_TIMER, CAST_DURATION_SEC)


func _scan_for_injured_animals(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var passives: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_injured: Node3D = null
	var min_dist_sq := RANGE_SENSE_SQ
	
	for child: Object in passives:
		if is_instance_valid(child) and child != host and child is Node3D:
			var domain: Object = child.get("domain_entity")
			if domain != null and not domain.get("is_dead"):
				if _is_animal_injured(child, domain):
					var dist_sq: float = host_pos.distance_squared_to(child.global_position)
					if dist_sq < min_dist_sq:
						min_dist_sq = dist_sq
						closest_injured = child as Node3D
	return closest_injured


func _is_animal_injured(child: Object, domain: Object) -> bool:
	var current_hp: int = domain.get("health") as int
	var child_name: String = child.get("name")
	
	if child_name.contains("PIG") or child_name.contains("SHEEP") or child_name.contains("CHICKEN"):
		return current_hp < 2 
	elif child_name.contains("COW") or child_name.contains("GROWLITHE") or child_name.contains("OCTOPUS"):
		return current_hp < 6 
	return current_hp < 4 


# ==============================================================================
# SACRED GROVE MEDITATION (New Feature)
# ==============================================================================

func _process_shrine_meditation(host: Object, ai: Object, delta: float) -> bool:
	var med_cooldown: float = host.get_meta(META_MEDITATE_COOLDOWN) as float
	if med_cooldown > 0.0:
		return false
		
	host.set_meta(META_STATE, State.MEDITATING)
	ai.set("current_task", TASK_WORKING)
	_halt_movement(host, ai)
	
	var med_timer: float = host.get_meta(META_MEDITATE_TIMER) as float
	med_timer -= delta
	if med_timer <= 0.0:
		host.set_meta(META_MEDITATE_COOLDOWN, COOLDOWN_MEDITATE_SEC)
		_reset_druid_state(host)
	else:
		host.set_meta(META_MEDITATE_TIMER, med_timer)
		if host.has_method("_play_healing_visuals"):
			host.call("_play_healing_visuals", host)
	return true


# ==============================================================================
# DEFAULT MOVEMENT & DECOUPLED UTILITIES
# ==============================================================================

func _process_default_patrol(host: Object, ai: Object, delta: float) -> void:
	ai.set("current_task", TASK_WANDERING)
	host.set_meta(META_STATE, State.PATROLLING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 5.0)
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		
		wander_dir = candidate_dir if _is_direction_safe_druid(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_movement_vectors(host, ai, wander_dir, SPEED_PATROL)


func _halt_movement(host: Object, ai: Object) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0; velocity.z = 0.0
	host.set("velocity", velocity)
	ai.set("wander_direction", Vector3.ZERO)


func _apply_movement_vectors(host: Object, ai: Object, wander_dir: Vector3, speed: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_ANIMAL): host.set_meta(META_TARGET_ANIMAL, "")
	if not host.has_meta(META_CAST_TIMER): host.set_meta(META_CAST_TIMER, 0.0)
	if not host.has_meta(META_MEDITATE_COOLDOWN): host.set_meta(META_MEDITATE_COOLDOWN, 5.0) 
	if not host.has_meta(META_MEDITATE_TIMER): host.set_meta(META_MEDITATE_TIMER, MEDITATE_DURATION_SEC)
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.IDLE)


func _reset_druid_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_ANIMAL, "")
	host.set_meta(META_CAST_TIMER, 0.0)
	host.set_meta(META_MEDITATE_TIMER, MEDITATE_DURATION_SEC)
	host.set_meta(META_STATE, State.IDLE)


func _get_metadata_object(host: Object, key: String) -> Object:
	if host.has_meta(key):
		var val: Variant = host.get_meta(key)
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			return val as Object
	return null


func _is_direction_safe_druid(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	return ws.get_block(block_below_coord) != 6 and ws.get_block(block_at_coord) != 6 and ws.get_block(block_below_coord) != 0


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.IDLE: return "IDLE"
		State.PATROLLING: return "PATROLLING"
		State.CHANNELING: return "WORKING"   
		State.MEDITATING: return "EXAMINE"   
		State.FLEEING: return "PANIC"
		_: return "IDLE"

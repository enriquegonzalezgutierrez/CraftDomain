# ==============================================================================
# Pathfile: res://src/Domain/Life/ChickenAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              soil-pecking, predator evasion, and seed-luring routines.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly chicken state 
#   transitions, pecking intervals, and panic flutters.
# - Open-Closed Principle (OCP): Integrates dynamic food-following routines
#   without modifying the core physics controller.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChickenAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	WANDERING,      # Standard passive roaming
	PECKING,        # Stopping to peck the ground
	FOLLOWING_FOOD, # Following a player holding seeds
	FLEEING         # Running away from a predator (Zombie or Fox)
}

const SPEED_WANDER: float = 0.9
const SPEED_FOLLOW: float = 1.4
const SPEED_PANIC: float = 2.4

const SENSORY_RANGE_SQ: float = 64.0  # 8.0m threat detection radius
const LURE_RANGE_SQ: float = 100.0    # 10.0m seed luring radius

# Pecking duration parameters
const PECK_INTERVAL_MIN_SEC: float = 10.0
const PECK_INTERVAL_MAX_SEC: float = 20.0
const PECK_DURATION_SEC: float = 1.6

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "chicken_local_state"
const META_WANDER_TIMER := "chicken_wander_timer"
const META_WANDER_DIR := "chicken_wander_dir"
const META_PECK_TIMER := "chicken_peck_timer"
const META_PECK_COOLDOWN := "chicken_peck_cooldown"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, luring, and panic escape cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_cooldowns(host, delta)
	
	# Priority 1: Survival (Fleeing predators)
	if _process_predator_evasion(host, delta):
		return
		
	# Priority 2: Hunger (Following seeds)
	if _process_food_luring(host):
		return
		
	# Priority 3: Default routines (Wandering & Pecking)
	var state: int = host.get_meta(META_STATE) as int
	match state:
		State.PECKING:
			_process_pecking_state(host, delta)
		State.WANDERING:
			_process_wandering_state(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_PECK_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_PECK_COOLDOWN, cooldown - delta)


# ==============================================================================
# SURVIVAL & EVASION (Predators)
# ==============================================================================

func _process_predator_evasion(host: Object, delta: float) -> bool:
	var closest_threat := _detect_closest_predator(host)
	
	if closest_threat == null:
		return false
		
	host.set_meta(META_STATE, State.FLEEING)
	
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai): ai.set("current_task", TASK_PANIC)
		
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		# Change escape direction rapidly
		wander_timer = randf_range(0.3, 0.6)
		
		# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
		var host_pos: Vector3 = host.get("global_position")
		var escape_dir: Vector3 = (host_pos - closest_threat.global_position).normalized()
		escape_dir.y = 0.0
		
		# Add a slight random deflection to the escape vector
		escape_dir = escape_dir.rotated(Vector3.UP, randf_range(-0.5, 0.5))
		host.set_meta(META_WANDER_DIR, escape_dir)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, host.get_meta(META_WANDER_DIR), SPEED_PANIC)
	
	return true


func _detect_closest_predator(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	
	var hostiles: Array = []
	var passives: Array = []
	
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			passives = tree.call("get_nodes_in_group", "passives")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_threat: Node3D = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	# Check standard monsters (Zombies, Gargoyles)
	closest_threat = _scan_group_for_predator(hostiles, host_pos, min_dist_sq, closest_threat, "")
	
	# Check natural wildlife predators (Foxes)
	if closest_threat == null:
		closest_threat = _scan_group_for_predator(passives, host_pos, min_dist_sq, closest_threat, "FOX")
		
	return closest_threat


func _scan_group_for_predator(group: Array, host_pos: Vector3, min_dist_sq: float, current_closest: Node3D, required_name: String) -> Node3D:
	var closest := current_closest
	for child: Object in group:
		if is_instance_valid(child) and child is Node3D:
			var node_name: String = child.get("name")
			if required_name != "" and not node_name.contains(required_name):
				continue
				
			var domain: Object = child.get("domain_entity")
			if domain != null and not domain.get("is_dead"):
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest = child as Node3D
	return closest


# ==============================================================================
# FOOD LURING (Emergent Gameplay)
# ==============================================================================

func _process_food_luring(host: Object) -> bool:
	var parent: Node = host.call("get_parent") as Node
	if not is_instance_valid(parent): return false
		
	var player_node: Object = parent.call("get_node_or_null", "Player")
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	
	if host_pos.distance_squared_to(p_pos) > LURE_RANGE_SQ or not _is_player_holding_seeds(player_node):
		return false
		
	host.set_meta(META_STATE, State.FOLLOWING_FOOD)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	ai.set("current_task", TASK_WANDERING)
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	if diff.length_squared() > 1.5:
		_apply_movement_vectors(host, diff.normalized(), SPEED_FOLLOW)
	else:
		_apply_movement_vectors(host, diff.normalized(), 0.0)
		
	return true


func _is_player_holding_seeds(player_node: Object) -> bool:
	var inventory := player_node.get("inventory")
	if is_instance_valid(inventory):
		var active_slot: int = player_node.get("active_slot_index") as int
		var slot_data: Object = inventory.call("get_slot_data", active_slot)
		# 18 = Crop Seeds (BlockType.Type.CROP_SEED)
		return is_instance_valid(slot_data) and slot_data.get("item_id") == 18
	return false


# ==============================================================================
# STANDARD WANDERING & PECKING
# ==============================================================================

func _process_wandering_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WANDERING)
	host.set_meta(META_STATE, State.WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		_calculate_next_wander_step(host)
		wander_timer = randf_range(1.5, 4.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, host.get_meta(META_WANDER_DIR), SPEED_WANDER)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_PECK_COOLDOWN) as float
	
	# Verify if standing on Grass or Dirt and pecking cooldown is cleared
	if ws != null and cooldown <= 0.0 and randf() < 0.45:
		var check_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		var block := ws.get_block(check_coord)
		if block == 3 or block == 2: # 3 = Grass, 2 = Dirt
			host.set_meta(META_STATE, State.PECKING)
			host.set_meta(META_PECK_TIMER, PECK_DURATION_SEC)
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			return
			
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.6 else Vector3.ZERO)


func _process_pecking_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING)
	ai.set("wander_direction", Vector3.ZERO)
	
	var peck_timer: float = host.get_meta(META_PECK_TIMER) as float
	peck_timer -= delta
	
	if peck_timer <= 0.0:
		# Restart pecking cooldown
		host.set_meta(META_PECK_COOLDOWN, randf_range(PECK_INTERVAL_MIN_SEC, PECK_INTERVAL_MAX_SEC))
		host.set_meta(META_STATE, State.WANDERING)
		host.set_meta(META_WANDER_TIMER, 1.0)
	else:
		host.set_meta(META_PECK_TIMER, peck_timer)


func _apply_movement_vectors(host: Object, wander_dir: Vector3, speed: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
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
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.WANDERING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_PECK_TIMER): host.set_meta(META_PECK_TIMER, 0.0)
	if not host.has_meta(META_PECK_COOLDOWN): host.set_meta(META_PECK_COOLDOWN, 4.0)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.PECKING: return "WORKING" 
		State.FOLLOWING_FOOD: return "EXAMINE" # Maps to a focused/following string
		State.FLEEING: return "PANIC"
		_: return "WANDER"

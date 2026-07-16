# ==============================================================================
# Pathfile: res://src/Domain/Life/CowAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              grazing, milk regrowth, predator evasion, and wheat-luring.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly cow state 
#   transitions, grazing, and food attraction cycles.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior, closing core physical
#   movement nodes to direct modifications.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CowAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	WANDERING,      # Standard passive roaming over pastures
	GRAZING,        # Munching grass to produce milk
	FOLLOWING_FOOD, # Approaching a player holding golden wheat
	FLEEING         # Escaping frantically from nearby hostiles
}

const SPEED_WALK: float = 0.6
const SPEED_TROT: float = 1.0
const SPEED_PANIC: float = 1.8

const SENSORY_RANGE_SQ: float = 64.0  # 8.0m threat detection
const LURE_RANGE_SQ: float = 144.0    # 12.0m wheat luring radius

# Grazing parameters
const GRAZE_INTERVAL_MIN: float = 15.0
const GRAZE_INTERVAL_MAX: float = 30.0
const GRAZE_DURATION: float = 3.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "cow_local_state"
const META_WANDER_TIMER := "cow_wander_timer"
const META_WANDER_DIR := "cow_wander_dir"
const META_GRAZE_TIMER := "cow_graze_timer"
const META_GRAZE_COOLDOWN := "cow_graze_cooldown"
const META_HAS_MILK := "cow_has_milk"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, soil-munching, and wheat luring cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_cooldowns(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	# Priority 1: Survival (Fleeing from nearby zombies)
	if _process_predator_evasion(host, ai, delta):
		return
		
	# Priority 2: Husbandry (Following player holding wheat)
	if _process_food_luring(host, ai):
		return
		
	# Priority 3: Default routines (Wandering vs Grazing)
	var state := host.get_meta(META_STATE) as int
	match state:
		State.GRAZING:
			_process_grazing_state(host, ai, delta)
		State.WANDERING:
			_process_wandering_state(host, ai, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown := host.get_meta(META_GRAZE_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_GRAZE_COOLDOWN, cooldown - delta)


# ==============================================================================
# PREDATOR EVASION
# ==============================================================================

func _process_predator_evasion(host: Object, ai: Object, delta: float) -> bool:
	var threat := _detect_closest_threat(host)
	if threat == null:
		return false
		
	host.set_meta(META_STATE, State.FLEEING)
	ai.set("current_task", TASK_PANIC)
	
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.5, 1.2)
		
		# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
		var host_pos: Vector3 = host.get("global_position")
		var escape_dir: Vector3 = (host_pos - threat.global_position).normalized()
		escape_dir.y = 0.0
		host.set_meta(META_WANDER_DIR, escape_dir)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, ai, host.get_meta(META_WANDER_DIR), SPEED_PANIC)
	return true


func _detect_closest_threat(host: Object) -> Node3D:
	if not host.call("is_inside_tree"): return null
	var hostiles: Array = []
	if host.has_method("get_tree"):
		var tree: Object = host.call("get_tree")
		if is_instance_valid(tree):
			hostiles = tree.call("get_nodes_in_group", "hostiles")
			
	var host_pos: Vector3 = host.get("global_position")
	var closest_threat: Node3D = null
	var min_dist_sq := SENSORY_RANGE_SQ
	
	for child: Object in hostiles:
		if is_instance_valid(child) and child is Node3D:
			var domain: Object = child.get("domain_entity")
			if domain != null and not domain.get("is_dead"):
				var dist_sq := host_pos.distance_squared_to(child.global_position)
				if dist_sq < min_dist_sq:
					min_dist_sq = dist_sq
					closest_threat = child as Node3D
	return closest_threat


# ==============================================================================
# WHEAT LURING
# ==============================================================================

func _process_food_luring(host: Object, ai: Object) -> bool:
	var parent: Node = host.call("get_parent") as Node
	if not is_instance_valid(parent): return false
	
	var player_node: Object = parent.call("get_node_or_null", "Player")
	if not is_instance_valid(player_node) or not player_node.get("is_active"):
		return false
		
	var host_pos: Vector3 = host.get("global_position")
	var p_pos: Vector3 = player_node.get("global_position")
	
	if host_pos.distance_squared_to(p_pos) > LURE_RANGE_SQ or not _is_player_holding_wheat(player_node):
		return false
		
	host.set_meta(META_STATE, State.FOLLOWING_FOOD)
	ai.set("current_task", TASK_WANDERING)
	var diff := p_pos - host_pos
	diff.y = 0.0
	
	var speed := SPEED_TROT if diff.length_squared() > 2.25 else 0.0
	_apply_movement_vectors(host, ai, diff.normalized(), speed)
	return true


func _is_player_holding_wheat(player_node: Object) -> bool:
	var inventory := player_node.get("inventory")
	if is_instance_valid(inventory):
		var active_slot: int = player_node.get("active_slot_index") as int
		var slot_data: Object = inventory.call("get_slot_data", active_slot)
		# 20 = Mature Golden Wheat (BlockType.Type.CROP_RIPE)
		return is_instance_valid(slot_data) and slot_data.get("item_id") == 20
	return false


# ==============================================================================
# GRAZING & WANDERING
# ==============================================================================

func _process_wandering_state(host: Object, ai: Object, delta: float) -> void:
	ai.set("current_task", TASK_WANDERING)
	host.set_meta(META_STATE, State.WANDERING)
	
	var wander_timer := host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	if wander_timer <= 0.0:
		_calculate_next_wander_step(host)
		wander_timer = randf_range(3.0, 6.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, ai, host.get_meta(META_WANDER_DIR), SPEED_WALK)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_GRAZE_COOLDOWN) as float
	var has_milk: bool = host.get_meta(META_HAS_MILK) as bool
	
	# Milked cows actively search for Grass to digest and produce milk
	if ws != null and not has_milk and cooldown <= 0.0 and randf() < 0.45:
		var below_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		if ws.get_block(below_coord) == 3: # 3 = Grass Block
			host.set_meta(META_STATE, State.GRAZING)
			host.set_meta(META_GRAZE_TIMER, GRAZE_DURATION)
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			return
			
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.4 else Vector3.ZERO)


func _process_grazing_state(host: Object, ai: Object, delta: float) -> void:
	ai.set("current_task", TASK_WORKING)
	ai.set("wander_direction", Vector3.ZERO)
	
	var graze_timer := host.get_meta(META_GRAZE_TIMER) as float
	graze_timer -= delta
	if graze_timer <= 0.0:
		_complete_soil_grazing(host)
	else:
		host.set_meta(META_GRAZE_TIMER, graze_timer)


func _complete_soil_grazing(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	
	if ws != null and parent.has_method("set_block_globally"):
		var below_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		if ws.get_block(below_coord) == 3:
			parent.call("set_block_globally", below_coord, 2) # 2 = Dirt Block
			host.set_meta(META_HAS_MILK, true)
			if host.has_method("_play_grazing_joy_hop"):
				host.call("_play_grazing_joy_hop")
				
	host.set_meta(META_GRAZE_COOLDOWN, randf_range(GRAZE_INTERVAL_MIN, GRAZE_INTERVAL_MAX))
	host.set_meta(META_STATE, State.WANDERING)
	host.set_meta(META_WANDER_TIMER, 1.0)


# ==============================================================================
# DECOUPLED UTILITIES & POSITION PRESENTERS
# ==============================================================================

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
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, State.WANDERING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_GRAZE_TIMER): host.set_meta(META_GRAZE_TIMER, 0.0)
	if not host.has_meta(META_GRAZE_COOLDOWN): host.set_meta(META_GRAZE_COOLDOWN, 6.0)
	if not host.has_meta(META_HAS_MILK): host.set_meta(META_HAS_MILK, true)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.GRAZING: return "WORKING" 
		State.FOLLOWING_FOOD: return "EXAMINE" 
		State.FLEEING: return "PANIC"
		_: return "WANDER"

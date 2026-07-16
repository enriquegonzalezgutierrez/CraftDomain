# ==============================================================================
# Pathfile: res://src/Domain/Life/PigAIBehavior.gd
# Description: Pure Domain AI behavior strategy implementing specialized 
#              root-sniffing, grass-tilling, and crop-eating routines for the Wild Pig.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly pig state 
#   transitions, tilling checks, and cooldown timers.
# - Layered DDD Compliance: Pure logical state calculations with zero framework 
#   leakage, delegating voxel mutations to the abstract world modifier boundary.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PigAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	WANDERING,  # Standard passive roaming
	SNIFFING,   # Halting to smell the ground
	TILLING,    # Digging up grass to turn it into dirt
	EATING      # Actively destroying/consuming a planted crop block
}

const SPEED_WALK: float = 0.8
const SPEED_PANIC: float = 2.4
const SPEED_TROT: float = 1.3
const SENSORY_RANGE_SQ: float = 64.0 # 8.0m threat detection radius

# Action duration parameters
const SNIFF_DURATION_SEC: float = 1.5
const TILL_DURATION_SEC: float = 2.0
const EAT_DURATION_SEC: float = 2.5
const COOLDOWN_TILL_MIN_SEC: float = 15.0
const COOLDOWN_TILL_MAX_SEC: float = 30.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_STATE := "pig_local_state"
const META_WANDER_TIMER := "pig_wander_timer"
const META_WANDER_DIR := "pig_wander_dir"
const META_ACTION_TIMER := "pig_action_timer"
const META_COOLDOWN := "pig_till_cooldown"
const META_TARGET_CROP := "pig_target_crop"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives grazing, soil-sniffing, crop eating, and panic cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_cooldowns(host, delta)
	
	var is_panicking := _evaluate_threat_panic(host)
	if is_panicking:
		_process_panic_state(host, delta)
		return
		
	var state: int = host.get_meta(META_STATE) as int
	match state:
		State.TILLING:
			_process_tilling_state(host, delta)
		State.SNIFFING:
			_process_sniffing_state(host, delta)
		State.EATING:
			_process_eating_state(host, delta)
		State.WANDERING:
			_process_wandering_state(host, delta)


func _update_cooldowns(host: Object, delta: float) -> void:
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	if cooldown > 0.0:
		host.set_meta(META_COOLDOWN, cooldown - delta)


# ==============================================================================
# PANIC & SENSORY ROUTINES
# ==============================================================================

func _evaluate_threat_panic(host: Object) -> bool:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
		
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	var parent: Node = host.call("get_parent") as Node
	
	if not is_panicking and is_instance_valid(parent):
		var hostiles: Array = []
		if host.has_method("get_tree"):
			var tree: Object = host.call("get_tree")
			if is_instance_valid(tree):
				hostiles = tree.call("get_nodes_in_group", "hostiles")
				
		var host_pos: Vector3 = host.get("global_position")
		for child: Object in hostiles:
			if is_instance_valid(child):
				var child_pos: Vector3 = child.get("global_position")
				if child_pos.distance_squared_to(host_pos) <= SENSORY_RANGE_SQ:
					var z_domain: Object = child.get("domain_entity")
					if z_domain != null and not z_domain.get("is_dead"):
						is_panicking = true
						ai.set("current_task", TASK_PANIC)
						break
					
	return is_panicking


func _process_panic_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		wander_timer = randf_range(0.4, 1.0)
		var angle := randf() * TAU
		host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)))
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	host.set_meta(META_STATE, State.WANDERING)
	
	_apply_movement_vectors(host, ai, host.get_meta(META_WANDER_DIR), SPEED_PANIC)


# ==============================================================================
# WANDERING & FOOD SCANNING
# ==============================================================================

func _process_wandering_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WANDERING)
	
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP) as Vector3i
	if target_crop.y != -999:
		_approach_target_crop(host, ai, target_crop)
		return
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	
	if wander_timer <= 0.0:
		_calculate_next_wander_step(host)
		wander_timer = randf_range(2.0, 5.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_movement_vectors(host, ai, host.get_meta(META_WANDER_DIR), SPEED_WALK)


func _calculate_next_wander_step(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	var cooldown: float = host.get_meta(META_COOLDOWN) as float
	
	if ws != null and cooldown <= 0.0:
		# 1. High Priority: Scan for tasty farm crops to eat!
		var nearby_crop := _scan_for_nearby_crops(host_pos, ws)
		if nearby_crop.y != -999:
			host.set_meta(META_TARGET_CROP, nearby_crop)
			return
		
		# 2. Low Priority: If standing on Grass, sniff and till the soil
		if randf() < 0.35:
			var check_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
			if ws.get_block(check_coord) == 3: # 3 = Grass Block
				host.set_meta(META_STATE, State.SNIFFING)
				host.set_meta(META_ACTION_TIMER, SNIFF_DURATION_SEC)
				host.set_meta(META_WANDER_DIR, Vector3.ZERO)
				return
			
	# Default: Pick a new random angle or stand still
	var angle := randf() * TAU
	host.set_meta(META_WANDER_DIR, Vector3(cos(angle), 0.0, sin(angle)) if randf() < 0.5 else Vector3.ZERO)


# ==============================================================================
# CROP EATING ROUTINE (New Feature)
# ==============================================================================

func _scan_for_nearby_crops(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-3, 4):
		for y in range(-1, 2):
			for z in range(-3, 4):
				var check_coord := my_coord + Vector3i(x, y, z)
				var block_type := ws.get_block(check_coord)
				# Target ripe wheat or growing crops (BlockType.Type.CROP_RIPE / CROP_GROWING)
				if block_type == 20 or block_type == 19: 
					return check_coord
	return Vector3i(0, -999, 0)


func _approach_target_crop(host: Object, ai: Object, target_crop: Vector3i) -> void:
	var target_pos := Vector3(target_crop) + Vector3(0.5, 0.0, 0.5)
	
	# STRICT TYPING FIX: Cast Variant explicitly to Vector3 before subtraction
	var host_pos: Vector3 = host.get("global_position")
	var diff: Vector3 = target_pos - host_pos
	diff.y = 0.0
	
	if diff.length_squared() > 0.8:
		# Trot towards the tasty crop
		_apply_movement_vectors(host, ai, diff.normalized(), SPEED_TROT)
	else:
		# Arrived! Halt and begin eating animation
		host.set_meta(META_STATE, State.EATING)
		host.set_meta(META_ACTION_TIMER, EAT_DURATION_SEC)
		_apply_movement_vectors(host, ai, diff.normalized(), 0.0)


func _process_eating_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING) # Triggers the rapid snout-tilting head animation in PigEntity.gd
	ai.set("wander_direction", Vector3.ZERO)
	
	var eat_timer: float = host.get_meta(META_ACTION_TIMER) as float
	eat_timer -= delta
	
	if eat_timer <= 0.0:
		_complete_crop_eating(host)
	else:
		host.set_meta(META_ACTION_TIMER, eat_timer)


func _complete_crop_eating(host: Object) -> void:
	var target_crop: Vector3i = host.get_meta(META_TARGET_CROP) as Vector3i
	var parent: Node = host.call("get_parent") as Node
	
	if is_instance_valid(parent) and parent.has_method("set_block_globally"):
		# Destroy the crop block, replacing it with AIR
		parent.call("set_block_globally", target_crop, 0)
		
		# Heal the pig if damaged
		var domain_entity: Object = host.get("domain_entity")
		if is_instance_valid(domain_entity):
			domain_entity.set("health", min(4, domain_entity.get("health") as int + 1))
			
		if host.has_method("_play_tilling_joy_hop"):
			host.call("_play_tilling_joy_hop")
			
	# Restart cooldowns and resume wandering
	host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	host.set_meta(META_COOLDOWN, randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
	host.set_meta(META_STATE, State.WANDERING)
	host.set_meta(META_WANDER_TIMER, 1.0)


# ==============================================================================
# SNIFFING & TILLING ROUTINES
# ==============================================================================

func _process_sniffing_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_IDLE)
	ai.set("wander_direction", Vector3.ZERO)
	
	var sniff_timer: float = host.get_meta(META_ACTION_TIMER) as float
	sniff_timer -= delta
	
	if sniff_timer <= 0.0:
		host.set_meta(META_STATE, State.TILLING)
		host.set_meta(META_ACTION_TIMER, TILL_DURATION_SEC)
	else:
		host.set_meta(META_ACTION_TIMER, sniff_timer)


func _process_tilling_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
		
	ai.set("current_task", TASK_WORKING)
	
	var till_timer: float = host.get_meta(META_ACTION_TIMER) as float
	till_timer -= delta
	
	if till_timer <= 0.0:
		_complete_soil_tilling(host)
	else:
		host.set_meta(META_ACTION_TIMER, till_timer)


func _complete_soil_tilling(host: Object) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	var host_pos: Vector3 = host.get("global_position")
	
	if ws != null and parent.has_method("set_block_globally"):
		var block_below_coord := Vector3i(floori(host_pos.x), floori(host_pos.y - 0.5), floori(host_pos.z))
		
		# 40% probability to dynamically turn Grass (3) into Dirt (2)
		if ws.get_block(block_below_coord) == 3 and randf() < 0.40:
			parent.call("set_block_globally", block_below_coord, 2) # 2 = Dirt Block
			if host.has_method("_play_tilling_joy_hop"):
				host.call("_play_tilling_joy_hop")
				
	host.set_meta(META_COOLDOWN, randf_range(COOLDOWN_TILL_MIN_SEC, COOLDOWN_TILL_MAX_SEC))
	host.set_meta(META_STATE, State.WANDERING)
	host.set_meta(META_WANDER_TIMER, 1.0)


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
	if not host.has_meta(META_ACTION_TIMER): host.set_meta(META_ACTION_TIMER, 0.0)
	if not host.has_meta(META_TARGET_CROP): host.set_meta(META_TARGET_CROP, Vector3i(0, -999, 0))
	if not host.has_meta(META_COOLDOWN): host.set_meta(META_COOLDOWN, 5.0) # Grace period on spawn


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_STATE):
		return "WANDER"
		
	var state_val: int = host.get_meta(META_STATE) as int
	match state_val:
		State.SNIFFING: return "EXAMINE"    
		State.TILLING:  return "WORKING"    
		State.EATING:   return "SCANNING_CROPS" # Mapeado visual para la UI
		_: return "WANDER"

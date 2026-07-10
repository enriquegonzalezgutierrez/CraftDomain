# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Behavior Strategies)
# Class: MonkeyAIBehavior
# Description: Specialized AI behavior strategy implementing acrobatic and arboreal 
#              routines for the Tropical Monkey. Features leaf clambering (actively 
#              seeking surrounding Leaves blocks to jump and perch on top), and 
#              acrobatic backflips, executing timed jumps with roll spin rotations.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Only coordinates the monkey's acrobatic 
#   decision trees, clamber loops, flip cooldowns, and chatter states.
# - Open-Closed Principle (OCP): Inherits from IAIBehavior. New fruit gathering, 
#   banana items, or player taunts can be appended cleanly here.
# - Liskov Substitution Principle (LSP): Fully compatible with the contract signatures.
# CLIMBING JUMP & ENUM CORRECTION:
# - Corrected 'chat_timer' scope typo on ambient vocalizations.
# - Appended the missing 'WANDERING' state inside the local State enum, 
#   clearing the compilation errors.
# ==============================================================================
class_name MonkeyAIBehavior
extends IAIBehavior

# Localized State Machine (SRP / OCP Compliant)
enum State {
	IDLE,       # resting on branches
	WANDERING,  # standard ground-level patrol
	SCANNING,   # looking for nearby trees to clamber
	CLAMBERING, # climbing up tree trunks
	ACROBATICS  # performing playful backflips
}

const SPEED_PATROL: float = 1.2
const SPEED_CLIMB: float = 1.8
const COOLDOWN_FLIP_SEC: float = 5.0

const RANGE_SENSE_SQ: float = 100.0 # 10.0 meters squared leaves tracking radius

# Throttled interval preventing audio from overlapping
const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

# Decoupled task enums mirroring NPCAIComponent.TaskState
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys to store state variables safely on the host node
const META_WANDER_TIMER := "monkey_wander_timer"
const META_WANDER_DIR := "monkey_wander_dir"
const META_FLIP_COOLDOWN := "monkey_flip_cooldown"
const META_TARGET_TREE := "monkey_tree_target"
const META_CHAT_TIMER := "monkey_chat_timer"
const META_MONKEY_STATE := "monkey_local_state"


func _init() -> void:
	# Monkeys manage their pathing schedules completely
	overrides_wandering = true


## Concrete Contract: Drives leaf climbing, arboreal rest, backflips, and ambient chatter
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var flip_cooldown: float = host.get_meta(META_FLIP_COOLDOWN) as float
	var target_tree: Vector3i = host.get_meta(META_TARGET_TREE) as Vector3i
	var chat_timer: float = host.get_meta(META_CHAT_TIMER) as float
	
	if flip_cooldown > 0.0:
		flip_cooldown -= delta
		host.set_meta(META_FLIP_COOLDOWN, flip_cooldown)
		
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai):
		return
		
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var parent: Node = host.call("get_parent") as Node

	# Check panic startle state
	var is_panicking := false
	if ai.get("current_task") as int == TASK_PANIC:
		is_panicking = true

	# ==========================================================================
	# AMBIENT CHATTER LOGIC (DIP/SRP Compliant)
	# ==========================================================================
	if not is_panicking:
		chat_timer -= delta
		if chat_timer <= 0.0:
			# Reset timer to a random long interval to prevent audio spam
			chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
			
			# Trigger the presentation layer to play the spatial sound effect
			if host.has_method("_play_monkey_chatter"):
				host.call("_play_monkey_chatter")
				
		host.set_meta(META_CHAT_TIMER, chat_timer)

	# ==========================================================================
	# 1. ARBOREAL TREE CLAMBERING SYSTEM (Attracted to Leaves ID 5)
	# ==========================================================================
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	if ws != null and not is_panicking:
		# If no active tree canopy block is targeted, perform vertical foliage scans
		if target_tree.y == -999:
			target_tree = _scan_for_nearby_leaves(host_pos, ws)
			host.set_meta(META_TARGET_TREE, target_tree)
			
		# If foliage coordinates are targeted, walk to climb and perch on branches
		if target_tree.y != -999:
			host.set_meta(META_MONKEY_STATE, State.CLAMBERING)
			ai.set("current_task", TASK_WORKING)
			
			var tree_pos := Vector3(target_tree) + Vector3(0.5, 1.0, 0.5)
			var diff := tree_pos - host_pos
			var dist_flat := Vector2(diff.x, diff.z).length()
			
			if dist_flat > 1.2:
				# Walk relaxed towards the trunk
				var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
				velocity.x = climb_dir.x * SPEED_CLIMB
				velocity.z = climb_dir.z * SPEED_CLIMB
				host.set("velocity", velocity)
				ai.set("wander_direction", climb_dir)
			else:
				# Arrived at trunk! Climb up or sit comfortably on the leaves
				var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
				ai.set("wander_direction", climb_dir)
				
				# If on floor, execute vertical thrust jump to clamber up onto foliage
				if host.call("is_on_floor"):
					velocity.y = 5.5 # high-climb jump!
					
					# FIX: Preserve a forward-pushing horizontal momentum towards the trunk
					# during the jump so the monkey actually lands ON the leaves instead 
					# of bouncing straight up in a trampoline loop.
					velocity.x = climb_dir.x * (SPEED_CLIMB * 0.6)
					velocity.z = climb_dir.z * (SPEED_CLIMB * 0.6)
					
					host.set("velocity", velocity)
				else:
					# In the air: continue pushing forward slowly to reach the branches
					velocity.x = climb_dir.x * (SPEED_CLIMB * 0.4)
					velocity.z = climb_dir.z * (SPEED_CLIMB * 0.4)
					host.set("velocity", velocity)
					
					# Resting perched in the branches: trigger backflips
					if flip_cooldown <= 0.0:
						flip_cooldown = COOLDOWN_FLIP_SEC
						host.set_meta(META_FLIP_COOLDOWN, flip_cooldown)
						
						# Play playful backflip on presenter
						if host.has_method("_play_backflip_effect"):
							host.call("_play_backflip_effect")
			return

	# ==========================================================================
	# 2. DEFAULT PLAYFUL ACROBATIC WANDERING (Ground level)
	# ==========================================================================
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		
		var roll := randf()
		if roll < 0.45 or is_panicking:
			host.set_meta(META_MONKEY_STATE, State.WANDERING)
			var angle := randf() * TAU
			wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		elif roll < 0.65 and flip_cooldown <= 0.0:
			host.set_meta(META_MONKEY_STATE, State.ACROBATICS)
			# Playful ground flip!
			flip_cooldown = COOLDOWN_FLIP_SEC
			host.set_meta(META_FLIP_COOLDOWN, flip_cooldown)
			if host.has_method("_play_backflip_effect"):
				host.call("_play_backflip_effect")
			wander_dir = Vector3.ZERO
		else:
			host.set_meta(META_MONKEY_STATE, State.IDLE)
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_TIMER, wander_timer)
		host.set_meta(META_WANDER_DIR, wander_dir)

	if wander_dir != Vector3.ZERO:
		var active_speed := SPEED_PATROL * (2.2 if is_panicking else 1.0)
		velocity.x = wander_dir.x * active_speed
		velocity.z = wander_dir.z * active_speed
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.ZERO)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER):
		host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR):
		host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_FLIP_COOLDOWN):
		host.set_meta(META_FLIP_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_TREE):
		host.set_meta(META_TARGET_TREE, Vector3i(0, -999, 0))
	if not host.has_meta(META_CHAT_TIMER):
		host.set_meta(META_CHAT_TIMER, randf_range(5.0, 15.0))
	if not host.has_meta(META_MONKEY_STATE):
		host.set_meta(META_MONKEY_STATE, State.IDLE)


func _reset_monkey_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_TREE, Vector3i(0, -999, 0))
	host.set_meta(META_WANDER_TIMER, 1.0)
	host.set_meta(META_MONKEY_STATE, State.IDLE)


## Proximity Scanner: Scans a 3D grid looking for foliage tree canopies (ID 5 Leaves)
func _scan_for_nearby_leaves(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	
	# Scans adjacent blocks in a 4x4 bounding box
	for x: int in range(-4, 5):
		for y: int in range(-1, 4): # Scan slightly upwards for low-hanging branches
			for z: int in range(-4, 5):
				var check_coord := my_coord + Vector3i(x, y, z)
				# Block ID 5 is Shrubbery Leaves (LEAVES)
				if ws.get_block(check_coord) == 5:
					return check_coord
					
	return Vector3i(0, -999, 0)


# ==============================================================================
# POLYMORPHIC TELEMETRY EXPOSURE (LSP / OCP Compliant)
# ==============================================================================

## Symmetrical Override: Maps the localized, private State enum to 
## human-readable telemetry strings.
func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_MONKEY_STATE):
		return "IDLE"
		
	var state_val: int = host.get_meta(META_MONKEY_STATE) as int
	match state_val:
		State.IDLE:        return "IDLE"
		State.WANDERING:   return "WANDERING"
		State.SCANNING:    return "SCANNING_TREES"
		State.CLAMBERING:  return "CLAMBERING_BRANCHES"
		State.ACROBATICS:  return "BACKFLIP_PLAY"
		_: return "IDLE"

# ==============================================================================
# Pathfile: res://src/Domain/Life/MonkeyAIBehavior.gd
# Description: Specialized AI behavior strategy implementing acrobatic and arboreal 
#              routines for the Tropical Monkey. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MonkeyAIBehavior
extends IAIBehavior

# Localized State Machine
enum State {
	IDLE,       
	WANDERING,  
	SCANNING,   
	CLAMBERING, 
	ACROBATICS  
}

const SPEED_PATROL: float = 1.2
const SPEED_CLIMB: float = 1.8
const COOLDOWN_FLIP_SEC: float = 5.0
const RANGE_SENSE_SQ: float = 100.0 

const COOLDOWN_CHAT_MIN_SEC: float = 15.0
const COOLDOWN_CHAT_MAX_SEC: float = 25.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Decoupled metadata keys
const META_WANDER_TIMER := "monkey_wander_timer"
const META_WANDER_DIR := "monkey_wander_dir"
const META_FLIP_COOLDOWN := "monkey_flip_cooldown"
const META_TARGET_TREE := "monkey_tree_target"
const META_CHAT_TIMER := "monkey_chat_timer"
const META_MONKEY_STATE := "monkey_local_state"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives leaf climbing, arboreal rest, backflips, and ambient chatter
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_update_flip_cooldown(host, delta)
	
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	if not is_panicking:
		_process_ambient_chatter(host, delta)
		
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	
	var is_clambering := false
	if ws != null and not is_panicking:
		is_clambering = _process_arboreal_clambering(host, ws, delta)
		
	if not is_clambering:
		_process_ground_acrobatics(host, is_panicking, delta)


func _update_flip_cooldown(host: Object, delta: float) -> void:
	var flip_cooldown: float = host.get_meta(META_FLIP_COOLDOWN) as float
	if flip_cooldown > 0.0:
		flip_cooldown -= delta
		host.set_meta(META_FLIP_COOLDOWN, flip_cooldown)


func _process_ambient_chatter(host: Object, delta: float) -> void:
	var chat_timer: float = host.get_meta(META_CHAT_TIMER) as float
	chat_timer -= delta
	if chat_timer <= 0.0:
		chat_timer = randf_range(COOLDOWN_CHAT_MIN_SEC, COOLDOWN_CHAT_MAX_SEC)
		if host.has_method("_play_monkey_chatter"):
			host.call("_play_monkey_chatter")
	host.set_meta(META_CHAT_TIMER, chat_timer)


func _process_arboreal_clambering(host: Object, ws: WorldState, delta: float) -> bool:
	var target_tree: Vector3i = host.get_meta(META_TARGET_TREE) as Vector3i
	if target_tree.y == -999:
		target_tree = _scan_for_nearby_leaves(host.global_position, ws)
		host.set_meta(META_TARGET_TREE, target_tree)
		
	if target_tree.y == -999:
		return false
		
	var ai: Object = host.get("ai_component")
	var host_node := host as Node3D
	if not is_instance_valid(ai) or not is_instance_valid(host_node): return false
	
	host.set_meta(META_MONKEY_STATE, State.CLAMBERING)
	ai.set("current_task", TASK_WORKING)
	
	var tree_pos := Vector3(target_tree) + Vector3(0.5, 1.0, 0.5)
	var diff: Vector3 = tree_pos - host_node.global_position
	var dist_flat := Vector2(diff.x, diff.z).length()
	
	if dist_flat > 1.2:
		_approach_tree_trunk(host, ai, diff)
	else:
		_execute_tree_climb(host, ai, diff, delta)
	return true


func _approach_tree_trunk(host: Object, ai: Object, diff: Vector3) -> void:
	var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = climb_dir.x * SPEED_CLIMB
	velocity.z = climb_dir.z * SPEED_CLIMB
	host.set("velocity", velocity)
	ai.set("wander_direction", climb_dir)


func _execute_tree_climb(host: Object, ai: Object, diff: Vector3, delta: float) -> void:
	var climb_dir := Vector3(diff.x, 0.0, diff.z).normalized()
	ai.set("wander_direction", climb_dir)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if host.call("is_on_floor"):
		velocity.y = 5.5 
		velocity.x = climb_dir.x * (SPEED_CLIMB * 0.6)
		velocity.z = climb_dir.z * (SPEED_CLIMB * 0.6)
		host.set("velocity", velocity)
	else:
		velocity.x = climb_dir.x * (SPEED_CLIMB * 0.4)
		velocity.z = climb_dir.z * (SPEED_CLIMB * 0.4)
		host.set("velocity", velocity)
		_handle_branches_backflip(host, delta)


func _handle_branches_backflip(host: Object, delta: float) -> void:
	# Avoid unused parameters warning
	var _d := delta
	
	var flip_cooldown: float = host.get_meta(META_FLIP_COOLDOWN) as float
	if flip_cooldown <= 0.0:
		host.set_meta(META_FLIP_COOLDOWN, COOLDOWN_FLIP_SEC)
		if host.has_method("_play_backflip_effect"):
			host.call("_play_backflip_effect")


func _process_ground_acrobatics(host: Object, is_panicking: bool, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var flip_cooldown: float = host.get_meta(META_FLIP_COOLDOWN) as float
	
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(1.5, 4.0)
		var roll := randf()
		if roll < 0.45 or is_panicking:
			host.set_meta(META_MONKEY_STATE, State.WANDERING)
			wander_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))
		elif roll < 0.65 and flip_cooldown <= 0.0:
			host.set_meta(META_MONKEY_STATE, State.ACROBATICS)
			host.set_meta(META_FLIP_COOLDOWN, COOLDOWN_FLIP_SEC)
			if host.has_method("_play_backflip_effect"): host.call("_play_backflip_effect")
			wander_dir = Vector3.ZERO
		else:
			host.set_meta(META_MONKEY_STATE, State.IDLE)
			wander_dir = Vector3.ZERO
			
		host.set_meta(META_WANDER_DIR, wander_dir)
		host.set_meta(META_WANDER_TIMER, wander_timer)
		
	_apply_computed_movement_vectors(host, wander_dir, is_panicking)


func _apply_computed_movement_vectors(host: Object, wander_dir: Vector3, is_panicking: bool) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		var speed := SPEED_PATROL * (2.2 if is_panicking else 1.0)
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_PATROL)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_PATROL)
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_FLIP_COOLDOWN): host.set_meta(META_FLIP_COOLDOWN, 0.0)
	if not host.has_meta(META_TARGET_TREE): host.set_meta(META_TARGET_TREE, Vector3i(0, -999, 0))
	if not host.has_meta(META_CHAT_TIMER): host.set_meta(META_CHAT_TIMER, randf_range(5.0, 15.0))
	if not host.has_meta(META_MONKEY_STATE): host.set_meta(META_MONKEY_STATE, State.IDLE)


func _reset_monkey_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_TARGET_TREE, Vector3i(0, -999, 0))
	host.set_meta(META_WANDER_TIMER, 1.0)
	host.set_meta(META_MONKEY_STATE, State.IDLE)


func _scan_for_nearby_leaves(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-4, 5):
		for y in range(-1, 4): 
			for z in range(-4, 5):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == 5: # 5 = Leaves
					return check_coord
	return Vector3i(0, -999, 0)


func get_active_state_name(host: Object) -> String:
	if not host.has_meta(META_MONKEY_STATE):
		return "IDLE"
	var state_val: int = host.get_meta(META_MONKEY_STATE) as int
	match state_val:
		State.IDLE: return "IDLE"
		State.WANDERING: return "WANDERING"
		State.SCANNING: return "SCANNING_TREES"
		State.CLAMBERING: return "CLAMBERING_BRANCHES"
		State.ACROBATICS: return "BACKFLIP_PLAY"
		_: return "IDLE"

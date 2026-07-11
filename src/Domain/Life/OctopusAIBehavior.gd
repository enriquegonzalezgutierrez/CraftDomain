# ==============================================================================
# Pathfile: res://src/Domain/Life/OctopusAIBehavior.gd
# Description: Specialized AI behavior strategy implementing rhythmic jet-propulsion
#              swimming loops for the Deep-Water Octopus. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name OctopusAIBehavior
extends IAIBehavior

const SPEED_JET: float = 2.8
const SPEED_DRIFT: float = 0.4
const SPEED_PANIC_JET: float = 4.2

const COOLDOWN_INK_SEC: float = 5.0
const JET_CYCLE_DURATION_SEC: float = 2.0

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys
const META_JET_TIMER := "octopus_jet_timer"
const META_WANDER_DIR := "octopus_wander_dir"
const META_INK_COOLDOWN := "octopus_ink_cooldown"
const META_FLEE_TIMER := "octopus_flee_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives pulsing jet propulsion and tactical ink evasion cycles
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	if host.get("is_talking") == true:
		_reset_octopus_state(host)
		return
		
	_initialize_metadata_if_missing(host)
	_update_ink_cooldown(host, delta)
	
	if _process_defensive_ink(host, delta):
		return
		
	_process_propulsion_swim(host, delta)


func _update_ink_cooldown(host: Object, delta: float) -> void:
	var ink_cooldown: float = host.get_meta(META_INK_COOLDOWN) as float
	if ink_cooldown > 0.0:
		ink_cooldown -= delta
		host.set_meta(META_INK_COOLDOWN, ink_cooldown)


func _process_defensive_ink(host: Object, delta: float) -> bool:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return false
	
	var flee_timer: float = host.get_meta(META_FLEE_TIMER) as float
	var is_panicking := ai.get("current_task") as int == TASK_PANIC or flee_timer > 0.0
	
	if not is_panicking:
		return false
		
	if flee_timer <= 0.0:
		flee_timer = 3.5 
		
	flee_timer -= delta
	host.set_meta(META_FLEE_TIMER, flee_timer)
	ai.set("current_task", TASK_PANIC)
	
	_execute_ink_shroud(host)
	_process_panic_escape_pulsion(host, delta)
	return true


func _execute_ink_shroud(host: Object) -> void:
	var ink_cooldown: float = host.get_meta(META_INK_COOLDOWN) as float
	if ink_cooldown <= 0.0:
		host.set_meta(META_INK_COOLDOWN, COOLDOWN_INK_SEC)
		if host.has_method("_play_ink_spray"):
			host.call("_play_ink_spray")


func _process_panic_escape_pulsion(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var jet_timer: float = host.get_meta(META_JET_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	jet_timer -= delta
	if jet_timer <= 0.0 or wander_dir == Vector3.ZERO:
		jet_timer = 0.8 
		var angle := randf() * TAU
		var parent: Node = host.call("get_parent") as Node
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_octopus(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_JET_TIMER, jet_timer)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * SPEED_PANIC_JET
		velocity.z = wander_dir.z * SPEED_PANIC_JET
		velocity.y = randf_range(-0.5, 0.5) 
		host.set("velocity", velocity)
		ai.set("wander_direction", wander_dir)


func _process_propulsion_swim(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_WANDERING)
	
	var jet_timer: float = host.get_meta(META_JET_TIMER) as float
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	
	jet_timer -= delta
	if jet_timer <= 0.0 or wander_dir == Vector3.ZERO:
		jet_timer = JET_CYCLE_DURATION_SEC
		var parent: Node = host.call("get_parent") as Node
		var angle := randf() * TAU
		var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
		wander_dir = candidate_dir if _is_direction_safe_octopus(host, candidate_dir, parent) else Vector3.ZERO
		host.set_meta(META_WANDER_DIR, wander_dir)
		
	host.set_meta(META_JET_TIMER, jet_timer)
	_apply_pulsing_swim_physics(host, ai, wander_dir, jet_timer)


func _apply_pulsing_swim_physics(host: Object, ai: Object, wander_dir: Vector3, jet_timer: float) -> void:
	var velocity: Vector3 = host.get("velocity") as Vector3
	var speed_coef := SPEED_DRIFT
	var time_elapsed := JET_CYCLE_DURATION_SEC - jet_timer
	
	if time_elapsed <= 0.6:
		var t := time_elapsed / 0.6
		speed_coef = lerp(SPEED_JET, SPEED_DRIFT, t)
		
	if wander_dir != Vector3.ZERO:
		velocity.x = wander_dir.x * speed_coef
		velocity.z = wander_dir.z * speed_coef
		velocity.y = sin(float(Time.get_ticks_msec()) / 1000.0 * 1.5) * 0.08
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_DRIFT)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_DRIFT)
		velocity.y = sin(float(Time.get_ticks_msec()) / 1000.0 * 1.0) * 0.04
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_JET_TIMER): host.set_meta(META_JET_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_INK_COOLDOWN): host.set_meta(META_INK_COOLDOWN, 0.0)
	if not host.has_meta(META_FLEE_TIMER): host.set_meta(META_FLEE_TIMER, 0.0)


func _reset_octopus_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		ai.set("current_task", TASK_IDLE)
		ai.set("wander_direction", Vector3.ZERO)
	host.set_meta(META_JET_TIMER, 0.0)
	host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	host.set_meta(META_FLEE_TIMER, 0.0)


func _is_direction_safe_octopus(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 1.5
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	# Allowed block: Water (ID 6)
	return ws.get_block(block_below_coord) == 6 or ws.get_block(block_at_coord) == 6

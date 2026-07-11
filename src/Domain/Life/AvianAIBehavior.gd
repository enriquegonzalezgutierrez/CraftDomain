# ==============================================================================
# Pathfile: res://src/Domain/Life/AvianAIBehavior.gd
# Description: Specialized AI behavior strategy implementing realistic flight loops
#              for Avian Mobs (Birds and Parrots). Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AvianAIBehavior
extends IAIBehavior

const SPEED_SOAR: float = 1.4
const SPEED_GLIDE: float = 1.8
const PERCH_DURATION_SEC: float = 5.0
const RANGE_SENSORY_SQ: float = 225.0 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5
const TASK_WORKING = 6

# Flight State machine: 0 = SOARING, 1 = LANDING_TO_PERCH, 2 = PERCHED
const STATE_SOARING = 0
const STATE_LANDING = 1
const STATE_PERCHED = 2

# Decoupled metadata keys
const META_STATE := "avian_flight_state"
const META_WANDER_TIMER := "avian_wander_timer"
const META_WANDER_DIR := "avian_wander_dir"
const META_TARGET_LEAF := "avian_leaf_target"
const META_REST_TIMER := "avian_rest_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives circular soaring, landing glide, and perched rest
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_evaluate_panic_takeoff(host)
	
	var state: int = host.get_meta(META_STATE) as int
	match state:
		STATE_PERCHED:
			_process_perched_state(host, delta)
		STATE_LANDING:
			_process_landing_state(host, delta)
		STATE_SOARING:
			_process_soaring_state(host, delta)


func _evaluate_panic_takeoff(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai) and ai.get("current_task") as int == TASK_PANIC:
		var state: int = host.get_meta(META_STATE) as int
		if state == STATE_PERCHED:
			host.set_meta(META_STATE, STATE_SOARING)
			host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
			
			var velocity: Vector3 = host.get("velocity") as Vector3
			velocity.y = 4.5 # Takeoff upward thrust
			host.set("velocity", velocity)


func _process_perched_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	ai.set("current_task", TASK_IDLE)
	ai.set("wander_direction", Vector3.ZERO)
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	velocity.x = 0.0
	velocity.z = 0.0
	velocity.y = -0.1 
	host.set("velocity", velocity)
	
	var rest_timer: float = host.get_meta(META_REST_TIMER) as float
	rest_timer -= delta
	if rest_timer <= 0.0:
		host.set_meta(META_STATE, STATE_SOARING)
		host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
		velocity.y = 4.5
		host.set("velocity", velocity)
	else:
		host.set_meta(META_REST_TIMER, rest_timer)


func _process_landing_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	var target_leaf: Vector3i = host.get_meta(META_TARGET_LEAF) as Vector3i
	if not is_instance_valid(ai) or target_leaf.y == -999: return
	
	ai.set("current_task", TASK_WORKING)
	
	var target_pos := Vector3(target_leaf) + Vector3(0.5, 1.1, 0.5)
	var host_pos: Vector3 = host.get("global_position")
	var diff := target_pos - host_pos
	
	var velocity: Vector3 = host.get("velocity") as Vector3
	if diff.length_squared() > 0.64:
		var glide_dir := diff.normalized()
		velocity.x = glide_dir.x * SPEED_GLIDE
		velocity.z = glide_dir.z * SPEED_GLIDE
		velocity.y = move_toward(velocity.y, glide_dir.y * SPEED_GLIDE, delta * 3.0)
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3(glide_dir.x, 0.0, glide_dir.z).normalized())
	else:
		velocity.x = 0.0; velocity.y = 0.0; velocity.z = 0.0
		host.set("velocity", velocity)
		ai.set("wander_direction", Vector3.FORWARD)
		host.set_meta(META_STATE, STATE_PERCHED)
		host.set_meta(META_REST_TIMER, PERCH_DURATION_SEC)


func _process_soaring_state(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)
	
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	if wander_timer <= 0.0:
		_handle_soaring_timer_timeout(host, is_panicking)
		wander_timer = randf_range(3.0, 6.0)
		
	host.set_meta(META_WANDER_TIMER, wander_timer)
	_apply_soaring_flight_physics(host, delta, is_panicking)


func _handle_soaring_timer_timeout(host: Object, is_panicking: bool) -> void:
	var parent: Node = host.call("get_parent") as Node
	var ws: WorldState = parent.get("world_state") as WorldState if is_instance_valid(parent) else null
	if ws != null and not is_panicking and randf() < 0.35:
		var leaves_coord := _scan_for_nest_leaves(host.global_position, ws)
		if leaves_coord.y != -999:
			host.set_meta(META_STATE, STATE_LANDING)
			host.set_meta(META_TARGET_LEAF, leaves_coord)


func _apply_soaring_flight_physics(host: Object, delta: float, is_panicking: bool) -> void:
	var ai: Object = host.get("ai_component")
	var velocity: Vector3 = host.get("velocity") as Vector3
	var host_pos: Vector3 = host.get("global_position")
	var time_sec: float = float(Time.get_ticks_msec()) / 1000.0
	var soar_freq := 0.6 if is_panicking else 0.35
	
	var wander_dir := Vector3(sin(time_sec * soar_freq), 0.0, cos(time_sec * soar_freq)).normalized()
	var vertical_drift: float = ((21.0 if is_panicking else 18.0) - host_pos.y) * 0.12
	
	var speed := SPEED_SOAR * (2.2 if is_panicking else 1.0)
	velocity.x = wander_dir.x * speed
	velocity.z = wander_dir.z * speed
	velocity.y = lerp(velocity.y, vertical_drift + sin(time_sec * 2.5) * 0.15, delta * 4.0)
	
	host.set("velocity", velocity)
	ai.set("wander_direction", wander_dir)


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_STATE): host.set_meta(META_STATE, STATE_SOARING)
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_TARGET_LEAF): host.set_meta(META_TARGET_LEAF, Vector3i(0, -999, 0))
	if not host.has_meta(META_REST_TIMER): host.set_meta(META_REST_TIMER, 0.0)


func _scan_for_nest_leaves(host_pos: Vector3, ws: WorldState) -> Vector3i:
	var my_coord := Vector3i(floori(host_pos.x), floori(host_pos.y), floori(host_pos.z))
	for x in range(-5, 6):
		for y in range(-4, 5):
			for z in range(-5, 6):
				var check_coord := my_coord + Vector3i(x, y, z)
				if ws.get_block(check_coord) == 5: # 5 = Leaves
					if ws.get_block(check_coord + Vector3i(0, 1, 0)) == 0: # 0 = Air
						return check_coord
	return Vector3i(0, -999, 0)

# ==============================================================================
# Pathfile: res://src/Domain/Life/ElephantAIBehavior.gd
# Description: Specialized AI behavior strategy implementing heavy colossal routines
#              for the Colossal Elephant. Decomposed into short methods (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ElephantAIBehavior
extends IAIBehavior

const SPEED_WALK: float = 0.6
const STRIDE_INTERVAL_SEC: float = 1.8
const RANGE_SIGHT_SQ: float = 144.0 

# Decoupled task enums
const TASK_IDLE = 0
const TASK_WANDERING = 1
const TASK_PANIC = 5

# Decoupled metadata keys
const META_WANDER_TIMER := "elephant_wander_timer"
const META_WANDER_DIR := "elephant_wander_dir"
const META_STRIDE_TIMER := "elephant_stride_timer"


func _init() -> void:
	overrides_wandering = true


## Concrete Contract: Drives heavy walk strides, rest, and stomp triggers
func evaluate_and_execute(host: Object, delta: float) -> void:
	if not is_instance_valid(host):
		return
		
	_initialize_metadata_if_missing(host)
	_evaluate_panic_state(host)
	_calculate_next_stroll(host, delta)
	_process_heavy_locomotion(host, delta)


func _evaluate_panic_state(host: Object) -> void:
	var ai: Object = host.get("ai_component")
	if is_instance_valid(ai):
		var is_panicking := ai.get("current_task") as int == TASK_PANIC
		ai.set("current_task", TASK_PANIC if is_panicking else TASK_WANDERING)


func _calculate_next_stroll(host: Object, delta: float) -> void:
	var wander_timer: float = host.get_meta(META_WANDER_TIMER) as float
	wander_timer -= delta
	if wander_timer <= 0.0:
		var parent: Node = host.call("get_parent") as Node
		if randf() < 0.45:
			var angle := randf() * TAU
			var candidate_dir := Vector3(cos(angle), 0.0, sin(angle))
			var is_safe := _is_direction_safe_elephant(host, candidate_dir, parent)
			host.set_meta(META_WANDER_DIR, candidate_dir if is_safe else Vector3.ZERO)
			host.set_meta(META_WANDER_TIMER, randf_range(4.0, 8.0))
		else:
			host.set_meta(META_WANDER_DIR, Vector3.ZERO)
			host.set_meta(META_WANDER_TIMER, randf_range(2.0, 5.0))
	else:
		host.set_meta(META_WANDER_TIMER, wander_timer)


func _process_heavy_locomotion(host: Object, delta: float) -> void:
	var ai: Object = host.get("ai_component")
	if not is_instance_valid(ai): return
	
	var is_panicking := ai.get("current_task") as int == TASK_PANIC
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	var velocity: Vector3 = host.get("velocity") as Vector3
	
	if wander_dir != Vector3.ZERO:
		var speed: float = SPEED_WALK * (1.6 if is_panicking else 1.0)
		velocity.x = wander_dir.x * speed
		velocity.z = wander_dir.z * speed
		_process_stride_timers(host, delta)
		_apply_heavy_rebound(host, delta)
		ai.set("wander_direction", wander_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED_WALK)
		velocity.z = move_toward(velocity.z, 0.0, SPEED_WALK)
		host.set_meta(META_STRIDE_TIMER, 0.4) 
		ai.set("wander_direction", Vector3.ZERO)
		
	host.set("velocity", velocity)


func _process_stride_timers(host: Object, delta: float) -> void:
	var stride_timer: float = host.get_meta(META_STRIDE_TIMER) as float
	stride_timer -= delta
	if stride_timer <= 0.0:
		stride_timer = STRIDE_INTERVAL_SEC
		if host.has_method("_play_heavy_step_impact"):
			host.call("_play_heavy_step_impact")
	host.set_meta(META_STRIDE_TIMER, stride_timer)


func _apply_heavy_rebound(host: Object, _delta: float) -> void:
	var wander_dir: Vector3 = host.get_meta(META_WANDER_DIR) as Vector3
	if host.call("is_on_wall"):
		var wall_normal: Vector3 = host.call("get_wall_normal")
		var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			var bounce_dir := wander_dir.bounce(flat_normal).rotated(Vector3.UP, randf_range(-0.2, 0.2)).normalized()
			host.set_meta(META_WANDER_DIR, bounce_dir)


func _is_direction_safe_elephant(host: Object, dir: Vector3, world_node: Node) -> bool:
	if not is_instance_valid(world_node) or not "world_state" in world_node: return true
	var ws: WorldState = world_node.get("world_state") as WorldState
	if ws == null: return true
	
	var host_pos: Vector3 = host.get("global_position")
	var check_pos := host_pos + dir * 2.5 
	var block_below_coord := Vector3i(floori(check_pos.x), floori(check_pos.y) - 1, floori(check_pos.z))
	var block_at_coord := Vector3i(floori(check_pos.x), floori(check_pos.y + 0.5), floori(check_pos.z))
	
	var block_below := ws.get_block(block_below_coord)
	var block_at := ws.get_block(block_at_coord)
	
	return block_below != 6 and block_at != 6 and block_below != 0


func _initialize_metadata_if_missing(host: Object) -> void:
	if not host.has_meta(META_WANDER_TIMER): host.set_meta(META_WANDER_TIMER, 0.0)
	if not host.has_meta(META_WANDER_DIR): host.set_meta(META_WANDER_DIR, Vector3.ZERO)
	if not host.has_meta(META_STRIDE_TIMER): host.set_meta(META_STRIDE_TIMER, 0.4)

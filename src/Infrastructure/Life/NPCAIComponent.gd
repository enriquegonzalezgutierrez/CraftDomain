# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCAIComponent.gd
# Description: Infrastructure NPC Sensory AI Brain with diagnostic logging.
#              Coordinates GOAP tick routing, steering, and locomotion vectors.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly physics and 
#   sensory loops with diagnostic output tracing.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NPCAIComponent
extends Node

enum TaskState {
	IDLE,       
	WANDERING,  
	EXAMINING,  
	GREETING,   
	CHATTIING,  
	PANIC,      
	WORKING     
}

@export var active_behavior: IAIBehavior

var current_task: TaskState = TaskState.IDLE
var wander_direction: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
var task_timer: float = 0.0
var social_cooldown: float = 0.0

var is_manual_override: bool = false

var SIGHT_RANGE_SQ: float = 64.0
var SOCIAL_RANGE_SQ: float = 9.0
var GREET_DISTANCE_SQ: float = 12.25

var _host: CharacterBody3D
var _ai_timer_accum: float = 0.0
var _ai_tick_rate: float = 0.25 

var _steering_component: NPCObstacleSteering
var _last_pos_for_stuck: Vector3 = Vector3.ZERO
var _log_timer: float = 0.0


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, _ai_tick_rate)
	_setup_steering_component()
	_subscribe_to_world_modifications()
	_log_initial_state()


func _log_initial_state() -> void:
	var h_name: String = "NULL_HOST"
	if is_instance_valid(_host):
		h_name = str(_host.name)
		
	var b_name: String = "NULL_BEHAVIOR"
	if active_behavior != null:
		b_name = active_behavior.get_class()
		
	print("[AI_DIAGNOSTIC] Ready for '%s' | Active Behavior: %s" % [h_name, b_name])


func _setup_steering_component() -> void:
	_steering_component = NPCObstacleSteering.new()
	add_child(_steering_component)
	_steering_component.initialize(_host, self)


func _subscribe_to_world_modifications() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var world_node := parent_node.get_parent()
		if is_instance_valid(world_node) and world_node.has_signal("block_modified"):
			world_node.connect("block_modified", _on_world_block_modified)


func _on_world_block_modified(global_pos: Vector3i, _type: BlockType.Type) -> void:
	if not is_instance_valid(_host):
		return
		
	var h_pos := _host.global_position
	var host_coord := Vector3i(floori(h_pos.x), floori(h_pos.y), floori(h_pos.z))
	
	if host_coord.distance_to(global_pos) < 15:
		_ai_timer_accum = _ai_tick_rate


func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.domain_entity.is_dead: 
		return
		
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	_calculate_base_desired_direction(delta)
	_verify_active_plan_presence()
	_apply_movement_vectors(delta)
	
	if is_instance_valid(_steering_component):
		_steering_component.process_steering(delta)
		
	_process_periodic_diagnostic_logging(delta)


func _process_periodic_diagnostic_logging(delta: float) -> void:
	_log_timer += delta
	if _log_timer >= 1.0:
		_log_timer = 0.0
		_print_ai_diagnostic_snapshot()


func _print_ai_diagnostic_snapshot() -> void:
	if not is_instance_valid(_host): return
	var h_name := str(_host.name)
	var task_str := get_task_state_name(int(current_task))
	var vel := _host.velocity
	var is_on_flr := _host.is_on_floor()
	var b_state: String = "NO_BEHAVIOR"
	if active_behavior != null:
		b_state = active_behavior.get_active_state_name(_host)
	
	print("[AI_DIAGNOSTIC] '%s' | Task: %s | BehaviorState: %s | Manual: %s | Dir: %s | Vel: (%.2f, %.2f, %.2f) | Floor: %s" % [
		h_name, task_str, b_state, str(is_manual_override), str(wander_direction), vel.x, vel.y, vel.z, str(is_on_flr)
	])


func _calculate_base_desired_direction(delta: float) -> void:
	if is_manual_override:
		return
		
	_ai_timer_accum += delta
	if _ai_timer_accum >= _ai_tick_rate:
		_ai_timer_accum = 0.0
		_execute_throttled_ai_tick()


func _execute_throttled_ai_tick() -> void:
	if active_behavior != null:
		active_behavior.evaluate_and_execute(_host, _ai_tick_rate)


func _verify_active_plan_presence() -> void:
	if active_behavior != null and not is_manual_override:
		var active_plan: Variant = active_behavior.get("_active_plan")
		if active_plan is Array and active_plan.is_empty():
			current_task = TaskState.IDLE
			wander_direction = Vector3.ZERO


func _apply_movement_vectors(delta: float) -> void:
	var base_speed: float = 1.3
	if "BASE_SPEED" in _host:
		base_speed = _host.get("BASE_SPEED") as float
		
	var is_trying_to_move := wander_direction.length_squared() > 0.01
	
	if is_trying_to_move and current_task != TaskState.IDLE:
		_execute_linear_walk(base_speed, delta)
	else:
		_host.velocity.x = move_toward(_host.velocity.x, 0.0, base_speed)
		_host.velocity.z = move_toward(_host.velocity.z, 0.0, base_speed)
		stuck_timer = 0.0


func _execute_linear_walk(base_speed: float, delta: float) -> void:
	var final_dir := wander_direction
	var speed_mult: float = 1.0
	if current_task == TaskState.PANIC:
		speed_mult = 2.4
		
	_host.velocity.x = final_dir.x * base_speed * speed_mult
	_host.velocity.z = final_dir.z * base_speed * speed_mult
	
	_evaluate_stuck_state(delta)
	_keep_gaze_within_tether()


func _evaluate_stuck_state(delta: float) -> void:
	var is_trying_to_move := wander_direction.length_squared() > 0.05
	
	if _last_pos_for_stuck == Vector3.ZERO:
		_last_pos_for_stuck = _host.global_position
		
	var dist_moved := _host.global_position.distance_to(_last_pos_for_stuck)
	_last_pos_for_stuck = _host.global_position
	
	if is_trying_to_move and dist_moved < 0.04 and _host.is_on_floor():
		stuck_timer += delta
		if stuck_timer >= 1.0: 
			_resolve_stuck_state()
	else:
		stuck_timer = 0.0


func _resolve_stuck_state() -> void:
	var reverse_dir := -wander_direction.normalized()
	reverse_dir = reverse_dir.rotated(Vector3.UP, randf_range(-0.8, 0.8)).normalized()
	
	wander_direction = reverse_dir
	current_task = TaskState.WANDERING
	stuck_timer = 0.0
	_host.velocity.y = 4.0


func _keep_gaze_within_tether() -> void:
	if _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool:
		var spawn_pt: Vector3 = _host.global_position
		if "_spawn_point" in _host:
			spawn_pt = _host.get("_spawn_point") as Vector3
			
		if _host.global_position.distance_squared_to(spawn_pt) > 144.0: 
			wander_direction = (spawn_pt - _host.global_position).normalized()
			wander_direction.y = 0.0


func get_task_state_name(task_val: int) -> String:
	var names: Array[String] = ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size(): 
		return names[task_val]
	return "IDLE"


func force_manual_task(task_state_id: int) -> void:
	is_manual_override = true
	current_task = task_state_id as TaskState
	
	if current_task == TaskState.WANDERING or current_task == TaskState.PANIC or current_task == TaskState.EXAMINING:
		var angle := randf() * TAU
		wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	else:
		wander_direction = Vector3.ZERO


func disable_manual_override() -> void:
	is_manual_override = false
	current_task = TaskState.IDLE
	wander_direction = Vector3.ZERO
	task_timer = 0.0

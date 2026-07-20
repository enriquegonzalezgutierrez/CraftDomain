# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCAIComponent.gd
# Description: Infrastructure NPC Sensory AI Brain. Coordinates GOAP tick 
#              routing, steering execution, and physical locomotion vectors.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly physics and 
#   sensory loops, ensuring correct sequential execution (GOAP -> Locomotion -> Steering).
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
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


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, _ai_tick_rate)
	_setup_steering_component()
	_subscribe_to_world_modifications()


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
		_ai_timer_accum = _ai_tick_rate # Force immediate AI update on next frame


## Master Loop: Executes correct sequential data pipeline (GOAP -> Locomotion -> Steering)
func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.domain_entity.is_dead: 
		return
		
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	# 1. GOAP calculates high-level intent (sets tasks & base desired vectors)
	_calculate_base_desired_direction(delta)
	
	# 2. Prevent drift of obsolete movement vectors when plan is empty or idle
	_verify_active_plan_presence()
	
	# 3. Locomotion applies base physical velocities to the CharacterBody
	_apply_movement_vectors(delta)
	
	# 4. Steering runs LAST, adjusting and damping velocities safely before move_and_slide()
	if is_instance_valid(_steering_component):
		_steering_component.process_steering(delta)


func _calculate_base_desired_direction(delta: float) -> void:
	if is_manual_override:
		return
		
	_ai_timer_accum += delta
	if _ai_timer_accum >= _ai_tick_rate:
		_ai_timer_accum = 0.0
		_execute_throttled_ai_tick()


func _execute_throttled_ai_tick() -> void:
	if active_behavior != null:
		# Delegate high-level plans and decisions 100% to the GOAP active strategy
		active_behavior.evaluate_and_execute(_host, _ai_tick_rate)


## Shield of Drift: Zeroes out obsolete direction vectors when GOAP plans are inactive
func _verify_active_plan_presence() -> void:
	if active_behavior != null and not is_manual_override:
		# Reflective lookup bypasses vulnerable telemetry strings
		var active_plan: Variant = active_behavior.get("_active_plan")
		if active_plan is Array and active_plan.is_empty():
			current_task = TaskState.IDLE
			wander_direction = Vector3.ZERO


func _apply_movement_vectors(delta: float) -> void:
	var base_speed: float = _host.get("BASE_SPEED") as float if "BASE_SPEED" in _host else 1.3
	
	match current_task:
		# Symmetrical Fix: WORKING (6) grouped with IDLE to stay locked in place during tasks
		TaskState.IDLE, TaskState.GREETING, TaskState.CHATTIING, TaskState.WORKING:
			_host.velocity.x = move_toward(_host.velocity.x, 0.0, base_speed)
			_host.velocity.z = move_toward(_host.velocity.z, 0.0, base_speed)
			stuck_timer = 0.0
		TaskState.EXAMINING:
			_host.velocity.x = wander_direction.x * (base_speed * 0.25)
			_host.velocity.z = wander_direction.z * (base_speed * 0.25)
			stuck_timer = 0.0
		_:
			_execute_linear_walk(base_speed, delta)


func _execute_linear_walk(base_speed: float, delta: float) -> void:
	var final_dir := wander_direction
	var speed_mult: float = 2.4 if current_task == TaskState.PANIC else 1.0
	
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
		var spawn_pt: Vector3 = _host.get("_spawn_point") if "_spawn_point" in _host else _host.global_position
		if _host.global_position.distance_squared_to(spawn_pt) > 144.0: 
			wander_direction = (spawn_pt - _host.global_position).normalized()
			wander_direction.y = 0.0


func _get_task_state_name(task_val: int) -> String:
	var names: Array[String] = ["IDLE", "WANDERING", "EXAMINING", "GREETING", "CHATTING", "PANIC", "WORKING"]
	if task_val >= 0 and task_val < names.size(): return names[task_val]
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

# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/NPCAIComponent.gd
# Description: Infrastructure NPC Sensory AI Brain managing high-performance
#              GOAP tick routing, dynamic AI LODs, and organic motion curves.
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

const STEERING_SCRIPT_PATH: String = "res://src/Infrastructure/Life/NPCObstacleSteering.gd"

const DISTANCE_LOD_0_SQ: float = 256.0 # < 16 meters
const DISTANCE_LOD_1_SQ: float = 1600.0 # < 40 meters

const TICK_LOD_0: float = 0.1
const TICK_LOD_1: float = 0.5
const TICK_LOD_2: float = 2.0

const STUCK_THRESHOLD_SEC: float = 0.55
const MIN_DESIRED_DISPLACEMENT: float = 0.05
const WALL_ALIGNMENT_THRESHOLD: float = 0.25

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
var _steering_component: Node = null
var _last_pos_for_stuck: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "NPCAIComponent"
	_host = get_parent() as CharacterBody3D
	_ai_timer_accum = randf_range(0.0, TICK_LOD_1)
	_setup_steering_component()
	_subscribe_to_world_modifications()


func _setup_steering_component() -> void:
	if ResourceLoader.exists(STEERING_SCRIPT_PATH):
		var steering_script := load(STEERING_SCRIPT_PATH) as GDScript
		if steering_script != null:
			_steering_component = steering_script.new() as Node
			add_child(_steering_component)
			if _steering_component.has_method("initialize"):
				_steering_component.call("initialize", _host, self)


func _subscribe_to_world_modifications() -> void:
	var parent_node := get_parent()
	if is_instance_valid(parent_node) and is_instance_valid(parent_node.get_parent()):
		var world_node := parent_node.get_parent()
		if world_node.has_signal("block_modified"):
			world_node.connect("block_modified", _on_world_block_modified)


func _on_world_block_modified(global_pos: Vector3i, _type: BlockType.Type) -> void:
	if not is_instance_valid(_host):
		return
		
	var h_pos := _host.global_position
	var host_coord := Vector3i(floori(h_pos.x), floori(h_pos.y), floori(h_pos.z))
	if host_coord.distance_to(global_pos) < 15:
		_ai_timer_accum = TICK_LOD_0


func process_ai(delta: float) -> void:
	if not is_instance_valid(_host) or _host.domain_entity.is_dead: 
		return
		
	if is_instance_valid(AITelemetryService.instance):
		AITelemetryService.instance.process_telemetry_flush(delta)
		
	_calculate_base_desired_direction(delta)
	_verify_active_plan_presence()
	_apply_movement_vectors(delta)
	
	if is_instance_valid(_steering_component) and _steering_component.has_method("process_steering"):
		_steering_component.call("process_steering", delta)


func _calculate_base_desired_direction(delta: float) -> void:
	if is_manual_override:
		return
		
	var active_tick_rate := _calculate_dynamic_ai_lod_tick_rate()
	_ai_timer_accum += delta
	
	if _ai_timer_accum >= active_tick_rate:
		_ai_timer_accum = 0.0
		if active_behavior != null:
			active_behavior.evaluate_and_execute(_host, active_tick_rate)


func _calculate_dynamic_ai_lod_tick_rate() -> float:
	if not is_instance_valid(_host): return TICK_LOD_2
	var player_node := _get_player_node_ref()
	if not is_instance_valid(player_node): return TICK_LOD_2
		
	var dist_sq := _host.global_position.distance_squared_to(player_node.global_position)
	if dist_sq <= DISTANCE_LOD_0_SQ: return TICK_LOD_0
	elif dist_sq <= DISTANCE_LOD_1_SQ: return TICK_LOD_1
	return TICK_LOD_2


func _get_player_node_ref() -> CharacterBody3D:
	var parent := _host.get_parent()
	if is_instance_valid(parent):
		return parent.get_node_or_null("Player") as CharacterBody3D
	return null


func _verify_active_plan_presence() -> void:
	if active_behavior != null and not is_manual_override:
		var active_plan: Variant = active_behavior.get("_active_plan")
		if active_plan is Array and active_plan.is_empty():
			if current_task != TaskState.IDLE:
				current_task = TaskState.IDLE


func _apply_movement_vectors(delta: float) -> void:
	var base_speed := _get_host_base_speed()
	var is_trying_to_move := wander_direction.length_squared() > 0.01
	
	if is_trying_to_move and current_task != TaskState.IDLE:
		_execute_linear_walk(base_speed, delta)
	else:
		var friction := base_speed * delta * 8.0
		_host.velocity.x = move_toward(_host.velocity.x, 0.0, friction)
		_host.velocity.z = move_toward(_host.velocity.z, 0.0, friction)
		stuck_timer = 0.0


func _get_host_base_speed() -> float:
	var speed := 1.3
	if "BASE_SPEED" in _host:
		speed = _host.get("BASE_SPEED") as float
		
	if current_task == TaskState.PANIC:
		speed *= 2.4
		
	if active_behavior != null:
		if active_behavior is QuiqueAIBehavior:
			if current_task == TaskState.PANIC:
				return QuiqueAIBehavior.SPEED_PANIC
			return QuiqueAIBehavior.SPEED_STROLL
			
	return speed


func _execute_linear_walk(base_speed: float, delta: float) -> void:
	var final_dir := wander_direction.normalized()
	var target_vel_x := final_dir.x * base_speed
	var target_vel_z := final_dir.z * base_speed
		
	_host.velocity.x = lerp(_host.velocity.x, target_vel_x, delta * 12.0)
	_host.velocity.z = lerp(_host.velocity.z, target_vel_z, delta * 12.0)
	
	_evaluate_stuck_state(delta)
	_keep_gaze_within_tether()


func _evaluate_stuck_state(delta: float) -> void:
	var is_trying_to_move := wander_direction.length_squared() > 0.05
	if _last_pos_for_stuck == Vector3.ZERO:
		_last_pos_for_stuck = _host.global_position
		
	var dist_moved := _host.global_position.distance_to(_last_pos_for_stuck)
	_last_pos_for_stuck = _host.global_position
	
	var is_blocked_by_wall := _is_actively_pushing_into_wall()
	var is_stalled_on_ground := is_trying_to_move and dist_moved < MIN_DESIRED_DISPLACEMENT and _host.is_on_floor()
	
	if is_blocked_by_wall or is_stalled_on_ground:
		stuck_timer += delta
		if stuck_timer >= STUCK_THRESHOLD_SEC:
			_resolve_stuck_state()
	else:
		stuck_timer = 0.0


func _is_actively_pushing_into_wall() -> bool:
	if not _host.is_on_wall() or wander_direction == Vector3.ZERO:
		return false
		
	var wall_normal := _host.get_wall_normal()
	var flat_normal := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	if flat_normal == Vector3.ZERO:
		return false
		
	var dot_prod := wander_direction.normalized().dot(-flat_normal)
	return dot_prod > WALL_ALIGNMENT_THRESHOLD


func _resolve_stuck_state() -> void:
	stuck_timer = 0.0
	var new_dir := Vector3.ZERO
	
	if _host.is_on_wall():
		var normal := _host.get_wall_normal()
		var flat_normal := Vector3(normal.x, 0.0, normal.z).normalized()
		if flat_normal != Vector3.ZERO:
			new_dir = flat_normal.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()
			
	if new_dir == Vector3.ZERO and wander_direction != Vector3.ZERO:
		new_dir = -wander_direction.rotated(Vector3.UP, randf_range(-0.5, 0.5)).normalized()
		
	if new_dir != Vector3.ZERO:
		wander_direction = new_dir
		_sync_direction_to_active_blackboard(new_dir)


func _sync_direction_to_active_blackboard(new_dir: Vector3) -> void:
	var normalized_dir := new_dir.normalized()
	if active_behavior != null:
		var bb: Variant = active_behavior.get("_blackboard")
		if bb != null and bb.has_method("set_memory"):
			bb.call("set_memory", "wander_direction", normalized_dir)
			bb.call("set_memory", "wander_timer", randf_range(3.0, 6.0))


func _keep_gaze_within_tether() -> void:
	if is_instance_valid(_host) and _host.has_method("_has_ui_decorations") and _host.call("_has_ui_decorations") as bool:
		var spawn_pt: Vector3 = _host._spawn_point
		var current_pos_2d := Vector2(_host.global_position.x, _host.global_position.z)
		var spawn_pt_2d := Vector2(spawn_pt.x, spawn_pt.z)
		
		if current_pos_2d.distance_squared_to(spawn_pt_2d) > 144.0: 
			var diff := spawn_pt - _host.global_position
			diff.y = 0.0
			wander_direction = diff.normalized()


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
		wander_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	else:
		wander_direction = Vector3.ZERO


func disable_manual_override() -> void:
	is_manual_override = false
	current_task = TaskState.IDLE
	wander_direction = Vector3.ZERO
	task_timer = 0.0

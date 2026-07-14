# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/AITelemetryService.gd
# Description: Infrastructure service responsible for gathering, buffering, 
#              and writing high-resolution AI movement and pathfinding telemetry 
#              directly to disk.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 12 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AITelemetryService
extends RefCounted

static var instance: AITelemetryService = null

const LOG_PATH := "user://world_save/ai_telemetry_diagnostics.log"
const FLUSH_INTERVAL_SEC: float = 5.0

var _lock: Mutex
var _log_buffer: PackedStringArray = PackedStringArray()
var _time_since_last_flush: float = 0.0


func _init() -> void:
	_lock = Mutex.new()
	instance = self
	_clear_previous_log_file()


static func log_movement(
	entity_name: String, 
	pos: Vector3, 
	vel: Vector3, 
	wander_dir: Vector3, 
	task_name: String, 
	on_wall: bool, 
	on_floor: bool, 
	waypoints_left: int
) -> void:
	if is_instance_valid(instance):
		instance.append_log_line(entity_name, pos, vel, wander_dir, task_name, on_wall, on_floor, waypoints_left)


func append_log_line(
	entity_name: String, 
	pos: Vector3, 
	vel: Vector3, 
	wander_dir: Vector3, 
	task_name: String, 
	on_wall: bool, 
	on_floor: bool, 
	waypoints_left: int
) -> void:
	_lock.lock()
	
	var timestamp: String = Time.get_time_string_from_system()
	var is_stuck: bool = _is_entity_physically_stuck(vel, wander_dir, on_wall)
	var log_line: String = _format_telemetry_line(
		timestamp, entity_name, pos, vel, wander_dir, 
		task_name, on_wall, on_floor, waypoints_left, is_stuck
	)
	
	_log_buffer.append(log_line)
	_lock.unlock()


func _is_entity_physically_stuck(vel: Vector3, wander_dir: Vector3, on_wall: bool) -> bool:
	var horizontal_vel_sq: float = Vector2(vel.x, vel.z).length_squared()
	var horizontal_dir_sq: float = Vector2(wander_dir.x, wander_dir.z).length_squared()
	return on_wall and horizontal_dir_sq > 0.1 and horizontal_vel_sq < 0.05


func _format_telemetry_line(
	timestamp: String, 
	entity_name: String, 
	pos: Vector3, 
	vel: Vector3, 
	wander_dir: Vector3, 
	task_name: String, 
	on_wall: bool, 
	on_floor: bool, 
	waypoints_left: int, 
	is_stuck: bool
) -> String:
	var wall_str: String = "TRUE" if on_wall else "FALSE"
	var floor_str: String = "TRUE" if on_floor else "FALSE"
	var stuck_str: String = " | ⚠️  [STUCK DETECTED]" if is_stuck else ""
	
	return "[%s] [Subject: %s] Pos: (%.2f, %.2f, %.2f) | Vel: (%.2f, %.2f) | Desired: (%.2f, %.2f) | Task: %s | OnWall: %s | OnFloor: %s | WaypointsLeft: %d%s" % [
		timestamp, entity_name, pos.x, pos.y, pos.z, vel.x, vel.z, wander_dir.x, wander_dir.z,
		task_name, wall_str, floor_str, waypoints_left, stuck_str
	]


func process_telemetry_flush(delta: float) -> void:
	_lock.lock()
	_time_since_last_flush += delta
	
	if _time_since_last_flush >= FLUSH_INTERVAL_SEC:
		_time_since_last_flush = 0.0
		_flush_buffer_to_disk_unlocked()
		
	_lock.unlock()


func force_immediate_flush() -> void:
	_lock.lock()
	_flush_buffer_to_disk_unlocked()
	_lock.unlock()


func _flush_buffer_to_disk_unlocked() -> void:
	if _log_buffer.is_empty(): return
		
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for line: String in _log_buffer:
			file.store_line(line)
		file.close()
		_log_buffer.clear()


func _clear_previous_log_file() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)

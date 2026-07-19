# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/AITelemetryService.gd
# Description: Infrastructure service responsible for gathering, buffering, 
#              and writing high-resolution AI movement, environmental blocks, 
#              and goal-planning telemetry to disk.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively diagnostics 
#   formatting and asynchronous thread-safe log flushing.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AITelemetryService
extends RefCounted

static var instance: AITelemetryService = null

# Enable diagnostics logging for environmental inspection
const IS_TELEMETRY_ENABLED: bool = true

const LOG_PATH := "user://world_save/ai_telemetry_diagnostics.log"
const FLUSH_INTERVAL_SEC: float = 2.0

var _lock: Mutex
var _log_buffer: PackedStringArray = PackedStringArray()
var _time_since_last_flush: float = 0.0


func _init() -> void:
	_lock = Mutex.new()
	instance = self
	if IS_TELEMETRY_ENABLED:
		_clear_previous_log_file()


static func log_movement(
	entity_name: String, pos: Vector3, vel: Vector3, wander_dir: Vector3, 
	task_name: String, on_wall: bool, on_floor: bool, blocks_info: String = "", target_info: String = ""
) -> void:
	if not IS_TELEMETRY_ENABLED: return
	if is_instance_valid(instance):
		instance.append_log_line(entity_name, pos, vel, wander_dir, task_name, on_wall, on_floor, blocks_info, target_info)


func append_log_line(
	entity_name: String, pos: Vector3, vel: Vector3, wander_dir: Vector3, 
	task_name: String, on_wall: bool, on_floor: bool, blocks_info: String, target_info: String
) -> void:
	if not IS_TELEMETRY_ENABLED: return
	
	var timestamp := Time.get_time_string_from_system()
	var is_stuck := _is_entity_physically_stuck(vel, wander_dir, on_wall)
	var log_line := _format_telemetry_line(
		timestamp, entity_name, pos, vel, wander_dir, 
		task_name, on_wall, on_floor, blocks_info, target_info, is_stuck
	)
	
	_lock.lock()
	_log_buffer.append(log_line)
	_lock.unlock()


func _is_entity_physically_stuck(vel: Vector3, wander_dir: Vector3, on_wall: bool) -> bool:
	var horizontal_vel_sq := Vector2(vel.x, vel.z).length_squared()
	var horizontal_dir_sq := Vector2(wander_dir.x, wander_dir.z).length_squared()
	return on_wall and horizontal_dir_sq > 0.1 and horizontal_vel_sq < 0.05


func _format_telemetry_line(
	timestamp: String, entity_name: String, pos: Vector3, vel: Vector3, 
	wander_dir: Vector3, task_name: String, on_wall: bool, on_floor: bool, 
	blocks_info: String, target_info: String, is_stuck: bool
) -> String:
	var wall_str := "TRUE" if on_wall else "FALSE"
	var floor_str := "TRUE" if on_floor else "FALSE"
	var stuck_str := " | ⚠️ [STUCK]" if is_stuck else ""
	var env_str := (" | Env: " + blocks_info) if blocks_info != "" else ""
	var tgt_str := (" | Target: " + target_info) if target_info != "" else ""
	
	return "[%s] [%s] Pos:(%.2f,%.2f,%.2f) Vel:(%.2f,%.2f) Desired:(%.2f,%.2f) Task:%s Wall:%s Floor:%s%s%s%s" % [
		timestamp, entity_name, pos.x, pos.y, pos.z, vel.x, vel.z, wander_dir.x, wander_dir.z,
		task_name, wall_str, floor_str, env_str, tgt_str, stuck_str
	]


func process_telemetry_flush(delta: float) -> void:
	if not IS_TELEMETRY_ENABLED: return
	
	_lock.lock()
	_time_since_last_flush += delta
	
	if _time_since_last_flush >= FLUSH_INTERVAL_SEC:
		_time_since_last_flush = 0.0
		_flush_buffer_to_disk_async()
		
	_lock.unlock()


func force_immediate_flush() -> void:
	if not IS_TELEMETRY_ENABLED: return
	_lock.lock()
	_flush_buffer_to_disk_async()
	_lock.unlock()


func _flush_buffer_to_disk_async() -> void:
	if _log_buffer.is_empty(): return
		
	var lines_to_write := _log_buffer.duplicate()
	_log_buffer.clear()
	WorkerThreadPool.add_task(_write_lines_to_disk.bind(lines_to_write))


func _write_lines_to_disk(lines: PackedStringArray) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for line: String in lines:
			file.store_line(line)
		file.close()


func _clear_previous_log_file() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)

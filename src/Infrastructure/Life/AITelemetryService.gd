# ==============================================================================
# Pathfile: res://src/Infrastructure/Life/AITelemetryService.gd
# Description: Infrastructure service responsible for gathering, buffering, 
#              and writing high-resolution AI deep-diagnostics to disk.
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


## OCP-Compliant Deep Diagnostics entry point for the physics pipeline
static func log_deep_diagnostics(host: CharacterBody3D, task: String, dir: Vector3, v_in: Vector3, v_out: Vector3, col: bool, flags: Dictionary) -> void:
	if not IS_TELEMETRY_ENABLED: return
	if is_instance_valid(instance):
		instance._format_and_append_deep(host, task, dir, v_in, v_out, col, flags)


func _format_and_append_deep(host: CharacterBody3D, task: String, dir: Vector3, v_in: Vector3, v_out: Vector3, col: bool, flags: Dictionary) -> void:
	var ts := Time.get_time_string_from_system()
	var p := host.global_position
	
	var line1 := "[%s] [%s] Task:%s | Pos:(%.2f,%.2f,%.2f) | Dir:(%.2f,%.2f)\n" % [ts, host.name, task, p.x, p.y, p.z, dir.x, dir.z]
	var line2 := "    L-> Vel_IN:(%.2f,%.2f,%.2f) -> Vel_OUT:(%.2f,%.2f,%.2f)\n" % [v_in.x, v_in.y, v_in.z, v_out.x, v_out.y, v_out.z]
	var line3 := "    L-> Floor:%s Wall:%s Col:%s | HabBlk:%s Turn:%.2f Edge:%s Yld:%s Wsk:%s\n" % [
		host.is_on_floor(), host.is_on_wall(), col,
		flags.get("hab_blk", false), flags.get("turn_thr", 1.0),
		flags.get("edge_stp", false), flags.get("yield", false), flags.get("whisk", false)
	]
	
	_lock.lock()
	_log_buffer.append(line1 + line2 + line3)
	_lock.unlock()


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

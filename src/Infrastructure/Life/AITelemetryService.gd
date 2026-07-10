# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure / Presentation & UI (Developer Diagnostics)
# Class: AITelemetryService
# Description: Infrastructure service responsible for gathering, buffering, 
#              and writing high-resolution AI movement and pathfinding telemetry 
#              directly to disk.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively thread-safe 
#   RAM buffering and disk file streaming, isolating logging from active AI loops.
# - Open-Closed Principle (OCP): Closed for modifications. Supports logging 
#   arbitrary metadata payloads dynamically.
# - Dependency Inversion Principle (DIP): Pure data coordinator, completely 
#   decoupled from physical Node3D structures.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Life/AITelemetryService.gd
# ==============================================================================
class_name AITelemetryService
extends RefCounted

static var instance: AITelemetryService = null

const LOG_PATH := "user://world_save/ai_telemetry_diagnostics.log"
const FLUSH_INTERVAL_SEC: float = 5.0

# Mutex to ensure thread-safe operations during background thread compiles
var _lock: Mutex

# RAM Buffer holding telemetry lines before flushing to protect SSD health
var _log_buffer: PackedStringArray = PackedStringArray()
var _time_since_last_flush: float = 0.0


func _init() -> void:
	_lock = Mutex.new()
	instance = self
	_clear_previous_log_file()


## Public Service Locator API: Broadcasts telemetry parameters securely to the logger
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


## Appends a formatted timestamped line into the RAM buffer
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
	
	var timestamp := Time.get_time_string_from_system()
	
	# Determine if the entity is physically stuck
	# (desiring to move but horizontal velocity has collapsed to near zero)
	var is_stuck := false
	var horizontal_vel_sq := Vector2(vel.x, vel.z).length_squared()
	var horizontal_dir_sq := Vector2(wander_dir.x, wander_dir.z).length_squared()
	
	if on_wall and horizontal_dir_sq > 0.1 and horizontal_vel_sq < 0.05:
		is_stuck = true
		
	var log_line := "[%s] [Subject: %s] Pos: (%.2f, %.2f, %.2f) | Vel: (%.2f, %.2f) | Desired: (%.2f, %.2f) | Task: %s | OnWall: %s | OnFloor: %s | WaypointsLeft: %d%s" % [
		timestamp,
		entity_name,
		pos.x, pos.y, pos.z,
		vel.x, vel.z,
		wander_dir.x, wander_dir.z,
		task_name,
		"TRUE" if on_wall else "FALSE",
		"TRUE" if on_floor else "FALSE",
		waypoints_left,
		" | ⚠️  [STUCK DETECTED]" if is_stuck else ""
	]
	
	_log_buffer.append(log_line)
	_lock.unlock()


## Periodically flushes RAM buffer into the physical log file
func process_telemetry_flush(delta: float) -> void:
	_lock.lock()
	_time_since_last_flush += delta
	
	if _time_since_last_flush >= FLUSH_INTERVAL_SEC:
		_time_since_last_flush = 0.0
		_flush_buffer_to_disk_unlocked()
		
	_lock.unlock()


## Forces immediate write (Useful during game pause, save, or exits)
func force_immediate_flush() -> void:
	_lock.lock()
	_flush_buffer_to_disk_unlocked()
	_lock.unlock()


func _flush_buffer_to_disk_unlocked() -> void:
	if _log_buffer.is_empty():
		return
		
	# Open file in APPEND mode to write at the end of the file
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file != null:
		file.seek_end()
		for line: String in _log_buffer:
			file.store_line(line)
		file.close()
		_log_buffer.clear()


func _clear_previous_log_file() -> void:
	# Clean up previous session logs on boot to start fresh
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)

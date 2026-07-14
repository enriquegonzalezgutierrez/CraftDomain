# ==============================================================================
# Pathfile: res://src/Domain/World/GlitchRiftService.gd
# Description: Pure Domain Service managing active GlitchRiftVolume instances.
#              Provides thread-safe query APIs to evaluate if coordinate 
#              vectors fall within any registered space-time anomaly.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GlitchRiftService
extends RefCounted

## Static instance provider for global access across layers (Service Locator Pattern)
static var instance: GlitchRiftService = null

## Thread-safe array storing currently active Glitch Rift volumes
var _rifts: Array[GlitchRiftVolume] = []

## Mutex lock protecting concurrent reads/writes during background chunk updates
var _lock: Mutex


func _init() -> void:
	_lock = Mutex.new()
	instance = self


## Thread-safe registration of a new Glitch Rift volume into the active database.
func register_rift(rift: GlitchRiftVolume) -> void:
	if rift == null:
		return
	_lock.lock()
	# Prevent duplicate registrations of the same volume reference
	if not _rifts.has(rift):
		_rifts.append(rift)
	_lock.unlock()


## Unregisters an active Glitch Rift by its unique ID.
func unregister_rift(rift_id: String) -> void:
	if rift_id == "":
		return
	_lock.lock()
	for i in range(_rifts.size() - 1, -1, -1):
		if _rifts[i].rift_id == rift_id:
			_rifts.remove_at(i)
	_lock.unlock()


## Locates and returns the active GlitchRiftVolume containing the target coordinate.
## Returns null if the position lies in safe, uncorrupted territory.
func get_active_rift_at(global_pos: Vector3) -> GlitchRiftVolume:
	var result: GlitchRiftVolume = null
	_lock.lock()
	for rift in _rifts:
		if rift.contains_position(global_pos):
			result = rift
			break
	_lock.unlock()
	return result


## Quick-query API: Returns true if the target position falls within any active rift.
func is_position_corrupted(global_pos: Vector3) -> bool:
	return get_active_rift_at(global_pos) != null


## Fully clears the registered rifts database (called during world unloads).
func clear_all_rifts() -> void:
	_lock.lock()
	_rifts.clear()
	_lock.unlock()

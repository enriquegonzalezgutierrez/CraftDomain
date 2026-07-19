# ==============================================================================
# Pathfile: res://src/Domain/Life/AIBlackboard.gd
# Description: Pure Domain memory container for individual NPCs. Stores 
#              episodic and spatial knowledge (e.g., home bed, workplace, 
#              last known threat) to prevent expensive redundant world scans 
#              and enable GOAP agents to formulate context-aware plans.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Acts exclusively as a typesafe data 
#   repository for a single agent's memory.
# - Strict Typing: Provides explicit type-casting wrappers to prevent GDScript 
#   Variant compiler warnings when accessing memory states.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AIBlackboard
extends RefCounted

## Internal dictionary storing generic key-value memory pairings
var _memories: Dictionary = {}


## Writes or updates a memory value in the agent's blackboard
func set_memory(key: String, value: Variant) -> void:
	_memories[key] = value


## Returns true if the agent remembers the specific key
func has_memory(key: String) -> bool:
	return _memories.has(key)


## Erases a specific memory (e.g., forgetting a threat once it's dead)
func erase_memory(key: String) -> void:
	if _memories.has(key):
		_memories.erase(key)


## Clears all episodic memories completely
func clear_all_memories() -> void:
	_memories.clear()


# ==============================================================================
# TYPESAFE ACCESSOR WRAPPERS (GDScript 2.0 / SOLID Compliance)
# ==============================================================================

func get_vector3(key: String, default_val: Vector3 = Vector3.ZERO) -> Vector3:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_VECTOR3:
			return val as Vector3
	return default_val


func get_vector3i(key: String, default_val: Vector3i = Vector3i.ZERO) -> Vector3i:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_VECTOR3I:
			return val as Vector3i
	return default_val


func get_float(key: String, default_val: float = 0.0) -> float:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
			return float(val)
	return default_val


func get_int(key: String, default_val: int = 0) -> int:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
			return int(val)
	return default_val


func get_bool(key: String, default_val: bool = false) -> bool:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_BOOL:
			return val as bool
	return default_val


func get_object(key: String) -> Object:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val as Object):
			return val as Object
	return null

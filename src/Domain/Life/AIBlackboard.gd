# ==============================================================================
# Pathfile: res://src/Domain/Life/AIBlackboard.gd
# Description: Pure Domain memory container for individual NPCs. Stores 
#              episodic and spatial knowledge (e.g., home bed, workplace).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Acts exclusively as a typesafe data 
#   repository for a single agent's memory.
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


## Erases a specific memory
func erase_memory(key: String) -> void:
	if _memories.has(key):
		_memories.erase(key)


## Clears all episodic memories completely
func clear_all_memories() -> void:
	_memories.clear()


## Generic Getter: Returns a memory as a Variant.
## Used for complex types like Arrays or Dictionaries.
func get_memory(key: String, default_val: Variant = null) -> Variant:
	return _memories.get(key, default_val)


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


## Dynamic Object Unpacker: Defensively checks pointer validity
func get_object(key: String) -> Object:
	if _memories.has(key):
		var val: Variant = _memories[key]
		if typeof(val) == TYPE_OBJECT and is_instance_valid(val):
			return val
	return null

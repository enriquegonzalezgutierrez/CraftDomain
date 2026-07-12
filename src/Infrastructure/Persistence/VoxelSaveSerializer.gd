# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/VoxelSaveSerializer.gd
# Description: Infrastructure Serialization Helper responsible for data formatting.
#              Packs and unpacks coordinate vectors, arrays, and quest states (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelSaveSerializer
extends RefCounted


## Compiles raw block modification deltas into a string-keyed JSON-compatible dictionary
static func serialize_chunk_deltas(modifications: Dictionary) -> Dictionary:
	var serialized: Dictionary = {}
	for local_pos: Vector3i in modifications.keys():
		var str_key := "%d,%d,%d" % [local_pos.x, local_pos.y, local_pos.z]
		serialized[str_key] = modifications[local_pos]
	return serialized


## Unpacks a string-keyed JSON dictionary back into coordinate Vector3i keys
static func deserialize_chunk_deltas(serialized_data: Dictionary) -> Dictionary:
	var modifications: Dictionary = {}
	for str_key: String in serialized_data.keys():
		var parts: PackedStringArray = str_key.split(",")
		if parts.size() == 3:
			var local_pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
			modifications[local_pos] = int(serialized_data[str_key])
	return modifications


## Packs the player's 3D vector variables and world state parameters into a structured dictionary
static func serialize_global_state(player_pos: Vector3, player_rot: Vector3, seed_val: int, inventory_quantities: Array, active_quest_id: String, celestial_time: float, calendar_day: int) -> Dictionary:
	return {
		"player_pos": {
			"x": player_pos.x,
			"y": player_pos.y,
			"z": player_pos.z
		},
		"player_rot": {
			"x": player_rot.x,
			"y": player_rot.y,
			"z": player_rot.z
		},
		"seed": seed_val,
		"inventory": inventory_quantities,
		"active_quest_id": active_quest_id,
		"celestial_time": celestial_time,
		"calendar_day": calendar_day
	}


## Unpacks and safely parses raw JSON dictionary variants back into typed states
static func deserialize_global_state(data: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	if data.is_empty():
		return state
		
	state["seed"] = int(data.get("seed", 42))
	state["player_pos"] = _unpack_player_position(data)
	state["player_rot"] = _unpack_player_rotation(data)
	state["inventory"] = data.get("inventory", []) as Array
	state["active_quest_id"] = str(data.get("active_quest_id", ""))
	state["celestial_time"] = float(data.get("celestial_time", 0.5))
	state["calendar_day"] = int(data.get("calendar_day", 14))
	
	return state


static func _unpack_player_position(data: Dictionary) -> Vector3:
	if data.has("player_pos") and data["player_pos"] is Dictionary:
		var p_pos := data["player_pos"] as Dictionary
		return Vector3(
			float(p_pos.get("x", 8.5)), 
			float(p_pos.get("y", 14.0)), 
			float(p_pos.get("z", 8.5))
		)
	return Vector3(8.5, 14.0, 8.5)


static func _unpack_player_rotation(data: Dictionary) -> Vector3:
	if data.has("player_rot") and data["player_rot"] is Dictionary:
		var p_rot := data["player_rot"] as Dictionary
		return Vector3(
			float(p_rot.get("x", 0.0)), 
			float(p_rot.get("y", 0.0)), 
			float(p_rot.get("z", 0.0))
		)
	return Vector3.ZERO

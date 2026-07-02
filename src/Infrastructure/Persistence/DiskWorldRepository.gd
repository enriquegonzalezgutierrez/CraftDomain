# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Repository concrete implementation handling file I/O,
#              JSON serialization, and delta chunk saving to Godot's user directory.
#              SOLID COMPLIANCE:
#              - Liskov Substitution Principle (LSP): Fully implements WorldRepository.
#              UPDATED: Added persistence for celestial cycle coordinates and 
#              calendar days to accurately save moon phases and day/night state.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Persistence/DiskWorldRepository.gd
# ==============================================================================
class_name DiskWorldRepository
extends WorldRepository

const SAVE_DIR := "user://world_save/"
const CHUNKS_DIR := "user://world_save/chunks/"
const GLOBAL_SAVE_PATH := "user://world_save/global_save.json"


func _init() -> void:
	_ensure_directories_exist()


func _ensure_directories_exist() -> void:
	if not DirAccess.dir_exists_absolute(CHUNKS_DIR):
		DirAccess.make_dir_recursive_absolute(CHUNKS_DIR)


## Concrete Implementation: Saves modifications for a specific chunk.
## Modifications is a Dictionary mapping: Vector3i (local block position) -> BlockType.Type
func save_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	var path := _get_chunk_file_path(chunk_pos)
	
	# If there are no modifications to save, delete the save file if it exists
	if modifications.size() == 0:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	# Convert Vector3i dictionary keys to JSON-compatible strings "x,y,z"
	var json_data: Dictionary = {}
	for local_pos: Vector3i in modifications.keys():
		var str_key := "%d,%d,%d" % [local_pos.x, local_pos.y, local_pos.z]
		json_data[str_key] = modifications[local_pos]

	# Serialize and write to disk
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		var json_string := JSON.stringify(json_data)
		file.store_string(json_string)
		file.close()


## Concrete Implementation: Loads and returns saved modifications for a specific chunk.
## Returns an empty dictionary if no modifications exist.
func load_chunk_modifications(chunk_pos: Vector3i) -> Dictionary:
	var path := _get_chunk_file_path(chunk_pos)
	var modifications: Dictionary = {}
	
	if not FileAccess.file_exists(path):
		return modifications
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		# Parse JSON
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data: Dictionary = json.data as Dictionary
			for str_key: String in json_data.keys():
				var parts: PackedStringArray = str_key.split(",")
				if parts.size() == 3:
					var local_pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
					modifications[local_pos] = int(json_data[str_key])
					
	return modifications


## Concrete Implementation: Saves global metadata alongside player inventory, quest state, and time.
func save_global_state(
	player_pos: Vector3, 
	player_rot: Vector3, 
	seed_val: int, 
	inventory_quantities: Array = [], 
	active_quest_id: String = "",
	celestial_time: float = 0.5,
	calendar_day: int = 1
) -> void:
	var json_data := {
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
	
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(json_data))
		file.close()
		print("[DiskWorldRepository] Global state, inventory, quests & time of day saved successfully.")


## Concrete Implementation: Loads global metadata.
## Returns a dictionary containing 'player_pos', 'player_rot', 'seed', 'inventory', 
## 'active_quest_id', 'celestial_time', and 'calendar_day'.
func load_global_state() -> Dictionary:
	var state: Dictionary = {}
	if not FileAccess.file_exists(GLOBAL_SAVE_PATH):
		return state
		
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data: Dictionary = json.data as Dictionary
			
			state["seed"] = int(json_data["seed"])
			
			var p_pos: Dictionary = json_data["player_pos"] as Dictionary
			state["player_pos"] = Vector3(float(p_pos["x"]), float(p_pos["y"]), float(p_pos["z"]))
			
			var p_rot: Dictionary = json_data["player_rot"] as Dictionary
			state["player_rot"] = Vector3(float(p_rot["x"]), float(p_rot["y"]), float(p_rot["z"]))
			
			if json_data.has("inventory"):
				state["inventory"] = json_data["inventory"] as Array
			else:
				state["inventory"] = []
				
			if json_data.has("active_quest_id"):
				state["active_quest_id"] = str(json_data["active_quest_id"])
				
			# Load time of day parameters (Fallback to high noon if old save file)
			if json_data.has("celestial_time"):
				state["celestial_time"] = float(json_data["celestial_time"])
			else:
				state["celestial_time"] = 0.5
				
			if json_data.has("calendar_day"):
				state["calendar_day"] = int(json_data["calendar_day"])
			else:
				state["calendar_day"] = 14 # Default Full Moon
				
	return state


func _get_chunk_file_path(chunk_pos: Vector3i) -> String:
	return CHUNKS_DIR + "chunk_%d_%d_%d.json" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]

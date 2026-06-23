# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Repository concrete implementation handling file I/O,
#              JSON serialization, and delta chunk saving to Godot's user directory.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Persistence/DiskWorldRepository.gd
# ==============================================================================
class_name DiskWorldRepository
extends WorldRepository

const SAVE_DIR := "user://world_save/"
const CHUNKS_DIR := "user://world_save/chunks/"
const GLOBAL_SAVE_PATH := "user://world_save/global_save.json"

func _init() -> void:
	# Guarantee the directories exist on disk upon initialization
	_ensure_directories_exist()

func _ensure_directories_exist() -> void:
	if not DirAccess.dir_exists_absolute(CHUNKS_DIR):
		DirAccess.make_dir_recursive_absolute(CHUNKS_DIR)

## Concrete Implementation: Saves modifications for a specific chunk.
func save_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	var path := _get_chunk_file_path(chunk_pos)
	
	# If there are no modifications to save, delete the save file if it exists
	if modifications.size() == 0:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	# Convert Vector3i dictionary keys to JSON-compatible strings "x,y,z"
	var json_data: Dictionary = {}
	for local_pos in modifications.keys():
		var pos: Vector3i = local_pos
		var str_key := "%d,%d,%d" % [pos.x, pos.y, pos.z]
		json_data[str_key] = modifications[local_pos]

	# Serialize and write to disk
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		var json_string := JSON.stringify(json_data)
		file.store_string(json_string)
		file.close()

## Concrete Implementation: Loads and returns saved modifications for a specific chunk.
func load_chunk_modifications(chunk_pos: Vector3i) -> Dictionary:
	var path := _get_chunk_file_path(chunk_pos)
	var modifications: Dictionary = {}
	
	if not FileAccess.file_exists(path):
		return modifications # Return empty dictionary if no file exists
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		# Parse JSON
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data: Dictionary = json.data
			# Parse string keys "x,y,z" back to Vector3i structures
			for str_key in json_data.keys():
				# Statically declared PackedStringArray to ensure perfect type-safety
				var parts: PackedStringArray = str_key.split(",")
				if parts.size() == 3:
					var local_pos := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
					modifications[local_pos] = int(json_data[str_key])
					
	return modifications

## Concrete Implementation: Saves global metadata.
func save_global_state(player_pos: Vector3, player_rot: Vector3, seed_val: int) -> void:
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
		"seed": seed_val
	}
	
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(json_data))
		file.close()
		print("[DiskWorldRepository] Global game state saved successfully.")

## Concrete Implementation: Loads global metadata.
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
			var json_data: Dictionary = json.data
			
			state["seed"] = int(json_data["seed"])
			
			var p_pos: Dictionary = json_data["player_pos"]
			state["player_pos"] = Vector3(float(p_pos["x"]), float(p_pos["y"]), float(p_pos["z"]))
			
			var p_rot: Dictionary = json_data["player_rot"]
			state["player_rot"] = Vector3(float(p_rot["x"]), float(p_rot["y"]), float(p_rot["z"]))
			
	return state

func _get_chunk_file_path(chunk_pos: Vector3i) -> String:
	return CHUNKS_DIR + "chunk_%d_%d_%d.json" % [chunk_pos.x, chunk_pos.z, chunk_pos.z] # Modified Y coordinate mapping

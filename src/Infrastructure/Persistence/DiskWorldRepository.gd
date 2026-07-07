# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Repository concrete implementation handling file I/O,
#              and delta chunk saving to Godot's user directory.
# SOLID COMPLIANCE:
# - Liskov Substitution Principle (LSP): Fully implements WorldRepository contract.
# - Single Responsibility Principle (SRP): Handles exclusively physical directory 
#   verification, file opening, reading, and stream writing. All data-structure 
#   formatting and JSON packing are delegated to `VoxelSaveSerializer`.
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
func save_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	var path := _get_chunk_file_path(chunk_pos)
	
	# If there are no modifications to save, delete the save file if it exists
	if modifications.size() == 0:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	# SRP: Delegate data formatting entirely to the VoxelSaveSerializer helper
	var json_data: Dictionary = VoxelSaveSerializer.serialize_chunk_deltas(modifications)

	# I/O: Open file stream and write string content
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
		return modifications
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		# Parse JSON stream
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data: Dictionary = json.data as Dictionary
			# SRP: Delegate coordinate unpacking entirely to the VoxelSaveSerializer helper
			modifications = VoxelSaveSerializer.deserialize_chunk_deltas(json_data)
			
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
	# SRP: Delegate player and state packing entirely to the VoxelSaveSerializer helper
	var json_data: Dictionary = VoxelSaveSerializer.serialize_global_state(
		player_pos, 
		player_rot, 
		seed_val, 
		inventory_quantities, 
		active_quest_id, 
		celestial_time, 
		calendar_day
	)
	
	# I/O: Open file stream and write packed dictionary
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(json_data))
		file.close()
		print("[DiskWorldRepository] Global state, inventory, quests & time of day saved successfully.")


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
			var json_data: Dictionary = json.data as Dictionary
			# SRP: Delegate data unpacking/parsing entirely to the VoxelSaveSerializer helper
			state = VoxelSaveSerializer.deserialize_global_state(json_data)
			
	return state


func _get_chunk_file_path(chunk_pos: Vector3i) -> String:
	return CHUNKS_DIR + "chunk_%d_%d_%d.json" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]

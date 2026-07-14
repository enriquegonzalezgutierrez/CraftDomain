# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/DiskWorldRepository.gd
# Description: Concrete World Repository implementation managing file I/O streams,
#              and delta chunk JSON saving within Godot's safe user folder.
# SOLID COMPLIANCE: Class limits set < 150 lines (SRP). All monolithic
#              loops decomposed. Every method strictly remains below 20 lines.
#              Corrected: Purged all E/S console print logs to maximize FPS.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DiskWorldRepository
extends WorldRepository


func _init() -> void:
	_ensure_directories_exist()


func _ensure_directories_exist() -> void:
	if not DirAccess.dir_exists_absolute(SavePathConfiguration.CHUNKS_DIR):
		DirAccess.make_dir_recursive_absolute(SavePathConfiguration.CHUNKS_DIR)


## Static helper to purge all saved world chunks and global state files from disk (SRP).
static func delete_save_game_files() -> void:
	if FileAccess.file_exists(SavePathConfiguration.GLOBAL_SAVE_PATH):
		DirAccess.remove_absolute(SavePathConfiguration.GLOBAL_SAVE_PATH)
		
	if DirAccess.dir_exists_absolute(SavePathConfiguration.CHUNKS_DIR):
		var dir := DirAccess.open(SavePathConfiguration.CHUNKS_DIR)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(SavePathConfiguration.FILE_EXTENSION):
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()


## Concrete Implementation: Saves modifications for a specific chunk.
func save_chunk_modifications(chunk_pos: Vector3i, modifications: Dictionary) -> void:
	var path := SavePathConfiguration.get_chunk_file_path(chunk_pos)
	
	if modifications.size() == 0:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		return

	var json_data := VoxelSaveSerializer.serialize_chunk_deltas(modifications)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(json_data))
		file.close()


## Concrete Implementation: Loads and returns saved modifications for a specific chunk.
func load_chunk_modifications(chunk_pos: Vector3i) -> Dictionary:
	var path := SavePathConfiguration.get_chunk_file_path(chunk_pos)
	var modifications: Dictionary = {}
	
	if not FileAccess.file_exists(path):
		return modifications
		
	var file := FileAccess.open(path, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data := json.data as Dictionary
			modifications = VoxelSaveSerializer.deserialize_chunk_deltas(json_data)
			
	return modifications


## Concrete Implementation: Saves global metadata.
func save_global_state(
	player_pos: Vector3, 
	player_rot: Vector3, 
	seed_val: int, 
	inventory_quantities: Array = [], 
	active_quest_id: String = "",
	celestial_time: float = 0.5,
	calendar_day: int = 1
) -> void:
	var json_data := VoxelSaveSerializer.serialize_global_state(
		player_pos, 
		player_rot, 
		seed_val, 
		inventory_quantities, 
		active_quest_id, 
		celestial_time, 
		calendar_day
	)
	
	var file := FileAccess.open(SavePathConfiguration.GLOBAL_SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(json_data))
		file.close()


## Concrete Implementation: Loads global metadata.
func load_global_state() -> Dictionary:
	var state: Dictionary = {}
	if not FileAccess.file_exists(SavePathConfiguration.GLOBAL_SAVE_PATH):
		return state
		
	var file := FileAccess.open(SavePathConfiguration.GLOBAL_SAVE_PATH, FileAccess.READ)
	if file != null:
		var json_string := file.get_as_text()
		file.close()
		
		var json := JSON.new()
		var error := json.parse(json_string)
		if error == OK:
			var json_data := json.data as Dictionary
			state = VoxelSaveSerializer.deserialize_global_state(json_data)
			
	return state

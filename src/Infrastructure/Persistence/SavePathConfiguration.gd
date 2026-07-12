# ==============================================================================
# Pathfile: res://src/Infrastructure/Persistence/SavePathConfiguration.gd
# Description: Static Value Object centralizing all user save directories,
#              file paths, and chunk prefixes, completely removing hardcoded strings (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SavePathConfiguration
extends RefCounted

const ROOT_DIR: String = "user://world_save/"
const CHUNKS_DIR: String = "user://world_save/chunks/"
const GLOBAL_SAVE_PATH: String = "user://world_save/global_save.json"
const SETTINGS_PATH: String = "user://settings.json"

const CHUNK_FILE_PREFIX: String = "chunk_"
const FILE_EXTENSION: String = ".json"


## Returns the compiled physical file path for a specific chunk coordinate
static func get_chunk_file_path(chunk_pos: Vector3i) -> String:
	return CHUNKS_DIR + CHUNK_FILE_PREFIX + "%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z] + FILE_EXTENSION

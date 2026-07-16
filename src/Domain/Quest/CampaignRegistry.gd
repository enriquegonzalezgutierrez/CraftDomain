# ==============================================================================
# Pathfile: res://src/Domain/Quest/CampaignRegistry.gd
# Description: Domain Registry/Loader responsible for parsing and instantiating 
#              quests from external JSON data.
# SOLID COMPLIANCE: Adheres strictly to the Open-Closed Principle (OCP).
# STRICT MODE FIX: Implemented safe type parsing for JSON variants.
# WARNING FIX:
# - Added explicit static typing `Dictionary` to the `item` loop iterator 
#   on line 70 to completely resolve `UNTYPED_DECLARATION` compiler warnings.
# - Method Size Limits (Rule 4.2): All compiled methods kept strictly < 20 lines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Quest/CampaignRegistry.gd
# ==============================================================================
class_name CampaignRegistry
extends RefCounted

const QUEST_DIR := "res://assets/quests/"


## Scans the directory and loads all present JSON quest files (OCP compliant)
static func initialize_campaign() -> void:
	_scan_and_load_all_quest_files()


## Scans the quest directory and parses every single .json file present (OCP)
static func _scan_and_load_all_quest_files() -> void:
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_error("[CampaignRegistry] Error: Could not access quest directory: " + QUEST_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := QUEST_DIR + file_name
			_load_quests_from_file(full_path)
		file_name = dir.get_next()
		
	dir.list_dir_end()
	
	# Automatically activate the starter quest to begin the campaign
	if QuestService.get_quest("lost_bazaar") != null:
		# Only activate if the player hasn't already loaded an active quest from their save file
		if QuestService.get_active_quest() == null:
			QuestService.set_active_quest("lost_bazaar")


## Parses a specific JSON file and registers its instantiated Quests
static func _load_quests_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[CampaignRegistry] Error: Could not read quest file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) != OK:
		return
		
	var quest_array := json.data as Array
	if quest_array == null:
		return
	
	for item: Dictionary in quest_array:
		_parse_and_register_quest(item)


static func _parse_and_register_quest(q_data: Dictionary) -> void:
	var q := Quest.new()
	q.quest_id = str(q_data.get("quest_id", ""))
	q.title = str(q_data.get("title", ""))
	q.description = str(q_data.get("description", ""))
	q.objective_text = str(q_data.get("objective_text", ""))
	
	if q_data.has("target_position"):
		q.target_position = _parse_quest_target_position(q_data["target_position"] as Dictionary)
		
	q.target_range = float(q_data.get("target_range", 8.0))
	q.autocomplete_on_arrival = bool(q_data.get("autocomplete_on_arrival", false))
	q.next_quest_id = str(q_data.get("next_quest_id", ""))
	q.reward_item_index = int(q_data.get("reward_item_index", -1))
	q.reward_quantity = int(q_data.get("reward_quantity", 0))
	q.required_item_index = int(q_data.get("required_item_index", -1))
	q.required_quantity = int(q_data.get("required_quantity", 0))
	
	QuestService.register_quest(q)


static func _parse_quest_target_position(pos_dict: Dictionary) -> Vector3:
	return Vector3(
		float(pos_dict.get("x", 0.0)), 
		float(pos_dict.get("y", 0.0)), 
		float(pos_dict.get("z", 0.0))
	)

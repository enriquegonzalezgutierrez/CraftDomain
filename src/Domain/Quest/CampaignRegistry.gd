# ==============================================================================
# Pathfile: res://src/Domain/Quest/CampaignRegistry.gd
# Description: Pure Domain Registry parsing campaign quests from JSON files
#              and registering their objective state machines into QuestService.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CampaignRegistry
extends RefCounted

const QUEST_DIR := "res://assets/quests/"


## Scans the quest directory and activates starter campaign state.
static func initialize_campaign() -> void:
	_scan_and_load_all_quest_files()
	_activate_starter_quest_if_needed()


static func _scan_and_load_all_quest_files() -> void:
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_error("[CampaignRegistry] Error: Could not access quest directory: " + QUEST_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_quests_from_file(QUEST_DIR + file_name)
		file_name = dir.get_next()
		
	dir.list_dir_end()


static func _activate_starter_quest_if_needed() -> void:
	if QuestService.get_quest("lost_bazaar") != null and QuestService.get_active_quest() == null:
		QuestService.set_active_quest("lost_bazaar")


static func _load_quests_from_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[CampaignRegistry] Error: Could not read quest file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) == OK and json.data is Array:
		for item: Dictionary in (json.data as Array):
			_parse_and_register_quest(item)


static func _parse_and_register_quest(q_data: Dictionary) -> void:
	var q := Quest.new()
	q.quest_id = str(q_data.get("quest_id", ""))
	q.title = str(q_data.get("title", ""))
	q.description = str(q_data.get("description", ""))
	q.objective_text = str(q_data.get("objective_text", ""))
	
	if q_data.has("target_position"):
		q.target_position = _parse_quest_target_position(q_data["target_position"] as Dictionary)
		
	_populate_quest_metadata(q, q_data)
	QuestService.register_quest(q)


static func _populate_quest_metadata(q: Quest, q_data: Dictionary) -> void:
	q.target_range = float(q_data.get("target_range", 8.0))
	q.autocomplete_on_arrival = bool(q_data.get("autocomplete_on_arrival", false))
	q.next_quest_id = str(q_data.get("next_quest_id", ""))
	q.reward_item_index = int(q_data.get("reward_item_index", -1))
	q.reward_quantity = int(q_data.get("reward_quantity", 0))
	q.required_item_index = int(q_data.get("required_item_index", -1))
	q.required_quantity = int(q_data.get("required_quantity", 0))


static func _parse_quest_target_position(pos_dict: Dictionary) -> Vector3:
	return Vector3(
		float(pos_dict.get("x", 0.0)), 
		float(pos_dict.get("y", 0.0)), 
		float(pos_dict.get("z", 0.0))
	)
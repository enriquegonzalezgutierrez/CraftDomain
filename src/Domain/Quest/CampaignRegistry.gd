# ==============================================================================
# Project: CraftDomain
# Description: Domain Registry/Loader responsible for parsing and instantiating 
#              quests from external JSON data.
#              SOLID COMPLIANCE: Adheres strictly to the Open-Closed Principle (OCP)
#              and Single Responsibility Principle (SRP). All template generators
#              and hardcoded dictionaries have been completely removed from the
#              GDScript code.
#              STRICT MODE UPDATE: Implemented safe type casting (`as Type`) for
#              all parsed JSON Variants to completely eliminate UNSAFE_CALL_ARGUMENT warnings.
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
	print("[CampaignRegistry] Scanning directory for quest files: ", QUEST_DIR)
	
	var dir := DirAccess.open(QUEST_DIR)
	if dir == null:
		push_error("[CampaignRegistry] Error: Could not access quest directory: " + QUEST_DIR)
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var loaded_files_count := 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path := QUEST_DIR + file_name
			_load_quests_from_file(full_path)
			loaded_files_count += 1
		file_name = dir.get_next()
		
	dir.list_dir_end()
	print("[CampaignRegistry] Dynamic scan finished. Total quest files loaded: ", loaded_files_count)
	
	# Automatically activate the starter quest to begin the campaign
	if QuestService.get_quest("lost_bazaar") != null:
		QuestService.set_active_quest("lost_bazaar")

## Parses a specific JSON file and registers its instantiated Quests
static func _load_quests_from_file(file_path: String) -> void:
	print("  -> Loading quest pack: ", file_path)
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[CampaignRegistry] Error: Could not read quest file: " + file_path)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[CampaignRegistry] Error parsing JSON " + file_path + ". Line: " + str(json.get_error_line()) + " | Error: " + json.get_error_message())
		return
		
	# STRICT MODE FIX: Safely cast the root Variant to an Array
	var quest_array := json.data as Array
	
	for item in quest_array:
		# STRICT MODE FIX: Safely cast the iterated Variant to a Dictionary
		var q_data := item as Dictionary
		var q := Quest.new()
		
		# STRICT MODE FIX: Use `as Type` instead of constructors to avoid UNSAFE_CALL_ARGUMENT
		q.quest_id = q_data["quest_id"] as String
		q.title = q_data["title"] as String
		q.description = q_data["description"] as String
		q.objective_text = q_data["objective_text"] as String
		
		# Parse 3D coordinates target safely
		var pos_dict := q_data["target_position"] as Dictionary
		q.target_position = Vector3(
			pos_dict["x"] as float, 
			pos_dict["y"] as float, 
			pos_dict["z"] as float
		)
		q.target_range = q_data["target_range"] as float
		
		q.autocomplete_on_arrival = q_data["autocomplete_on_arrival"] as bool
		q.next_quest_id = q_data["next_quest_id"] as String
		
		q.reward_item_index = q_data["reward_item_index"] as int
		q.reward_quantity = q_data["reward_quantity"] as int
		
		# Optional requirements mapped safely
		if q_data.has("required_item_index"):
			q.required_item_index = q_data["required_item_index"] as int
		if q_data.has("required_quantity"):
			q.required_quantity = q_data["required_quantity"] as int
			
		# Register in the Domain Database
		QuestService.register_quest(q)

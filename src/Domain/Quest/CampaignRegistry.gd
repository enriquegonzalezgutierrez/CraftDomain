# ==============================================================================
# Project: CraftDomain
# Description: Domain Registry/Loader responsible for parsing and instantiating 
#              quests from external JSON data.
#              SOLID COMPLIANCE: Strictly satisfies the Open-Closed Principle (OCP)
#              and Single Responsibility Principle (SRP). All hardcoded campaign 
#              dictionaries have been completely removed from the GDScript codebase.
#              The system relies strictly on the external "campaign.json" asset.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Quest/CampaignRegistry.gd
# ==============================================================================
class_name CampaignRegistry
extends RefCounted

const CAMPAIGN_FILE := "res://assets/quests/campaign.json"

## Initializes the campaign by loading the external JSON configuration (OCP compliant)
static func initialize_campaign() -> void:
	_load_campaign_from_json()

## Parses the JSON file and registers the instantiated Quests into the QuestService
static func _load_campaign_from_json() -> void:
	print("[CampaignRegistry] Loading campaign dynamically from external JSON: ", CAMPAIGN_FILE)
	
	var file := FileAccess.open(CAMPAIGN_FILE, FileAccess.READ)
	if file == null:
		push_error("[CampaignRegistry] Error: Critical asset 'campaign.json' is missing from " + CAMPAIGN_FILE)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_error("[CampaignRegistry] Error parsing JSON. Line: %d | Error: %s" % [json.get_error_line(), json.get_error_message()])
		return
		
	# Instantiates Quests polymorphically from the parsed JSON array
	var quest_array: Array = json.data
	for q_data in quest_array:
		var q := Quest.new()
		q.quest_id = str(q_data["quest_id"])
		q.title = str(q_data["title"])
		q.description = str(q_data["description"])
		q.objective_text = str(q_data["objective_text"])
		
		# Parse 3D coordinates target
		var pos_dict: Dictionary = q_data["target_position"]
		q.target_position = Vector3(float(pos_dict["x"]), float(pos_dict["y"]), float(pos_dict["z"]))
		q.target_range = float(q_data["target_range"])
		
		q.autocomplete_on_arrival = bool(q_data["autocomplete_on_arrival"])
		q.next_quest_id = str(q_data["next_quest_id"])
		
		q.reward_item_index = int(q_data["reward_item_index"])
		q.reward_quantity = int(q_data["reward_quantity"])
		
		# Register in the Domain Database
		QuestService.register_quest(q)
		
	# Automatically activate the first registered quest to begin the narrative Campaign
	if quest_array.size() > 0:
		var first_quest_id: String = str(quest_array[0]["quest_id"])
		QuestService.set_active_quest(first_quest_id)
		print("[CampaignRegistry] Campaign loaded successfully. Starting quest: ", first_quest_id)

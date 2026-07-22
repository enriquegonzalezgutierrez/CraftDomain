# ==============================================================================
# Pathfile: res://src/Domain/Dialogue/DialogueRegistry.gd
# Description: Pure Domain Registry managing conversation nodes and parsing
#              interactive dialogue trees dynamically from JSON database assets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueRegistry
extends RefCounted

const DIALOGUES_FILE_PATH := "res://assets/dialogues/dialogues.json"

static var _nodes: Dictionary = {}


## Parses and registers the standard dialogue database on startup.
static func initialize_dialogue_database() -> void:
	_nodes.clear()
	_load_dialogues_from_json()


## Registers a custom DialogueNode dynamically at runtime.
static func register_dialogue_node(node: DialogueNode) -> void:
	if node != null and node.node_id != "":
		_nodes[node.node_id] = node
		DialogueService.register_node(node)


## Retrieves a registered dialogue node by its ID.
static func get_dialogue_node(node_id: String) -> DialogueNode:
	if _nodes.has(node_id):
		return _nodes[node_id] as DialogueNode
	return null


static func _load_dialogues_from_json() -> void:
	if not FileAccess.file_exists(DIALOGUES_FILE_PATH):
		push_error("[DialogueRegistry ERROR] Dialogues configuration file missing.")
		return
		
	var file := FileAccess.open(DIALOGUES_FILE_PATH, FileAccess.READ)
	if file == null:
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	if json.parse(json_string) == OK and json.data is Array:
		for node_any: Variant in (json.data as Array):
			if node_any is Dictionary:
				_parse_and_register_node(node_any as Dictionary)


static func _parse_and_register_node(node_data: Dictionary) -> void:
	var node := DialogueNode.new()
	node.node_id = node_data.get("node_id", "") as String
	node.text = node_data.get("text", "") as String
	
	var choices_list: Array = []
	if node_data.has("choices") and node_data["choices"] is Array:
		for choice_any: Variant in (node_data["choices"] as Array):
			if choice_any is Dictionary:
				choices_list.append(_parse_dialogue_choice(choice_any as Dictionary))
				
	node.choices = choices_list
	register_dialogue_node(node)


static func _parse_dialogue_choice(choice_data: Dictionary) -> DialogueChoice:
	var choice := DialogueChoice.new()
	choice.option_text = choice_data.get("option_text", "") as String
	choice.target_node_id = choice_data.get("target_node_id", "") as String
	choice.required_quest_id = choice_data.get("required_quest_id", "") as String
	choice.reward_recipe_id = choice_data.get("reward_recipe_id", "") as String
	return choice
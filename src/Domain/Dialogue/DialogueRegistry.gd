# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Dialogue System)
# Class: DialogueRegistry
# Description: Pure Domain Registry responsible for managing conversation nodes, 
#              routing options, and compiling dynamic interactive dialogue trees.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates dialogue compilation and 
#   declarative node linking away from visual and text rendering overlays.
# - Open-Closed Principle (OCP): Decoupled from hardcoded source code lines. 
#   Conversations are loaded dynamically from an external JSON file.
# - Dependency Inversion Principle (DIP): Resolves dialogue nodes polimorphically 
#   by storing references to abstract domain resources ('DialogueNode', 'DialogueChoice'), 
#   decoupling data structures from frame-bound user interfaces.
# ==============================================================================
class_name DialogueRegistry
extends RefCounted

const DIALOGUES_FILE_PATH := "res://assets/dialogues/dialogues.json"

## Static map holding registered conversation nodes: String (node_id) -> DialogueNode
static var _nodes: Dictionary = {}


## Startup Initializer: Parses and registers the standard 
## dialogue trees from the external JSON database.
static func initialize_dialogue_database() -> void:
	print("[DialogueRegistry] Compiling dialogue database from external JSON asset...")
	_nodes.clear()
	
	_load_dialogues_from_json()


## Public OCP Extension API: Registers a custom DialogueNode dynamically.
## Can be called from data-loaders, story expansions, or mods at runtime.
static func register_dialogue_node(node: DialogueNode) -> void:
	if node != null and node.node_id != "":
		_nodes[node.node_id] = node
		
		# Synchronize the node cleanly with DialogueService (DIP Adapter sync)
		DialogueService.register_node(node)


## Public Reader API: Queries and retrieves a registered dialogue node by its ID.
static func get_dialogue_node(node_id: String) -> DialogueNode:
	if _nodes.has(node_id):
		return _nodes[node_id] as DialogueNode
	return null


## Internal Parser: Reads the JSON definition file and builds the concrete resources.
static func _load_dialogues_from_json() -> void:
	if not FileAccess.file_exists(DIALOGUES_FILE_PATH):
		push_error("[DialogueRegistry ERROR] Dialogues configuration file missing at: " + DIALOGUES_FILE_PATH)
		return
		
	var file := FileAccess.open(DIALOGUES_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("[DialogueRegistry ERROR] Failed to open dialogues file: " + DIALOGUES_FILE_PATH)
		return
		
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error_code := json.parse(json_string)
	if error_code != OK:
		push_error("[DialogueRegistry ERROR] JSON parsing failed. Line: %d | Error: %s" % [json.get_error_line(), json.get_error_message()])
		return
		
	var raw_data: Variant = json.data
	if not (raw_data is Array):
		push_error("[DialogueRegistry ERROR] Root JSON element is not a valid Array.")
		return
		
	var nodes_array := raw_data as Array
	
	for node_any: Variant in nodes_array:
		if not (node_any is Dictionary):
			continue
		var node_data := node_any as Dictionary
		
		var node := DialogueNode.new()
		node.node_id = node_data.get("node_id", "") as String
		node.text = node_data.get("text", "") as String
		
		var choices_list: Array = []
		
		if node_data.has("choices") and node_data["choices"] is Array:
			var choices_array := node_data["choices"] as Array
			for choice_any: Variant in choices_array:
				if not (choice_any is Dictionary):
					continue
				var choice_data := choice_any as Dictionary
				
				var choice := DialogueChoice.new()
				choice.option_text = choice_data.get("option_text", "") as String
				choice.target_node_id = choice_data.get("target_node_id", "") as String
				choice.required_quest_id = choice_data.get("required_quest_id", "") as String
				choice.reward_recipe_id = choice_data.get("reward_recipe_id", "") as String
				
				choices_list.append(choice)
				
		node.choices = choices_list
		register_dialogue_node(node)
		
	print("[DialogueRegistry] Successfully loaded %d dialogue nodes from JSON." % _nodes.size())

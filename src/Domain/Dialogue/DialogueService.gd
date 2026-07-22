# ==============================================================================
# Pathfile: res://src/Domain/Dialogue/DialogueService.gd
# Description: Pure Domain Service acting as a runtime router for active 
#              dialogue nodes across conversations.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueService
extends RefCounted

static var _nodes: Dictionary = {}


## Registers a dialogue node in the runtime domain cache.
static func register_node(node: Resource) -> void:
	if node != null:
		var node_id := str(node.get("node_id"))
		if node_id != "":
			_nodes[node_id] = node


## Retrieves a registered dialogue node by its unique ID.
static func get_dialogue_node(node_id: String) -> Resource:
	if _nodes.has(node_id):
		return _nodes[node_id] as Resource
	return null
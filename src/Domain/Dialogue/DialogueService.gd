# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service acting as a Registry and Router for dialogue nodes.
#              SOLID COMPLIANCE: Stripped of hardcoded database builders (SRP) 
#              to remain strictly closed to modifications (OCP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Dialogue/DialogueService.gd
# ==============================================================================
class_name DialogueService
extends RefCounted

## Dynamic registry mapping node IDs to their DialogueNode instances
static var _nodes: Dictionary = {}

## Registers a node in the domain dialogue database
static func register_node(node: Resource) -> void:
	if node != null:
		var n_id: String = str(node.get("node_id"))
		if n_id != "":
			_nodes[n_id] = node

## Retrieves a dialogue node by its ID
static func get_dialogue_node(node_id: String) -> Resource:
	if _nodes.has(node_id):
		return _nodes[node_id] as Resource
	return null

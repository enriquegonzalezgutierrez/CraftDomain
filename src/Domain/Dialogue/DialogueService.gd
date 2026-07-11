# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Dialogue System / Services)
# Class: DialogueService
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Service acting as a Registry and Router for dialogue nodes.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Acts exclusively as a runtime 
#   dialogue node router.
# - Open-Closed Principle (OCP): Stripped of hardcoded database builders, remaining
#   strictly closed to modifications.
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

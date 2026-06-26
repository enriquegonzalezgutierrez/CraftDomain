# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service acting as a Registry and Router for dialogue nodes.
#              FIXED: Utilizes base Resource types inside public signatures to bypass
#              the Godot 4 compile-time race conditions and circular parser locks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Dialogue/DialogueService.gd
# ==============================================================================
class_name DialogueService
extends RefCounted

## Dynamic registry mapping node IDs to their DialogueNode instances
static var _nodes: Dictionary = {}

static func _static_init() -> void:
	_build_merchant_dialogue_tree()

## Registers a node in the domain dialogue database
## FIXED: Input is cast to base Resource to prevent compilation race-conditions
static func register_node(node: Resource) -> void:
	if node != null:
		var n_id: String = str(node.get("node_id"))
		if n_id != "":
			_nodes[n_id] = node

## Retrieves a dialogue node by its ID
## FIXED: Returns base Resource to bypass compiler class registration lag
static func get_dialogue_node(node_id: String) -> Resource:
	if _nodes.has(node_id):
		return _nodes[node_id] as Resource
	return null

## Generates the standard branching dialogue tree for the Merchant on startup
static func _build_merchant_dialogue_tree() -> void:
	# 1. Main Introduction Node
	var intro := DialogueNode.new()
	intro.node_id = "merchant_intro"
	intro.text = "Hmmm! Welcome to my Golden Bazaar stall, traveler. Are you here to trade some hot lava, or just looking around?"
	
	var c1 := DialogueChoice.new()
	c1.option_text = "I want to trade a Lava Bucket for Fried Chicken!"
	c1.target_node_id = "merchant_trade_info"
	
	var c2 := DialogueChoice.new()
	c2.option_text = "Tell me, who are you?"
	c2.target_node_id = "merchant_about"
	
	var c3 := DialogueChoice.new()
	c3.option_text = "Just looking around, thank you. (Close)"
	c3.target_node_id = "" # Empty target means close conversation
	
	intro.choices = [c1, c2, c3]
	register_node(intro)
	
	# 2. About/Lore Node
	var about := DialogueNode.new()
	about.node_id = "merchant_about"
	about.text = "I am the Master Merchant of these plains. I gather geothermal lava to fry our legendary chickens! It keeps them hot, crispy, and highly therapeutic."
	
	var a1 := DialogueChoice.new()
	a1.option_text = "Fascinating! Let's talk about trades."
	a1.target_node_id = "merchant_intro"
	
	about.choices = [a1]
	register_node(about)
	
	# 3. Trade Information Node
	var trade_info := DialogueNode.new()
	trade_info.node_id = "merchant_trade_info"
	trade_info.text = "Ah, excellent! My lava-chicken fryers are hungry for fuel. One Bucket of Lava (Slot 6) gets you one famous Fried Chicken!"
	
	var t1 := DialogueChoice.new()
	t1.option_text = "[EXECUTE TRADE] Hand over 1x Lava Bucket"
	t1.target_node_id = "merchant_trade_execute"
	
	var t2 := DialogueChoice.new()
	t2.option_text = "Actually, let's talk about something else."
	t2.target_node_id = "merchant_intro"
	
	trade_info.choices = [t1, t2]
	register_node(trade_info)
	
	# 4. Trade Execution Outcome Node
	var trade_exec := DialogueNode.new()
	trade_exec.node_id = "merchant_trade_execute"
	trade_exec.text = "Trade outcome depends on your bucket count..." # Handled dynamically by the controller
	
	var e1 := DialogueChoice.new()
	e1.option_text = "Back to introduction"
	e1.target_node_id = "merchant_intro"
	
	trade_exec.choices = [e1]
	register_node(trade_exec)

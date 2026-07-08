# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Dialogue System)
# Class: DialogueRegistry
# Description: Pure Domain Registry responsible for managing conversation nodes, 
#              routing options, and compiling dynamic interactive dialogue trees.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Isolates dialogue compilation and 
#   declarative node linking away from visual and text rendering overlays.
# - Open-Closed Principle (OCP): Completely open to extension. Baseline story loops 
#   are populated automatically, but developers can register and link infinite 
#   new dialog lines and branching trees dynamically via public APIs, 
#   completely closing existing logic to manual source modifications.
# - Dependency Inversion Principle (DIP): Resolves dialogue nodes polimorphically 
#   by storing references to abstract domain resources ('DialogueNode', 'DialogueChoice'), 
#   decoupling data structures from frame-bound user interfaces.
# ==============================================================================
class_name DialogueRegistry
extends RefCounted

## Static map holding registered conversation nodes: String (node_id) -> DialogueNode
static var _nodes: Dictionary = {}


## Startup Initializer: Instantiates, compiles, and registers the standard 
## dialogue trees of the game world on boot.
static func initialize_dialogue_database() -> void:
	print("[DialogueRegistry] Compiling baseline conversational dialogue database...")
	_nodes.clear()
	
	# Compile and register default Bazaar Merchant story flow
	_build_merchant_dialogue_tree()


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


# ==============================================================================
# INTERNAL COMBAT & STORY TREES ASSEMBLY (SRP Compliant)
# ==============================================================================

## Symmetrical compilation of the branching Merchant dialogue tree (Bazaar Act I)
static func _build_merchant_dialogue_tree() -> void:
	# --------------------------------------------------------------------------
	# NODE 1: MAIN ENTRANCE
	# --------------------------------------------------------------------------
	var intro := DialogueNode.new()
	intro.node_id = "merchant_intro"
	intro.text = "DIALOGUE_MERCHANT_INTRO" # Localized key
	
	var c1 := DialogueChoice.new()
	c1.option_text = "DIALOGUE_MERCHANT_CHOICE_TRADE"
	c1.target_node_id = "merchant_trade_info"
	
	var c2 := DialogueChoice.new()
	c2.option_text = "DIALOGUE_MERCHANT_CHOICE_WHO"
	c2.target_node_id = "merchant_about"
	
	var c3 := DialogueChoice.new()
	c3.option_text = "DIALOGUE_MERCHANT_CHOICE_CLOSE"
	c3.target_node_id = "" # Closes interface
	
	intro.choices = [c1, c2, c3]
	register_dialogue_node(intro)
	
	# --------------------------------------------------------------------------
	# NODE 2: LORE INFORMATION
	# --------------------------------------------------------------------------
	var about := DialogueNode.new()
	about.node_id = "merchant_about"
	about.text = "DIALOGUE_MERCHANT_ABOUT"
	
	var a1 := DialogueChoice.new()
	a1.option_text = "DIALOGUE_MERCHANT_CHOICE_BACK"
	a1.target_node_id = "merchant_intro"
	
	about.choices = [a1]
	register_dialogue_node(about)
	
	# --------------------------------------------------------------------------
	# NODE 3: TRADE DESCRIPTION AND DETAILS
	# --------------------------------------------------------------------------
	var trade_info := DialogueNode.new()
	trade_info.node_id = "merchant_trade_info"
	trade_info.text = "DIALOGUE_MERCHANT_TRADE_INFO"
	
	var t1 := DialogueChoice.new()
	t1.option_text = "DIALOGUE_MERCHANT_CHOICE_EXECUTE"
	t1.target_node_id = "merchant_trade_execute"
	
	var t2 := DialogueChoice.new()
	t2.option_text = "DIALOGUE_MERCHANT_CHOICE_BACK"
	t2.target_node_id = "merchant_intro"
	
	trade_info.choices = [t1, t2]
	register_dialogue_node(trade_info)
	
	# --------------------------------------------------------------------------
	# NODE 4: TRADE RUNTIME EXECUTION (State evaluation resolved by controller)
	# --------------------------------------------------------------------------
	var trade_exec := DialogueNode.new()
	trade_exec.node_id = "merchant_trade_execute"
	trade_exec.text = "DIALOGUE_MERCHANT_TRADE_FAILED" # Default failure callback
	
	var e1 := DialogueChoice.new()
	e1.option_text = "DIALOGUE_MERCHANT_CHOICE_BACK"
	e1.target_node_id = "merchant_intro"
	
	trade_exec.choices = [e1]
	register_dialogue_node(trade_exec)

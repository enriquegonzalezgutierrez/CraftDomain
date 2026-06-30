# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Registry responsible for defining and storing all NPC 
#              dialogue trees (Villager, Merchant, Guard, Farmer).
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates dialogue definitions 
#                from rendering layers.
#              - Open-Closed Principle (OCP) & i18n: Exclusively registers 
#                translation keys instead of raw English text to ensure complete 
#                multi-language localization.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Dialogue/DialogueRegistry.gd
# ==============================================================================
class_name DialogueRegistry
extends RefCounted

## Constructs and registers all standard NPC dialogue trees dynamically on startup
static func initialize_dialogue_database() -> void:
	print("[DialogueRegistry] Constructing and registering all NPC dialogue trees...")
	_build_merchant_dialogue_tree()


## Generates the standard branching dialogue tree for the Merchant using translation keys.
static func _build_merchant_dialogue_tree() -> void:
	# 1. Main Introduction Node
	var intro := DialogueNode.new()
	intro.node_id = "merchant_intro"
	intro.text = "DIALOGUE_MERCHANT_INTRO"
	
	var c1 := DialogueChoice.new()
	c1.option_text = "DIALOGUE_MERCHANT_CHOICE_TRADE"
	c1.target_node_id = "merchant_trade_info"
	
	var c2 := DialogueChoice.new()
	c2.option_text = "DIALOGUE_MERCHANT_CHOICE_WHO"
	c2.target_node_id = "merchant_about"
	
	var c3 := DialogueChoice.new()
	c3.option_text = "DIALOGUE_MERCHANT_CHOICE_CLOSE"
	c3.target_node_id = "" 
	
	intro.choices = [c1, c2, c3]
	DialogueService.register_node(intro)
	
	# 2. About/Lore Node
	var about := DialogueNode.new()
	about.node_id = "merchant_about"
	about.text = "DIALOGUE_MERCHANT_ABOUT"
	
	var a1 := DialogueChoice.new()
	a1.option_text = "DIALOGUE_MERCHANT_CHOICE_BACK"
	a1.target_node_id = "merchant_intro"
	
	about.choices = [a1]
	DialogueService.register_node(about)
	
	# 3. Trade Information Node
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
	DialogueService.register_node(trade_info)
	
	# 4. Trade Execution Outcome Node (Text overridden dynamically in DialogueManager.gd)
	var trade_exec := DialogueNode.new()
	trade_exec.node_id = "merchant_trade_execute"
	trade_exec.text = "DIALOGUE_MERCHANT_TRADE_FAILED" 
	
	var e1 := DialogueChoice.new()
	e1.option_text = "DIALOGUE_MERCHANT_CHOICE_BACK"
	e1.target_node_id = "merchant_intro"
	
	trade_exec.choices = [e1]
	DialogueService.register_node(trade_exec)

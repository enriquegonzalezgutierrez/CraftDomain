# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Service acting as the orchestrator for dialogues.
#              SRP COMPLIANCE: Responsible ONLY for opening/closing dialogue panels.
#              STRICT MODE UPDATE: Connected signals natively to eliminate UNSAFE_CAST.
#              TRADE FIX: Replaced broken, slot-based TradingService calls with 
#              robust ID-based safe inventory transactions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Dialogue/DialogueManager.gd
# ==============================================================================
class_name DialogueManager
extends Node

## Injected reference to the player controller
var player: CharacterBody3D

# STRICT MODE FIX: Typed overlay node
var active_dialogue: DialogueOverlay
var _active_speaker_name: String = ""

## Public API: Instantiates the Dialogue Overlay panel and freezes player movement
func open_dialogue(node: Resource, speaker_name: String) -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		
	_active_speaker_name = speaker_name
	
	# STRICT MODE FIX: Direct class instantiation
	active_dialogue = DialogueOverlay.new()
	add_child(active_dialogue)
	
	# Connect signals using the native Godot 4 approach
	active_dialogue.choice_selected.connect(_on_dialogue_choice_selected)
	active_dialogue.dialogue_closed.connect(close_dialogue)
	
	active_dialogue.load_dialogue_node(node, speaker_name)
	
	# Lock standard player physics inputs and show mouse cursor
	if is_instance_valid(player):
		player.set("is_active", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## Router evaluating choices and processing in-dialogue trade transactions
func _on_dialogue_choice_selected(target_node_id: String) -> void:
	# --- TRANSACTION TRIGGER: Trade execution evaluated securely inside the Dialogue Loop ---
	if target_node_id == "merchant_trade_execute" and is_instance_valid(player):
		var inventory = player.get("inventory") as IInventory
		if is_instance_valid(inventory):
			# ID-BASED SAFE TRANSACTION: Consumes 1x Lava Bucket (ID 15), grants 1x Fried Chicken (ID 16)
			if inventory.get_item_total_quantity(15) >= 1 and inventory.can_receive_item(16, 1):
				inventory.consume_item(15, 1)
				inventory.add_item(16, 1)
				
				# Make the merchant hop in the air with physical joy!
				var raycast = player.get("raycast")
				if is_instance_valid(raycast) and raycast.is_colliding():
					var merchant = raycast.get_collider()
					if is_instance_valid(merchant) and merchant.has_method("take_damage"): 
						merchant.velocity.y = 5.0 # Hop!
						
				# --- MISSION 4 TRIGGER: Complete Fuel the Fryer ---
				var active_q := QuestService.get_active_quest()
				if active_q != null and active_q.quest_id == "fuel_fryer":
					QuestService.complete_active_quest(player)
					
					var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
					if exec_node != null:
						exec_node.set("text", "Oh! Dynamic lava! Delicious! Here is your Fried Chicken! And as a special reward for completing my quest, here are 3x EXTRA Fried Chickens!\n\nOh no, wait! Look at the radar! The Guard is calling for help near the tower, a zombie is approaching the llanuras!")
				else:
					var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
					if exec_node != null:
						exec_node.set("text", "Hmmm! Hot, geothermal, delicious lava! Thank you! Here is your crispy Fried Chicken! It is fresh, delicious, and highly therapeutic.")
						
				player.call("_sync_hud_counters")
			else:
				var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
				if exec_node != null:
					exec_node.set("text", "Hmmm? It seems you are completely out of Lava Buckets! Bring me a Bucket of Lava (Slot 6) and I will fry up a fresh Chicken!")

	# Navigate to the next Dialogue Node, or close if a leaf node is reached
	var next_node: Resource = DialogueService.get_dialogue_node(target_node_id)
	if is_instance_valid(next_node) and is_instance_valid(active_dialogue):
		active_dialogue.load_dialogue_node(next_node, _active_speaker_name)
	else:
		close_dialogue()

## Closes the overlay and restores normal first-person player controls
func close_dialogue() -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		active_dialogue = null
		
	# Restore standard movement parameters and capture mouse cursor
	if is_instance_valid(player):
		player.set("is_active", true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

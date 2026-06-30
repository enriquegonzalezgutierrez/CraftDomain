# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Coordinator managing the lifecycle of the dialogue 
#              interface, blocking/unblocking player input, and routing selections.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only coordinates the UI 
#                lifecycle, delegating inventory transaction rules to the pure 
#                domain service (TradingService).
#              - Open-Closed Principle (OCP) & i18n: Exclusively uses translation 
#                keys to prevent hardcoded string leakage in codebase.
#              - Dependency Inversion Principle (DIP): Connects directly with 
#                IInventory abstractions.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Dialogue/DialogueManager.gd
# ==============================================================================
class_name DialogueManager
extends Node

## Injected reference to the active player controller.
var player: CharacterBody3D

## Statically typed reference to the active dialogue overlay.
var active_dialogue: DialogueOverlay

# The name of the speaker currently interacting with the player.
var _active_speaker_name: String = ""

# Define concrete transaction IDs (ID 15: Lava Bucket, ID 16: Fried Chicken)
const LAVA_BUCKET_ID := 15
const FRIED_CHICKEN_ID := 16


## Instantiates the Dialogue Overlay panel, freezes player movement, and 
## displays the target dialogue tree node.
func open_dialogue(node: Resource, speaker_name: String) -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		
	_active_speaker_name = speaker_name
	
	# Instantiate presentation overlay
	active_dialogue = DialogueOverlay.new()
	add_child(active_dialogue)
	
	# Connect signal emitters to internal receivers
	active_dialogue.choice_selected.connect(_on_dialogue_choice_selected)
	active_dialogue.dialogue_closed.connect(close_dialogue)
	
	active_dialogue.load_dialogue_node(node, speaker_name)
	
	# Lock standard player physics inputs and release captured hardware mouse
	if is_instance_valid(player):
		player.set("is_active", false)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Closes the active dialogue overlay and restores normal first-person controls.
func close_dialogue() -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		active_dialogue = null
		
	# Restore standard movement parameters and re-capture mouse pointer
	if is_instance_valid(player):
		player.set("is_active", true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Evaluates branching choices, handles contextual transaction triggers, 
## and routes navigation to the next target node.
func _on_dialogue_choice_selected(target_node_id: String) -> void:
	if target_node_id == "merchant_trade_execute" and is_instance_valid(player):
		_process_merchant_trade_transaction()

	# Route to the next Dialogue Node, or close the overlay if a leaf is reached
	var next_node: Resource = DialogueService.get_dialogue_node(target_node_id)
	if is_instance_valid(next_node) and is_instance_valid(active_dialogue):
		active_dialogue.load_dialogue_node(next_node, _active_speaker_name)
	else:
		close_dialogue()


## Handles the trade transaction by delegating transaction rules to the domain.
func _process_merchant_trade_transaction() -> void:
	var inventory := player.get("inventory") as IInventory
	if not is_instance_valid(inventory):
		return
		
	# SRP COMPLIANCE: Delegate validation and mutation to the Domain Service
	var trade_success := TradingService.execute_id_trade(
		inventory, 
		LAVA_BUCKET_ID, 1, 
		FRIED_CHICKEN_ID, 1
	)
	
	if trade_success:
		_on_trade_success(inventory)
	else:
		_on_trade_failed()


## Handles success visual feedback, quest triggers, and state synchronization.
## FIXED: Prefixed the unused inventory variable with an underscore to prevent compiler warnings.
func _on_trade_success(_inventory: IInventory) -> void:
	# Visual physical bounce feedback on the NPC if available
	var raycast = player.get("raycast")
	if is_instance_valid(raycast) and raycast.is_colliding():
		var merchant = raycast.get_collider()
		if is_instance_valid(merchant) and merchant.has_method("take_damage"):
			merchant.velocity.y = 5.0 # Make the merchant hop with physical joy!
			
	# Update active quest progression if applicable
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "fuel_fryer":
		QuestService.complete_active_quest(player)
		
		# Set localized translation key for quest completion
		var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
		if exec_node != null:
			exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_QUEST_COMPLETE")
	else:
		# Set localized translation key for successful trade
		var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
		if exec_node != null:
			exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_SUCCESS")
			
	# Sync player quickbar and HUD counters
	player.call("_sync_hud_counters")


## Handles failure responses using localized translation keys.
func _on_trade_failed() -> void:
	var exec_node: Resource = DialogueService.get_dialogue_node("merchant_trade_execute")
	if exec_node != null:
		exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_FAILED")

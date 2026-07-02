# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Coordinator managing the lifecycle of the dialogue 
#              interface, blocking/unblocking player input, and routing selections.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Only coordinates the UI 
#                lifecycle and speaker state locks, delegating inventory 
#                transaction rules to the pure domain service (TradingService).
#              - Dependency Inversion Principle (DIP): Connects directly with 
#                IInventory abstractions without direct coupling.
#              - OBSERVER PATTERN: Removed manual HUD synchronizations. UI updates 
#                are now driven reactively by the domain.
#              WARNING FIX:
#              - Replaced dynamic Variant queries (`raycast`, `merchant`, `inventory`, `hud`) 
#                with strictly cast static typed variables to completely resolve 
#                `UNTYPED_DECLARATION` compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Dialogue/DialogueManager.gd
# ==============================================================================
class_name DialogueManager
extends Node

## Emitted when the active dialogue sequence has fully ended.
signal dialogue_closed

## Injected reference to the active player controller.
var player: CharacterBody3D

## Statically typed reference to the active dialogue overlay.
var active_dialogue: DialogueOverlay

# The name of the speaker currently interacting with the player.
var _active_speaker_name: String = ""

# Symmetrically tracked 3D node of the active speaker NPC
var _active_speaker_node: CharacterBody3D = null

# Define concrete transaction IDs (ID 15: Lava Bucket, ID 16: Fried Chicken)
const LAVA_BUCKET_ID := 15
const FRIED_CHICKEN_ID := 16


## Instantiates the Dialogue Overlay panel, freezes player movement, and 
## locks the NPC's pathfinding and gaze onto the player.
func open_dialogue(node: Resource, speaker_name: String, speaker_node: CharacterBody3D = null) -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		
	_active_speaker_name = speaker_name
	
	# If a concrete speaker node is passed, trigger conversation freeze & lock
	if is_instance_valid(speaker_node):
		_active_speaker_node = speaker_node
		if _active_speaker_node.has_method("start_talking") and is_instance_valid(player):
			_active_speaker_node.call("start_talking", player)
	
	# Instantiate presentation overlay
	active_dialogue = DialogueOverlay.new()
	add_child(active_dialogue)
	
	# Connect signal emitters to internal receivers
	active_dialogue.choice_selected.connect(_on_dialogue_choice_selected)
	active_dialogue.dialogue_closed.connect(close_dialogue)
	
	# Populate dialogue nodes with localized translation strings
	active_dialogue.load_dialogue_node(node, speaker_name)
	
	# Open dialog reveals the mouse pointer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Closes the active dialogue overlay and restores player capture controls safely.
func close_dialogue() -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		active_dialogue = null
		
	if is_instance_valid(_active_speaker_node):
		if _active_speaker_node.has_method("stop_talking"):
			_active_speaker_node.call("stop_talking")
		_active_speaker_node = null
		
	# Let the HUD orchestrator check if other panels are open before recapturing cursor
	# FIX: Explicit static typing on player HUD reference
	var hud: PlayerHUD = player.get("hud") as PlayerHUD
	if is_instance_valid(hud) and not hud.is_any_menu_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	dialogue_closed.emit()


func _on_dialogue_choice_selected(target_node_id: String) -> void:
	var next_node := DialogueService.get_dialogue_node(target_node_id)
	
	if next_node != null:
		# Custom Business Rule: Evaluate trading actions on navigation trigger
		if target_node_id == "merchant_trade_execute":
			_process_merchant_trade_transaction()
		else:
			active_dialogue.load_dialogue_node(next_node, _active_speaker_name)
	else:
		close_dialogue()


func _process_merchant_trade_transaction() -> void:
	# FIX: Explicit static typing on inventory interface
	var inventory: IInventory = player.get("inventory") as IInventory
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
func _on_trade_success(_inventory: IInventory) -> void:
	# Visual physical bounce feedback on the NPC if available
	# FIX: Explicit static typing on player raycast reference
	var raycast: RayCast3D = player.get("raycast") as RayCast3D
	if is_instance_valid(raycast) and raycast.is_colliding():
		# FIX: Explicit static typing on hit merchant collider node
		var merchant: CharacterBody3D = raycast.get_collider() as CharacterBody3D
		if is_instance_valid(merchant) and merchant.has_method("take_damage"):
			merchant.velocity.y = 5.0 # Make the merchant hop with physical joy!
			
	# Update active quest progression if applicable
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.quest_id == "fuel_fryer":
		QuestService.complete_active_quest(player)
		
		# Set localized translation key for quest completion
		var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute")
		if exec_node != null:
			exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_QUEST_COMPLETE")
	else:
		# Set localized translation key for successful trade
		var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute")
		if exec_node != null:
			exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_SUCCESS")


## Handles failure responses using localized translation keys.
func _on_trade_failed() -> void:
	var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute")
	if exec_node != null:
		exec_node.set("text", "DIALOGUE_MERCHANT_TRADE_FAILED")

# ==============================================================================
# Pathfile: res://src/Infrastructure/Dialogue/DialogueCoordinator.gd
# Description: Infrastructure Coordinator strictly managing the dialogue interface,
#              blocking/unblocking player input, and routing selections.
# SOLID COMPLIANCE: Class limits set < 100 lines (SRP). All monolithic
#              loops decomposed. Redundant YAGNI dead code purged.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DialogueCoordinator
extends Node

signal dialogue_closed

var player: CharacterBody3D
var active_dialogue: DialogueOverlay

var _active_speaker_name: String = ""
var _active_speaker_node: CharacterBody3D = null

const LAVA_BUCKET_ID: int = 15
const FRIED_CHICKEN_ID: int = 16


func open_dialogue(node: Resource, speaker_name: String, speaker_node: CharacterBody3D = null) -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		
	_active_speaker_name = speaker_name
	
	if is_instance_valid(speaker_node):
		_active_speaker_node = speaker_node
		if _active_speaker_node.has_method("start_talking") and is_instance_valid(player):
			_active_speaker_node.call("start_talking", player)
	
	active_dialogue = DialogueOverlay.new()
	add_child(active_dialogue)
	
	active_dialogue.choice_selected.connect(_on_dialogue_choice_selected)
	active_dialogue.dialogue_closed.connect(close_dialogue)
	active_dialogue.load_dialogue_node(node, speaker_name)
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_dialogue() -> void:
	if is_instance_valid(active_dialogue):
		active_dialogue.queue_free()
		active_dialogue = null
		
	if is_instance_valid(_active_speaker_node):
		if _active_speaker_node.has_method("stop_talking"):
			_active_speaker_node.call("stop_talking")
		_active_speaker_node = null
		
	var hud: PlayerHUD = player.get("hud") as PlayerHUD if is_instance_valid(player) else null
	if is_instance_valid(hud) and not hud.is_any_menu_open():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	dialogue_closed.emit()


func _on_dialogue_choice_selected(target_node_id: String) -> void:
	var next_node := DialogueService.get_dialogue_node(target_node_id) as DialogueNode
	
	if next_node != null:
		if target_node_id == "merchant_trade_execute":
			_process_merchant_trade_transaction()
		else:
			active_dialogue.load_dialogue_node(next_node, _active_speaker_name)
	else:
		close_dialogue()


func _process_merchant_trade_transaction() -> void:
	var inventory := player.get("inventory") as IInventory if is_instance_valid(player) else null
	if not is_instance_valid(inventory): return
		
	var trade_success: bool = TradingService.execute_id_trade(
		inventory, 
		LAVA_BUCKET_ID, 1, 
		FRIED_CHICKEN_ID, 1
	)
	
	if trade_success:
		_on_trade_success()
	else:
		_on_trade_failed()


func _on_trade_success() -> void:
	_apply_merchant_visual_bounce()
	_complete_fuel_fryer_quest()


func _apply_merchant_visual_bounce() -> void:
	var raycast := player.get("raycast") as RayCast3D if is_instance_valid(player) else null
	if is_instance_valid(raycast) and raycast.is_colliding():
		var merchant := raycast.get_collider() as CharacterBody3D
		if is_instance_valid(merchant) and merchant.has_method("take_damage"):
			merchant.velocity.y = 5.0 


func _complete_fuel_fryer_quest() -> void:
	var active_q: Quest = QuestService.get_active_quest() as Quest
	if active_q != null and active_q.quest_id == "fuel_fryer":
		QuestService.complete_active_quest(player)
		
		var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute") as DialogueNode
		if exec_node != null:
			exec_node.text = "DIALOGUE_MERCHANT_TRADE_QUEST_COMPLETE"
	else:
		var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute") as DialogueNode
		if exec_node != null:
			exec_node.text = "DIALOGUE_MERCHANT_TRADE_SUCCESS"


func _on_trade_failed() -> void:
	var exec_node := DialogueService.get_dialogue_node("merchant_trade_execute") as DialogueNode
	if exec_node != null:
		exec_node.text = "DIALOGUE_MERCHANT_TRADE_FAILED"

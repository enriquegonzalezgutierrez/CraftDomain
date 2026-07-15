# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/ChatBoxWidget.gd
# Description: Infrastructure UI Widget managing the 2D Multiplayer Chat Log 
#              and command input. Coordinates text input captures and P2P 
#              network transmission.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the 2D presentation
#   and input focus states of the chat box, delegating transmission to network adapters.
# - High-Performance Input: Simplified `_input()` to only evaluate the `Escape` key 
#   during active typing, offloading opening triggers to PlayerHUD.
# - Warning Fix: Prefixed unused parameter inside `_on_input_submitted()` with 
#   an underscore (`_text`) to satisfy Godot 2.0 static analyzers.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChatBoxWidget
extends Control

@onready var _chat_log: RichTextLabel = $VBoxContainer/ScrollContainer/RichTextLabel
@onready var _input_field: LineEdit = $VBoxContainer/InputHBox/LineEdit
@onready var _input_container: HBoxContainer = $VBoxContainer/InputHBox
@onready var _panel_bg: Panel = $PanelBG

var _adapter: P2PNetworkAdapter
var _is_typing: bool = false


func _ready() -> void:
	name = "ChatBoxWidget"
	_input_container.visible = false
	_panel_bg.visible = false
	
	_locate_p2p_network_adapter()
	_input_field.text_submitted.connect(_on_input_submitted)


## Locates and binds to the global P2P Network Adapter to listen for incoming chats
func _locate_p2p_network_adapter() -> void:
	var net_service := get_node_or_null("/root/Bootstrap/NetworkService")
	if is_instance_valid(net_service):
		_adapter = net_service.get_node_or_null("P2PNetworkAdapter") as P2PNetworkAdapter
		if is_instance_valid(_adapter):
			_adapter.message_received.connect(_on_message_received)
			print("[ChatBox] Successfully connected to P2PNetworkAdapter.")


## Captures only 'Escape' to cancel typing when the chat is active.
## General open actions (T / Enter) are managed elegantly by PlayerHUD.
func _input(event: InputEvent) -> void:
	if not _is_typing:
		return
		
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_deactivate_typing_mode()


func _activate_typing_mode() -> void:
	_is_typing = true
	_input_container.visible = true
	_panel_bg.visible = true
	_input_field.grab_focus()
	
	# Freeze local player look-rotations and movements to prevent drift while typing
	_set_player_input_active(false)


func _deactivate_typing_mode() -> void:
	_is_typing = false
	_input_container.visible = false
	_panel_bg.visible = false
	_input_field.text = ""
	_input_field.release_focus()
	
	# Restore local player movement controls
	_set_player_input_active(true)


func _set_player_input_active(active: bool) -> void:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_ctrl := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_ctrl):
			player_ctrl.set("is_active", active)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if not active else Input.MOUSE_MODE_CAPTURED


func _on_input_submitted(_text: String) -> void:
	_submit_chat_message()


func _submit_chat_message() -> void:
	var text := _input_field.text.strip_edges()
	if text != "":
		if is_instance_valid(_adapter):
			_adapter.send_chat_message(text)
			
	_deactivate_typing_mode()


func _on_message_received(formatted_text: String) -> void:
	if is_instance_valid(_chat_log):
		_chat_log.append_text(formatted_text + "\n")
		_auto_scroll_to_bottom()


## High-Fidelity Auto-Scroll: Defers scroll adjustment to the next frame, 
## allowing the RichTextLabel to compile its new layout size first.
func _auto_scroll_to_bottom() -> void:
	var scroll := _chat_log.get_v_scroll_bar()
	if is_instance_valid(scroll):
		get_tree().process_frame.connect(func() -> void:
			if is_instance_valid(scroll):
				scroll.value = scroll.max_value
		, CONNECT_ONE_SHOT)

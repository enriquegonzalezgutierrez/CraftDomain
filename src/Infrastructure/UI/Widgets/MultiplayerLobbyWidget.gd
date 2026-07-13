# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/MultiplayerLobbyWidget.gd
# Description: Symmetrical glassmorphic controller managing responsive P2P 
#              Host and Join Code inputs.
#              Corrected: Client now waits for server handshake before launching (UX).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MultiplayerLobbyWidget
extends Panel

signal closed

@onready var _code_edit: LineEdit = $LobbyCard/MarginContainer/VBoxContainer/JoinHBox/JoinCodeLineEdit
@onready var _host_btn: Button = $LobbyCard/MarginContainer/VBoxContainer/HostButton
@onready var _join_btn: Button = $LobbyCard/MarginContainer/VBoxContainer/JoinHBox/JoinButton
@onready var _back_btn: Button = $LobbyCard/MarginContainer/VBoxContainer/BackButton

var _net_service: NetworkService


func _ready() -> void:
	_net_service = get_node_or_null("/root/Bootstrap/NetworkService") as NetworkService
	_host_btn.pressed.connect(_on_host_pressed)
	_join_btn.pressed.connect(_on_join_pressed)
	_back_btn.pressed.connect(func() -> void: closed.emit())
	_refresh_localized_ui()


func _refresh_localized_ui() -> void:
	_host_btn.text = tr("LOBBY_HOST_GAME").to_upper()
	_join_btn.text = tr("LOBBY_JOIN_GAME").to_upper()
	_back_btn.text = tr("SETTINGS_BACK").to_upper()
	_code_edit.placeholder_text = tr("LOBBY_ENTER_CODE")


func _on_host_pressed() -> void:
	if is_instance_valid(_net_service) and _net_service.host_game() == OK:
		var upnp := NetworkUPnPService.new()
		_net_service.add_child(upnp) 
		upnp.start_upnp_and_ip_lookup()
		
		# Host doesn't need to wait for handshake, launches world instantly
		_trigger_world_launch()


func _on_join_pressed() -> void:
	var res := NetworkJoinCodeSolver.decode_to_ip_and_port(_code_edit.text)
	if res.is_empty():
		_code_edit.text = ""
		_code_edit.placeholder_text = "INVALID CODE!"
		return
		
	if is_instance_valid(_net_service) and _net_service.join_game(res["ip"] as String, res["port"] as int) == OK:
		# Lock UI while awaiting server handshake response
		_join_btn.disabled = true
		_host_btn.disabled = true
		_join_btn.text = "CONNECTING..."
		
		# Bind safely using Godot 4 Callables
		_net_service.connection_successful.connect(_on_client_connected, CONNECT_ONE_SHOT)
		_net_service.connection_failed.connect(_on_client_connection_failed, CONNECT_ONE_SHOT)


func _on_client_connected() -> void:
	# Safe disconnect of the failure signal to prevent memory leaks
	if _net_service.connection_failed.is_connected(_on_client_connection_failed):
		_net_service.connection_failed.disconnect(_on_client_connection_failed)
		
	_trigger_world_launch()


func _on_client_connection_failed() -> void:
	if _net_service.connection_successful.is_connected(_on_client_connected):
		_net_service.connection_successful.disconnect(_on_client_connected)
		
	_join_btn.disabled = false
	_host_btn.disabled = false
	_join_btn.text = tr("LOBBY_JOIN_GAME").to_upper()
	
	_code_edit.text = ""
	_code_edit.placeholder_text = "CONNECTION FAILED!"


func _trigger_world_launch() -> void:
	var pm := get_parent() as MainMenu
	if is_instance_valid(pm): 
		pm.play_pressed.emit()

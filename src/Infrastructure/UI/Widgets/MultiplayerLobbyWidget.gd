# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/MultiplayerLobbyWidget.gd
# Description: Symmetrical glassmorphic controller managing responsive P2P 
#              Host and Join Code inputs. Stays under 50 lines (Section 7.1).
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
		add_child(upnp)
		# Symmetrical binding: When the public IP is resolved, display the Join Code!
		upnp.join_code_generated.connect(func(c: String) -> void: _code_edit.text = c)
		upnp.start_upnp_and_ip_lookup()


func _on_join_pressed() -> void:
	# Decode the friendly Join Code back to raw IP and port locally (0 cost math)
	var res := NetworkJoinCodeSolver.decode_to_ip_and_port(_code_edit.text)
	if not res.is_empty() and is_instance_valid(_net_service):
		_net_service.join_game(res["ip"] as String, res["port"] as int)
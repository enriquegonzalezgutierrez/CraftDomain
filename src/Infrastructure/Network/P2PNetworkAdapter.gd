# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/P2PNetworkAdapter.gd
# Description: Infrastructure Network Adapter handling RPC replication of text
#              chat messages and transactional P2P trade session states.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name P2PNetworkAdapter
extends Node

signal message_received(formatted_text: String)
signal trade_request_received(sender_peer_id: int)
signal trade_session_started(session_id: String, partner_peer_id: int, is_leader: bool)
signal trade_offer_updated(session_id: String, offer_data: Dictionary)
signal trade_confirmation_updated(session_id: String, confirmed: bool)

var _peer_names: Dictionary = {}
var _active_sessions: Dictionary = {}

const TRADE_REACH_DISTANCE_SQ: float = 25.0


func _ready() -> void:
	name = "P2PNetworkAdapter"
	_connect_network_signals()


func _connect_network_signals() -> void:
	var net_service := get_node_or_null("../NetworkService") as NetworkService
	if is_instance_valid(net_service):
		net_service.connection_successful.connect(_on_connection_successful)
		net_service.connection_closed.connect(_on_connection_closed)


# ==============================================================================
# MULTIPLAYER TEXT CHAT REPLICATION PIPELINE
# ==============================================================================

func send_chat_message(raw_text: String) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_process_offline_message(raw_text)
		return
		
	rpc_id(1, "_server_receive_message", raw_text)


@rpc("any_peer", "reliable")
func _server_receive_message(raw_text: String) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_name := _get_peer_name(sender_id)
	var msg := P2PChatService.parse_incoming_text(sender_id, sender_name, raw_text)
	
	if msg.channel == P2PChatService.Channel.GLOBAL:
		rpc("_client_receive_message", msg.sender_id, msg.sender_name, msg.text, int(msg.channel), "")
	elif msg.channel == P2PChatService.Channel.PRIVATE:
		_route_private_whisper(msg)


@rpc("call_local", "reliable")
func _client_receive_message(sender_id: int, sender_name: String, text: String, channel_val: int, target: String) -> void:
	var msg := P2PChatService.ChatMessage.new(sender_id, sender_name, text, channel_val as P2PChatService.Channel, target)
	message_received.emit(P2PChatService.format_message(msg))


# ==============================================================================
# DYNAMIC USERNAME REGISTRATION & CONFLICT RESOLUTION
# ==============================================================================

func _get_local_username() -> String:
	var settings := SettingsRepository.load_settings()
	if settings.has("username") and str(settings["username"]).strip_edges() != "":
		return str(settings["username"]).strip_edges()
		
	var os_name := OS.get_environment("USERNAME") if OS.has_environment("USERNAME") else OS.get_environment("USER")
	return os_name if os_name != "" else "Player_" + str(randi_range(100, 999))


func _get_peer_name(peer_id: int) -> String:
	return _peer_names.get(peer_id, str(peer_id)) as String


func _on_connection_successful() -> void:
	var my_id := multiplayer.get_unique_id()
	var my_name := _get_local_username()
	
	if multiplayer.is_server():
		_peer_names[1] = my_name
	else:
		rpc_id(1, "_server_register_username", my_id, my_name)


@rpc("any_peer", "reliable")
func _server_register_username(peer_id: int, requested_name: String) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
		
	var resolved_name := _resolve_unique_name(requested_name)
	_peer_names[peer_id] = resolved_name
	
	rpc("_client_register_username", peer_id, resolved_name)
	rpc_id(peer_id, "_client_sync_all_usernames", _peer_names)


func _resolve_unique_name(requested_name: String) -> String:
	var sanitized := P2PChatService.sanitize_text(requested_name)
	if sanitized == "":
		sanitized = "Player"
		
	var candidate := sanitized
	var suffix := 1
	while _is_name_taken(candidate):
		candidate = sanitized + "_" + str(suffix)
		suffix += 1
		
	return candidate


func _is_name_taken(name_to_check: String) -> bool:
	for val: String in _peer_names.values():
		if val.to_lower() == name_to_check.to_lower():
			return true
	return false


@rpc("call_local", "reliable")
func _client_register_username(peer_id: int, resolved_name: String) -> void:
	_peer_names[peer_id] = resolved_name


@rpc("reliable")
func _client_sync_all_usernames(server_names: Dictionary) -> void:
	for key: Variant in server_names.keys():
		_peer_names[int(key)] = server_names[key] as String


func _on_connection_closed() -> void:
	_peer_names.clear()


# ==============================================================================
# MULTIPLAYER P2P TRADING REPLICATION PIPELINE
# ==============================================================================

func request_trade_session(target_peer_id: int) -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		rpc_id(1, "_server_receive_trade_request", target_peer_id)


func sync_trade_offer(session_id: String, offer_data: Dictionary) -> void:
	rpc_id(1, "_server_sync_offer", session_id, offer_data)


func confirm_trade_session(session_id: String, confirmed: bool) -> void:
	rpc_id(1, "_server_confirm_trade", session_id, confirmed)


@rpc("any_peer", "reliable")
func _server_receive_trade_request(target_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	if _is_within_interaction_distance(sender_id, target_id):
		rpc_id(target_id, "_client_receive_trade_request", sender_id)
	else:
		var err_text := tr("TRADE_ERROR_OUT_OF_RANGE")
		rpc_id(sender_id, "_client_receive_message", 1, "SYSTEM", err_text, int(P2PChatService.Channel.SYSTEM), "")


@rpc("reliable")
func _client_receive_trade_request(sender_id: int) -> void:
	trade_request_received.emit(sender_id)


func accept_trade_request(sender_id: int) -> void:
	rpc_id(1, "_server_accept_trade_request", sender_id)


@rpc("any_peer", "reliable")
func _server_accept_trade_request(sender_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var receiver_id := multiplayer.get_remote_sender_id()
	if not _is_within_interaction_distance(sender_id, receiver_id):
		return
		
	var session_id := "%d_%d" % [sender_id, receiver_id]
	rpc_id(sender_id, "_client_start_trade_session", session_id, receiver_id, true)
	rpc_id(receiver_id, "_client_start_trade_session", session_id, sender_id, false)


@rpc("reliable")
func _client_start_trade_session(session_id: String, partner_id: int, is_leader: bool) -> void:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): 
		return
		
	var player_node := bootstrap.get("player_controller") as CharacterBody3D
	if is_instance_valid(player_node):
		var inv := player_node.get("inventory") as IInventory
		var session := P2PTradeService.create_session(session_id, inv, InventoryComponent.new())
		_active_sessions[session_id] = session
		trade_session_started.emit(session_id, partner_id, is_leader)


@rpc("any_peer", "reliable")
func _server_sync_offer(session_id: String, offer_data: Dictionary) -> void:
	if multiplayer.is_server():
		var sender_id := multiplayer.get_remote_sender_id()
		rpc_id(_get_trade_partner_id(session_id, sender_id), "_client_sync_offer", session_id, offer_data)


@rpc("reliable")
func _client_sync_offer(session_id: String, offer_data: Dictionary) -> void:
	if _active_sessions.has(session_id):
		var session: P2PTradeService.P2PTradeSession = _active_sessions[session_id]
		var is_partner_a := (session_id.split("_")[0].to_int() != multiplayer.get_unique_id())
		P2PTradeService.update_offer(session, is_partner_a, offer_data)
		trade_offer_updated.emit(session_id, offer_data)


@rpc("any_peer", "reliable")
func _server_confirm_trade(session_id: String, confirmed: bool) -> void:
	if multiplayer.is_server():
		var sender_id := multiplayer.get_remote_sender_id()
		rpc_id(_get_trade_partner_id(session_id, sender_id), "_client_confirm_trade", session_id, confirmed)


@rpc("reliable")
func _client_confirm_trade(session_id: String, confirmed: bool) -> void:
	if _active_sessions.has(session_id):
		var session: P2PTradeService.P2PTradeSession = _active_sessions[session_id]
		var is_partner_a := (session_id.split("_")[0].to_int() != multiplayer.get_unique_id())
		P2PTradeService.set_confirmed(session, is_partner_a, confirmed)
		trade_confirmation_updated.emit(session_id, confirmed)


# ==============================================================================
# INTERNAL UTILITIES
# ==============================================================================

func _process_offline_message(raw_text: String) -> void:
	var msg := P2PChatService.parse_incoming_text(1, _get_local_username(), raw_text)
	message_received.emit(P2PChatService.format_message(msg))


func _route_private_whisper(msg: P2PChatService.ChatMessage) -> void:
	var target_id := _get_peer_id_by_name(msg.target_name)
	if target_id != -1:
		rpc_id(target_id, "_client_receive_message", msg.sender_id, msg.sender_name, msg.text, int(msg.channel), msg.target_name)
		rpc_id(msg.sender_id, "_client_receive_message", msg.sender_id, msg.sender_name, msg.text, int(msg.channel), msg.target_name)
	else:
		var err_text := tr("CHAT_ERROR_USER_OFFLINE") % msg.target_name
		rpc_id(msg.sender_id, "_client_receive_message", 1, "SYSTEM", err_text, int(P2PChatService.Channel.SYSTEM), "")


func _get_peer_id_by_name(p_name: String) -> int:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var controller := bootstrap.get("world_controller") as Node
		if is_instance_valid(controller):
			var node := controller.get_node_or_null(p_name)
			if is_instance_valid(node) and node is CharacterBody3D:
				return p_name.to_int()
	return -1


func _get_trade_partner_id(session_id: String, sender_id: int) -> int:
	var parts := session_id.split("_")
	if parts.size() == 2:
		var id_a := parts[0].to_int()
		var id_b := parts[1].to_int()
		return id_b if sender_id == id_a else id_a
	return -1


func _is_within_interaction_distance(id_a: int, id_b: int) -> bool:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): 
		return false
	
	var ctrl := bootstrap.get("world_controller") as Node
	if is_instance_valid(ctrl):
		var node_a := _resolve_player_node(ctrl, id_a)
		var node_b := _resolve_player_node(ctrl, id_b)
		if is_instance_valid(node_a) and is_instance_valid(node_b):
			return node_a.global_position.distance_squared_to(node_b.global_position) <= TRADE_REACH_DISTANCE_SQ
			
	return false


func _resolve_player_node(ctrl: Node, peer_id: int) -> CharacterBody3D:
	if peer_id == 1:
		return ctrl.get_node_or_null("Player") as CharacterBody3D
	return ctrl.get_node_or_null(str(peer_id)) as CharacterBody3D
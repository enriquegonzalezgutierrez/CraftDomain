# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/P2PNetworkAdapter.gd
# Description: Infrastructure Network Adapter responsible for replicating text 
#              chats and P2P trade session states across multiplayer peers.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly RPC packets 
#   for chat and trade, delegating data state validation to the Domain services.
# - Dependency Inversion Principle (DIP): Operates entirely on abstract IInventory
#   contracts during peer trade initializations.
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

var _active_sessions: Dictionary = {} # session_id (String) -> P2PTradeSession

const TRADE_REACH_DISTANCE_SQ: float = 25.0 # 5 meters squared max transaction range


func _ready() -> void:
	name = "P2PNetworkAdapter"


# ==============================================================================
# MULTIPLAYER TEXT CHAT REPLICATION PIPELINE
# ==============================================================================

## Local Client API: Processes raw local inputs and uploads them to the server
func send_chat_message(raw_text: String) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_process_offline_message(raw_text)
		return
		
	rpc_id(1, "_server_receive_message", raw_text)


## Server-Authoritative: Parses, sanitizes, and routes the message across peers
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


## Client-Authoritative: Receives, bakes, and appends formatted BBCodes to the UI
@rpc("call_local", "reliable")
func _client_receive_message(sender_id: int, sender_name: String, text: String, channel_val: int, target: String) -> void:
	var msg := P2PChatService.ChatMessage.new(sender_id, sender_name, text, channel_val as P2PChatService.Channel, target)
	var formatted := P2PChatService.format_message(msg)
	message_received.emit(formatted)


# ==============================================================================
# MULTIPLAYER P2P TRADING REPLICATION PIPELINE
# ==============================================================================

## Local Client API: Requests a secure trade handshake with a nearby peer
func request_trade_session(target_peer_id: int) -> void:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	rpc_id(1, "_server_receive_trade_request", target_peer_id)


## Local Client API: Updates active offers, flushing sibling confirmations
func sync_trade_offer(session_id: String, offer_data: Dictionary) -> void:
	rpc_id(1, "_server_sync_offer", session_id, offer_data)


## Local Client API: Confirms active offer validations
func confirm_trade_session(session_id: String, confirmed: bool) -> void:
	rpc_id(1, "_server_confirm_trade", session_id, confirmed)


## Server-Authoritative: Receives, proximity-checks, and dispatches trade handshakes
@rpc("any_peer", "reliable")
func _server_receive_trade_request(target_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	
	# ANTI-CHEAT: Validate physical proximity before authorizing the handshake popup
	if _is_within_interaction_distance(sender_id, target_id):
		rpc_id(target_id, "_client_receive_trade_request", sender_id)
	else:
		# Provide system feedback to the violator
		var err_text := "SYSTEM: Trade failed. Player is out of range."
		rpc_id(sender_id, "_client_receive_message", 1, "SYSTEM", err_text, int(P2PChatService.Channel.SYSTEM), "")


@rpc("reliable")
func _client_receive_trade_request(sender_id: int) -> void:
	trade_request_received.emit(sender_id)


## Local Client API: Accepts an incoming trade request
func accept_trade_request(sender_id: int) -> void:
	rpc_id(1, "_server_accept_trade_request", sender_id)


## Server-Authoritative: Spawns the unified session ID, notifying both clients
@rpc("any_peer", "reliable")
func _server_accept_trade_request(sender_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var receiver_id := multiplayer.get_remote_sender_id()
	
	# Second validation pass to ensure players didn't move away during the prompt
	if not _is_within_interaction_distance(sender_id, receiver_id):
		return
		
	var session_id := "%d_%d" % [sender_id, receiver_id]
	
	rpc_id(sender_id, "_client_start_trade_session", session_id, receiver_id, true)
	rpc_id(receiver_id, "_client_start_trade_session", session_id, sender_id, false)


## Client-Authoritative: Maps local player inventory references to the session
@rpc("reliable")
func _client_start_trade_session(session_id: String, partner_id: int, is_leader: bool) -> void:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): return
		
	var player_node := bootstrap.get("player_controller") as CharacterBody3D
	if is_instance_valid(player_node):
		var inv := player_node.get("inventory") as IInventory
		var mock_partner_inv := InventoryComponent.new() # Simulated proxy for negotiations
		
		var session := P2PTradeService.create_session(session_id, inv, mock_partner_inv)
		_active_sessions[session_id] = session
		trade_session_started.emit(session_id, partner_id, is_leader)


@rpc("any_peer", "reliable")
func _server_sync_offer(session_id: String, offer_data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var partner_id := _get_trade_partner_id(session_id, sender_id)
	rpc_id(partner_id, "_client_sync_offer", session_id, offer_data)


@rpc("reliable")
func _client_sync_offer(session_id: String, offer_data: Dictionary) -> void:
	if _active_sessions.has(session_id):
		var session: P2PTradeService.P2PTradeSession = _active_sessions[session_id]
		var is_partner_a := (session_id.split("_")[0].to_int() != multiplayer.get_unique_id())
		P2PTradeService.update_offer(session, is_partner_a, offer_data)
		trade_offer_updated.emit(session_id, offer_data)


@rpc("any_peer", "reliable")
func _server_confirm_trade(session_id: String, confirmed: bool) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	var partner_id := _get_trade_partner_id(session_id, sender_id)
	rpc_id(partner_id, "_client_confirm_trade", session_id, confirmed)


@rpc("reliable")
func _client_confirm_trade(session_id: String, confirmed: bool) -> void:
	if _active_sessions.has(session_id):
		var session: P2PTradeService.P2PTradeSession = _active_sessions[session_id]
		var is_partner_a := (session_id.split("_")[0].to_int() != multiplayer.get_unique_id())
		P2PTradeService.set_confirmed(session, is_partner_a, confirmed)
		trade_confirmation_updated.emit(session_id, confirmed)


# ==============================================================================
# INTERNAL PRIVATE UTILITIES (Strict SRP/OCP Compliance)
# ==============================================================================

func _process_offline_message(raw_text: String) -> void:
	var msg := P2PChatService.parse_incoming_text(1, "SOLO", raw_text)
	var formatted := P2PChatService.format_message(msg)
	message_received.emit(formatted)


func _route_private_whisper(msg: P2PChatService.ChatMessage) -> void:
	var target_id := _get_peer_id_by_name(msg.target_name)
	if target_id != -1:
		rpc_id(target_id, "_client_receive_message", msg.sender_id, msg.sender_name, msg.text, int(msg.channel), msg.target_name)
		# Send confirmation echo to the original sender
		rpc_id(msg.sender_id, "_client_receive_message", msg.sender_id, msg.sender_name, msg.text, int(msg.channel), msg.target_name)
	else:
		var err_text := "ERROR: PLAYER '%s' IS OFFLINE OR OUT OF RANGE." % msg.target_name
		rpc_id(msg.sender_id, "_client_receive_message", 1, "SYSTEM", err_text, int(P2PChatService.Channel.SYSTEM), "")


func _get_peer_id_by_name(p_name: String) -> int:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var controller := bootstrap.get("world_controller") as Node
		if is_instance_valid(controller):
			# The NetworkSpawnerService instantiates player nodes matching their integer Peer ID
			var node := controller.get_node_or_null(p_name)
			if is_instance_valid(node) and node is CharacterBody3D:
				return p_name.to_int()
	return -1


func _get_peer_name(peer_id: int) -> String:
	return str(peer_id)


func _get_trade_partner_id(session_id: String, sender_id: int) -> int:
	var parts := session_id.split("_")
	if parts.size() == 2:
		var id_a := parts[0].to_int()
		var id_b := parts[1].to_int()
		return id_b if sender_id == id_a else id_a
	return -1


func _is_within_interaction_distance(id_a: int, id_b: int) -> bool:
	# Host is always ID 1, but we use string paths to locate active physics bodies
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): return false
	
	var ctrl := bootstrap.get("world_controller") as Node
	if is_instance_valid(ctrl):
		var node_a: CharacterBody3D = ctrl.get_node_or_null(str(id_a)) as CharacterBody3D if id_a != 1 else ctrl.get_node_or_null("Player") as CharacterBody3D
		var node_b: CharacterBody3D = ctrl.get_node_or_null(str(id_b)) as CharacterBody3D if id_b != 1 else ctrl.get_node_or_null("Player") as CharacterBody3D
		
		if is_instance_valid(node_a) and is_instance_valid(node_b):
			return node_a.global_position.distance_squared_to(node_b.global_position) <= TRADE_REACH_DISTANCE_SQ
			
	return false

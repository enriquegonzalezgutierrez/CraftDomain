# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkService.gd
# Description: Infrastructure Service responsible for managing ENet socket 
#              connections, hosting games, and joining peers (DIP).
#              Corrected: Added join_code_updated signal for reactive HUD popups.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkService
extends Node

# Decoupled Network Signals (Observer Pattern / Section 7.3)
signal connection_started
signal connection_successful
signal connection_failed
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_closed

# UX Reactive Signal
signal join_code_updated(code: String)

# Network constants to avoid magic numbers (Section 5.3)
const DEFAULT_PORT: int = 25565 # Standard voxel sandbox port
const MAX_PEERS_LIMIT: int = 8  # Moderate limit for Listen-Server setups

# Cache in RAM of the active invitation code to display inside the pause menu (UX)
var active_join_code: String = ""

# Active multiplayer peer socket
var _peer: ENetMultiplayerPeer = null


func _ready() -> void:
	name = "NetworkService"
	_connect_multiplayer_signals()


## Safely updates the active cache and broadcasts the event to UI layers
func update_active_join_code(code: String) -> void:
	active_join_code = code
	join_code_updated.emit(code)


## Starts a Host/Listen-Server on the designated port.
## Returns OK if successful, or the corresponding Godot Error code.
func host_game(port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	active_join_code = "" # Reset previous session cache
	
	var err := _peer.create_server(port, MAX_PEERS_LIMIT)
	if err != OK:
		push_error("[NetworkService ERROR] Failed to create ENet server: " + error_string(err))
		_peer = null
		return err
		
	multiplayer.multiplayer_peer = _peer
	connection_started.emit()
	print("[NetworkService] Host server created successfully on port: ", port)
	return OK


## Connects to an active Host server at the designated IP address.
## Returns OK if successful, or the corresponding Godot Error code.
func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	_peer = ENetMultiplayerPeer.new()
	active_join_code = ""
	
	var err := _peer.create_client(ip, port)
	if err != OK:
		push_error("[NetworkService ERROR] Failed to initialize ENet client: " + error_string(err))
		_peer = null
		return err
		
	multiplayer.multiplayer_peer = _peer
	connection_started.emit()
	print("[NetworkService] Client connecting to host at: ", ip, ":", port)
	return OK


## Closes active sockets and shuts down connection parameters safely.
func close_connection() -> void:
	if is_instance_valid(_peer):
		_peer.close()
		_peer = null
		
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	active_join_code = ""
	connection_closed.emit()
	print("[NetworkService] Connection closed. Multiplayer offline.")


func _connect_multiplayer_signals() -> void:
	# Godot's built-in C++ network signals bindings
	multiplayer.connected_to_server.connect(_on_connection_successful)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _on_connection_successful() -> void:
	var local_id := multiplayer.get_unique_id()
	print("[NetworkService] Successfully connected to host! Local ID: ", local_id)
	connection_successful.emit()


func _on_connection_failed() -> void:
	push_error("[NetworkService ERROR] Connection to host failed.")
	_peer = null
	connection_failed.emit()


func _on_peer_connected(id: int) -> void:
	print("[NetworkService] Peer connected to session. ID: ", id)
	peer_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	print("[NetworkService] Peer disconnected from session. ID: ", id)
	peer_disconnected.emit(id)

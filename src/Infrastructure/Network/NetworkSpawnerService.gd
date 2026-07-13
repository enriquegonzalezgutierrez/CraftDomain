# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkSpawnerService.gd
# Description: Infrastructure Service responsible for managing peer-spawn 
#              authorities and replicating remote player controllers (OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkSpawnerService
extends Node

var world_controller: Node3D
var world_state: WorldState

# Cached dictionary mapping peer IDs (int) to their active player node instances
var _spawned_players: Dictionary = {}

# Preloaded Player Controller scene path (Section 5.4)
const PLAYER_SCENE_PATH: String = "res://src/Infrastructure/Player/PlayerController.gd"


## Registers dependencies and binds to ENet network signals.
func initialize(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state
	
	# Connect to network signals (Observer Pattern / Section 7.3)
	var net := get_node_or_null("../NetworkService") as NetworkService
	if is_instance_valid(net):
		net.peer_connected.connect(_on_peer_connected)
		net.peer_disconnected.connect(_on_peer_disconnected)
		net.connection_closed.connect(_on_connection_closed)


func _on_peer_connected(peer_id: int) -> void:
	# Spawning is server-authoritative. Only the Host/Server deploys nodes globally
	if not multiplayer.is_server():
		return
		
	_spawn_player_instance(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	_despawn_player_instance(peer_id)


## Instantiates the player controller, establishing server-authoritative authority (DIP).
func _spawn_player_instance(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		return # Already spawned!
		
	print("[NetworkSpawner] Spawning player instance for Peer ID: ", peer_id)
	
	# Instantiate PlayerController dynamically 
	var player_script := load(PLAYER_SCENE_PATH) as GDScript
	var player_instance := player_script.new() as CharacterBody3D
	
	# Set node name as the unique peer ID string for RPC lookups
	player_instance.name = str(peer_id)
	
	# 1. Establish server-authoritative multiplayer authority (Section 10.1)
	player_instance.set_multiplayer_authority(peer_id)
	
	# 2. De-activate inputs and physics for remote clients
	player_instance.set("is_active", false)
	
	# 3. Attach to WorldController root scene tree
	world_controller.add_child(player_instance)
	_spawned_players[peer_id] = player_instance
	
	# Spawn at safe ground height (DDD query)
	var spawn_y := world_state.get_highest_solid_y(8, 8)
	player_instance.global_position = Vector3(8.5, spawn_y, 8.5)


func _despawn_player_instance(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		var inst := _spawned_players[peer_id] as Node
		if is_instance_valid(inst):
			inst.queue_free()
		_spawned_players.erase(peer_id)
		print("[NetworkSpawner] Despawned player instance for Peer ID: ", peer_id)


func _on_connection_closed() -> void:
	# Connection closed: clean up all remote players instantly
	var active_keys := _spawned_players.keys()
	for id: int in active_keys:
		_despawn_player_instance(id)
	_spawned_players.clear()
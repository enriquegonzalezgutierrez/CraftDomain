# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkSpawnerService.gd
# Description: Infrastructure Service responsible for managing peer-spawn 
#              authorities and replicating remote player controllers (OCP).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages the multiplayer 
#   peer lifecycle, replica instantiations, and server-authoritative coordinate spawning.
# - Open-Closed Principle (OCP): Upgraded to support Symmetrical RPC Spawning
#   and Late-Join Player Synchronization, making all peers visible to each other.
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
		
	# 1. Calculate safe spawn height on server
	var spawn_y := world_state.get_highest_solid_y(8, 8)
	var spawn_pos := Vector3(8.5, spawn_y, 8.5)
	
	# 2. Spawn the newcomer's replica locally on the Host
	_spawn_replica_locally(peer_id, spawn_pos)
	
	# 3. Broadcast to all other clients to spawn this newcomer
	rpc("_client_spawn_player", peer_id, spawn_pos)
	
	# 4. Stream all already connected players to the newcomer
	_sync_existing_players_to_newcomer(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	_despawn_replica_locally(peer_id)
	rpc("_client_despawn_player", peer_id)


func _sync_existing_players_to_newcomer(new_peer_id: int) -> void:
	var existing_data: Dictionary = {}
	
	for id: int in _spawned_players.keys():
		if id != new_peer_id:
			var inst := _spawned_players[id] as CharacterBody3D
			if is_instance_valid(inst):
				existing_data[id] = inst.global_position
				
	# Targeted RPC: Send the list of existing players only to the newcomer
	rpc_id(new_peer_id, "_client_sync_existing_players", existing_data)


# ==============================================================================
# CLIENT-SIDE REPLICA SPANWER RPCs (Symmetrical Replication)
# ==============================================================================

## RPC: Instructs all clients to spawn a replica of a newly joined peer.
@rpc("authority", "reliable")
func _client_spawn_player(peer_id: int, pos: Vector3) -> void:
	# Skip if the peer to spawn is ourselves (we are already spawned locally as "Player")
	if peer_id == multiplayer.get_unique_id() or multiplayer.is_server():
		return
		
	_spawn_replica_locally(peer_id, pos)


## RPC: Instructs all clients to despawn a disconnected peer's replica.
@rpc("authority", "reliable")
func _client_despawn_player(peer_id: int) -> void:
	if multiplayer.is_server():
		return
		
	_despawn_replica_locally(peer_id)


## RPC: Called on a newly joined client to catch up on players already in the session.
@rpc("authority", "reliable")
func _client_sync_existing_players(existing_data: Dictionary) -> void:
	if multiplayer.is_server():
		return
		
	for str_id: String in existing_data.keys():
		var peer_id := str_id.to_int()
		var pos: Vector3 = existing_data[str_id]
		
		# Avoid duplicate spawns for ourselves
		if peer_id != multiplayer.get_unique_id():
			_spawn_replica_locally(peer_id, pos)


# ==============================================================================
# REPLICA NODE RIGGING & LIFECYCLE (SRP)
# ==============================================================================

func _spawn_replica_locally(peer_id: int, pos: Vector3) -> void:
	if _spawned_players.has(peer_id):
		return
		
	print("[NetworkSpawner] Spawning player replica for Peer ID: ", peer_id)
	
	# Instantiate PlayerController dynamically
	var player_script := load(PLAYER_SCENE_PATH) as GDScript
	var player_instance := player_script.new() as CharacterBody3D
	
	# Set node name as the unique peer ID string for RPC routing
	player_instance.name = str(peer_id)
	player_instance.set_multiplayer_authority(peer_id)
	
	# De-activate inputs and physics simulation locally for remote clones
	player_instance.set("is_active", false)
	
	# Configure visual culling to render the remote player to this peer
	var visual_comp := player_instance.get_node_or_null("PlayerVisualComponent") as PlayerVisualComponent
	if is_instance_valid(visual_comp):
		visual_comp.is_local_player = false
		if visual_comp.has_method("_update_cull_modes"):
			visual_comp.call_deferred("_update_cull_modes")
			
	# Attach the interpolation replica
	var replica := NetworkPlayerReplica.new()
	player_instance.add_child(replica)
	
	world_controller.add_child(player_instance)
	_spawned_players[peer_id] = player_instance
	player_instance.global_position = pos


func _despawn_replica_locally(peer_id: int) -> void:
	if _spawned_players.has(peer_id):
		var inst := _spawned_players[peer_id] as Node
		if is_instance_valid(inst):
			inst.queue_free()
		_spawned_players.erase(peer_id)
		print("[NetworkSpawner] Despawned player replica for Peer ID: ", peer_id)


func _on_connection_closed() -> void:
	# Connection closed: clean up all remote players instantly
	var active_keys := _spawned_players.keys()
	for id: int in active_keys:
		_despawn_replica_locally(id)
	_spawned_players.clear()

# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/VoxelReplicator.gd
# Description: Infrastructure Service responsible for replicating voxel edits 
#              (placing and breaking blocks) reliably across peers (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelReplicator
extends Node

var world_controller: Node3D
var world_state: WorldState

# Flag preventing signal feedback loops during network-applied block writes
var _is_applying_network_sync: bool = false


## Registers dependencies and binds to local world modified signals.
func initialize(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state
	
	# Subscribe to the local block modified signal (Observer Pattern / Section 7.3)
	if is_instance_valid(world_controller) and world_controller.has_signal("block_modified"):
		world_controller.block_modified.connect(_on_local_block_modified)


## Observer receptor: Translates local block edits into network RPC requests.
func _on_local_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	# Skip transmitting RPC if we are currently writing a remote network block
	if _is_applying_network_sync:
		return
		
	# Skip if we are running in single-player offline mode
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
		
	# Clients request the modification. Server validates and broadcasts
	rpc_id(1, "_server_receive_block_modification", global_pos, type as int)


## RPC: Executed only on the Server/Host. Validates block placement coordinates.
@rpc("any_peer", "reliable")
func _server_receive_block_modification(global_pos: Vector3i, type_val: int) -> void:
	if not multiplayer.is_server():
		return
		
	# Symmetrical Validation: Check player authority distance (Reach Cheat Protection)
	var sender_id := multiplayer.get_remote_sender_id()
	var sender_node := world_controller.get_node_or_null(str(sender_id)) as CharacterBody3D
	
	if is_instance_valid(sender_node):
		var dist := sender_node.global_position.distance_to(Vector3(global_pos))
		if dist > 8.0: # Prevent hacking/excessive reach distances (Section 1.2)
			push_warning("[VoxelReplicator WARNING] Rejected spoofed block edit from peer: ", sender_id)
			return
			
	# Broadcast valid changes to all connected clients
	rpc("_client_receive_block_modification", global_pos, type_val)


## RPC: Broadcasted to all peers. Applies the remote voxel change globally.
@rpc("call_local", "reliable")
func _client_receive_block_modification(global_pos: Vector3i, type_val: int) -> void:
	if not is_instance_valid(world_controller):
		return
		
	var block_type := type_val as BlockType.Type
	
	# Activate loop shielding
	_is_applying_network_sync = true
	
	# Execute global write
	world_controller.call("set_block_globally", global_pos, block_type)
	
	# Deactivate loop shielding
	_is_applying_network_sync = false
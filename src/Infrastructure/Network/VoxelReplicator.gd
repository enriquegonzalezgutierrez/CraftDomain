# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/VoxelReplicator.gd
# Description: Infrastructure Service responsible for replicating voxel edits 
#              and managing Late-Join Dual-Timeline Delta Synchronization.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates strictly block edit 
#   RPCs and delta streaming for new peers, delegating JSON serialization.
# - Open-Closed Principle (OCP): Fully supports dual-timeline (Past/Present) 
#   synchronization dynamically without altering base chunk protocols.
# - Anti-Cheat Security: Enforces strict server-side reach validation, reverting
#   client worlds automatically if spoofed block edits are detected.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelReplicator
extends Node

var world_controller: Node3D
var world_state: WorldState

# Flag preventing signal feedback loops during network-applied block writes
var _is_applying_network_sync: bool = false


## Registers dependencies and binds to local world modified and network signals.
func initialize(p_world_controller: Node3D, p_world_state: WorldState) -> void:
	world_controller = p_world_controller
	world_state = p_world_state
	
	# Subscribe to the local block modified signal (Observer Pattern / Section 7.3)
	if is_instance_valid(world_controller) and world_controller.has_signal("block_modified"):
		world_controller.block_modified.connect(_on_local_block_modified)
		
	# Bind to the NetworkService to detect late-joiners for Delta Synchronization
	var net_service := get_node_or_null("../NetworkService")
	if is_instance_valid(net_service) and net_service.has_signal("peer_connected"):
		net_service.peer_connected.connect(_on_peer_connected)


# ==============================================================================
# LATE-JOIN DELTA SYNCHRONIZATION (High-Frequency State Replication)
# ==============================================================================

func _on_peer_connected(peer_id: int) -> void:
	# Streaming world state is strictly Server-Authoritative
	if not multiplayer.is_server():
		return
		
	_stream_world_deltas_to_peer(peer_id)


func _stream_world_deltas_to_peer(peer_id: int) -> void:
	print("[VoxelReplicator] Streaming dual-timeline world deltas to late-joiner: ", peer_id)
	
	var present_map: Dictionary = world_state._timeline_modifications[WorldState.Timeline.PRESENT]
	var past_map: Dictionary = world_state._timeline_modifications[WorldState.Timeline.PAST]
	
	# Gather union of all modified chunks across both eras
	var unique_chunks: Dictionary = {}
	for pos: Vector3i in present_map.keys(): unique_chunks[pos] = true
	for pos: Vector3i in past_map.keys(): unique_chunks[pos] = true
	
	# Stream modifications chunk by chunk to prevent overflowing ENet's packet size limits
	for chunk_pos: Vector3i in unique_chunks.keys():
		var dual_data := {
			"present": present_map.get(chunk_pos, {}),
			"past": past_map.get(chunk_pos, {})
		}
		
		var serialized_deltas := VoxelSaveSerializer.serialize_chunk_deltas(dual_data)
		rpc_id(peer_id, "_client_receive_chunk_delta", chunk_pos, JSON.stringify(serialized_deltas))


## RPC: Executed only on joining Clients. Receives and applies historical world edits.
@rpc("authority", "reliable")
func _client_receive_chunk_delta(chunk_pos: Vector3i, json_payload: String) -> void:
	if multiplayer.is_server(): 
		return
		
	var json := JSON.new()
	if json.parse(json_payload) != OK:
		push_error("[VoxelReplicator ERROR] Failed to parse incoming chunk delta payload.")
		return
		
	var payload := json.data as Dictionary
	var dual_data := VoxelSaveSerializer.deserialize_chunk_deltas(payload)
	
	if is_instance_valid(world_state):
		world_state.apply_chunk_modifications(chunk_pos, dual_data)
		
	# If the chunk has already been loaded into memory, force a visual and physics rebuild
	if is_instance_valid(world_controller):
		var lifecycle: Object = world_controller.get("chunk_lifecycle")
		if is_instance_valid(lifecycle) and lifecycle.has_method("_request_chunk_rebuild"):
			lifecycle.call("_request_chunk_rebuild", chunk_pos)


# ==============================================================================
# LIVE VOXEL REPLICATION & ANTI-CHEAT VALIDATION
# ==============================================================================

## Observer receptor: Translates local live block edits into network RPC requests.
func _on_local_block_modified(global_pos: Vector3i, type: BlockType.Type) -> void:
	if _is_applying_network_sync:
		return
		
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
		
	# NETWORK FIX: If we are the Server (Host), we are the absolute authority. 
	# We apply modifications locally and broadcast them directly via rpc(), 
	# preventing Godot's C++ "RPC on yourself is not allowed" error.
	if multiplayer.is_server():
		rpc("_client_receive_block_modification", global_pos, type as int)
		return
		
	# Clients send the modification upstream to the Server for validation
	rpc_id(1, "_server_receive_block_modification", global_pos, type as int)


## RPC: Executed only on the Server/Host. Validates physical placement distances.
@rpc("any_peer", "reliable")
func _server_receive_block_modification(global_pos: Vector3i, type_val: int) -> void:
	if not multiplayer.is_server():
		return
		
	var sender_id := multiplayer.get_remote_sender_id()
	var is_valid := _validate_client_reach_distance(sender_id, global_pos)
	
	if not is_valid:
		# ANTI-CHEAT: The client spoofed a long-distance block break.
		# Force the client's local game to revert the block to its true server state.
		var correct_type := world_state.get_block(global_pos) as int
		rpc_id(sender_id, "_client_receive_block_modification", global_pos, correct_type)
		return
			
	# Validation passed. Broadcast the change to all other connected peers
	rpc("_client_receive_block_modification", global_pos, type_val)


func _validate_client_reach_distance(sender_id: int, global_pos: Vector3i) -> bool:
	var sender_node := world_controller.get_node_or_null(str(sender_id)) as CharacterBody3D
	if is_instance_valid(sender_node):
		var dist := sender_node.global_position.distance_to(Vector3(global_pos))
		if dist > 8.0: # Prevent hacking/excessive reach distances (Section 1.2)
			push_warning("[VoxelReplicator ANTI-CHEAT] Rejected spoofed block edit from peer: ", sender_id)
			return false
	return true


## RPC: Broadcasted to all peers. Applies the remote voxel change globally.
@rpc("call_local", "reliable")
func _client_receive_block_modification(global_pos: Vector3i, type_val: int) -> void:
	if not is_instance_valid(world_controller):
		return
		
	var block_type := type_val as BlockType.Type
	
	# Activate loop shielding to prevent echoing the edit back to the server
	_is_applying_network_sync = true
	world_controller.call("set_block_globally", global_pos, block_type)
	_is_applying_network_sync = false

# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkPlayerReplica.gd
# Description: Infrastructure Component attached to PlayerController representing
#              a remote peer. Handles network interpolation, Extrapolation for 
#              lost packets, and Server-Side Movement Anti-Cheat Validation.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively spatial network
#   sync operations, isolating latency mitigation logic.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkPlayerReplica
extends Node

# Network update rates and interpolation speeds (Section 5.3)
const NETWORK_TICK_RATE_HZ: float = 0.033 # 30Hz upload update rate
const LERP_SPEED_POSITION: float = 12.0
const LERP_SPEED_ROTATION: float = 10.0

# Anti-Cheat Server Constants
const MAX_LEGAL_DISPLACEMENT_PER_TICK: float = 20.0 # Meters squared

var _host: CharacterBody3D
var _camera: Camera3D

# Network target states synchronized via RPC
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _target_camera_x: float = 0.0

var _last_validated_server_pos: Vector3 = Vector3.ZERO

# Extrapolation accumulators
var _network_timer: float = 0.0
var _time_since_last_update: float = 0.0
var _last_velocity_vector: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "NetworkPlayerReplica"
	_host = get_parent() as CharacterBody3D
	
	if is_instance_valid(_host):
		_camera = _host.get_node_or_null("PlayerCamera") as Camera3D
		_target_position = _host.global_position
		_target_rotation_y = _host.rotation.y
		_last_validated_server_pos = _host.global_position
		
		if is_instance_valid(_camera):
			_target_camera_x = _camera.rotation.x


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_host):
		return
		
	if _host.is_multiplayer_authority():
		_process_authority_upload(delta)
	else:
		_process_remote_interpolation(delta)


func _process_authority_upload(delta: float) -> void:
	# 1. LOCAL AUTHORITY SENDS MOVEMENT (Client Upload)
	_network_timer += delta
	if _network_timer >= NETWORK_TICK_RATE_HZ:
		_network_timer = 0.0
		var cam_rot := _camera.rotation.x if is_instance_valid(_camera) else 0.0
		
		# Send un-reliably for max speed. Occasional packet loss handled via interpolation
		rpc_id(1, "_server_receive_state", _host.global_position, _host.rotation.y, cam_rot)


func _process_remote_interpolation(delta: float) -> void:
	# 2. REMOTE CLONES INTERPOLATE (Client Download / Presentation)
	_time_since_last_update += delta
	
	# Apply predictive Extrapolation if packets are delayed (Latency mitigation)
	var simulated_target := _target_position
	if _time_since_last_update > NETWORK_TICK_RATE_HZ:
		simulated_target += _last_velocity_vector * (_time_since_last_update - NETWORK_TICK_RATE_HZ)
		
	_host.global_position = _host.global_position.lerp(simulated_target, LERP_SPEED_POSITION * delta)
	_host.rotation.y = lerp_angle(_host.rotation.y, _target_rotation_y, LERP_SPEED_ROTATION * delta)
	
	if is_instance_valid(_camera):
		_camera.rotation.x = lerp_angle(_camera.rotation.x, _target_camera_x, LERP_SPEED_ROTATION * delta)


## RPC: Executed only on the Server/Host to authenticate and validate movement
@rpc("any_peer", "unreliable_ordered")
func _server_receive_state(pos: Vector3, rot_y: float, cam_x: float) -> void:
	if not multiplayer.is_server():
		return
		
	# A. Symmetrical authority check: prevent clients spoofing other players ID
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != _host.get_multiplayer_authority():
		return
		
	# B. Server-Authoritative Anti-Cheat Validation (Speedhack/Teleport Prevention)
	var displacement_sq := _last_validated_server_pos.distance_squared_to(pos)
	
	if displacement_sq > MAX_LEGAL_DISPLACEMENT_PER_TICK:
		# Player moved too fast! Rubberband them back to their last valid position
		push_warning("[NetworkReplica ANTI-CHEAT] Speedhack/Teleport detected on Peer: ", sender_id, ". Rubberbanding.")
		rpc_id(sender_id, "_client_force_rubberband", _last_validated_server_pos)
		return
		
	# State is legally valid. Save position and broadcast to all other peers.
	_last_validated_server_pos = pos
	rpc("_client_receive_state", pos, rot_y, cam_x)


## RPC: Server override. Forces a cheating/glitched client back to a valid physical coordinate.
@rpc("authority", "reliable")
func _client_force_rubberband(valid_pos: Vector3) -> void:
	if not _host.is_multiplayer_authority():
		return
		
	print("[NetworkReplica] Server forced position correction (Rubberband).")
	_host.global_position = valid_pos
	_host.velocity = Vector3.ZERO


## RPC: Broadcasted to all other clients to interpolate the remote clone visual representation
@rpc("call_local", "unreliable_ordered")
func _client_receive_state(pos: Vector3, rot_y: float, cam_x: float) -> void:
	# Local authorities bypass network downloads to prevent duplicate rubberbanding
	if _host.is_multiplayer_authority():
		return
		
	# Calculate implied velocity vector for predictive extrapolation
	if _time_since_last_update > 0.0:
		_last_velocity_vector = (pos - _target_position) / _time_since_last_update
		
	_target_position = pos
	_target_rotation_y = rot_y
	_target_camera_x = cam_x
	_time_since_last_update = 0.0

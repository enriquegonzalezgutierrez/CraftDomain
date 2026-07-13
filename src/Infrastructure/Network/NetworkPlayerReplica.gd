# ==============================================================================
# Pathfile: res://src/Infrastructure/Network/NetworkPlayerReplica.gd
# Description: Infrastructure Component attached to PlayerController representing
#              a remote peer. Interpolates received position and rotation (SRP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name NetworkPlayerReplica
extends Node

# Network update rates and interpolation speeds (Section 5.3)
const NETWORK_TICK_RATE_HZ: float = 0.033 # 30Hz update rate
const LERP_SPEED_POSITION: float = 12.0
const LERP_SPEED_ROTATION: float = 10.0

var _host: CharacterBody3D
var _camera: Camera3D

# Network target states synchronized via RPC
var _target_position: Vector3 = Vector3.ZERO
var _target_rotation_y: float = 0.0
var _target_camera_x: float = 0.0

var _network_timer: float = 0.0


func _ready() -> void:
	name = "NetworkPlayerReplica"
	_host = get_parent() as CharacterBody3D
	if is_instance_valid(_host):
		_camera = _host.get_node_or_null("PlayerCamera") as Camera3D
		_target_position = _host.global_position
		_target_rotation_y = _host.rotation.y
		if is_instance_valid(_camera):
			_target_camera_x = _camera.rotation.x


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_host):
		return
		
	if _host.is_multiplayer_authority():
		# 1. LOCAL AUTHORITY SENDS MOVEMENT (Client Upload)
		_network_timer += delta
		if _network_timer >= NETWORK_TICK_RATE_HZ:
			_network_timer = 0.0
			var cam_rot := _camera.rotation.x if is_instance_valid(_camera) else 0.0
			rpc_id(1, "_server_receive_state", _host.global_position, _host.rotation.y, cam_rot)
	else:
		# 2. REMOTE CLONES INTERPOLATE (Client Download / Presentation)
		_host.global_position = _host.global_position.lerp(_target_position, LERP_SPEED_POSITION * delta)
		_host.rotation.y = lerp_angle(_host.rotation.y, _target_rotation_y, LERP_SPEED_ROTATION * delta)
		if is_instance_valid(_camera):
			_camera.rotation.x = lerp_angle(_camera.rotation.x, _target_camera_x, LERP_SPEED_ROTATION * delta)


## RPC: Executed only on the Server/Host to authenticate and validate movement
@rpc("any_peer", "unreliable_ordered")
func _server_receive_state(pos: Vector3, rot_y: float, cam_x: float) -> void:
	# Symmetrical authority check: prevent clients spoofing other players ID
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id != _host.get_multiplayer_authority():
		return
		
	# Server consolidates state and broadcasts/replicates to all other peers
	rpc("_client_receive_state", pos, rot_y, cam_x)


## RPC: Broadcasted to all other clients to interpolate the remote clone visual representation
@rpc("call_local", "unreliable_ordered")
func _client_receive_state(pos: Vector3, rot_y: float, cam_x: float) -> void:
	# Local authorities bypass network downloads to prevent duplicate motion
	if _host.is_multiplayer_authority():
		return
		
	_target_position = pos
	_target_rotation_y = rot_y
	_target_camera_x = cam_x
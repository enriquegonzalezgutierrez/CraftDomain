# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/CameraEffectsComponent.gd
# Description: Infrastructure Component managing first-person camera animations,
#              head bobs, trauma screenshakes, and underwater camera submersion.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CameraEffectsComponent
extends Node

var host: CharacterBody3D
var camera: Camera3D

var _bob_timer: float = 0.0
var _target_camera_pos := Vector3(0.0, 1.6, 0.0)
var _target_camera_tilt: float = 0.0
var _shake_intensity: float = 0.0
var _is_underwater: bool = false

const BASELINE_CAMERA_Y: float = 1.6
const UNDERWATER_FOG_COLOR := Color(0.08, 0.35, 0.65)


func initialize(p_host: CharacterBody3D, p_camera: Camera3D) -> void:
	host = p_host
	camera = p_camera


func apply_trauma_shake(intensity: float) -> void:
	_shake_intensity = clampf(_shake_intensity + intensity, 0.0, 1.0)


func process_camera_effects(delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(camera):
		return
		
	var velocity_flat := Vector2(host.velocity.x, host.velocity.z)
	var horizontal_speed := velocity_flat.length()
	var is_moving := host.is_on_floor() and horizontal_speed > 0.1
	
	_calculate_target_offsets(delta, horizontal_speed, is_moving)
	_apply_interpolated_camera_transforms(delta)
	_evaluate_underwater_camera_submersion()


func _calculate_target_offsets(delta: float, horizontal_speed: float, is_moving: bool) -> void:
	if is_moving:
		_bob_timer += delta * horizontal_speed * 2.2
		var bob_y := sin(_bob_timer) * 0.035
		var bob_x := cos(_bob_timer * 0.5) * 0.018
		_target_camera_pos = Vector3(bob_x, BASELINE_CAMERA_Y + bob_y, 0.0)
		
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		_target_camera_tilt = -input_dir.x * 0.02
	else:
		_bob_timer += delta * 1.5
		var breath_y := sin(_bob_timer) * 0.006
		_target_camera_pos = Vector3(0.0, BASELINE_CAMERA_Y + breath_y, 0.0)
		_target_camera_tilt = 0.0


func _apply_interpolated_camera_transforms(delta: float) -> void:
	var current_pos := camera.position.lerp(_target_camera_pos, delta * 10.0)
	var current_tilt := lerp(camera.rotation.z, _target_camera_tilt, delta * 8.0)
	
	if _shake_intensity > 0.005:
		var shake_x := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		var shake_y := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		var shake_z := randf_range(-_shake_intensity, _shake_intensity) * 0.4
		current_pos += Vector3(shake_x, shake_y, shake_z)
		current_tilt += randf_range(-_shake_intensity, _shake_intensity) * 0.08
		_shake_intensity = lerp(_shake_intensity, 0.0, delta * 9.0)
	else:
		_shake_intensity = 0.0
		
	camera.position = current_pos
	camera.rotation.z = current_tilt


func _evaluate_underwater_camera_submersion() -> void:
	var world_ctrl := host.get("world_controller") as Node3D
	if not is_instance_valid(world_ctrl) or not "world_state" in world_ctrl:
		return
		
	var ws: WorldState = world_ctrl.get("world_state") as WorldState
	if ws == null: return
		
	var cam_pos := camera.global_position
	var cam_coord := Vector3i(floori(cam_pos.x), floori(cam_pos.y), floori(cam_pos.z))
	
	var is_currently_underwater := (ws.get_block(cam_coord) == BlockType.Type.WATER)
	if is_currently_underwater != _is_underwater:
		_is_underwater = is_currently_underwater
		_apply_underwater_environment_effects(_is_underwater, world_ctrl)


func _apply_underwater_environment_effects(underwater: bool, world_ctrl: Node3D) -> void:
	var parent_node := world_ctrl.get_parent()
	if not is_instance_valid(parent_node): return
		
	var env_node := parent_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not is_instance_valid(env_node) or env_node.environment == null: return
		
	var env := env_node.environment
	var hud := host.get("hud") as PlayerHUD
	if is_instance_valid(hud):
		hud.set_underwater_overlay_visible(underwater)
		
	if underwater:
		env.fog_enabled = true
		env.fog_light_color = UNDERWATER_FOG_COLOR
		env.fog_depth_begin = 1.0
		env.fog_depth_end = 18.0
	else:
		if is_instance_valid(CelestialService.instance):
			CelestialService.instance._sync_fog_density_multiplier(env)

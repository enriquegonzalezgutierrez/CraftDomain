# ==============================================================================
# Pathfile: res://src/Infrastructure/World/StreetlightEntity.gd
# Description: Infrastructure Static Entity representing an interactive 3D Streetlight.
#              Controls real-time light and glass emission material transitions.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StreetlightEntity
extends StaticBody3D

@onready var _left_light: OmniLight3D = $LeftLight
@onready var _right_light: OmniLight3D = $RightLight

@onready var _left_glass_mesh: MeshInstance3D = $Visuals/LeftLanternGlass
@onready var _right_glass_mesh: MeshInstance3D = $Visuals/RightLanternGlass

# Local duplicated materials to prevent instancing cross-talk
var _left_mat: StandardMaterial3D
var _right_mat: StandardMaterial3D

var _lights_active: bool = false
var npc_seed: int = 0


func _ready() -> void:
	name = "Prop_STREETLIGHT"
	npc_seed = abs(int(global_position.x * 73856093) ^ int(global_position.z * 19349663))
	
	# Duplicate materials locally so they glow independently
	if is_instance_valid(_left_glass_mesh) and _left_glass_mesh.material_override != null:
		_left_mat = _left_glass_mesh.material_override.duplicate() as StandardMaterial3D
		_left_glass_mesh.material_override = _left_mat
		
	if is_instance_valid(_right_glass_mesh) and _right_glass_mesh.material_override != null:
		_right_mat = _right_glass_mesh.material_override.duplicate() as StandardMaterial3D
		_right_glass_mesh.material_override = _right_mat
	
	# Auto-ignite lights on spawn if it is currently nighttime
	var is_night: bool = CelestialService.is_night_time_static()
	set_lights_active(is_night)


## Smoothly interpolates lighting energy and material emission on night transitions
func set_lights_active(is_night: bool) -> void:
	_lights_active = is_night
	
	var tween := create_tween()
	if tween == null:
		return
		
	tween.set_parallel(true)
	var has_tweeners := false
	var target_energy := 2.6 if is_night else 0.0
	var target_emission := 2.0 if is_night else 0.0
	
	if is_instance_valid(_left_light) and _left_light.is_inside_tree():
		tween.tween_property(_left_light, "light_energy", target_energy, 1.2).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
	if is_instance_valid(_right_light) and _right_light.is_inside_tree():
		tween.tween_property(_right_light, "light_energy", target_energy, 1.2).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
		
	if is_instance_valid(_left_mat):
		tween.tween_property(_left_mat, "emission_energy_multiplier", target_emission, 1.2).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
	if is_instance_valid(_right_mat):
		tween.tween_property(_right_mat, "emission_energy_multiplier", target_emission, 1.2).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
		
	if not has_tweeners:
		tween.kill()

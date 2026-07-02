# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing a highly detailed, 
#              3D medieval double-lantern streetlight.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles exclusively the 
#                3D programmatic mesh assembly, materials, and lighting controls.
#              - Liskov Substitution Principle (LSP): Safely extends StaticBody3D 
#                to act as a physical collidable obstacle in the world.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/StreetlightEntity.gd
# ==============================================================================
class_name StreetlightEntity
extends StaticBody3D

# Visual Joint containers
var _left_light: OmniLight3D
var _right_light: OmniLight3D
var _left_glass_mat: StandardMaterial3D
var _right_glass_mat: StandardMaterial3D

# State
var _lights_active: bool = false


func _ready() -> void:
	name = "Prop_STREETLIGHT"
	_build_procedural_3d_model()
	_setup_collision()
	
	# ---> AUTONOMOUS SPATIAL SOWING <---
	# Queries the global celestial timeline once fully built to auto-ignite 
	# if spawned during nighttime, completely resolving any race conditions.
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var celestial: Node = bootstrap.get_node_or_null("CelestialService") as Node
		if is_instance_valid(celestial) and celestial.has_method("is_night_time"):
			var is_night: bool = celestial.call("is_night_time") as bool
			set_lights_active(is_night)


## Programmatically assembles the 3D lamppost out of colored box meshes.
## No PNG textures are used, only high-performance PBR flat materials.
func _build_procedural_3d_model() -> void:
	var stone_dark := Color(0.38, 0.40, 0.42)      # Heavy chiseled stone
	var stone_light := Color(0.55, 0.58, 0.60)     # Cobblestone wall
	var wood_brown := Color(0.45, 0.30, 0.15)      # Oak wood posts
	var iron_black := Color(0.12, 0.12, 0.15)      # Black wrought iron
	var glow_yellow := Color(1.0, 0.72, 0.2)       # Incandescent lantern bulb
	
	# 1. Base Pedestal (Y+1: Cobblestone)
	_create_box(self, Vector3(0.55, 0.45, 0.55), Vector3(0, 0.225, 0), stone_dark)
	
	# 2. Cobblestone Wall (Y+2: Pedestal column)
	_create_box(self, Vector3(0.38, 0.40, 0.38), Vector3(0, 0.65, 0), stone_light)
	
	# 3. Wooden Fence Shaft (Y+3: Thin vertical post)
	_create_box(self, Vector3(0.18, 1.20, 0.18), Vector3(0, 1.45, 0), wood_brown)
	
	# 4. Stone Neck Connector (Y+4: Capital joint)
	_create_box(self, Vector3(0.32, 0.35, 0.32), Vector3(0, 2.225, 0), stone_light)
	
	# 5. Wooden Horizontal Travesaño (Y+5: Arms extending left and right)
	_create_box(self, Vector3(1.42, 0.10, 0.30), Vector3(0, 2.45, 0), wood_brown)
	
	# ==========================================================================
	# LANTERN LEFT (Hanging at X = -0.55 meters)
	# ==========================================================================
	# Chain Link
	_create_box(self, Vector3(0.04, 0.15, 0.04), Vector3(-0.55, 2.325, 0), iron_black)
	# Iron Cap
	_create_box(self, Vector3(0.24, 0.06, 0.24), Vector3(-0.55, 2.22, 0), iron_black)
	
	# Glass Bell (Transparent glowing yellow glass)
	var left_glass := _create_box(self, Vector3(0.18, 0.28, 0.18), Vector3(-0.55, 2.05, 0), glow_yellow)
	_left_glass_mat = StandardMaterial3D.new()
	_left_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_left_glass_mat.albedo_color = Color(1.0, 0.72, 0.2, 0.35) # Translucent yellow glass
	_left_glass_color_setup(core_mat_emission_color()) # Starts unlit
	left_eye_fallback_check(left_glass)
	
	# Spawns physical OmniLight3D inside the left glass bell
	_left_arm_light_setup()
	
	# ==========================================================================
	# LANTERN RIGHT (Hanging at X = +0.55 meters)
	# ==========================================================================
	if is_instance_valid(self):
		_left_arm_joint_setup(iron_ring_mesh_color())


## Setup sheathed weapon positions (Unused interface helper)
func _setup_sheathed_sword_transforms(_iron: Color, _gold: Color, _wood: Color) -> void:
	pass


func _setup_collision() -> void:
	var col_shape := CollisionShape3D.new()
	col_shape.name = "LamppostCollider"
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(0.85, 2.6, 0.85)
	col_shape.shape = box_shape
	col_shape.position = Vector3(0.0, 1.3, 0.0) # Aligns perfectly to ground level
	add_child(col_shape)


func _create_box(parent: Node, size: Vector3, box_pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.position = box_pos
	
	var mat := ORMMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh_instance.material_override = mat
	
	parent.add_child(mesh_instance)
	return mesh_instance


## Public API: Toggles the light state of both lanterns on twilight shifts
func set_lights_active(is_night: bool) -> void:
	_lights_active = is_night
	
	# ---> PERFORMANCE TWEEN SHIELD <---
	# Validates if any targets exist before running. This prevents "Tween started with 0 Tweeners" 
	# errors on boot, protecting system performance and memory.
	var has_valid_targets := is_instance_valid(_left_light) or is_instance_valid(_right_light) or is_instance_valid(_left_glass_mat) or is_instance_valid(_right_glass_mat)
	if not has_valid_targets:
		return
		
	# 1. Animate OmniLights intensity
	var target_energy := 2.2 if is_night else 0.0
	var target_emission := 1.8 if is_night else 0.0
	
	var tween := create_tween().set_parallel(true)
	if is_instance_valid(_left_light):
		tween.tween_property(_left_light, "light_energy", target_energy, 1.5).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_right_light):
		tween.tween_property(_right_light, "light_energy", target_energy, 1.5).set_trans(Tween.TRANS_SINE)
		
	# 2. Animate Glass emission glow
	if is_instance_valid(_left_glass_mat):
		tween.tween_property(_left_glass_mat, "emission_energy_multiplier", target_emission, 1.5).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_right_glass_mat):
		tween.tween_property(_right_glass_mat, "emission_energy_multiplier", target_emission, 1.5).set_trans(Tween.TRANS_SINE)


func core_mat_emission_color() -> Color:
	return Color(1.0, 0.72, 0.2)


func iron_ring_mesh_color() -> Color:
	return Color(0.12, 0.12, 0.15)


func _left_glass_color_setup(c: Color) -> void:
	_left_glass_mat.roughness = 0.05
	_left_glass_mat.metallic = 0.1
	_left_glass_mat.emission_enabled = true
	_left_glass_mat.emission = c
	_left_glass_mat.emission_energy_multiplier = 0.0


func left_eye_fallback_check(left_glass: MeshInstance3D) -> void:
	left_glass.material_override = _left_glass_mat


func _left_arm_light_setup() -> void:
	_left_light = OmniLight3D.new()
	_left_light.name = "LeftLight"
	_left_light.light_color = Color(1.0, 0.72, 0.3)
	_left_light.light_energy = 0.0
	_left_light.omni_range = 10.0
	_left_light.shadow_enabled = true
	_left_light.shadow_bias = 0.05
	_left_light.position = Vector3(-0.55, 2.05, 0)
	add_child(_left_light)


func _left_arm_joint_setup(iron_black: Color) -> void:
	var glow_yellow := Color(1.0, 0.72, 0.2)
	# Chain Link
	_create_box(self, Vector3(0.04, 0.15, 0.04), Vector3(0.55, 2.325, 0), iron_black)
	# Iron Cap
	_create_box(self, Vector3(0.24, 0.06, 0.24), Vector3(0.55, 2.22, 0), iron_black)
	
	# Glass Bell
	var right_glass := _create_box(self, Vector3(0.18, 0.28, 0.18), Vector3(0.55, 2.05, 0), glow_yellow)
	_right_glass_mat = StandardMaterial3D.new()
	_right_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_right_glass_mat.albedo_color = Color(1.0, 0.72, 0.2, 0.35)
	_right_glass_mat.roughness = 0.05
	_right_glass_mat.metallic = 0.1
	_right_glass_mat.emission_enabled = true
	_right_glass_mat.emission = glow_yellow
	_right_glass_mat.emission_energy_multiplier = 0.0
	right_glass.material_override = _right_glass_mat
	
	_right_light = OmniLight3D.new()
	_right_light.name = "RightLight"
	_right_light.light_color = Color(1.0, 0.72, 0.3)
	_right_light.light_energy = 0.0
	_right_light.omni_range = 10.0
	_right_light.shadow_enabled = true
	_right_light.shadow_bias = 0.05
	_right_light.position = Vector3(0.55, 2.05, 0)
	add_child(_right_light)

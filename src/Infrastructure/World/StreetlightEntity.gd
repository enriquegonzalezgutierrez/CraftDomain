# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Static Entity representing a highly detailed, 
#              3D medieval, cyber, or polar double-lantern streetlight.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively the 
#   3D programmatic mesh assembly, materials, and lighting controls.
# - Liskov Substitution Principle (LSP): Safely extends StaticBody3D 
#   to act as a physical collidable obstacle in the world.
# - Dependency Inversion Principle (DIP): Resolves time-of-day queries 
#   statically through the decoupled CelestialService provider.
# STREETLIGHT PROP PORTABLE THEMING (OCP Compliant - Phase 4):
# - Completely removed the hardcoded `match biome_id` blocks. The streetlight 
#   now queries the coordinate's `IBiome` strategy dynamically, unpacking the 
#   thematic colors in complete OCP and DIP compliance.
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
var npc_seed: int = 0


func _ready() -> void:
	name = "Prop_STREETLIGHT"
	npc_seed = abs(int(global_position.x * 73856093) ^ int(global_position.z * 19349663))
	_build_procedural_3d_model()
	_setup_collision()
	
	# ---> AUTONOMOUS SPATIAL SOWING <---
	# Queries the global celestial timeline statically once fully built to auto-ignite 
	# if spawned during nighttime, completely resolving any race conditions.
	var is_night: bool = CelestialService.is_night_time_static()
	set_lights_active(is_night)


## Programmatically assembles the 3D lamppost out of colored box meshes.
## Automatically queries the coordinate's biome to resolve the theme (OCP/DIP Compliant)
func _build_procedural_3d_model() -> void:
	# 1. Query the active biome strategy for the coordinate
	var biome_id := _detect_current_biome()
	var biome_strategy: IBiome = BiomeService.get_biome(biome_id)
	
	# 2. Unpack the custom themed color palette polimorphically
	var theme: Dictionary = biome_strategy.get_streetlight_theme()
	
	var stone_dark: Color = theme["stone_dark"]
	var stone_light: Color = theme["stone_light"]
	var wood_brown: Color = theme["wood_pole"]
	var iron_black: Color = theme["iron_black"]
	var glow_color: Color = theme["lantern_glow"]
	var light_tint: Color = theme["light_tint"]
	
	# 3. Base Pedestal (Y+1)
	_create_box(self, Vector3(0.55, 0.45, 0.55), Vector3(0, 0.225, 0), stone_dark)
	
	# 4. Main Pedestal column (Y+2)
	_create_box(self, Vector3(0.38, 0.40, 0.38), Vector3(0, 0.65, 0), stone_light)
	
	# 5. Vertical post (Y+3)
	_create_box(self, Vector3(0.18, 1.20, 0.18), Vector3(0, 1.45, 0), wood_brown)
	
	# 6. Capital joint (Y+4)
	_create_box(self, Vector3(0.32, 0.35, 0.32), Vector3(0, 2.225, 0), stone_light)
	
	# 7. Arms extending left and right (Y+5)
	_create_box(self, Vector3(1.42, 0.10, 0.30), Vector3(0, 2.45, 0), wood_brown)
	
	# ==========================================================================
	# LANTERN LEFT (Hanging at X = -0.55 meters)
	# ==========================================================================
	# Chain Link
	_create_box(self, Vector3(0.04, 0.15, 0.04), Vector3(-0.55, 2.325, 0), iron_black)
	# Iron Cap
	_create_box(self, Vector3(0.24, 0.06, 0.24), Vector3(-0.55, 2.22, 0), iron_black)
	
	# Glass Bell (Transparent glowing glass)
	var left_glass := _create_box(self, Vector3(0.18, 0.28, 0.18), Vector3(-0.55, 2.05, 0), glow_color)
	_left_glass_mat = StandardMaterial3D.new()
	_left_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_left_glass_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35) # Translucent glass
	_left_glass_color_setup(glow_color) # Starts unlit
	left_eye_fallback_check(left_glass)
	
	# Spawns physical OmniLight3D inside the left glass bell
	_left_arm_light_setup(light_tint)
	
	# ==========================================================================
	# LANTERN RIGHT (Hanging at X = +0.55 meters)
	# ==========================================================================
	if is_instance_valid(self):
		_left_arm_joint_setup(iron_black, glow_color, light_tint)


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
	
	# 1. Instantiate the tween animator safely
	var tween := create_tween()
	if tween == null:
		return
		
	tween.set_parallel(true)
	
	# ---> TWEEN WORKER HOOK SHIELD <---
	# Keep track of active tweeners. If we have no valid elements to animate, 
	# we kill the tween immediately to prevent "started with no Tweeners" console floods.
	var has_tweeners := false
	
	var target_energy := 2.2 if is_night else 0.0
	var target_emission := 1.8 if is_night else 0.0
	
	if is_instance_valid(_left_light) and _left_light.is_inside_tree():
		tween.tween_property(_left_light, "light_energy", target_energy, 1.5).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
	if is_instance_valid(_right_light) and _right_light.is_inside_tree():
		tween.tween_property(_right_light, "light_energy", target_energy, 1.5).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
		
	if is_instance_valid(_left_glass_mat):
		tween.tween_property(_left_glass_mat, "emission_energy_multiplier", target_emission, 1.5).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
	if is_instance_valid(_right_glass_mat):
		tween.tween_property(_right_glass_mat, "emission_energy_multiplier", target_emission, 1.5).set_trans(Tween.TRANS_SINE)
		has_tweeners = true
		
	# Safe Kill Trigger: Protects the console thread from thrashing
	if not has_tweeners:
		tween.kill()


func _left_glass_color_setup(c: Color) -> void:
	_left_glass_mat.roughness = 0.05
	_left_glass_mat.metallic = 0.1
	_left_glass_mat.emission_enabled = true
	_left_glass_mat.emission = c
	_left_glass_mat.emission_energy_multiplier = 0.0


func left_eye_fallback_check(left_glass: MeshInstance3D) -> void:
	left_glass.material_override = _left_glass_mat


func _left_arm_light_setup(light_tint: Color) -> void:
	_left_light = OmniLight3D.new()
	_left_light.name = "LeftLight"
	_left_light.light_color = light_tint
	_left_light.light_energy = 0.0
	_left_light.omni_range = 10.0
	_left_light.shadow_enabled = true
	_left_light.shadow_bias = 0.05
	_left_light.position = Vector3(-0.55, 2.05, 0)
	add_child(_left_light)


func _left_arm_joint_setup(iron_black: Color, glow_color: Color, light_tint: Color) -> void:
	# Chain Link
	_create_box(self, Vector3(0.04, 0.15, 0.04), Vector3(0.55, 2.325, 0), iron_black)
	# Iron Cap
	_create_box(self, Vector3(0.24, 0.06, 0.24), Vector3(0.55, 2.22, 0), iron_black)
	
	# Glass Bell
	var right_glass := _create_box(self, Vector3(0.18, 0.28, 0.18), Vector3(0.55, 2.05, 0), glow_color)
	_right_glass_mat = StandardMaterial3D.new()
	_right_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_right_glass_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.35)
	_right_glass_mat.roughness = 0.05
	_right_glass_mat.metallic = 0.1
	_right_glass_mat.emission_enabled = true
	_right_glass_mat.emission = glow_color
	_right_glass_mat.emission_energy_multiplier = 0.0
	right_glass.material_override = _right_glass_mat
	
	_right_light = OmniLight3D.new()
	_right_light.name = "RightLight"
	_right_light.light_color = light_tint
	_right_light.light_energy = 0.0
	_right_light.omni_range = 10.0
	_right_light.shadow_enabled = true
	_right_light.shadow_bias = 0.05
	_right_light.position = Vector3(0.55, 2.05, 0)
	add_child(_right_light)


## Queries the coordinate's biome dynamically to resolve theme IDs.
func _detect_current_biome() -> int:
	var world_controller_ref := get_parent()
	var default_biome_id := 2
	
	if is_instance_valid(world_controller_ref) and "generator" in world_controller_ref:
		var gen: WorldGenerator = world_controller_ref.get("generator") as WorldGenerator
		if gen != null:
			var terrain_noise: FastNoiseLite = gen.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				var profile := BiomeService.evaluate_coordinate(
					int(round(global_position.x)), 
					int(round(global_position.z)), 
					terrain_noise
				)
				return profile.biome_id
				
	return default_biome_id

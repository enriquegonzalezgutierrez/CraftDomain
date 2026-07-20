# ==============================================================================
# Pathfile: res://src/Infrastructure/World/StreetlightEntity.gd
# Description: Infrastructure Static Entity representing an interactive 3D Streetlight.
#              Controls real-time light and glass emission material transitions.
#              REFACTORED: Now traverses native .glb materials for emission control.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name StreetlightEntity
extends StaticBody3D

@onready var _left_light: OmniLight3D = $LeftLight
@onready var _right_light: OmniLight3D = $RightLight

var _glass_materials: Array[StandardMaterial3D] = []
var _lights_active: bool = false
var npc_seed: int = 0


func _ready() -> void:
	name = "Prop_STREETLIGHT"
	npc_seed = abs(int(global_position.x * 73856093) ^ int(global_position.z * 19349663))
	
	var model_node := get_node_or_null("Visuals/BodyBobJoint/streetlight") as Node3D
	if is_instance_valid(model_node):
		GLBModelSanitizer.sanitize_model(model_node)
		_duplicate_and_cache_materials(model_node)
	
	var is_night: bool = CelestialService.is_night_time_static()
	set_lights_active(is_night)


## Recursively finds and duplicates any material inside the .glb, caching them locally
func _duplicate_and_cache_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mat: Material = node.material_override
		if mat == null and node.mesh != null:
			mat = node.mesh.surface_get_material(0)
			
		if mat is StandardMaterial3D:
			var new_mat := mat.duplicate() as StandardMaterial3D
			node.material_override = new_mat
			_glass_materials.append(new_mat)
			
	for child: Node in node.get_children():
		_duplicate_and_cache_materials(child)


func apply_biome_theme(theme: Dictionary) -> void:
	if theme.is_empty(): return
	
	var iron_color: Color = theme.get("iron_black", Color(0.12, 0.12, 0.14))
	
	# Apply standard iron color to all materials in the .glb by default
	for mat: StandardMaterial3D in _glass_materials:
		mat.albedo_color = iron_color
		mat.roughness = 0.85
		
	_setup_emissive_theme_colors(theme)


func _setup_emissive_theme_colors(theme: Dictionary) -> void:
	if is_instance_valid(_left_light):
		_left_light.light_color = theme.get("light_tint", Color(1.0, 0.72, 0.3))
	if is_instance_valid(_right_light):
		_right_light.light_color = theme.get("light_tint", Color(1.0, 0.72, 0.3))
		
	var glow: Color = theme.get("lantern_glow", Color(1.0, 0.6, 0.1))
	
	# Any material with transparency enabled acts as the glass bulb
	for mat: StandardMaterial3D in _glass_materials:
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mat.emission = glow
			mat.albedo_color = Color(1.0, 0.75, 0.25, 0.35)


func set_lights_active(is_night: bool) -> void:
	_lights_active = is_night
	
	var tween := create_tween()
	if tween == null: return
		
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
		
	for mat: StandardMaterial3D in _glass_materials:
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			tween.tween_property(mat, "emission_energy_multiplier", target_emission, 1.2).set_trans(Tween.TRANS_SINE)
			has_tweeners = true
			
	if not has_tweeners:
		tween.kill()
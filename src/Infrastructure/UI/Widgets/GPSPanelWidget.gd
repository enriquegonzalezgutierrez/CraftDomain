# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              top coordinates, celestial clock, active biome, and regional compass distances.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating GPS navigation math from the main HUD class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/GPSPanelWidget.gd
# ==============================================================================
class_name GPSPanelWidget
extends Panel

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

var _coords_label: Label
var _biome_label: Label
var _compass_label: Label

# Biome names duplicated here for self-containment
const BIOME_NAMES = {
	0: "Bay of Sails (Spawn Ocean)",
	1: "Warp Plateau (Mario Steps)",
	2: "Golden Bazaar (Village Plains)",
	3: "Craggy Peaks & Caves",
	4: "Frostbite Glaciers (North Cap)",
	5: "Whispering Redwood Forest",
	6: "Red Sandstone Canyons",
	7: {"name": "Neon Ruins (Cyber Basin)"}, # Keep consistent with HUD map
	8: "Swamp of Sighs (Mist Bay)",
	9: "Cloud Kingdom (Floating Isles)"
}

func _ready() -> void:
	name = "GPSPanel"
	_setup_gps_layout()

func _setup_navigation_gps_panel() -> void:
	pass # Legacy placeholder

func _setup_gps_layout() -> void:
	custom_minimum_size = Vector2(500, 85)
	size = Vector2(500, 85)
	
	# Glassmorphic dark slate header style
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.08, 0.08, 0.1, 0.6)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 0.7)
	style.shadow_size = 5
	style.shadow_color = Color(0, 0, 0, 0.3)
	add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(vbox)
	
	# Coords & Clock Label
	_coords_label = Label.new()
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_coords := LabelSettings.new()
	ls_coords.font_size = 14
	ls_coords.font_color = Color(1.0, 0.85, 0.1)
	ls_coords.outline_size = 3
	ls_coords.outline_color = Color.BLACK
	_coords_label.label_settings = ls_coords
	vbox.add_child(_coords_label)
	
	# Biome Label
	_biome_label = Label.new()
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_biome := LabelSettings.new()
	ls_biome.font_size = 15
	ls_biome.font_color = Color(0.9, 0.95, 1.0)
	ls_biome.outline_size = 3
	ls_biome.outline_color = Color.BLACK
	_biome_label.label_settings = ls_biome
	vbox.add_child(_biome_label)
	
	# Compass Landmarks Label
	_compass_label = Label.new()
	_compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_compass := LabelSettings.new()
	ls_compass.font_size = 11
	ls_compass.font_color = Color(0.7, 0.8, 0.9)
	ls_compass.outline_size = 2
	ls_compass.outline_color = Color.BLACK
	_compass_label.label_settings = ls_compass
	vbox.add_child(_compass_label)

## Real-time metric updater: Decoupled navigation loop
func update_widget() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var p_pos := player.global_position
	
	# 1. Retrieve the celestial clock (HH:MM) from CelestialService
	var time_str: String = "12:00"
	var celestial = get_parent().get_parent().get_node_or_null("CelestialService")
	if is_instance_valid(celestial) and celestial.has_method("get_formatted_time"):
		time_str = celestial.call("get_formatted_time")
		
	_coords_label.text = "[ X: %d  ·  Y: %d  ·  Z: %d ]   ·   [ %s ]" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	# 2. Query Biome name from BiomeService dynamically (Zero circular loop dependencies!)
	var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), world_controller.generator._terrain_noise)
	var b_name: String = ""
	
	if profile.biome_id == 7: # Neon Ruins Dictionary fallback
		b_name = "Neon Ruins (Cyber Basin)"
	else:
		b_name = str(BIOME_NAMES[profile.biome_id])
		
	_biome_label.text = "REGION: " + b_name.to_upper()
	
	# 3. Calculate 2D Vector distances to main geographical landmarks dynamically
	var dist_n := int(p_pos.distance_to(Vector3(0.0, p_pos.y, -420.0))) # North Polar cap Spire
	var dist_e := int(p_pos.distance_to(Vector3(300.0, p_pos.y, 5.0))) # East village bazaar
	var dist_s := int(p_pos.distance_to(Vector3(0.0, p_pos.y, 178.0)))  # South Mario steps
	
	_compass_label.text = "[N] Polar Ice: %dm  |  [E] Village Bazaar: %dm  |  [S] Mario Hills: %dm" % [
		dist_n, dist_e, dist_s
	]

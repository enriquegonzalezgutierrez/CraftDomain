# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              top coordinates, celestial clock, and active biome.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating GPS navigation math from the main HUD class.
#              UX UPGRADE (MINECRAFT STYLE): Removed the bulky dark panel background.
#              Text now floats cleanly over the 3D world with strong text outlines.
#              Removed the redundant directional landmark texts to clear up screen space.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/GPSPanelWidget.gd
# ==============================================================================
class_name GPSPanelWidget
extends Control # Changed from Panel to Control to remove the dark background box

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

var _coords_label: Label
var _biome_label: Label

# Biome names duplicated here for self-containment
const BIOME_NAMES = {
	0: "Bay of Sails (Spawn Ocean)",
	1: "Warp Plateau (Mario Steps)",
	2: "Golden Bazaar (Village Plains)",
	3: "Craggy Peaks & Caves",
	4: "Frostbite Glaciers (North Cap)",
	5: "Whispering Redwood Forest",
	6: "Red Sandstone Canyons",
	7: {"name": "Neon Ruins (Cyber Basin)"}, 
	8: "Swamp of Sighs (Mist Bay)",
	9: "Cloud Kingdom (Floating Isles)"
}

func _ready() -> void:
	name = "GPSPanel"
	_setup_gps_layout()

func _setup_gps_layout() -> void:
	# Reduced size since we removed the 3rd line of text
	custom_minimum_size = Vector2(400, 50)
	size = Vector2(400, 50)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	# Tighten the gap between the two lines
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	
	# Coords & Clock Label
	_coords_label = Label.new()
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_coords := LabelSettings.new()
	ls_coords.font_size = 14
	ls_coords.font_color = Color(1.0, 1.0, 1.0) # Clean white instead of gold
	ls_coords.outline_size = 4
	ls_coords.outline_color = Color(0.0, 0.0, 0.0, 0.8) # Strong drop shadow/outline for readability
	_coords_label.label_settings = ls_coords
	vbox.add_child(_coords_label)
	
	# Biome Label
	_biome_label = Label.new()
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_biome := LabelSettings.new()
	ls_biome.font_size = 14
	ls_biome.font_color = Color(0.85, 0.85, 0.85) # Slight off-white
	ls_biome.outline_size = 4
	ls_biome.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	_biome_label.label_settings = ls_biome
	vbox.add_child(_biome_label)

## Real-time metric updater: Decoupled navigation loop
func update_widget() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var p_pos := player.global_position
	
	var time_str: String = "12:00"
	var celestial = get_node_or_null("/root/Bootstrap/CelestialService")
	if is_instance_valid(celestial) and celestial.has_method("get_formatted_time"):
		time_str = celestial.call("get_formatted_time")
		
	# Minimalist formatting
	_coords_label.text = "[ X: %d  Y: %d  Z: %d ]   ·   %s" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	# Query Biome name from BiomeService dynamically
	var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), world_controller.generator._terrain_noise)
	var b_name: String = ""
	
	if profile.biome_id == 7: # Neon Ruins Dictionary fallback
		b_name = "Neon Ruins (Cyber Basin)"
	else:
		b_name = str(BIOME_NAMES[profile.biome_id])
		
	_biome_label.text = b_name.to_upper()

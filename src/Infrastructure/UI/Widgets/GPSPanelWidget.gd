# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              top coordinates, celestial clock, and active biome.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating GPS panel.
#              i18n UPGRADE: Replaced hardcoded biome names with localized 
#              translation keys, ensuring strict OCP compliance.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/GPSPanelWidget.gd
# ==============================================================================
class_name GPSPanelWidget
extends Control

# Dependency injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

var _coords_label: Label
var _biome_label: Label

## Translation keys mapping IDs to global translation tables
const BIOME_KEYS = {
	0: "BIOME_BAY_OF_SAILS",
	1: "BIOME_WARP_PLATEAU",
	2: "BIOME_GOLDEN_BAZAAR",
	3: "BIOME_CRAGGY_MINES",
	4: "BIOME_FROSTBITE_GLACIERS",
	5: "BIOME_REDWOOD_FOREST",
	6: "BIOME_RED_BADLANDS",
	7: "BIOME_NEON_RUINS",
	8: "BIOME_SWAMP_OF_SIGHS",
	9: "BIOME_CLOUD_KINGDOM"
}

func _ready() -> void:
	name = "GPSPanel"
	_setup_gps_layout()

func _setup_gps_layout() -> void:
	# Clean floating design without heavy panels
	custom_minimum_size = Vector2(400, 50)
	size = Vector2(400, 50)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	
	# Coords & Clock Label
	_coords_label = Label.new()
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_coords := LabelSettings.new()
	ls_coords.font_size = 14
	ls_coords.font_color = Color(1.0, 1.0, 1.0)
	ls_coords.outline_size = 4
	ls_coords.outline_color = Color(0.0, 0.0, 0.0, 0.8) # High contrast drop shadow
	_coords_label.label_settings = ls_coords
	vbox.add_child(_coords_label)
	
	# Biome Label
	_biome_label = Label.new()
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_biome := LabelSettings.new()
	ls_biome.font_size = 14
	ls_biome.font_color = Color(0.85, 0.85, 0.85)
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
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	if is_instance_valid(celestial) and celestial.has_method("get_formatted_time"):
		time_str = celestial.call("get_formatted_time") as String
		
	# Coordinates formatting
	_coords_label.text = "[ X: %d  Y: %d  Z: %d ]   ·   %s" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	# Query Biome ID from world generator dynamically and translate it
	var generator = world_controller.get("generator")
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var noise := generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise)
			var key: String = BIOME_KEYS.get(profile.biome_id, "BIOME_BAY_OF_SAILS")
			_biome_label.text = tr(key).to_upper() # Localized and formatted

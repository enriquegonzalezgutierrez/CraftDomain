# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Widget responsible ONLY for rendering the 
#              top coordinates, celestial clock, active biome, and closest
#              fixed Point of Interest (POI) with distance and cardinal compass direction.
#              SOLID COMPLIANCE: Adheres strictly to SRP by isolating navigation.
#              i18n UPGRADE: Uses standardized translation keys for biomes, structures,
#              and dynamic cardinal directions (N, NE, E, SE, S, SW, W, NW).
#              WARNING FIX:
#              - Added explicit static typing `WorldGenerator` to the `generator` 
#                variable and `IMegaStructure` to the `landmark` loop iterator 
#                to completely resolve `UNTYPED_DECLARATION` compiler warnings.
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
var _poi_label: Label # New line for closest landmark tracking

## Translation keys mapping Biome IDs to their i18n codes
const BIOME_NAMES = {
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
	# Clean floating design (Expanded to height 72 to fit 3 lines elegantly)
	custom_minimum_size = Vector2(400, 72)
	size = Vector2(400, 72)
	
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)
	
	# Line 1: Coords & Clock Label
	_coords_label = Label.new()
	_coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_coords := LabelSettings.new()
	ls_coords.font_size = 14; ls_coords.font_color = Color(1.0, 1.0, 1.0)
	ls_coords.outline_size = 4; ls_coords.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	_coords_label.label_settings = ls_coords
	vbox.add_child(_coords_label)
	
	# Line 2: Biome Label
	_biome_label = Label.new()
	_biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_biome := LabelSettings.new()
	ls_biome.font_size = 13; ls_biome.font_color = Color(0.85, 0.85, 0.85)
	ls_biome.outline_size = 4; ls_biome.outline_color = Color(0.0, 0.0, 0.0, 0.8)
	_biome_label.label_settings = ls_biome
	vbox.add_child(_biome_label)
	
	# Line 3: Closest Fixed POI Compass Label
	_poi_label = Label.new()
	_poi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls_poi := LabelSettings.new()
	ls_poi.font_size = 11; ls_poi.font_color = Color(1.0, 0.85, 0.2) # Gold tracking color
	ls_poi.outline_size = 3; ls_poi.outline_color = Color(0.0, 0.0, 0.0, 0.9)
	_poi_label.label_settings = ls_poi
	vbox.add_child(_poi_label)

## Real-time metric updater: Decoupled navigation loop
func update_widget() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var p_pos := player.global_position
	
	# 1. Update Clock
	var time_str: String = "12:00"
	var celestial := get_node_or_null("/root/Bootstrap/CelestialService")
	if is_instance_valid(celestial) and celestial.has_method("get_formatted_time"):
		time_str = celestial.call("get_formatted_time") as String
		
	# 2. Render Coordinates
	_coords_label.text = "[ X: %d  Y: %d  Z: %d ]   ·   %s" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	# 3. Render Localized Biome
	# FIX: Explicit static typing on intermediate generator reference
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var noise := generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise) as BiomeService.BiomeProfile
			_biome_label.text = BiomeService.get_biome(profile.biome_id).get_biome_name()
		
	# 4. Draw Compass / Proximity Landmark
	_update_closest_landmark(p_pos)


## Calculates metrics and directions pointing toward the closest landmark
func _update_closest_landmark(p_pos: Vector3) -> void:
	var landmarks := MegaStructureService.get_structures()
	if landmarks.size() == 0:
		return
		
	var closest_landmark: IMegaStructure = null
	var min_dist := 99999.0
	
	# FIX: Explicit static typing on structures loop iterator
	for landmark: IMegaStructure in landmarks:
		var l_center := Vector2(landmark.global_center.x, landmark.global_center.y)
		var p_flat := Vector2(p_pos.x, p_pos.z)
		var dist := p_flat.distance_to(l_center)
		if dist < min_dist:
			min_dist = dist
			closest_landmark = landmark
			
	if is_instance_valid(closest_landmark):
		var l_center := Vector2(closest_landmark.global_center.x, closest_landmark.global_center.y)
		var p_flat := Vector2(p_pos.x, p_pos.z)
		var diff := l_center - p_flat
		
		# Trigonometric angle to cardinal direction
		var angle_rad := atan2(diff.y, diff.x)
		var angle_deg := rad_to_deg(angle_rad)
		if angle_deg < 0:
			angle_deg += 360.0
			
		var compass_key := ""
		if angle_deg >= 337.5 or angle_deg < 22.5: compass_key = "DIR_E"
		elif angle_deg >= 22.5 and angle_deg < 67.5: compass_key = "DIR_SE"
		elif angle_deg >= 67.5 and angle_deg < 112.5: compass_key = "DIR_S"
		elif angle_deg >= 112.5 and angle_deg < 157.5: compass_key = "DIR_SW"
		elif angle_deg >= 157.5 and angle_deg < 202.5: compass_key = "DIR_W"
		elif angle_deg >= 202.5 and angle_deg < 247.5: compass_key = "DIR_NW"
		elif angle_deg >= 247.5 and angle_deg < 292.5: compass_key = "DIR_N"
		else: compass_key = "DIR_NE"
		
		# Localize structure name and direction strings (i18n compliant!)
		var header_prefix := tr("GPS_CLOSEST_POI_HEADER")
		var landmark_name := tr(closest_landmark.get_name())
		var cardinal_direction := tr(compass_key)
		
		_poi_label.text = "%s: %s (%dm %s)" % [
			header_prefix.to_upper(), 
			landmark_name, 
			int(closest_distance_formatting_clamp(min_dist)), 
			cardinal_direction
		]


func closest_distance_formatting_clamp(dist: float) -> float:
	return clamp(dist, 0.0, 99999.0)

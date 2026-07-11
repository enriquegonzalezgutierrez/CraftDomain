# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/GPSPanelWidget.gd
# Description: Infrastructure UI Widget responsible ONLY for updating the 
#              coordinates, celestial clock, active biome, and closest
#              fixed Point of Interest (POI) metrics. Layout is defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GPSPanelWidget
extends Control

# Dependencies injected by the HUD orchestrator
var player: CharacterBody3D
var world_controller: Node3D

@onready var _coords_label: Label = $VBoxContainer/CoordsLabel
@onready var _biome_label: Label = $VBoxContainer/BiomeLabel
@onready var _poi_label: Label = $VBoxContainer/POILabel


## Real-time metric updater: Decoupled navigation loop
func update_widget() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var p_pos := player.global_position
	
	# 1. Update Clock
	# DIP Compliance: Safely retrieve formatted time statically
	var time_str: String = CelestialService.get_formatted_time_static()
		
	# 2. Render Coordinates
	_coords_label.text = "[ X: %d  Y: %d  Z: %d ]   ·   %s" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	# 3. Render Localized Biome
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
			int(_closest_distance_formatting_clamp(min_dist)), 
			cardinal_direction
		]


func _closest_distance_formatting_clamp(dist: float) -> float:
	return clampf(dist, 0.0, 99999.0)

# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/GPSPanelWidget.gd
# Description: Infrastructure UI Widget responsible for updating 3D position 
#              coordinates, celestial clock, active biome, dynamic weather state,
#              and Point of Interest (POI) proximity metrics.
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


## Real-time metric updater called from the HUD loop at 20Hz
func update_widget() -> void:
	if not is_instance_valid(player) or not is_instance_valid(world_controller):
		return
		
	var p_pos := player.global_position
	var time_str: String = CelestialService.get_formatted_time_static()
	
	_coords_label.text = "[ X: %d  Y: %d  Z: %d ]   ·   %s" % [
		int(round(p_pos.x)), 
		int(round(p_pos.y)), 
		int(round(p_pos.z)),
		time_str
	]
	
	_update_biome_and_weather_display(p_pos)
	_update_closest_landmark(p_pos)


func _update_biome_and_weather_display(p_pos: Vector3) -> void:
	var biome_name := _query_active_biome_name(p_pos)
	var weather_str := _get_active_weather_string()
	
	if is_instance_valid(_biome_label):
		_biome_label.text = "%s   |   %s" % [biome_name, weather_str]


func _query_active_biome_name(p_pos: Vector3) -> String:
	var generator: WorldGenerator = world_controller.get("generator") as WorldGenerator
	if is_instance_valid(generator) and "_terrain_noise" in generator:
		var noise := generator.get("_terrain_noise") as FastNoiseLite
		if noise != null:
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise) as BiomeService.BiomeProfile
			return BiomeService.get_biome(profile.biome_id).get_biome_name()
	return tr("BIOME_GOLDEN_BAZAAR")


func _get_active_weather_string() -> String:
	var weather_type := 0
	var bootstrap := get_node_or_null("/root/Bootstrap")
	
	if is_instance_valid(bootstrap):
		var weather_service := bootstrap.get("weather_service") as Node
		if is_instance_valid(weather_service):
			weather_type = weather_service.get("current_weather") as int
			
	return _format_weather_type_with_icon(weather_type)


func _format_weather_type_with_icon(weather_type: int) -> String:
	match weather_type:
		0: return "☀️ " + tr("WEATHER_SUNNY").to_upper()
		1: return "⛅ " + tr("WEATHER_CLOUDY").to_upper()
		2: return "🌧️ " + tr("WEATHER_RAINY").to_upper()
		3: return "❄️ " + tr("WEATHER_SNOWY").to_upper()
		4: return "🏜️ " + tr("WEATHER_SANDSTORM").to_upper()
		5: return "🌫️ " + tr("WEATHER_FOGGY").to_upper()
	return "☀️ " + tr("WEATHER_SUNNY").to_upper()


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
		_format_landmark_direction_text(closest_landmark, p_pos, min_dist)


func _format_landmark_direction_text(closest_landmark: IMegaStructure, p_pos: Vector3, min_dist: float) -> void:
	var l_center := Vector2(closest_landmark.global_center.x, landmark_center_y(closest_landmark))
	var p_flat := Vector2(p_pos.x, p_pos.z)
	var diff := l_center - p_flat
	
	var angle_deg := rad_to_deg(atan2(diff.y, diff.x))
	if angle_deg < 0: angle_deg += 360.0
		
	var compass_key := _resolve_cardinal_key(angle_deg)
	var header_prefix := tr("GPS_CLOSEST_POI_HEADER")
	var landmark_name := tr(closest_landmark.get_name())
	var cardinal_direction := tr(compass_key)
	
	if is_instance_valid(_poi_label):
		_poi_label.text = "%s: %s (%dm %s)" % [
			header_prefix.to_upper(), 
			landmark_name, 
			int(clampf(min_dist, 0.0, 99999.0)), 
			cardinal_direction
		]


func landmark_center_y(landmark: IMegaStructure) -> float:
	return float(landmark.global_center.y)


func _resolve_cardinal_key(angle_deg: float) -> String:
	if angle_deg >= 337.5 or angle_deg < 22.5: return "DIR_E"
	elif angle_deg >= 22.5 and angle_deg < 67.5: return "DIR_SE"
	elif angle_deg >= 67.5 and angle_deg < 112.5: return "DIR_S"
	elif angle_deg >= 112.5 and angle_deg < 157.5: return "DIR_SW"
	elif angle_deg >= 157.5 and angle_deg < 202.5: return "DIR_W"
	elif angle_deg >= 202.5 and angle_deg < 247.5: return "DIR_NW"
	elif angle_deg >= 247.5 and angle_deg < 292.5: return "DIR_N"
	return "DIR_NE"

# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/CelestialService.gd
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic Sun/Moon rotations, dynamic fog light color syncing,
#              and sky material shader parameter syncing.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CelestialService
extends Node

static var instance: CelestialService = null

var time_speed: float = 96.0
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment
var moon_light: DirectionalLight3D

var _current_time: float = 0.5
var _last_time_value: float = 0.5
var _calendar_days: int = 14 
var _current_storm_weight: float = 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	name = "CelestialService"
	_setup_dynamic_moon_light()


func _process(delta: float) -> void:
	_update_orbital_timers(delta)
	_update_sun_rotation()
	_update_moon_rotation()
	_process_weather_transitions(delta)
	_update_sky_atmosphere()


func _setup_dynamic_moon_light() -> void:
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.0
	moon_light.light_color = Color(0.75, 0.85, 1.0)
	moon_light.light_energy = 0.0 
	moon_light.light_indirect_energy = 1.0
	moon_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	add_child(moon_light)


func _update_orbital_timers(delta: float) -> void:
	_last_time_value = _current_time
	_current_time += (delta * time_speed) / 86400.0
	
	if _current_time >= 1.0:
		_current_time = 0.0
		
	if _last_time_value > 0.95 and _current_time < 0.05:
		_calendar_days += 1
		if _calendar_days > 28:
			_calendar_days = 1


func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light): return
		
	var angle_rad := -((_current_time * TAU) - (PI / 2.0))
	sun_light.rotation.x = angle_rad
	sun_light.rotation.y = deg_to_rad(35)
	
	var is_night := _current_time < 0.24 or _current_time > 0.76
	if is_night:
		sun_light.light_energy = 0.0
		sun_light.shadow_enabled = false
	else:
		sun_light.light_energy = _calculate_sun_light_intensity()
		sun_light.shadow_enabled = true


func _calculate_sun_light_intensity() -> float:
	var intensity := 1.2
	if _current_time < 0.32: 
		intensity = remap(_current_time, 0.24, 0.32, 0.0, 1.2)
	elif _current_time > 0.68: 
		intensity = remap(_current_time, 0.68, 0.76, 1.2, 0.0)
	return clampf(intensity, 0.0, 1.2)


func _update_moon_rotation() -> void:
	if not is_instance_valid(moon_light): return
		
	var angle_rad := -((_current_time * TAU) - (PI / 2.0)) + PI
	moon_light.rotation.x = angle_rad
	# Corrección del plano orbital: Comparte la misma rotación en Y que el Sol (35 grados)
	# para que el desfase en X de 180 grados los coloque en horizontes opuestos.
	moon_light.rotation.y = deg_to_rad(35)


func _calculate_moon_light_intensity() -> float:
	var moon_phase_mult: float = 1.0 - absf((float(_calendar_days) - 14.0) / 14.0)
	var max_intensity: float = 0.06 * moon_phase_mult
	var intensity: float = max_intensity
	
	if _current_time > 0.76 and _current_time < 0.84: 
		intensity = remap(_current_time, 0.76, 0.84, 0.0, max_intensity)
	elif _current_time < 0.24 and _current_time > 0.16: 
		intensity = remap(_current_time, 0.16, 0.24, max_intensity, 0.0)
	return clampf(intensity, 0.0, 0.06)


func _process_weather_transitions(delta: float) -> void:
	var weather_node := get_parent().get_node_or_null("WeatherService") as Node
	var target_storm := 0.0
	if is_instance_valid(weather_node) and weather_node.get("current_weather") != null:
		var w_type := int(weather_node.get("current_weather"))
		if w_type != 0: target_storm = 1.0
			
	_current_storm_weight = lerp(_current_storm_weight, target_storm, delta * 0.4)


func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment): return
	var sky := world_environment.environment.sky
	if sky == null or not (sky.sky_material is ShaderMaterial): return
	
	var sky_mat := sky.sky_material as ShaderMaterial
	var day_weight := _sync_sun_shader_parameters(sky_mat)
	_sync_moon_shader_parameters(sky_mat)
	sky_mat.set_shader_parameter("storm_weight", _current_storm_weight)
	
	_sync_fog_light_color(world_environment.environment, day_weight)


func _sync_sun_shader_parameters(sky_mat: ShaderMaterial) -> float:
	var day_weight := 0.0
	if is_instance_valid(sun_light):
		var sun_dir := sun_light.global_transform.basis.z.normalized()
		var sun_sky_vector := sun_dir.y
		day_weight = clampf(sun_sky_vector * 4.0, 0.0, 1.0)
		
		sky_mat.set_shader_parameter("day_weight", day_weight)
		sky_mat.set_shader_parameter("sun_direction", sun_dir)
	return day_weight


func _sync_moon_shader_parameters(sky_mat: ShaderMaterial) -> void:
	if is_instance_valid(moon_light):
		var moon_dir := moon_light.global_transform.basis.z.normalized()
		var moon_phase_val := float(_calendar_days) / 28.0
		
		sky_mat.set_shader_parameter("moon_direction", moon_dir)
		sky_mat.set_shader_parameter("moon_phase", moon_phase_val)


func _sync_fog_light_color(env: Environment, day_weight: float) -> void:
	if not env.fog_enabled:
		return
		
	var day_fog_color := Color(0.42, 0.65, 0.88)
	var night_fog_color := Color(0.015, 0.02, 0.04)
	var storm_fog_color := Color(0.12, 0.13, 0.15)
	
	var base_fog_color := night_fog_color.lerp(day_fog_color, day_weight)
	env.fog_light_color = base_fog_color.lerp(storm_fog_color, _current_storm_weight * 0.72)


func is_night_time() -> bool:
	return _current_time < 0.24 or _current_time > 0.76


func get_moon_phase_name() -> String:
	if _calendar_days == 14: return "Full Moon"
	elif _calendar_days == 1 or _calendar_days == 28: return "New Moon"
	elif _calendar_days < 7 or (_calendar_days > 7 and _calendar_days < 14): return "Waxing Crescent"
	elif _calendar_days == 7: return "First Quarter"
	elif _calendar_days >= 15 and _calendar_days < 21: return "Waning Gibbous"
	elif _calendar_days == 21: return "Third Quarter"
	return "Waning Crescent"


func get_formatted_time() -> String:
	var total_minutes := int(floor(_current_time * 1440.0))
	return "%02d:%02d" % [int(float(total_minutes) / 60.0), int(total_minutes % 60)]


static func is_night_time_static() -> bool:
	return instance.is_night_time() if is_instance_valid(instance) else false


static func get_formatted_time_static() -> String:
	return instance.get_formatted_time() if is_instance_valid(instance) else "12:00"

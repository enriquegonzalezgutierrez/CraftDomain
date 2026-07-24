# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/CelestialService.gd
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              astronomically aligned Sun/Moon orbits, sky shader uniforms,
#              and dynamic polar aurora borealis intensity modulation.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CelestialService
extends Node

static var instance: CelestialService = null

# --- ATMOSPHERIC HORIZON CONSTANTS ---
const DAY_HORIZON_COLOR := Color(0.78, 0.88, 0.95)
const SUNSET_HORIZON_COLOR := Color(0.98, 0.52, 0.22)
const NIGHT_HORIZON_COLOR := Color(0.02, 0.03, 0.05)
const STORM_HORIZON_COLOR := Color(0.12, 0.13, 0.16)
const LIGHTNING_FLASH_COLOR := Color(0.85, 0.90, 1.00)

var time_speed: float = 96.0
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment
var moon_light: DirectionalLight3D

var _current_time: float = 0.5
var _last_time_value: float = 0.5
var _calendar_days: int = 14 
var _current_storm_weight: float = 0.0
var _active_aurora_intensity: float = 0.0

var _weather_service: WeatherService

var _lightning_timer: float = 8.0
var _lightning_flash_phase: int = 0 
var _lightning_energy_boost: float = 0.0
var _is_flashing: bool = false
var _flash_duration: float = 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self: instance = null


func _ready() -> void:
	name = "CelestialService"
	_setup_dynamic_moon_light()
	_lightning_timer = randf_range(15.0, 30.0)


func _process(delta: float) -> void:
	var safe_delta := clampf(delta, 0.0, 0.1)
	_locate_weather_service_if_missing()
	_update_orbital_timers(safe_delta)
	_process_lightning_strikes(safe_delta)
	_update_sun_rotation()
	_update_moon_rotation()
	_process_weather_transitions(safe_delta)
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


func _locate_weather_service_if_missing() -> void:
	if _weather_service == null and is_instance_valid(get_parent()):
		_weather_service = get_parent().get_node_or_null("WeatherService") as WeatherService


func _update_orbital_timers(delta: float) -> void:
	_last_time_value = _current_time
	_current_time = fmod(_current_time + (delta * time_speed) / 86400.0, 1.0)
	if _last_time_value > 0.95 and _current_time < 0.05:
		_calendar_days = 1 if _calendar_days >= 28 else _calendar_days + 1


func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light): return
		
	var sun_pos := _calculate_sun_position_vector()
	sun_light.global_position = sun_pos * 500.0
	sun_light.look_at(Vector3.ZERO, Vector3.UP)
	
	var is_day := sun_pos.y > -0.05
	sun_light.light_energy = _calculate_sun_light_intensity() if is_day else 0.0
	sun_light.shadow_enabled = is_day


func _calculate_sun_position_vector() -> Vector3:
	var theta_sun := (_current_time - 0.25) * TAU
	return Vector3(cos(theta_sun), sin(theta_sun), 0.15).normalized()


func _update_moon_rotation() -> void:
	if not is_instance_valid(moon_light): return
		
	var moon_pos := _calculate_moon_position_vector()
	moon_light.global_position = moon_pos * 500.0
	moon_light.look_at(Vector3.ZERO, Vector3.UP)
	
	var is_night := moon_pos.y > -0.05
	moon_light.light_energy = _calculate_moon_light_intensity() if is_night else 0.0
	moon_light.shadow_enabled = is_night


func _calculate_moon_position_vector() -> Vector3:
	var theta_moon := (_current_time - 0.25) * TAU + PI
	return Vector3(cos(theta_moon), sin(theta_moon), 0.15).normalized()


func _calculate_sun_light_intensity() -> float:
	var intensity: float = 1.2
	if _current_time < 0.32: intensity = remap(_current_time, 0.24, 0.32, 0.0, 1.2)
	elif _current_time > 0.68: intensity = remap(_current_time, 0.68, 0.76, 1.2, 0.0)
		
	var storm_dim: float = lerpf(1.0, 0.22, clampf(_current_storm_weight, 0.0, 1.0))
	var final_intensity: float = intensity * storm_dim
	
	if _is_flashing and _lightning_energy_boost > 0.1:
		var boost: float = _lightning_energy_boost * (0.15 if _is_player_indoors() else 1.0)
		final_intensity += boost
		
	return clampf(final_intensity, 0.0, 10.0)


func _calculate_moon_light_intensity() -> float:
	var moon_phase_mult := 1.0 - absf((float(_calendar_days) - 14.0) / 14.0)
	var max_intensity := 0.06 * moon_phase_mult
	var intensity := max_intensity
	
	if _current_time > 0.76 and _current_time < 0.84: intensity = remap(_current_time, 0.76, 0.84, 0.0, max_intensity)
	elif _current_time < 0.24 and _current_time > 0.16: intensity = remap(_current_time, 0.16, 0.24, max_intensity, 0.0)
		
	var storm_factor: float = lerpf(1.0, 0.3, clampf(_current_storm_weight, 0.0, 1.0))
	return clampf(intensity * storm_factor, 0.0, 0.06)


func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment): return
	var sky: Sky = world_environment.environment.sky
	if sky == null or not (sky.sky_material is ShaderMaterial): return
	
	var sky_mat: ShaderMaterial = sky.sky_material as ShaderMaterial
	var day_weight := _sync_sun_shader_parameters(sky_mat)
	_sync_moon_shader_parameters(sky_mat)
	_sync_aurora_shader_parameters(sky_mat, day_weight)
	
	sky_mat.set_shader_parameter("storm_weight", _current_storm_weight)
	_sync_fog_light_color(world_environment.environment, day_weight)
	_sync_fog_density_multiplier(world_environment.environment)


func _sync_sun_shader_parameters(sky_mat: ShaderMaterial) -> float:
	var sun_pos := _calculate_sun_position_vector()
	var day_weight := clampf(sun_pos.y * 4.0, 0.0, 1.0)
	sky_mat.set_shader_parameter("day_weight", day_weight)
	sky_mat.set_shader_parameter("sun_direction", sun_pos)
	return day_weight


func _sync_moon_shader_parameters(sky_mat: ShaderMaterial) -> void:
	var moon_pos := _calculate_moon_position_vector()
	sky_mat.set_shader_parameter("moon_direction", moon_pos)
	sky_mat.set_shader_parameter("moon_phase", float(_calendar_days) / 28.0)


func _sync_aurora_shader_parameters(sky_mat: ShaderMaterial, day_weight: float) -> void:
	var biome_id := _get_player_biome_id()
	var is_polar_or_celestial := (biome_id == 4 or biome_id == 9) # Frostbite Glaciers & Cloud Kingdom
	var night_factor := clampf(1.0 - day_weight, 0.0, 1.0)
	
	var target_intensity := 1.0 if (is_polar_or_celestial and night_factor > 0.1) else 0.0
	target_intensity *= (1.0 - _current_storm_weight * 0.8)
	
	_active_aurora_intensity = lerpf(_active_aurora_intensity, target_intensity, get_process_delta_time() * 2.0)
	sky_mat.set_shader_parameter("aurora_intensity", _active_aurora_intensity)


func _get_player_biome_id() -> int:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		var world_ctrl := bootstrap.get("world_controller") as Node3D
		if is_instance_valid(player_node) and is_instance_valid(world_ctrl):
			return BiomeService.get_biome_id_at_position(player_node.global_position, world_ctrl)
	return 2


func _process_lightning_strikes(delta: float) -> void:
	if not _is_world_fully_active() or _weather_service == null or _weather_service.current_weather != IClimateProfile.ClimateType.RAINY:
		_is_flashing = false
		_lightning_energy_boost = 0.0
		return
		
	if _is_flashing:
		_flash_duration -= delta
		if _flash_duration <= 0.0: _advance_lightning_phase()
	else:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0: _trigger_new_lightning()


func _trigger_new_lightning() -> void:
	_is_flashing = true
	_lightning_flash_phase = 1
	_lightning_energy_boost = 6.5 
	_flash_duration = 0.08 
	AudioService.play_sfx_static("thunder_strike", Vector3.ZERO)


func _advance_lightning_phase() -> void:
	match _lightning_flash_phase:
		1:
			_lightning_flash_phase = 2
			_lightning_energy_boost = 0.0
			_flash_duration = 0.12 
		2:
			_lightning_flash_phase = 3
			_lightning_energy_boost = 4.0 
			_flash_duration = 0.22
		3:
			_is_flashing = false
			_lightning_energy_boost = 0.0
			_lightning_timer = randf_range(12.0, 28.0)


func _process_weather_transitions(delta: float) -> void:
	var target_storm := 0.0
	if is_instance_valid(_weather_service):
		var w_type: IClimateProfile.ClimateType = _weather_service.current_weather
		if w_type != IClimateProfile.ClimateType.SUNNY and w_type != IClimateProfile.ClimateType.FOGGY:
			target_storm = 1.0
			
	_current_storm_weight = lerpf(_current_storm_weight, target_storm, clampf(delta * 0.4, 0.0, 1.0))


func _sync_fog_light_color(env: Environment, day_weight: float) -> void:
	if not env.fog_enabled: return
	
	var sun_dir := _calculate_sun_position_vector()
	var sunset_factor := _calculate_sunset_factor(sun_dir, day_weight)
	
	var day_sky := DAY_HORIZON_COLOR.lerp(SUNSET_HORIZON_COLOR, sunset_factor)
	var active_horizon := NIGHT_HORIZON_COLOR.lerp(day_sky, clampf(day_weight, 0.0, 1.0))
	active_horizon = active_horizon.lerp(STORM_HORIZON_COLOR, clampf(_current_storm_weight * 0.85, 0.0, 1.0))
	
	var sun_glare := _calculate_sun_forward_scattering(sun_dir, day_weight)
	var target_fog := active_horizon + sun_glare
	
	if _is_flashing and _lightning_energy_boost > 0.0 and not _is_player_indoors():
		env.fog_light_color = LIGHTNING_FLASH_COLOR
	else:
		env.fog_light_color = target_fog


func _calculate_sunset_factor(sun_dir: Vector3, day_weight: float) -> float:
	var sun_elevation := clampf(sun_dir.y, -0.2, 0.2)
	var norm_elev := absf(sun_elevation) / 0.2
	var smooth_elev := smoothstep(1.0, 0.0, norm_elev)
	return smooth_elev * clampf(day_weight * 2.0, 0.0, 1.0)


func _calculate_sun_forward_scattering(sun_dir: Vector3, day_weight: float) -> Color:
	var camera_dir := _get_camera_look_direction()
	if camera_dir == Vector3.ZERO:
		return Color.BLACK
		
	var sun_dot := maxf(0.0, camera_dir.dot(sun_dir.normalized()))
	var glare_intensity := pow(sun_dot, 8.0) * 0.25 * day_weight
	return Color(1.0, 0.92, 0.78) * glare_intensity


func _get_camera_look_direction() -> Vector3:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_node):
			var camera_node := player_node.get_node_or_null("PlayerCamera") as Camera3D
			if is_instance_valid(camera_node):
				return -camera_node.global_transform.basis.z.normalized()
	return Vector3.ZERO


func _sync_fog_density_multiplier(env: Environment) -> void:
	if not env.fog_enabled: return
	var fog_mult: float = _weather_service.active_fog_multiplier if is_instance_valid(_weather_service) else 1.0
	var height_factor := remap(clampf(_get_player_altitude(), 5.0, 22.0), 5.0, 22.0, 1.2, 0.15)
	
	var is_low_end: bool = (RenderingServer.get_video_adapter_type() == 1 or RenderingServer.get_video_adapter_type() == 4)
	var base_begin := 40.0 if is_low_end else 65.0
	var base_end := 80.0 if is_low_end else 120.0
	
	var final_mult := fog_mult * height_factor
	env.fog_depth_begin = clampf(base_begin / final_mult, 8.0, base_begin * 5.0)
	env.fog_depth_end = clampf(base_end / final_mult, 20.0, base_end * 5.0)


func _get_player_altitude() -> float:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_node): return player_node.global_position.y
	return 12.0


func _is_player_indoors() -> bool:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): return false
	var player_node := bootstrap.get("player_controller") as CharacterBody3D
	var world_ctrl := bootstrap.get("world_controller") as Node3D
	
	if is_instance_valid(player_node) and is_instance_valid(world_ctrl):
		var ws := world_ctrl.get("world_state") as WorldState
		if is_instance_valid(ws) and player_node.get("is_active") == true:
			var p_pos := player_node.global_position
			for y in range(floori(p_pos.y) + 2, 32):
				if BlockLibrary.is_solid(ws.get_block(Vector3i(floori(p_pos.x), y, floori(p_pos.z)))):
					return true
	return false


func _is_world_fully_active() -> bool:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_node): return player_node.get("is_active") == true
	return false


func is_night_time() -> bool:
	return _current_time < 0.24 or _current_time > 0.76


func get_formatted_time() -> String:
	var total_minutes := int(floor(_current_time * 1440.0))
	return "%02d:%02d" % [int(float(total_minutes) / 60.0), int(total_minutes % 60)]


static func is_night_time_static() -> bool:
	return instance.is_night_time() if is_instance_valid(instance) else false


static func get_formatted_time_static() -> String:
	return instance.get_formatted_time() if is_instance_valid(instance) else "12:00"

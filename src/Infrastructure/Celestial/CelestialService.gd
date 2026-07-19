# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/CelestialService.gd
# Description: Infrastructure Celestial Service managing global game time-of-day,
#              dynamic Sun/Moon rotations, dynamic fog light color syncing,
#              and sky material shader parameter syncing.
#              WEATHER UPGRADE: Added real-time atmospheric dimming, dynamic
#              fog density scale syncing, and procedural double-flash lightning.
#              FOG SOFTENING: Re-calibrated altitude remapping factor from 3.0 
#              to 1.2 to extend standard ground horizon visual clearance.
#              INDOOR SAFETY: Added a fast 3D block-casting sensor to suppress 
#              and dampen lightning flashes and fog color leaks inside houses.
#              STARTUP SHIELD: Blocks lightning processing during loading screens 
#              and CPU thread stalls to prevent silent, glitchy flashes on spawn.
#              STABILITY: Implemented Defensive Delta Clamping to protect simulation 
#              timers and color interpolations from main thread loading lag-spikes.
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

var _weather_service: WeatherService

# Procedural Lightning states
var _lightning_timer: float = 8.0
var _lightning_flash_phase: int = 0 # 0 = Off, 1 = Flash A, 2 = Dark Interval, 3 = Flash B
var _lightning_energy_boost: float = 0.0
var _is_flashing: bool = false
var _flash_duration: float = 0.0


func _enter_tree() -> void:
	instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	name = "CelestialService"
	_setup_dynamic_moon_light()


func _process(delta: float) -> void:
	# Defensive Delta Clamping: Prevents simulation and timer blowout during loading stalls
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
	# Symmetrical lookup: check if we are currently inside the Showcase Room
	var showcase := get_tree().root.find_child("AIShowcaseRoom", true, false)
	if is_instance_valid(showcase):
		_weather_service = showcase.get_node_or_null("WeatherService") as WeatherService
		return
		
	if _weather_service == null:
		var parent_node := get_parent()
		if is_instance_valid(parent_node):
			_weather_service = parent_node.get_node_or_null("WeatherService") as WeatherService


func _update_orbital_timers(delta: float) -> void:
	_last_time_value = _current_time
	_current_time += (delta * time_speed) / 86400.0
	
	if _current_time >= 1.0:
		_current_time = 0.0
		
	if _last_time_value > 0.95 and _current_time < 0.05:
		_calendar_days += 1
		if _calendar_days > 28:
			_calendar_days = 1


## Procedural Lightning engine: Coordinates double-flash lightning in storms
func _process_lightning_strikes(delta: float) -> void:
	# Symmetrical Startup Shield: Prevent lightning during loading screen frames
	if not _is_world_fully_active():
		_is_flashing = false
		_lightning_energy_boost = 0.0
		_lightning_timer = 8.0 # Reset timer to prevent instant post-load flashes
		return
		
	if _weather_service == null or _weather_service.current_weather != IClimateProfile.ClimateType.RAINY:
		_is_flashing = false
		_lightning_energy_boost = 0.0
		return
		
	if _is_flashing:
		_ghost_flee_safeguard(delta)
	else:
		_lightning_timer -= delta
		if _lightning_timer <= 0.0:
			_trigger_new_lightning()


func _ghost_flee_safeguard(delta: float) -> void:
	_flash_duration -= delta
	if _flash_duration <= 0.0:
		_advance_lightning_phase()


func _trigger_new_lightning() -> void:
	_is_flashing = true
	_lightning_flash_phase = 1
	_lightning_energy_boost = 6.5 
	_flash_duration = 0.08 
	
	print("[CelestialService] Lightning Flash! Triggering instantaneous Thunder strike sound.")
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


func _update_sun_rotation() -> void:
	if not is_instance_valid(sun_light): return
		
	var angle_rad: float = -((_current_time * TAU) - (PI / 2.0))
	sun_light.rotation.x = angle_rad
	sun_light.rotation.y = deg_to_rad(35)
	
	var is_night: bool = _current_time < 0.24 or _current_time > 0.76
	if is_night:
		sun_light.light_energy = 0.0
		sun_light.shadow_enabled = false
	else:
		sun_light.light_energy = _calculate_sun_light_intensity()
		sun_light.shadow_enabled = true


func _calculate_sun_light_intensity() -> float:
	var intensity: float = 1.2
	if _current_time < 0.32: 
		intensity = remap(_current_time, 0.24, 0.32, 0.0, 1.2)
	elif _current_time > 0.68: 
		intensity = remap(_current_time, 0.68, 0.76, 1.2, 0.0)
		
	var storm_dim: float = lerp(1.0, 0.22, _current_storm_weight)
	var final_intensity: float = intensity * storm_dim
	
	if _is_flashing and _lightning_energy_boost > 0.1:
		var boost := _lightning_energy_boost
		if _is_player_indoors():
			boost *= 0.15 # 85% light flash mitigation inside houses
		final_intensity += boost
		
	return clampf(final_intensity, 0.0, 10.0)


func _update_moon_rotation() -> void:
	if not is_instance_valid(moon_light): return
		
	var angle_rad: float = -((_current_time * TAU) - (PI / 2.0)) + PI
	moon_light.rotation.x = angle_rad
	moon_light.rotation.y = deg_to_rad(35)


func _calculate_moon_light_intensity() -> float:
	var moon_phase_mult: float = 1.0 - absf((float(_calendar_days) - 14.0) / 14.0)
	var max_intensity: float = 0.06 * moon_phase_mult
	var intensity: float = max_intensity
	
	if _current_time > 0.76 and _current_time < 0.84: 
		intensity = remap(_current_time, 0.76, 0.84, 0.0, max_intensity)
	elif _current_time < 0.24 and _current_time > 0.16: 
		intensity = remap(_current_time, 0.16, 0.24, max_intensity, 0.0)
		
	var storm_dim: float = lerp(1.0, 0.3, _current_storm_weight)
	return clampf(intensity * storm_dim, 0.0, 0.06)


func _process_weather_transitions(delta: float) -> void:
	var target_storm: float = 0.0
	if is_instance_valid(_weather_service):
		var w_type: IClimateProfile.ClimateType = _weather_service.current_weather
		if w_type != IClimateProfile.ClimateType.SUNNY and w_type != IClimateProfile.ClimateType.FOGGY:
			target_storm = 1.0
			
	_current_storm_weight = lerp(_current_storm_weight, target_storm, delta * 0.4)


func _update_sky_atmosphere() -> void:
	if not is_instance_valid(world_environment) or not is_instance_valid(world_environment.environment): return
	var sky: Sky = world_environment.environment.sky
	if sky == null or not (sky.sky_material is ShaderMaterial): return
	
	var sky_mat: ShaderMaterial = sky.sky_material as ShaderMaterial
	var day_weight: float = _sync_sun_shader_parameters(sky_mat)
	_sync_moon_shader_parameters(sky_mat)
	sky_mat.set_shader_parameter("storm_weight", _current_storm_weight)
	
	_sync_fog_light_color(world_environment.environment, day_weight)
	_sync_fog_density_multiplier(world_environment.environment)


func _sync_sun_shader_parameters(sky_mat: ShaderMaterial) -> float:
	var day_weight: float = 0.0
	if is_instance_valid(sun_light):
		var sun_dir: Vector3 = sun_light.global_transform.basis.z.normalized()
		var sun_sky_vector: float = sun_dir.y
		day_weight = clampf(sun_sky_vector * 4.0, 0.0, 1.0)
		
		sky_mat.set_shader_parameter("day_weight", day_weight)
		sky_mat.set_shader_parameter("sun_direction", sun_dir)
	return day_weight


func _sync_moon_shader_parameters(sky_mat: ShaderMaterial) -> void:
	if is_instance_valid(moon_light):
		var moon_dir: Vector3 = moon_light.global_transform.basis.z.normalized()
		var moon_phase_val: float = float(_calendar_days) / 28.0
		
		sky_mat.set_shader_parameter("moon_direction", moon_dir)
		sky_mat.set_shader_parameter("moon_phase", moon_phase_val)


func _sync_fog_light_color(env: Environment, day_weight: float) -> void:
	if not env.fog_enabled:
		return
		
	var day_fog_color: Color = Color(0.42, 0.65, 0.88)
	var night_fog_color: Color = Color(0.015, 0.02, 0.04)
	var storm_fog_color: Color = Color(0.12, 0.13, 0.15)
	var lightning_color: Color = Color(0.85, 0.9, 1.0)
	
	var base_fog_color: Color = night_fog_color.lerp(day_fog_color, day_weight)
	var target_fog: Color = base_fog_color.lerp(storm_fog_color, _current_storm_weight * 0.72)
	
	if _is_flashing and _lightning_energy_boost > 0.0:
		if _is_player_indoors():
			env.fog_light_color = target_fog 
		else:
			env.fog_light_color = lightning_color
	else:
		env.fog_light_color = target_fog


## Height-Fog Coordinator: Pulls fog close in valleys and pushes it out in high altitudes (SRP)
func _sync_fog_density_multiplier(env: Environment) -> void:
	if not env.fog_enabled:
		return
		
	var fog_mult: float = 1.0
	if is_instance_valid(_weather_service):
		fog_mult = _weather_service.active_fog_multiplier
		
	var player_y := _get_player_altitude()
	
	# FOG SOFTENING LIMITS: Slashed baseline density factor from 3.0 to 1.2.
	var height_factor := remap(clampf(player_y, 5.0, 22.0), 5.0, 22.0, 1.2, 0.15)
	var final_multiplier := fog_mult * height_factor
	
	_apply_environment_fog_limits(env, final_multiplier)


func _get_player_altitude() -> float:
	var player_y: float = 12.0 
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_node):
			player_y = player_node.global_position.y
	return player_y


func _apply_environment_fog_limits(env: Environment, final_multiplier: float) -> void:
	var adapter_type: int = RenderingServer.get_video_adapter_type()
	var is_low_end: bool = (adapter_type == 1 or adapter_type == 4)
	
	var base_begin := 40.0 if is_low_end else 65.0
	var base_end := 80.0 if is_low_end else 120.0
	
	env.fog_depth_begin = clampf(base_begin / final_multiplier, 8.0, base_begin * 5.0)
	env.fog_depth_end = clampf(base_end / final_multiplier, 20.0, base_end * 5.0)


## Voxel Raycaster: Detects if there is any solid block above the player's head
func _is_player_indoors() -> bool:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap):
		return false
		
	var player_node := bootstrap.get("player_controller") as CharacterBody3D
	var world_ctrl := bootstrap.get("world_controller") as Node3D
	
	if is_instance_valid(player_node) and is_instance_valid(world_ctrl):
		var ws := world_ctrl.get("world_state") as WorldState
		if is_instance_valid(ws) and player_node.get("is_active") == true:
			var p_pos := player_node.global_position
			var feet_coord := Vector3i(floori(p_pos.x), floori(p_pos.y), floori(p_pos.z))
			
			# Scan upwards from head level to world ceiling height limit (31)
			for y in range(feet_coord.y + 2, 32):
				var block := ws.get_block(Vector3i(feet_coord.x, y, feet_coord.z))
				if BlockType.is_solid(block):
					return true
	return false


func _is_world_fully_active() -> bool:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap):
		var player_node := bootstrap.get("player_controller") as CharacterBody3D
		if is_instance_valid(player_node):
			return player_node.get("is_active") == true
	return false


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
	var total_minutes: int = int(floor(_current_time * 1440.0))
	return "%02d:%02d" % [int(float(total_minutes) / 60.0), int(total_minutes % 60)]


static func is_night_time_static() -> bool:
	return instance.is_night_time() if is_instance_valid(instance) else false


static func get_formatted_time_static() -> String:
	return instance.get_formatted_time() if is_instance_valid(instance) else "12:00"

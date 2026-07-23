# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/WeatherService.gd
# Description: Infrastructure Weather Service managing dynamic meteorological cycles,
#              real-time GPU particle overrides, and smooth cloud coverage shader sync.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeatherService
extends Node

var current_weather: IClimateProfile.ClimateType = IClimateProfile.ClimateType.SUNNY
var active_fog_multiplier: float = 1.0

var player: CharacterBody3D
var world_controller: WorldController

var _weather_timer: float = 90.0 
var _gust_timer: float = 8.0     
var _gust_duration: float = 0.0
var _gust_multiplier: float = 1.0
var _is_gusting: bool = false

var _particles: GPUParticles3D
var _particles_material: ParticleProcessMaterial
var _particles_mesh: BoxMesh
var _mesh_material: ORMMaterial3D

var _current_wind_strength: float = 0.4
var _current_wind_vector: Vector2 = Vector2.ZERO
var _current_cloud_coverage_cache: float = 0.0

var _wind_accum_offset: Vector2 = Vector2.ZERO
var _wind_wave_time: float = 0.0

static var _globals_initialized: bool = false


func _ready() -> void:
	name = "WeatherService"
	_setup_global_wind_parameters()
	_setup_particles_system()
	_cycle_weather()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	if is_instance_valid(_particles):
		_particles.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
		_process_indoor_rain_safety()
		
	_process_wind_gusts(delta)
	_update_weather_and_shader_coverage(delta)
	
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()


func _update_weather_and_shader_coverage(delta: float) -> void:
	var biome_id := _detect_player_biome_id()
	var profile := BiomeService.get_biome(biome_id).get_climate_profile()
	
	_process_dynamic_wind_simulation(delta, profile)
	_update_shader_cloud_coverage(delta)


func _setup_global_wind_parameters() -> void:
	if _globals_initialized:
		return
	_globals_initialized = true
	RenderingServer.global_shader_parameter_set("wind_vector", Vector2(0.3, 0.1))
	RenderingServer.global_shader_parameter_set("wind_strength", 0.4)


func _setup_particles_system() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "WeatherParticles"
	_particles.emitting = false
	_particles.amount = 350
	_particles.lifetime = 1.5
	
	_particles_material = ParticleProcessMaterial.new()
	_particles_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particles_material.emission_box_extents = Vector3(18.0, 1.0, 18.0) 
	_particles_material.direction = Vector3(0.0, -1.0, 0.0)
	_particles_material.spread = 4.0
	_particles_material.initial_velocity_min = 12.0
	_particles_material.initial_velocity_max = 16.0
	_particles_material.gravity = Vector3(0.0, -9.8, 0.0)
	_particles.process_material = _particles_material
	
	_particles_mesh = BoxMesh.new()
	_mesh_material = ORMMaterial3D.new()
	_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particles_mesh.material = _mesh_material
	_particles.draw_pass_1 = _particles_mesh
	add_child(_particles)


func _process_wind_gusts(delta: float) -> void:
	if _is_gusting:
		_gust_duration -= delta
		if _gust_duration <= 0.0:
			_is_gusting = false
			_gust_multiplier = 1.0
			_gust_timer = randf_range(10.0, 20.0)
	else:
		_gust_timer -= delta
		if _gust_timer <= 0.0:
			_is_gusting = true
			_gust_duration = randf_range(2.0, 4.5)
			_gust_multiplier = randf_range(1.8, 2.5) 
			if is_instance_valid(player):
				AudioService.play_sfx_static("wind_howl", player.global_position, 40.0)


func _process_dynamic_wind_simulation(delta: float, profile: IClimateProfile) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0
	var base_dir := Vector2(cos(elapsed * 0.03), sin(elapsed * 0.03)).normalized()
	var target_strength := 0.35
	
	match current_weather:
		IClimateProfile.ClimateType.RAINY:
			base_dir = Vector2(-1.0, -0.4).normalized()
			target_strength = 0.85
		IClimateProfile.ClimateType.SNOWY:
			base_dir = Vector2(-0.8, -0.8).normalized()
			target_strength = 0.95
		IClimateProfile.ClimateType.SANDSTORM:
			base_dir = Vector2(-1.2, -0.2).normalized()
			target_strength = 1.25
			
	var max_allowed_wind := profile.get_max_wind_strength()
	var final_target_strength := clampf(target_strength * _gust_multiplier, 0.1, max_allowed_wind * _gust_multiplier)
	
	_current_wind_strength = lerp(_current_wind_strength, final_target_strength, delta * 0.4)
	_current_wind_vector = _current_wind_vector.lerp(base_dir, delta * 0.3)
	_wind_accum_offset += _current_wind_vector * _current_wind_strength * delta
	_wind_wave_time += (1.0 + _current_wind_strength * 0.8) * delta
	
	RenderingServer.global_shader_parameter_set("wind_strength", _current_wind_strength)
	RenderingServer.global_shader_parameter_set("wind_vector", _current_wind_vector)
	RenderingServer.global_shader_parameter_set("wind_offset", _wind_accum_offset)
	RenderingServer.global_shader_parameter_set("wind_wave_time", _wind_wave_time)


func _update_shader_cloud_coverage(delta: float) -> void:
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if not is_instance_valid(bootstrap): return
		
	var env_node := bootstrap.get("world_environment") as WorldEnvironment
	if not is_instance_valid(env_node) or env_node.environment == null: return
		
	var sky := env_node.environment.sky
	if is_instance_valid(sky) and sky.sky_material is ShaderMaterial:
		var sky_mat := sky.sky_material as ShaderMaterial
		var target_coverage := _get_target_cloud_coverage()
		
		# Smooth transitions over 25 seconds
		_current_cloud_coverage_cache = lerpf(_current_cloud_coverage_cache, target_coverage, delta * 0.15)
		sky_mat.set_shader_parameter("cloud_coverage", _current_cloud_coverage_cache)


func _get_target_cloud_coverage() -> float:
	match current_weather:
		IClimateProfile.ClimateType.SUNNY: return 0.0
		IClimateProfile.ClimateType.CLOUDY: return 0.55
		IClimateProfile.ClimateType.RAINY, IClimateProfile.ClimateType.SNOWY: return 0.85
		IClimateProfile.ClimateType.SANDSTORM: return 0.95
		IClimateProfile.ClimateType.FOGGY: return 0.20
	return 0.0


func _cycle_weather() -> void:
	_weather_timer = randf_range(45.0, 90.0) 
	
	var biome_id := _detect_player_biome_id()
	var profile := BiomeService.get_biome(biome_id).get_climate_profile()
	var weights := profile.get_climate_weights()
	current_weather = _roll_climate_by_weights(weights)
	
	_update_active_fog_multiplier(profile)
	_trigger_climatological_overcast()


func _detect_player_biome_id() -> int:
	if is_instance_valid(player) and is_instance_valid(world_controller):
		return BiomeService.get_biome_id_at_position(player.global_position, world_controller)
	return 2


func _roll_climate_by_weights(weights: Dictionary) -> IClimateProfile.ClimateType:
	var total_weight := 0.0
	for val: float in weights.values():
		total_weight += val
		
	var roll := randf() * total_weight
	var current_sum := 0.0
	
	for key: IClimateProfile.ClimateType in weights.keys():
		current_sum += weights[key] as float
		if roll <= current_sum:
			return key
			
	return IClimateProfile.ClimateType.SUNNY


func _update_active_fog_multiplier(profile: IClimateProfile) -> void:
	var biome_fog_mult := profile.get_fog_density_multiplier()
	var storm_boost := 1.75 if current_weather != IClimateProfile.ClimateType.SUNNY else 1.0
	active_fog_multiplier = biome_fog_mult * storm_boost


func _trigger_climatological_overcast() -> void:
	if current_weather == IClimateProfile.ClimateType.SUNNY or current_weather == IClimateProfile.ClimateType.CLOUDY or current_weather == IClimateProfile.ClimateType.FOGGY:
		_particles.emitting = false
		return
		
	_particles.emitting = true
	match current_weather:
		IClimateProfile.ClimateType.RAINY: _apply_rain_parameters()
		IClimateProfile.ClimateType.SNOWY: _apply_snow_parameters()
		IClimateProfile.ClimateType.SANDSTORM: _apply_sandstorm_parameters()


func _apply_rain_parameters() -> void:
	_particles_mesh.size = Vector3(0.02, 0.75, 0.02)
	_mesh_material.albedo_color = Color(0.5, 0.72, 1.0, 0.55)
	_mesh_material.emission_enabled = false
	_particles_material.initial_velocity_min = 16.0
	_particles_material.initial_velocity_max = 22.0
	_particles_material.gravity = Vector3(0.0, -12.0, 0.0)


func _apply_snow_parameters() -> void:
	_particles_mesh.size = Vector3(0.06, 0.06, 0.06)
	_mesh_material.albedo_color = Color(0.98, 0.98, 1.0, 0.85)
	_mesh_material.emission_enabled = false
	_particles_material.initial_velocity_min = 2.0
	_particles_material.initial_velocity_max = 3.5
	_particles_material.gravity = Vector3(-1.2, -1.8, -0.6)


func _apply_sandstorm_parameters() -> void:
	_particles_mesh.size = Vector3(0.08, 0.08, 0.08)
	_mesh_material.albedo_color = Color(0.85, 0.38, 0.22, 0.85)
	_mesh_material.emission_enabled = false
	_particles_material.initial_velocity_min = 22.0
	_particles_material.initial_velocity_max = 30.0 
	_particles_material.gravity = Vector3(-20.0, -1.8, -8.0)


func _process_indoor_rain_safety() -> void:
	var is_indoors := false
	if is_instance_valid(CelestialService.instance):
		is_indoors = CelestialService.instance._is_player_indoors()
		
	if is_indoors:
		if _particles.emitting: _particles.emitting = false
	else:
		if current_weather != IClimateProfile.ClimateType.SUNNY and current_weather != IClimateProfile.ClimateType.CLOUDY and current_weather != IClimateProfile.ClimateType.FOGGY:
			if not _particles.emitting: _particles.emitting = true

# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/WeatherService.gd
# Description: Infrastructure Weather Service managing dynamic regional meteorological cycles.
#              SOLID COMPLIANCE: Fully integrated with the segregated 'IClimateProfile'
#              domain interface. Purged local enums and string comparisons (LSP / DIP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# ==============================================================================
class_name WeatherService
extends Node

var current_weather: IClimateProfile.ClimateType = IClimateProfile.ClimateType.SUNNY
var active_fog_multiplier: float = 1.0

# --- INJECTED DEPENDENCIES (DIP COMPLIANT) ---
var player: CharacterBody3D
var world_controller: WorldController

# Internal timers
var _weather_timer: float = 15.0 
var _gust_timer: float = 8.0     
var _gust_duration: float = 0.0
var _gust_multiplier: float = 1.0
var _is_gusting: bool = false

# Dynamic GPU Particle System
var _particles: GPUParticles3D
var _particles_material: ParticleProcessMaterial
var _particles_mesh: BoxMesh
var _mesh_material: ORMMaterial3D

# CPU-Side State Trackers
var _current_wind_strength: float = 0.4
var _current_wind_vector: Vector2 = Vector2.ZERO

static var _globals_initialized: bool = false


func _ready() -> void:
	name = "WeatherService"
	_setup_global_wind_parameters()
	_setup_particles_system()
	_cycle_weather()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	# Follow player head exactly (floats 12 meters above) to maintain fillrate budget
	if is_instance_valid(_particles) and _particles.emitting:
		_particles.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
		
	_process_wind_gusts(delta)
	
	# Symmetrical Profile Fetching (OCP Compliant)
	var biome_id := _detect_player_biome_id()
	var profile := BiomeService.get_biome(biome_id).get_climate_profile()
	_process_dynamic_wind_simulation(delta, profile)
	
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()


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


## Micro-Gusts Simulator: Periodic wind howling bursts that affect aerodynamics
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
			
	# Limit target wind strength dynamically based on the active biome's profile limits
	var max_allowed_wind := profile.get_max_wind_strength()
	var final_target_strength := clampf(target_strength * _gust_multiplier, 0.1, max_allowed_wind * _gust_multiplier)
	
	_current_wind_strength = lerp(_current_wind_strength, final_target_strength, delta * 0.8)
	_current_wind_vector = _current_wind_vector.lerp(base_dir * _current_wind_strength, delta * 0.8)
	
	RenderingServer.global_shader_parameter_set("wind_strength", _current_wind_strength)
	RenderingServer.global_shader_parameter_set("wind_vector", _current_wind_vector)


## Regional weather cycler: Queries active biome weights on the CPU and rolls the dice
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
	
	# During storms, fog naturally becomes denser
	var storm_boost := 1.75 if current_weather != IClimateProfile.ClimateType.SUNNY else 1.0
	active_fog_multiplier = biome_fog_mult * storm_boost


func _trigger_climatological_overcast() -> void:
	if current_weather == IClimateProfile.ClimateType.SUNNY or current_weather == IClimateProfile.ClimateType.FOGGY:
		_particles.emitting = false
		return
		
	_particles.emitting = true
	match current_weather:
		IClimateProfile.ClimateType.RAINY:
			_apply_rain_parameters()
		IClimateProfile.ClimateType.SNOWY:
			_apply_snow_parameters()
		IClimateProfile.ClimateType.SANDSTORM:
			_apply_sandstorm_parameters()


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

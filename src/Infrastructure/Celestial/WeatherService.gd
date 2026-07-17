# ==============================================================================
# Pathfile: res://src/Infrastructure/Celestial/WeatherService.gd
# Description: Infrastructure Weather Service managing dynamic meteorological cycles.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates particle setups 
#                and climate routines. All methods kept strictly < 20 lines.
#              - Dependency Inversion Principle (DIP): Receives player and world 
#                references explicitly via dependency injection.
#              - Project Settings Integration: Relies on project.godot for global 
#                parameter declarations, avoiding duplicate C++ add errors.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name WeatherService
extends Node

enum WeatherType {
	SUNNY,
	RAINY,
	SNOWY
}

var current_weather: WeatherType = WeatherType.SUNNY

# --- INJECTED DEPENDENCIES (DIP COMPLIANT) ---
var player: CharacterBody3D
var world_controller: WorldController

# Internal timer to cycle weather (every 90 seconds)
var _weather_timer: float = 90.0

# Dynamic GPU Particle System configured via code (SRP compliant)
var _particles: GPUParticles3D
var _particles_material: ParticleProcessMaterial
var _particles_mesh: BoxMesh
var _mesh_material: ORMMaterial3D

# CPU-SIDE STATE TRACKERS (Avoids expensive GPU-to-CPU readbacks completely)
var _current_wind_strength: float = 0.4
var _current_wind_vector: Vector2 = Vector2.ZERO

# Persistent static flag (survives world reloads in memory)
static var _globals_initialized: bool = false


func _ready() -> void:
	name = "WeatherService"
	_setup_global_wind_parameters()
	_setup_particles_system()
	_cycle_weather()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	# Follow player head exactly (floats 12 meters above) to maintain performance
	if is_instance_valid(_particles) and _particles.emitting:
		_particles.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
		
	_process_dynamic_wind_simulation(delta)
	
	# Process climatological cycle timers
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()


## Safe initialization of Shader Globals.
## All declarations are statically defined inside 'project.godot' (shader_globals)
## to prevent C++ rendering server conflicts during editor/runtime compilation.
func _setup_global_wind_parameters() -> void:
	if _globals_initialized:
		return
	_globals_initialized = true
	
	# Set default starting values directly (no longer adding them as they are declared in project.godot)
	RenderingServer.global_shader_parameter_set("wind_vector", Vector2(0.3, 0.1))
	RenderingServer.global_shader_parameter_set("wind_strength", 0.4)


## Dynamic Wind Simulator: Simulates a slow rotating breeze during sunny days, 
## and a hard-pushed directional gale-force wind during heavy storms.
func _process_dynamic_wind_simulation(delta: float) -> void:
	var elapsed := Time.get_ticks_msec() / 1000.0
	
	# Default Sunny Breeze: Slow circular rotation (X, Z coordinate pan)
	var target_vector := Vector2(cos(elapsed * 0.04), sin(elapsed * 0.04)).normalized()
	var target_strength := 0.35
	
	match current_weather:
		WeatherType.RAINY:
			# Hard stormy southwest gale-force winds
			target_vector = Vector2(-1.0, -0.4).normalized()
			target_strength = 1.6
		WeatherType.SNOWY:
			# Turbulent diagonal blizzard winds
			target_vector = Vector2(-0.8, -0.8).normalized()
			target_strength = 1.2
			
	# Interpolate state LOCALLY on the CPU
	_current_wind_strength = lerp(_current_wind_strength, target_strength, delta * 0.4)
	_current_wind_vector = _current_wind_vector.lerp(target_vector * _current_wind_strength, delta * 0.4)
	
	# Fast write-only pipeline to push vectors directly to shaders (zero overhead)
	RenderingServer.global_shader_parameter_set("wind_strength", _current_wind_strength)
	RenderingServer.global_shader_parameter_set("wind_vector", _current_wind_vector)


## Programmatically builds and registers the GPUParticles3D emitter
func _setup_particles_system() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "WeatherParticles"
	_particles.emitting = false
	_particles.amount = 350
	_particles.lifetime = 1.5
	
	# Particle movement material
	_particles_material = ParticleProcessMaterial.new()
	_particles_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particles_material.emission_box_extents = Vector3(18.0, 1.0, 18.0) # Spawn area around the player
	_particles_material.direction = Vector3(0.0, -1.0, 0.0)
	_particles_material.spread = 4.0
	_particles_material.initial_velocity_min = 12.0
	_particles_material.initial_velocity_max = 16.0
	_particles_material.gravity = Vector3(0.0, -9.8, 0.0)
	_particles.process_material = _particles_material
	
	# Block particle mesh
	_particles_mesh = BoxMesh.new()
	_mesh_material = ORMMaterial3D.new()
	_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particles_mesh.material = _mesh_material
	_particles.draw_pass_1 = _particles_mesh
	
	add_child(_particles)


## Automates weather state shifts based on regional biomes
func _cycle_weather() -> void:
	_weather_timer = randf_range(60.0, 120.0) # Next shift in 1-2 minutes
	var roll := randf()
	
	if roll < 0.45:
		current_weather = WeatherType.SUNNY
		_particles.emitting = false
	else:
		_trigger_stormy_overcast(_check_if_polar_region())


func _check_if_polar_region() -> bool:
	if is_instance_valid(player) and is_instance_valid(world_controller):
		var p_pos := player.global_position
		var generator := world_controller.get("generator") as WorldGenerator
		
		if is_instance_valid(generator) and generator.get("_terrain_noise") != null:
			var noise := generator.get("_terrain_noise") as FastNoiseLite
			var profile := BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), noise) as BiomeService.BiomeProfile
			return (profile.biome_id == 4 or profile.biome_id == 9)
	return false


func _trigger_stormy_overcast(is_polar: bool) -> void:
	if is_polar:
		current_weather = WeatherType.SNOWY
		_apply_snow_parameters()
		_particles.emitting = true
	else:
		current_weather = WeatherType.RAINY
		_apply_rain_parameters()
		_particles.emitting = true


## Sets up thin, fast-falling translucent blue rain needles
func _apply_rain_parameters() -> void:
	_particles_mesh.size = Vector3(0.02, 0.75, 0.02) # Elongated needles
	_mesh_material.albedo_color = Color(0.5, 0.72, 1.0, 0.55) # Transparent water blue
	_mesh_material.emission_enabled = false
	
	_particles_material.initial_velocity_min = 16.0
	_particles_material.initial_velocity_max = 22.0
	_particles_material.gravity = Vector3(0.0, -12.0, 0.0)


## Sets up fluffy, slowly drifting, wind-blown white snowflakes
func _apply_snow_parameters() -> void:
	_particles_mesh.size = Vector3(0.06, 0.06, 0.06) # Tiny white cubes
	_mesh_material.albedo_color = Color(0.98, 0.98, 1.0, 0.85) # Opaque white
	_mesh_material.emission_enabled = false
	
	_particles_material.initial_velocity_min = 2.0
	_particles_material.initial_velocity_max = 3.5
	# Add slight lateral wind drift (X and Z) so the snowflakes fall diagonally
	_particles_material.gravity = Vector3(-1.2, -1.8, -0.6)

# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Weather Service managing dynamic meteorological cycles.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating particle setups and climate routines.
# DYNAMIC WIND ENGINE (120 FPS STABILIZATION):
# - Programmatically registers Global Shader Uniforms ("wind_vector" and "wind_strength") 
#   in Godot's RenderingServer to share wind parameters with all materials at zero cost.
# - Simulates a slow rotating breeze during sunny weather, and a violent, directed 
#   blizzard/storm wind vector during rainy or snowy weather cycles.
# - RUNTIME PERFORMANCE OPTIMIZATION: Removed all slow GPU-to-CPU read operations 
#   (get/get_list reflection) to prevent rendering thread stalls and crashes in F5 runs.
# - Utilizes a static initialization flag and CPU-side state interpolation.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Celestial/WeatherService.gd
# ==============================================================================
class_name WeatherService
extends Node

enum WeatherType {
	SUNNY,
	RAINY,
	SNOWY
}

var current_weather: WeatherType = WeatherType.SUNNY
var player: CharacterBody3D

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
		_locate_player()
		return
		
	# Follow player head exactly (floats 12 meters above) to maintain extreme performance
	if is_instance_valid(_particles) and _particles.emitting:
		_particles.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
		
	_process_dynamic_wind_simulation(delta)
	
	# Process climatological cycle timers
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()


## Safe programmatic registration of Shader Globals.
## Uses a static flag to guarantee execution exactly once per game lifecycle.
func _setup_global_wind_parameters() -> void:
	if _globals_initialized:
		return
	_globals_initialized = true
	
	print("[WeatherService] Initializing Global GPU Shader Parameters...")
	RenderingServer.global_shader_parameter_add("wind_vector", RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(0.3, 0.1))
	RenderingServer.global_shader_parameter_add("wind_strength", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.4)


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
			
	# Interpolate state LOCALLY on the CPU (infinite times faster than querying GPU memory)
	_current_wind_strength = lerp(_current_wind_strength, target_strength, delta * 0.4)
	_current_wind_vector = _current_wind_vector.lerp(target_vector * _current_wind_strength, delta * 0.4)
	
	# Fast write-only pipeline to push vectors directly to shaders (zero overhead)
	RenderingServer.global_shader_parameter_set("wind_strength", _current_wind_strength)
	RenderingServer.global_shader_parameter_set("wind_vector", _current_wind_vector)


## Locates the sibling player controller node dynamically
func _locate_player() -> void:
	var parent: Node = get_parent()
	if is_instance_valid(parent):
		player = parent.get_node_or_null("Player") as CharacterBody3D


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
	
	# 1. Determine region to customize local climate
	var is_polar_region := false
	if is_instance_valid(player) and is_instance_valid(get_node_or_null("../World")):
		var p_pos := player.global_position
		
		# FIX: Explicit static typing on intermediate getter variables
		var world_node: Node = get_node("../World") as Node
		var generator: WorldGenerator = world_node.get("generator") as WorldGenerator
		
		if is_instance_valid(generator):
			# FIX: Explicit static typing on terrain noise provider
			var terrain_noise: FastNoiseLite = generator.get("_terrain_noise") as FastNoiseLite
			if terrain_noise != null:
				# FIX: Explicit static typing on evaluated biome profile
				var profile: BiomeService.BiomeProfile = BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), terrain_noise) as BiomeService.BiomeProfile
				# Biome 4 is Frostbite Glaciers (North Cap), Biome 9 is Cloud Kingdom
				is_polar_region = (profile.biome_id == 4 or profile.biome_id == 9)

	# 2. Roll a weather change
	var roll := randf()
	
	if roll < 0.45:
		current_weather = WeatherType.SUNNY
		_particles.emitting = false
		print("[WeatherService] Weather shifted to: SUNNY.")
	else:
		if is_polar_region:
			current_weather = WeatherType.SNOWY
			_apply_snow_parameters()
			_particles.emitting = true
			print("[WeatherService] Weather shifted to: SNOWY (Regional Glacial Snowflake).")
		else:
			current_weather = WeatherType.RAINY
			_apply_rain_parameters()
			_particles.emitting = true
			print("[WeatherService] Weather shifted to: RAINY (Regional Rain needles).")


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

# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Weather Service managing dynamic meteorological cycles.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating particle setups and climate routines.
#              UPDATED: Introduces a dynamic Sunny/Rainy/Snowy cycle that tracks 
#              the player's position, dynamically generating falling rain needles 
#              or drifting snowflakes based on regional biomes.
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

func _ready() -> void:
	name = "WeatherService"
	_setup_particles_system()
	_cycle_weather()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_locate_player()
		return
		
	# Follow player head exactly (floats 12 meters above) to maintain extreme performance
	if is_instance_valid(_particles) and _particles.emitting:
		_particles.global_position = player.global_position + Vector3(0.0, 12.0, 0.0)
		
	# Process climatological cycle timers
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_cycle_weather()

## Locates the sibling player controller node dynamically
func _locate_player() -> void:
	var parent := get_parent()
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
		var world_node = get_node("../World")
		var generator = world_node.get("generator")
		if is_instance_valid(generator):
			var terrain_noise = generator.get("_terrain_noise")
			if terrain_noise != null:
				var profile = BiomeService.evaluate_coordinate(int(round(p_pos.x)), int(round(p_pos.z)), terrain_noise)
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
	_mesh_material.albedo_color = Color(0.98, 0.98, 0.98, 0.85) # Opaque white
	_mesh_material.emission_enabled = false
	
	_particles_material.initial_velocity_min = 2.0
	_particles_material.initial_velocity_max = 3.5
	# Add slight lateral wind drift (X and Z) so the snowflakes fall diagonally
	_particles_material.gravity = Vector3(-1.2, -1.8, -0.6)

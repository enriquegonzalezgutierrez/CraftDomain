# ==============================================================================
# Project: CraftDomain
# Description: Composition root that bootstraps the DDD application lifecycle, 
#              instantiating the World, Player, and a beautiful Procedural Sky.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/Bootstrap/Bootstrap.gd
# ==============================================================================
class_name Bootstrap
extends Node

## References to initialized domain controllers.
var world_controller: WorldController
var player_controller: PlayerController

func _ready() -> void:
	_initialize_application()

func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application...")
	
	_setup_environment()
	_bootstrap_world()
	_bootstrap_player()

func _setup_environment() -> void:
	# 1. Setup directional Sun light with shadows
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	
	# Rotate the sun to a natural high-noon angle
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-55)).rotated(Vector3(0, 1, 0), deg_to_rad(30))
	add_child(sun_light)
	
	# 2. Configure a gorgeous Procedural Sky Environment
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	
	# Set background mode to Sky
	environment.background_mode = Environment.BG_SKY
	
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	
	# Custom sky dome colors
	sky_material.sky_top_color = Color(0.2, 0.5, 0.85)       # Deep blue
	sky_material.sky_horizon_color = Color(0.55, 0.75, 0.9)   # Pale horizon
	sky_material.ground_bottom_color = Color(0.12, 0.12, 0.12) # Dark ground
	sky_material.ground_horizon_color = Color(0.55, 0.75, 0.9)
	
	sky.sky_material = sky_material
	environment.sky = sky
	
	# Soft ambient lighting derived directly from the Sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	world_environment.environment = environment
	add_child(world_environment)
	
	print("[Bootstrap] Procedural environment initialized.")

func _bootstrap_world() -> void:
	print("[Bootstrap] Instantiating World controller...")
	
	world_controller = WorldController.new()
	world_controller.name = "World"
	add_child(world_controller)
	
	print("[Bootstrap] World controller loaded.")

func _bootstrap_player() -> void:
	print("[Bootstrap] Instantiating Player controller...")
	
	player_controller = PlayerController.new()
	player_controller.name = "Player"
	add_child(player_controller)
	
	print("[Bootstrap] Player controller loaded.")

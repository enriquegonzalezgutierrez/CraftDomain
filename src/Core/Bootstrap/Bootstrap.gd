# ==============================================================================
# Project: CraftDomain
# Description: Composition root that bootstraps the DDD application lifecycle, 
#              handling dynamic, loosely-typed dependency injection to prevent
#              compile-time circular class loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/Bootstrap/Bootstrap.gd
# ==============================================================================
class_name Bootstrap
extends Node

## References to active systems, loosely typed to prevent circular loops
var main_menu: MainMenu
var world_controller: Node3D
var player_controller: CharacterBody3D
var audio_service: AudioService

func _ready() -> void:
	_initialize_application()

func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application...")
	
	_setup_environment()
	_setup_audio()
	_load_main_menu()

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

func _setup_audio() -> void:
	print("[Bootstrap] Initializing Audio Service...")
	
	# Instantiate and register the audio presentation service
	audio_service = AudioService.new()
	add_child(audio_service)
	
	# Fade-in the main menu background music
	audio_service.play_menu_music()

func _load_main_menu() -> void:
	print("[Bootstrap] Loading Main Menu...")
	
	# Ensure the mouse cursor is visible to interact with buttons
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	
	# Connect to UI signal using event-driven delegation
	main_menu.play_pressed.connect(_on_start_game_requested)
	add_child(main_menu)
	
	print("[Bootstrap] Main Menu loaded successfully.")

func _on_start_game_requested() -> void:
	print("[Bootstrap] Start game requested. Swapping states...")
	
	# 1. Unload the Main Menu from memory
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
		
	# 2. Transition soundtrack using professional 1.5s crossfading
	if is_instance_valid(audio_service):
		audio_service.play_world_music()
		
	# 3. Bootstrap 3D World and Player
	_bootstrap_world()
	_bootstrap_player()
	_inject_dependencies()

func _bootstrap_world() -> void:
	print("[Bootstrap] Instantiating World controller...")
	
	# Dynamically load the controller class to bypass compile dependency checks
	var controller_script: Script = load("res://src/Infrastructure/World/WorldController.gd")
	world_controller = controller_script.new() as Node3D
	world_controller.name = "World"
	add_child(world_controller)
	
	print("[Bootstrap] World controller loaded.")

func _bootstrap_player() -> void:
	print("[Bootstrap] Instantiating Player controller...")
	
	# Dynamically load the player class to bypass compile dependency checks
	var player_script: Script = load("res://src/Infrastructure/Player/PlayerController.gd")
	player_controller = player_script.new() as CharacterBody3D
	player_controller.name = "Player"
	add_child(player_controller)
	
	print("[Bootstrap] Player controller loaded.")

func _inject_dependencies() -> void:
	print("[Bootstrap] Injecting dependencies dynamically...")
	
	# Use dynamic safe property binding to fully bypass circular compile-time errors
	if is_instance_valid(world_controller) and is_instance_valid(player_controller):
		world_controller.set("player", player_controller)
		player_controller.set("world_controller", world_controller)
		
		# Locate and inject world_controller reference into the Player's HUD
		var hud_node: Control = player_controller.get_node_or_null("HUD")
		if is_instance_valid(hud_node):
			hud_node.set("world_controller", world_controller)
			
	print("[Bootstrap] Dynamic dependency injection completed successfully.")

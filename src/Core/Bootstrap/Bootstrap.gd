# ==============================================================================
# Project: CraftDomain
# Description: Composition root that bootstraps the DDD application lifecycle, 
#              handling dynamic, decoupled dependency injection, soundtracks, 
#              safe audio crossfades, and dynamic OCP-compliant biome registrations.
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
var celestial_service: Node

## Shared infrastructure dependencies injected across the app
var world_repository: WorldRepository

## Environmental nodes stored for dependency injection
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

func _ready() -> void:
	_initialize_application()

func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application...")
	
	_setup_biomes() # CRITICAL OCP STEP: Registers biome strategies dynamically on startup
	_setup_persistence()
	_setup_environment()
	_setup_celestial()
	_setup_audio()
	_load_main_menu()

func _setup_biomes() -> void:
	print("[Bootstrap] Registering procedural biome strategies dynamically...")
	
	# Dynamically inject the 10 concrete biome strategy blueprints into the registry (OCP compliant)
	BiomeService.register_biome(BayOfSailsBiome.new())
	BiomeService.register_biome(WarpPlateauBiome.new())
	BiomeService.register_biome(GoldenBazaarBiome.new())
	BiomeService.register_biome(CraggyMinesBiome.new())
	BiomeService.register_biome(FrostbiteGlaciersBiome.new())
	BiomeService.register_biome(RedwoodForestBiome.new())
	BiomeService.register_biome(RedBadlandsBiome.new())
	BiomeService.register_biome(NeonRuinsBiome.new())
	BiomeService.register_biome(SwampOfSighsBiome.new())
	BiomeService.register_biome(CloudKingdomBiome.new())
	
	print("[Bootstrap] Dynamic biome strategies registered successfully.")

func _setup_persistence() -> void:
	print("[Bootstrap] Setting up global persistence layer...")
	# Concrete implementation is chosen here (Composition Root)
	world_repository = DiskWorldRepository.new()

func _setup_environment() -> void:
	# 1. Setup directional Sun light with shadows
	sun_light = DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	
	# Rotate the sun to a natural high-noon angle initially
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-55)).rotated(Vector3(0, 1, 0), deg_to_rad(30))
	add_child(sun_light)
	
	# 2. Configure a gorgeous Procedural Sky Environment
	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
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
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	world_environment.environment = environment
	add_child(world_environment)
	
	print("[Bootstrap] Procedural environment initialized.")

func _setup_celestial() -> void:
	print("[Bootstrap] Initializing Celestial Day/Night Cycle Service...")
	
	var celestial_script: Script = load("res://src/Infrastructure/Celestial/CelestialService.gd")
	celestial_service = celestial_script.new() as Node
	celestial_service.name = "CelestialService"
	
	# Inject atmospheric dependencies
	celestial_service.set("sun_light", sun_light)
	celestial_service.set("world_environment", world_environment)
	
	add_child(celestial_service)
	print("[Bootstrap] Celestial Service activated.")

func _setup_audio() -> void:
	print("[Bootstrap] Initializing Audio Service...")
	
	audio_service = AudioService.new()
	add_child(audio_service)
	
	audio_service.play_menu_music()

func _load_main_menu() -> void:
	print("[Bootstrap] Loading Main Menu...")
	
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	
	main_menu.play_pressed.connect(_on_start_game_requested)
	add_child(main_menu)
	
	print("[Bootstrap] Main Menu loaded successfully.")

func _on_start_game_requested() -> void:
	print("[Bootstrap] Start game requested. Swapping states...")
	
	# 1. Unload the Main Menu from memory
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
		
	# 2. Transition soundtrack
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_world()
		
	# 3. Instantiate, Inject, and THEN Add to Scene Tree (Safe Lifecycle)
	_bootstrap_world()
	_bootstrap_player()
	_inject_dependencies()
	
	add_child(world_controller)
	add_child(player_controller)

## Public API: Safely unloads the active 3D world/player and reloads the Main Menu
func return_to_main_menu() -> void:
	print("[Bootstrap] Unloading gameplay state...")
	
	if is_instance_valid(player_controller):
		player_controller.queue_free()
		player_controller = null
		
	if is_instance_valid(world_controller):
		world_controller.queue_free()
		world_controller = null
		
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_menu()
		
	_load_main_menu()
	print("[Bootstrap] Returned to main menu safely.")

func _bootstrap_world() -> void:
	print("[Bootstrap] Instantiating World controller...")
	var controller_script: Script = load("res://src/Infrastructure/World/WorldController.gd")
	world_controller = controller_script.new() as Node3D
	world_controller.name = "World"

func _bootstrap_player() -> void:
	print("[Bootstrap] Instantiating Player controller...")
	var player_script: Script = load("res://src/Infrastructure/Player/PlayerController.gd")
	player_controller = player_script.new() as CharacterBody3D
	player_controller.name = "Player"

func _inject_dependencies() -> void:
	print("[Bootstrap] Injecting dependencies dynamically...")
	if is_instance_valid(world_controller) and is_instance_valid(player_controller):
		world_controller.set("repository", world_repository)
		world_controller.set("player", player_controller)
		player_controller.set("world_controller", world_controller)
			
	print("[Bootstrap] Dynamic dependency injection completed successfully.")

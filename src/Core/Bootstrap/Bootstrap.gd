# ==============================================================================
# Project: CraftDomain
# Description: Composition root that bootstraps the DDD application lifecycle, 
#              handling dynamic, decoupled dependency injection, soundtracks, 
#              safe audio crossfades, and dynamic OCP-compliant registrations
#              for both Biome Strategies and Structure Blueprints.
#              SOLID COMPLIANCE: Environment setup completely delegated to 
#              EnvironmentBuilder to satisfy Single Responsibility Principle (SRP).
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
	
	_setup_biomes()      # Register 10 biome strategies dynamically
	_setup_structures()  # Register 11 architecture blueprints dynamically
	_setup_persistence()
	_setup_environment()
	_setup_celestial()
	_setup_audio()
	_load_main_menu()

func _setup_biomes() -> void:
	print("[Bootstrap] Registering procedural biome strategies dynamically...")
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

func _setup_structures() -> void:
	print("[Bootstrap] Registering procedural structure blueprints dynamically...")
	StructureLibrary.register_blueprint(OakTreeBlueprint.new())       # ID 1
	StructureLibrary.register_blueprint(RedwoodTreeBlueprint.new())   # ID 2
	StructureLibrary.register_blueprint(GiantMushroomBlueprint.new()) # ID 3
	StructureLibrary.register_blueprint(WarpPipeBlueprint.new())      # ID 4
	StructureLibrary.register_blueprint(MinePillarBlueprint.new())    # ID 5
	StructureLibrary.register_blueprint(IceTempleBlueprint.new())     # ID 6
	StructureLibrary.register_blueprint(NeonPyramidBlueprint.new())   # ID 7
	StructureLibrary.register_blueprint(MarketCabinBlueprint.new())   # ID 8
	StructureLibrary.register_blueprint(HarborPierBlueprint.new())    # ID 9
	
	# Register flora blueprints dynamically (OCP compliant)
	StructureLibrary.register_blueprint(SakuraTreeBlueprint.new())       # ID 10
	StructureLibrary.register_blueprint(UnderworldFungusBlueprint.new()) # ID 11
	
	print("[Bootstrap] Dynamic structure blueprints registered successfully.")

func _setup_persistence() -> void:
	print("[Bootstrap] Setting up global persistence layer...")
	world_repository = DiskWorldRepository.new()

func _setup_environment() -> void:
	print("[Bootstrap] Delegating environment setup to EnvironmentBuilder (SRP)...")
	
	# 1. Delegate Sun creation
	sun_light = EnvironmentBuilder.build_sun()
	add_child(sun_light)
	
	# 2. Delegate RTX-style WorldEnvironment creation
	world_environment = EnvironmentBuilder.build_environment()
	add_child(world_environment)
	
	print("[Bootstrap] Environment initialized.")

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
	print("[Bootstrap] Unloading gameplay state safely...")
	
	# 1. Instantiate the temporary unload screen immediately
	var unload_screen := _create_unload_loading_screen()
	add_child(unload_screen)
	
	# 2. Wait 1 frame to let Godot draw the loading screen before blocking de-allocation starts
	await get_tree().process_frame
	
	# 3. Execute disk saving safely while the loading screen is visible!
	if is_instance_valid(world_controller) and world_controller.has_method("save_all"):
		world_controller.call("save_all")
		
	# Wait 1 more frame to flush disk saves safely
	await get_tree().process_frame
	
	# 4. Perform asynchronous-deferred garbage collection unloading
	if is_instance_valid(player_controller):
		player_controller.queue_free()
		player_controller = null
		
	if is_instance_valid(world_controller):
		world_controller.queue_free()
		world_controller = null
		
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_menu()
		
	# Defer reloading the Main Menu slightly to allow clean de-allocations
	await get_tree().create_timer(0.15).timeout
	_load_main_menu()
	
	# 5. Smoothly fade out the unloading screen to reveal the Main Menu
	var fade_tween := create_tween()
	fade_tween.tween_property(unload_screen, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_callback(unload_screen.queue_free)
	
	print("[Bootstrap] Returned to main menu safely with complete transition.")

## Programmatically designs a transition loading screen
func _create_unload_loading_screen() -> Panel:
	var panel := Panel.new()
	panel.name = "UnloadLoadingScreen"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.06, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	var title := Label.new()
	title.text = "SAVING & UNLOADING WORLD..."
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 28
	ts.font_color = Color(1.0, 0.85, 0.2)
	ts.outline_size = 6
	ts.outline_color = Color.BLACK
	title.label_settings = ts
	vbox.add_child(title)
	
	return panel

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

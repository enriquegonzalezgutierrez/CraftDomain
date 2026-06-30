# ==============================================================================
# Project: CraftDomain
# Description: Composition root bootstrapping the DDD application lifecycle,
#              handling dynamic, decoupled dependency injection.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Acts exclusively as the 
#                application orchestrator, delegating resource registrations 
#                and visual shader setups to specialized managers.
#              - Open-Closed Principle (OCP): Closed for modifications when adding 
#                new biomes, structures, or entities, as their respective services 
#                contain encapsulated registry initialization routines.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/Bootstrap/Bootstrap.gd
# ==============================================================================
class_name Bootstrap
extends Node

## References to active systems, strictly typed for compiler safety
var main_menu: MainMenu
var world_controller: WorldController
var player_controller: PlayerController
var audio_service: AudioService
var celestial_service: CelestialService
var weather_service: WeatherService

var world_repository: WorldRepository
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment


func _ready() -> void:
	_initialize_application()


func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application...")
	
	# ---> INITIALIZE INTERNATIONAL LOCALES DATABASE (i18n) <---
	# Registers programmatically created English & Spanish locales into Godot's TranslationServer
	TranslationRegistry.initialize_translations()
	
	# ---> SOLID COMPLIANCE (PHASE 4): Delegate registry startup routines <---
	BiomeService.initialize_biomes()
	StructureLibrary.initialize_structures()
	MegaStructureService.initialize_megastructures()
	MobRegistry.initialize_mobs()
	
	_setup_persistence()
	_setup_environment()
	
	# Load external campaign quests
	CampaignRegistry.initialize_campaign()
	
	# Load dialogue trees
	DialogueRegistry.initialize_dialogue_database()
	
	# Load dynamic crafting recipes
	RecipeRegistry.initialize_recipes()
	
	_setup_celestial()
	_setup_audio()
	_load_main_menu()


func _setup_persistence() -> void:
	world_repository = DiskWorldRepository.new()


func _setup_environment() -> void:
	sun_light = EnvironmentBuilder.build_sun()
	add_child(sun_light)
	world_environment = EnvironmentBuilder.build_environment()
	add_child(world_environment)


func _setup_celestial() -> void:
	celestial_service = CelestialService.new()
	celestial_service.name = "CelestialService"
	celestial_service.sun_light = sun_light
	celestial_service.world_environment = world_environment
	add_child(celestial_service)
	
	weather_service = WeatherService.new()
	weather_service.name = "WeatherService"
	add_child(weather_service)


func _setup_audio() -> void:
	audio_service = AudioService.new()
	add_child(audio_service)
	audio_service.play_menu_music()


func _load_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	main_menu.play_pressed.connect(_on_start_game_requested)
	add_child(main_menu)


func _on_start_game_requested() -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
		
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_world()
		
	_bootstrap_world()
	_bootstrap_player()
	_inject_dependencies()
	
	add_child(world_controller)
	add_child(player_controller)


func return_to_main_menu() -> void:
	var unload_screen := _create_unload_loading_screen()
	add_child(unload_screen)
	
	await get_tree().process_frame
	
	if is_instance_valid(world_controller):
		world_controller.save_all()
		
	await get_tree().process_frame
	
	if is_instance_valid(player_controller):
		player_controller.queue_free()
		player_controller = null
		
	if is_instance_valid(world_controller):
		world_controller.queue_free()
		world_controller = null
		
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_menu()
		
	await get_tree().create_timer(0.15).timeout
	_load_main_menu()
	
	var fade_tween := create_tween()
	fade_tween.tween_property(unload_screen, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade_tween.tween_callback(unload_screen.queue_free)


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
	world_controller = WorldController.new()
	world_controller.name = "World"


func _bootstrap_player() -> void:
	player_controller = PlayerController.new()
	player_controller.name = "Player"


func _inject_dependencies() -> void:
	if is_instance_valid(world_controller) and is_instance_valid(player_controller):
		world_controller.repository = world_repository
		world_controller.player = player_controller
		player_controller.world_controller = world_controller
		
		if is_instance_valid(weather_service):
			weather_service.player = player_controller

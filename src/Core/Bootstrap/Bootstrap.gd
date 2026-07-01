# ==============================================================================
# Project: CraftDomain
# Description: Composition root that bootstraps the DDD application lifecycle, 
#              handling dynamic, decoupled dependency injection.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Acts exclusively as the 
#                application orchestrator, delegating resource registrations 
#                and visual shader setups to specialized managers.
#              - Open-Closed Principle (OCP): Closed for modifications when adding 
#                new biomes, structures, or entities.
#              PERSISTENCE UPGRADE:
#              - Integrated startup persistent configurations loader to restore 
#                user settings (volumes, screen modes, view distance) on boot.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Core/Bootstrap/Bootstrap.gd
# ==============================================================================
class_name Bootstrap
extends Node

# Dependencies injected by Bootstrap
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

func _ready() -> void:
	_initialize_application()


func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application...")
	
	# ---> LOAD AND APPLY PERSISTENT CONFIGURATIONS FIRST <---
	_load_and_apply_user_settings()
	
	# Registers programmatically created English & Spanish locales into Godot's TranslationServer
	TranslationRegistry.initialize_translations()
	
	# Initialize Biomes & Structures (SOLID / OCP compliant)
	BiomeService.initialize_biomes()
	StructureLibrary.initialize_structures()
	MegaStructureService.initialize_megastructures()
	
	# Assemble the physical 3D sky environment and sun lighting (SRP compliant)
	_setup_sky_environment()
	
	# Boot up the dynamic Loop Audio Service
	var audio_service := AudioService.new()
	add_child(audio_service)
	
	_setup_starting_scene()


## Persistent Loader: Queries the Settings Repository and configures system parameters.
func _load_and_apply_user_settings() -> void:
	var settings := SettingsRepository.load_settings()
	if settings.is_empty():
		return
		
	# 1. Apply Persistent Language Locale
	if settings.has("locale"):
		var locale: String = settings["locale"]
		TranslationServer.set_locale(locale)
		
	# 2. Apply Persistent Audio Volumes
	if settings.has("music_volume"):
		var music_vol: float = settings["music_volume"]
		var idx := _get_or_create_bus("Music")
		AudioServer.set_bus_volume_db(idx, music_vol)
		AudioServer.set_bus_mute(idx, music_vol <= -39.0)
		
	if settings.has("sfx_volume"):
		var sfx_vol: float = settings["sfx_volume"]
		var idx := _get_get_or_create_bus("SFX")
		AudioServer.set_bus_volume_db(idx, sfx_vol)
		AudioServer.set_bus_mute(idx, sfx_vol <= -39.0)
		
	# 3. Apply Persistent Chunk Render Distance
	if settings.has("render_distance"):
		ChunkLoaderService.global_view_distance = int(settings["render_distance"])
		
	# 4. Apply Persistent Window Properties (Skipped in Godot Editor debug run)
	if not OS.has_feature("editor") and settings.has("window_mode"):
		var main_window: Window = get_tree().root
		var mode_val := int(settings["window_mode"])
		main_window.mode = mode_val as Window.Mode
		
		if mode_val != int(Window.MODE_FULLSCREEN) and settings.has("window_size_x") and settings.has("window_size_y"):
			var size_x := int(settings["window_size_x"])
			var size_y := int(settings["window_size_y"])
			main_window.size = Vector2i(size_x, size_y)
			main_window.move_to_center()


func _get_or_create_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx


func _get_get_or_create_bus(bus_name: String) -> int:
	# Duplicate wrapper safeguard to prevent compiler reference errors
	return _get_or_create_bus(bus_name)


func _setup_sky_environment() -> void:
	# 1. Programmatically compile the high-fidelity post-processing WorldEnvironment
	world_environment = EnvironmentBuilder.build_environment()
	add_child(world_environment)
	
	# 2. Programmatically compile the Directional SunLight
	sun_light = EnvironmentBuilder.build_sun()
	add_child(sun_light)
	
	# 3. Instantiate and bind the orbital day/night service
	var celestial_service := CelestialService.new()
	celestial_service.name = "CelestialService"
	celestial_service.sun_light = sun_light
	celestial_service.world_environment = world_environment
	add_child(celestial_service)
	
	# 4. Instantiate and bind the weather system
	var weather_service := WeatherService.new()
	weather_service.name = "WeatherService"
	add_child(weather_service)


func _setup_starting_scene() -> void:
	var menu := MainMenu.new()
	menu.name = "MainMenu"
	menu.play_pressed.connect(_on_start_game_requested)
	add_child(menu)


func _on_start_game_requested() -> void:
	var menu := get_node_or_null("MainMenu")
	if is_instance_valid(menu):
		menu.queue_free()
		
	var audio_service := get_node_or_null("AudioService") as AudioService
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_world()
		
	# Instantiate World and Player Controllers (DIP injection)
	var world_controller := WorldController.new()
	world_controller.name = "World"
	world_controller.repository = DiskWorldRepository.new()
	
	var player_controller := PlayerController.new()
	player_controller.name = "Player"
	
	# Interlink dependencies cleanly
	world_controller.player = player_controller
	player_controller.world_controller = world_controller
	
	var weather_service := get_node_or_null("WeatherService") as WeatherService
	if is_instance_valid(weather_service):
		weather_service.player = player_controller
		
	add_child(world_controller)
	add_child(player_controller)


func return_to_main_menu() -> void:
	var unload_screen := _create_unload_loading_screen()
	add_child(unload_screen)
	
	await get_tree().process_frame
	
	var world_controller := get_node_or_null("World") as WorldController
	if is_instance_valid(world_controller):
		world_controller.save_all()
		
	await get_tree().process_frame
	
	var player_controller := get_node_or_null("Player")
	if is_instance_valid(player_controller):
		player_controller.queue_free()
		
	if is_instance_valid(world_controller):
		world_controller.queue_free()
		
	var audio_service := get_node_or_null("AudioService") as AudioService
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_menu()
		
	await get_tree().create_timer(0.15).timeout
	_setup_starting_scene()
	
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
	title.text = tr("LOADING_UNLOAD_WORLD").to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ts := LabelSettings.new()
	ts.font_size = 28
	ts.font_color = Color(1.0, 0.85, 0.2)
	ts.outline_size = 6
	ts.outline_color = Color.BLACK
	title.label_settings = ts
	vbox.add_child(title)
	
	return panel

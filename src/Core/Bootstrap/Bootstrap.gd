# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/Bootstrap.gd
# Description: Central composition root of the application. Orchestrates the 
#              initialization of global systems, applies user configuration settings,
#              injects decoupled dependencies, and manages main menu transitions.
#              Delegates preloads paths to EntityPreloaderRegistry (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name Bootstrap
extends Node

const MAIN_MENU_SCENE := preload("res://src/Infrastructure/UI/main_menu.tscn")

## References to active systems, strictly typed for compiler safety
var main_menu: MainMenu
var world_controller: WorldController
var player_controller: PlayerController
var audio_service: AudioService
var celestial_service: CelestialService
var weather_service: WeatherService

# Instantiated RefCounted Services (SRP compliant)
var ai_telemetry_service: AITelemetryService
var world_repository: WorldRepository
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment


func _ready() -> void:
	_initialize_application()


## Orchestrates the startup phases sequentially.
func _initialize_application() -> void:
	print("[Bootstrap] Initializing CraftDomain application composing root...")
	_init_telemetry_and_settings()
	_init_registries()
	_setup_persistence_and_env()
	_init_audio_and_menu()


## Initializes diagnostic telemetry, local settings, and translations.
func _init_telemetry_and_settings() -> void:
	ai_telemetry_service = AITelemetryService.new()
	_load_and_apply_user_settings()
	TranslationRegistry.initialize_translations()
	TextureRegistry.initialize_textures()


## Populates core registry databases for biomes, entities, and blueprints.
func _init_registries() -> void:
	_register_biomes()
	StructureLibrary.initialize_structures()
	MegaStructureService.initialize_megastructures()
	VoxelModelRegistry.initialize_registry()
	_setup_mob_registry()
	_setup_prop_registry()
	DialogueRegistry.initialize_dialogue_database()
	RecipeRegistry.initialize_recipes()


## Registers geographic biome strategies in BiomeService.
func _register_biomes() -> void:
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


## Dispatches mob registration categories.
func _setup_mob_registry() -> void:
	print("[Bootstrap] Injecting preloaded entity scenes into MobRegistry...")
	_register_preloaded_mobs()


func _register_preloaded_mobs() -> void:
	var h_land := MobRegistry.Habitat.TERRESTRIAL
	var h_both := MobRegistry.Habitat.AMPHIBIOUS
	var h_water := MobRegistry.Habitat.AQUATIC
	var ai_fauna := FaunaAIBehavior.new()
	var ai_zombie := ZombieAIBehavior.new()
	var ai_guard := GuardAIBehavior.new()
	var ai_farmer := FarmerAIBehavior.new()
	
	# Register Wildlife Fauna polimorphically
	_register_scene_mob(0, PigEntity, h_land, ai_fauna)
	_register_scene_mob(1, ChickenEntity, h_land, ai_fauna)
	_register_scene_mob(2, SheepEntity, h_land, ai_fauna)
	_register_scene_mob(3, CowEntity, h_land, ai_fauna)
	_register_scene_mob(201, TurtleEntity, h_both, ai_fauna)
	_register_scene_mob(209, ElephantEntity, h_land, ai_fauna)
	_register_scene_mob(204, FoxEntity, h_land, ai_fauna)
	_register_scene_mob(206, CatEntity, h_land, ai_fauna)
	_register_scene_mob(211, RaccoonEntity, h_land, ai_fauna)
	_register_scene_mob(212, GrowlitheEntity, h_land, ai_fauna)
	_register_scene_mob(213, MonkeyEntity, h_land, ai_fauna)
	_register_scene_mob(205, BirdEntity, h_land, ai_fauna)
	_register_scene_mob(207, ParrotEntity, h_land, ai_fauna)
	_register_scene_mob(208, CrabEntity, h_both, ai_fauna)
	_register_scene_mob(210, OctopusEntity, h_water, ai_fauna)
	
	# Register Humanoids / Guardians
	_register_scene_mob(11, SharkEntity, h_water, ai_zombie)
	_register_scene_mob(12, GargoyleEntity, h_land, ai_zombie)
	_register_scene_mob(13, GoblinEntity, h_land, ai_zombie)
	_register_scene_mob(10, HostileEntity, h_land, ai_zombie)
	_register_scene_mob(107, GolemEntity, h_land, ai_guard)
	_register_scene_mob(100, VillagerEntity, h_land)
	_register_scene_mob(102, GuardEntity, h_land, ai_guard)
	_register_scene_mob(103, FarmerEntity, h_land, ai_farmer)
	_register_scene_mob(104, DruidEntity, h_land)
	_register_scene_mob(101, MerchantEntity, h_land)
	_register_scene_mob(105, MinerEntity, h_land)
	_register_scene_mob(106, CyberCitizenEntity, h_land)


func _register_scene_mob(spawn_id: int, fallback_class: Variant, habitat: int, default_behavior: IAIBehavior = null) -> void:
	var factory := func(pos: Vector3) -> Node:
		var scene := EntityPreloaderRegistry.get_mob_scene(spawn_id)
		if scene != null:
			var inst := scene.instantiate() as CharacterBody3D
			inst.position = pos
			return inst
		var fallback_inst := fallback_class.new(pos) as Node
		return fallback_inst
		
	MobRegistry.register_mob(spawn_id, factory, habitat, default_behavior)


## Registers interactive scenery props.
func _setup_prop_registry() -> void:
	print("[Bootstrap] Injecting prop factories into PropRegistry...")
	_register_prop(200, ChestEntity)
	_register_prop(202, StreetlightEntity)
	_register_prop(203, CampfireEntity)
	_register_prop(213, WishingWellEntity)
	_register_prop(215, BarrelEntity)


## Binds an instantiation callback to a prop class or static scene.
func _register_prop(prop_id: int, prop_class: Variant) -> void:
	PropRegistry.register_prop(prop_id, func(pos: Vector3) -> Node:
		var script_res: Variant = EntityPreloaderRegistry.get_prop_scene(prop_id)
		
		# POLIMORPHIC SCENE LOADER: Instantiates the actual .tscn file if preloaded
		if script_res != null and script_res is PackedScene:
			var inst_scene := script_res.instantiate() as Node3D
			inst_scene.position = pos
			return inst_scene
			
		var inst := prop_class.new() as Node3D
		inst.position = pos
		return inst
	)


## Evaluates and applies user-preferences loaded from disk.
func _load_and_apply_user_settings() -> void:
	var settings := SettingsRepository.load_settings()
	if settings.is_empty():
		return
	_apply_locale_and_buses(settings)
	_apply_window_settings(settings)


## Sets up translations, audio buses, and view distances.
func _apply_locale_and_buses(settings: Dictionary) -> void:
	if settings.has("locale"):
		TranslationServer.set_locale(settings["locale"])
	if settings.has("music_volume"):
		_set_bus_volume("Music", float(settings["music_volume"]))
	if settings.has("sfx_volume"):
		_set_bus_volume("SFX", float(settings["sfx_volume"]))
	if settings.has("render_distance"):
		ChunkLoaderService.global_view_distance = int(settings["render_distance"])


## Configures the DB level and mute states of an audio bus.
func _set_bus_volume(bus_name: String, vol: float) -> void:
	var idx := _get_or_create_bus(bus_name)
	AudioServer.set_bus_volume_db(idx, vol)
	AudioServer.set_bus_mute(idx, vol <= -39.0)


## Resizes and structures the game window.
func _apply_window_settings(settings: Dictionary) -> void:
	if OS.has_feature("editor") or not settings.has("window_mode"):
		return
	var main_window := get_tree().root
	var mode_val := int(settings["window_mode"])
	main_window.mode = mode_val as Window.Mode
	if mode_val != int(Window.MODE_FULLSCREEN) and settings.has("window_size_x") and settings.has("window_size_y"):
		main_window.size = Vector2i(int(settings["window_size_x"]), int(settings["window_size_y"]))
		main_window.move_to_center()


## Returns the index of an audio bus, creating it if missing.
func _get_or_create_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx


## Binds persistence and environment structures.
func _setup_persistence_and_env() -> void:
	world_repository = DiskWorldRepository.new()
	sun_light = EnvironmentBuilder.build_sun()
	add_child(sun_light)
	world_environment = EnvironmentBuilder.build_environment()
	add_child(world_environment)


## Mounts celestial systems, weather loops, soundtracks, and loading menu overlays.
func _setup_celestial() -> void:
	celestial_service = CelestialService.new()
	celestial_service.name = "CelestialService"
	celestial_service.sun_light = sun_light
	celestial_service.world_environment = world_environment
	add_child(celestial_service)
	weather_service = WeatherService.new()
	weather_service.name = "WeatherService"
	add_child(weather_service)


## Instantiates the audio player pipeline.
func _setup_audio() -> void:
	audio_service = AudioService.new()
	add_child(audio_service)
	audio_service.play_menu_music()


## Loads the main menu.
func _load_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main_menu = MAIN_MENU_SCENE.instantiate() as MainMenu
	main_menu.name = "MainMenu"
	main_menu.play_pressed.connect(_on_start_game_requested)
	add_child(main_menu)


## Triggers system initializations.
func _init_audio_and_menu() -> void:
	_setup_celestial()
	_setup_audio()
	_load_main_menu()


## Assembles playing nodes and transitions into the viewport.
func _on_start_game_requested() -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_world()
	world_controller = WorldController.new()
	player_controller = PlayerController.new()
	_inject_dependencies()
	add_child(world_controller)
	add_child(player_controller)


## Links decoupled dependency parameters.
func _inject_dependencies() -> void:
	if is_instance_valid(world_controller) and is_instance_valid(player_controller):
		world_controller.repository = world_repository
		world_controller.player = player_controller
		player_controller.world_controller = world_controller
		if is_instance_valid(weather_service):
			weather_service.player = player_controller
			weather_service.world_controller = world_controller
		if is_instance_valid(audio_service):
			audio_service.player = player_controller
			audio_service.world_controller = world_controller


## Triggers the unload sequence and transitions back to the main menu.
func return_to_main_menu() -> void:
	var unload_screen := _create_unload_loading_screen()
	add_child(unload_screen)
	await get_tree().process_frame
	if is_instance_valid(world_controller):
		world_controller.save_all()
	await get_tree().process_frame
	_cleanup_and_load_menu(unload_screen)


## Cleans up active game instances and displays the menu.
func _cleanup_and_load_menu(unload_screen: Panel) -> void:
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
	fade_tween.tween_property(unload_screen, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	fade_tween.tween_callback(unload_screen.queue_free)


## Creates the unloading screen transition.
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
	_add_unloading_title(center)
	return panel


## Appends the localized unloading text block.
func _add_unloading_title(parent: Control) -> void:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(vbox)
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

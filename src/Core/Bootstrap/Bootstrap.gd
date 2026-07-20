# ==============================================================================
# Pathfile: res://src/Core/Bootstrap/Bootstrap.gd
# Description: Central composition root of the application. Orchestrates the 
#              asynchronous initialization of global systems, unified scene transitions,
#              Vulkan pre-warming, and 100% Offline Socket Isolation.
#              REFACTORED: Converted compile-time preloads to runtime load calls
#              to immunize the startup compiler from Windows file-locking race conditions.
# Author: Enrique Gonzalez Gutierrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name Bootstrap
extends Node

const LIGHT_RECOVERY_SECTOR_Y: float = 12.0
const VEGETATION_PROP_SCRIPT_PATH: String = "res://src/Infrastructure/World/VegetationProp.gd"

var main_menu: MainMenu
var world_controller: Node3D
var player_controller: CharacterBody3D
var audio_service: AudioService
var celestial_service: CelestialService
var weather_service: WeatherService
var network_service: NetworkService
var p2p_network_adapter: P2PNetworkAdapter

var ai_telemetry_service: AITelemetryService
var glitch_rift_service: GlitchRiftService
var dynamic_resolution_service: DynamicResolutionService
var world_repository: WorldRepository
var sun_light: DirectionalLight3D
var world_environment: WorldEnvironment

var main_menu_scene: PackedScene
var loading_screen_scene: PackedScene


func _ready() -> void:
	_enforce_offline_multiplayer_peer()
	_initialize_application_async()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_handle_safe_exit_isolation()


func _enforce_offline_multiplayer_peer() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _initialize_application_async() -> void:
	print("[Bootstrap] Launching asynchronous application bootstrapper...")
	_init_basic_telemetry_and_settings()
	TranslationRegistry.initialize_translations()
	
	_load_runtime_scenes()
	var splash := _instantiate_startup_splash()
	await get_tree().process_frame
	await get_tree().process_frame
	
	TextureRegistry.initialize_textures()
	await get_tree().process_frame
	
	_init_registries_async()
	await get_tree().process_frame
	
	_setup_persistence_and_env()
	_setup_celestial()
	_setup_audio_and_network()
	
	await _execute_vulkan_prewarming()
	_transition_to_main_menu(splash)


func _load_runtime_scenes() -> void:
	main_menu_scene = load("res://src/Infrastructure/UI/main_menu.tscn") as PackedScene
	loading_screen_scene = load("res://src/Infrastructure/UI/loading_screen.tscn") as PackedScene


func _execute_vulkan_prewarming() -> void:
	var prewarmer := VulkanPipelinePrewarmer.new()
	add_child(prewarmer)
	await prewarmer.prewarming_completed


func _instantiate_startup_splash() -> CanvasLayer:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "StartupSplashCanvas"
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	if is_instance_valid(loading_screen_scene):
		var splash := loading_screen_scene.instantiate() as LoadingScreen
		splash.name = "StartupSplash"
		canvas_layer.add_child(splash)
		var status := splash.get_node_or_null("CenterContainer/VBoxContainer/Status") as Label
		if is_instance_valid(status):
			status.text = tr("LOADING_STATUS").to_upper()
			
	return canvas_layer


func _create_declarative_loading_screen() -> CanvasLayer:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "UnloadLoadingScreenCanvas"
	canvas_layer.layer = 100
	
	if is_instance_valid(loading_screen_scene):
		var splash := loading_screen_scene.instantiate() as LoadingScreen
		splash.name = "UnloadLoadingScreen"
		canvas_layer.add_child(splash)
		var status := splash.get_node_or_null("CenterContainer/VBoxContainer/Status") as Label
		if is_instance_valid(status):
			status.text = tr("LOADING_UNLOAD_WORLD").to_upper()
			
	return canvas_layer


func _init_basic_telemetry_and_settings() -> void:
	ai_telemetry_service = AITelemetryService.new()
	glitch_rift_service = GlitchRiftService.new()
	
	dynamic_resolution_service = DynamicResolutionService.new()
	add_child(dynamic_resolution_service)
	
	_load_and_apply_user_settings()


func _init_registries_async() -> void:
	_register_biomes()
	StructureLibrary.initialize_structures()
	MegaStructureService.initialize_megastructures()
	VoxelModelRegistry.initialize_registry()
	_setup_mob_registry()
	_setup_prop_registry()
	DialogueRegistry.initialize_dialogue_database()
	RecipeRegistry.initialize_recipes()
	
	GamepadBindingsRepository.load_and_apply_bindings()
	ModLoaderService.scan_and_load_mods()


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


func _setup_mob_registry() -> void:
	var h_land := MobRegistry.Habitat.TERRESTRIAL
	var h_both := MobRegistry.Habitat.AMPHIBIOUS
	var h_water := MobRegistry.Habitat.AQUATIC
	
	_register_passive_wildlife(h_land, h_both, h_water)
	_register_hostile_husks(h_land, h_water)
	_register_civilian_professions(h_land)
	_register_campaign_bosses(h_land)


func _register_passive_wildlife(h_land: int, h_both: int, h_water: int) -> void:
	var ai_fauna := FaunaAIBehavior.new()
	_register_scene_mob(0, PigEntity, h_land, PigAIBehavior.new()) 
	_register_scene_mob(1, ChickenEntity, h_land, ChickenAIBehavior.new()) 
	_register_scene_mob(2, SheepEntity, h_land, SheepAIBehavior.new()) 
	_register_scene_mob(3, CowEntity, h_land, CowAIBehavior.new()) 
	_register_scene_mob(201, TurtleEntity, h_both, ai_fauna)
	_register_scene_mob(204, FoxEntity, h_land, ai_fauna)
	_register_scene_mob(206, CatEntity, h_land, ai_fauna)
	_register_scene_mob(211, RaccoonEntity, h_land, ai_fauna)
	_register_scene_mob(212, GrowlitheEntity, h_land, ai_fauna)
	_register_scene_mob(213, MonkeyEntity, h_land, ai_fauna)
	_register_scene_mob(205, BirdEntity, h_land, ai_fauna)
	_register_scene_mob(207, ParrotEntity, h_land, ai_fauna)
	_register_scene_mob(208, CrabEntity, h_both, ai_fauna)
	_register_scene_mob(209, ElephantEntity, h_land, ai_fauna) 
	_register_scene_mob(210, OctopusEntity, h_water, ai_fauna)


func _register_hostile_husks(h_land: int, h_water: int) -> void:
	var ai_zombie := ZombieAIBehavior.new()
	_register_scene_mob(11, SharkEntity, h_water, ai_zombie)
	_register_scene_mob(12, GargoyleEntity, h_land, ai_zombie)
	_register_scene_mob(13, GoblinEntity, h_land, ai_zombie)
	_register_scene_mob(10, HostileEntity, h_land, ai_zombie)


func _register_civilian_professions(h_land: int) -> void:
	var ai_guard := GuardAIBehavior.new()
	var ai_farmer := FarmerAIBehavior.new()
	_register_scene_mob(107, GolemEntity, h_land, ai_guard)
	_register_scene_mob(100, VillagerEntity, h_land)
	_register_scene_mob(102, GuardEntity, h_land, ai_guard)
	_register_scene_mob(103, FarmerEntity, h_land, ai_farmer)
	_register_scene_mob(104, DruidEntity, h_land)
	_register_scene_mob(101, MerchantEntity, h_land)
	_register_scene_mob(105, MinerEntity, h_land)
	_register_scene_mob(106, CyberCitizenEntity, h_land)


func _register_campaign_bosses(h_land: int) -> void:
	_register_scene_mob(50, LithicLurkerEntity, h_land, LithicLurkerAIBehavior.new())
	_register_scene_mob(51, ObsidianColossusEntity, h_land, ObsidianColossusAIBehavior.new())
	_register_scene_mob(52, WeaverMalakorEntity, h_land, WeaverMalakorAIBehavior.new())


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


func _setup_prop_registry() -> void:
	_register_prop(200, ChestEntity)
	_register_prop(202, StreetlightEntity)
	_register_prop(203, CampfireEntity)
	_register_prop(213, WishingWellEntity)
	_register_prop(215, BarrelEntity)
	
	for prop_id: int in range(220, 236):
		_register_prop(prop_id, null)


func _register_prop(prop_id: int, _prop_class: Variant) -> void:
	PropRegistry.register_prop(prop_id, func(pos: Vector3) -> Node:
		var scene: PackedScene = EntityPreloaderRegistry.get_prop_scene(prop_id) as PackedScene
		if is_instance_valid(scene):
			var inst := scene.instantiate() as Node3D
			inst.position = pos
			if prop_id >= 220 and prop_id <= 235:
				var script_res := load(VEGETATION_PROP_SCRIPT_PATH) as GDScript
				if is_instance_valid(script_res):
					inst.set_script(script_res)
			return inst
		return null
	)


func _load_and_apply_user_settings() -> void:
	_get_or_create_bus("Music")
	_get_or_create_bus("SFX")
	
	var settings := SettingsRepository.load_settings()
	if settings.is_empty(): return
	_apply_locale_and_buses(settings)
	_setup_window_modes_from_settings(settings)


func _apply_locale_and_buses(settings: Dictionary) -> void:
	if settings.has("locale"):
		TranslationServer.set_locale(settings["locale"])
	if settings.has("music_volume"):
		_set_bus_volume("Music", float(settings["music_volume"]))
	if settings.has("sfx_volume"):
		_set_bus_volume("SFX", float(settings["sfx_volume"]))
	if settings.has("render_distance"):
		ChunkLoaderService.global_view_distance = int(settings["render_distance"])


func _set_bus_volume(bus_name: String, val: float) -> void:
	var idx := _get_or_create_bus(bus_name)
	AudioServer.set_bus_volume_db(idx, val)
	AudioServer.set_bus_mute(idx, val <= -39.0)


func _setup_window_modes_from_settings(settings: Dictionary) -> void:
	if OS.has_feature("editor") or not settings.has("window_mode"): return
	var main_window := get_tree().root
	var mode_val := int(settings["window_mode"])
	main_window.mode = mode_val as Window.Mode
	if mode_val != int(Window.MODE_FULLSCREEN) and settings.has("window_size_x") and settings.has("window_size_y"):
		main_window.size = Vector2i(int(settings["window_size_x"]), int(settings["window_size_y"]))
		main_window.move_to_center()


func _get_or_create_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, bus_name)
	return idx


func _setup_persistence_and_env() -> void:
	world_repository = DiskWorldRepository.new()
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


func _setup_audio_and_network() -> void:
	audio_service = AudioService.new()
	add_child(audio_service)
	
	network_service = NetworkService.new()
	network_service.name = "NetworkService"
	add_child(network_service)
	
	p2p_network_adapter = P2PNetworkAdapter.new()
	p2p_network_adapter.name = "P2PNetworkAdapter"
	network_service.add_child(p2p_network_adapter)


func _load_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(main_menu_scene):
		main_menu = main_menu_scene.instantiate() as MainMenu
		main_menu.name = "MainMenu"
		main_menu.play_pressed.connect(_on_start_game_requested)
		main_menu.showcase_pressed.connect(_on_showcase_requested)
		add_child(main_menu)


func _transition_to_main_menu(splash_canvas: CanvasLayer) -> void:
	_load_main_menu()
	if is_instance_valid(audio_service):
		audio_service.play_menu_music()
		
	if is_instance_valid(splash_canvas):
		var splash_panel := splash_canvas.get_node_or_null("StartupSplash") as Panel
		if is_instance_valid(splash_panel):
			splash_panel.set_process(false)
			var fade_tween := create_tween()
			fade_tween.tween_property(splash_panel, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
			fade_tween.chain().tween_callback(splash_canvas.queue_free)


func _on_start_game_requested(should_clear_save: bool = false) -> void:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "LoadingScreenCanvas"
	canvas_layer.layer = 100
	add_child(canvas_layer)
	
	if is_instance_valid(loading_screen_scene):
		var loading_screen := loading_screen_scene.instantiate() as LoadingScreen
		loading_screen.name = "LoadingScreenOverlay"
		canvas_layer.add_child(loading_screen)
		
		await get_tree().process_frame
		_execute_world_start(should_clear_save, loading_screen)


func _execute_world_start(should_clear_save: bool, loading_screen: LoadingScreen) -> void:
	if should_clear_save:
		var task_id := WorkerThreadPool.add_task(DiskWorldRepository.delete_save_game_files)
		while not WorkerThreadPool.is_task_completed(task_id):
			await get_tree().process_frame
			
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
	loading_screen.player = player_controller


func _on_showcase_requested() -> void:
	var canvas_layer := _create_declarative_loading_screen()
	var splash := canvas_layer.get_child(0) as LoadingScreen
	var status := splash.get_node_or_null("CenterContainer/VBoxContainer/Status") as Label
	if is_instance_valid(status):
		status.text = tr("BOOT_STATUS_TELEMETRY").to_upper()
	add_child(canvas_layer)
	
	await get_tree().process_frame
	_execute_showcase_start(canvas_layer, splash)


func _execute_showcase_start(canvas_layer: CanvasLayer, splash: LoadingScreen) -> void:
	if is_instance_valid(main_menu):
		main_menu.queue_free()
		main_menu = null
		
	var showcase_room := AIShowcaseRoom.new()
	add_child(showcase_room)
	
	var fade_tween := create_tween()
	fade_tween.tween_property(splash, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	fade_tween.chain().tween_callback(canvas_layer.queue_free)


func _cleanup_showcase_room_if_exists() -> void:
	var room := get_node_or_null("AIShowcaseRoom")
	if is_instance_valid(room):
		room.queue_free()


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


func return_to_main_menu() -> void:
	var unload_canvas := _create_declarative_loading_screen()
	add_child(unload_canvas)
	await get_tree().process_frame
	
	if is_instance_valid(world_controller):
		world_controller.save_all()
	await get_tree().process_frame
	
	_cleanup_and_load_menu(unload_canvas)


func _cleanup_and_load_menu(unload_canvas: CanvasLayer) -> void:
	if is_instance_valid(player_controller):
		player_controller.queue_free()
		player_controller = null
	if is_instance_valid(world_controller):
		world_controller.queue_free()
		world_controller = null
		
	_cleanup_showcase_room_if_exists()
	
	if is_instance_valid(audio_service):
		audio_service.crossfade_to_menu()
	await get_tree().create_timer(0.15).timeout
	_load_main_menu()
	
	var splash := unload_canvas.get_child(0) as LoadingScreen
	var fade_tween := create_tween()
	fade_tween.tween_property(splash, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	fade_tween.chain().tween_callback(unload_canvas.queue_free)


func _handle_safe_exit_isolation() -> void:
	print("[Bootstrap] Intercepted close request. Executing secure thread-joining shutdown...")
	set_process(false)
	set_physics_process(false)
	
	if is_instance_valid(world_controller):
		world_controller.save_all()
		if "chunk_lifecycle" in world_controller and is_instance_valid(world_controller.chunk_lifecycle):
			world_controller.chunk_lifecycle.shutdown()
			
	if is_instance_valid(audio_service):
		audio_service.stop_all()
		
	get_tree().quit()

# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (UI Presentation / Developer Diagnostics)
# Class: AIShowcaseRoom
# Description: Self-contained AI and Entity Sandbox Laboratory. Generates mock 
#              surroundings, A* navigation nodes, and a diagnostic panel to 
#              test dynamic NPC behaviors in real-time.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates exclusively the diagnostic 
#   laboratory environment, spawning decks, and telemetry panel refreshes.
# - Open-Closed Principle (OCP): Dynamically populates spawning buttons by scanning 
#   the global MobRegistry, closing this class to future mob-type additions.
# - Liskov Substitution Principle (LSP): Fully compatible with standard 
#   Node3D scene structures.
# ==============================================================================
class_name AIShowcaseRoom
extends Node3D

# --- MOCK DDD WORLD REQUIREMENTS ---
var world_state: WorldState
var navigation_service: VoxelNavigationService
var generator: WorldGenerator
var player: CharacterBody3D # Simulated Player Dummy

# UI Node References
var _canvas: CanvasLayer
var _sidebar_vbox: VBoxContainer
var _telemetry_label: Label
var _chicken_checkbox: CheckButton
var _storm_checkbox: CheckButton
var _slowmo_slider: HSlider

# Environmental Node References
var _active_test_subject: CharacterBody3D = null
var _simulated_campfire: StaticBody3D = null
var _mock_weather_service: Node = null

# Core constants
const PLATFORM_SIZE: int = 16
const PLATFORM_Y: int = 11 # Dynamic floor height limit


func _ready() -> void:
	name = "AIShowcaseRoom"
	_setup_mock_world_state()
	_build_3d_testing_pad()
	_setup_mock_player_dummy()
	_setup_mock_weather_loop()
	_build_developer_dashboard()
	
	if is_instance_valid(AudioService.instance):
		AudioService.instance.crossfade_to_world()


func _process(delta: float) -> void:
	_update_diagnostic_telemetry(delta)


func _setup_mock_world_state() -> void:
	world_state = WorldState.new()
	navigation_service = VoxelNavigationService.new()
	generator = WorldGenerator.new(42) 
	
	# ==========================================================================
	# PATHFINDING STABILIZATION RESOLUTION (OCP/SRP Fix)
	# Build a solid 4-block deep stone foundation (Y=8 to Y=11) so that the 
	# A* pathfinding and boundary checks detect a safe terrestrial floor.
	# ==========================================================================
	for x: int in range(PLATFORM_SIZE):
		for z: int in range(PLATFORM_SIZE):
			for y: int in range(8, PLATFORM_Y + 1):
				var global_pos := Vector3i(x - 8, y, z - 8)
				world_state.set_block(global_pos, BlockType.Type.STONE)
				
			# Add navigation node to graph only on the topmost surface
			var top_pos := Vector3i(x - 8, PLATFORM_Y, z - 8)
			navigation_service.add_navigation_node(top_pos, false)
			
	# Connect adjacent A* nodes horizontally (4-directional)
	for x: int in range(-8, 8):
		for z: int in range(-8, 8):
			var node_pos := Vector3i(x, PLATFORM_Y, z)
			var directions: Array[Vector3i] = [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]
			for offset: Vector3i in directions:
				var neighbor: Vector3i = node_pos + offset
				if navigation_service._coord_to_id.has(neighbor):
					navigation_service.connect_nodes(node_pos, neighbor)


func _setup_mock_player_dummy() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_meta("is_active", true)
	
	player.set("inventory", InventoryComponent.new())
	player.set("active_slot_index", 6)
	player.set("is_active", true)
	
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position = Vector3(0.0, 0.9, 0.0)
	player.add_child(col)
	
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.4
	cyl.height = 1.8
	mesh.mesh = cyl
	mesh.position = Vector3(0.0, 0.9, 0.0)
	
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.15)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	player.add_child(mesh)
	
	add_child(player)
	player.position = Vector3(-4.5, 12.0, -4.5)


func _setup_mock_weather_loop() -> void:
	_mock_weather_service = Node.new()
	_mock_weather_service.name = "WeatherService"
	
	var mock_script := GDScript.new()
	mock_script.source_code = "extends Node\nvar current_weather: int = 0\n"
	mock_script.reload()
	_mock_weather_service.set_script(mock_script)
	
	add_child(_mock_weather_service)


func _build_3d_testing_pad() -> void:
	var camera := Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.position = Vector3(0.0, 22.0, 14.5)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	add_child(camera)
	
	var light := DirectionalLight3D.new()
	light.light_energy = 1.6
	light.light_color = Color(0.99, 0.96, 0.92)
	light.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	add_child(light)
	
	var checker_root := Node3D.new()
	checker_root.name = "CheckerFloor"
	add_child(checker_root)
	
	for x: int in range(-8, 8):
		for z: int in range(-8, 8):
			var box := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.0, 0.1, 1.0)
			box.mesh = bm
			box.position = Vector3(float(x) + 0.5, float(PLATFORM_Y) - 0.05, float(z) + 0.5)
			
			var mat := StandardMaterial3D.new()
			var is_even := ((x + z) % 2 == 0)
			mat.albedo_color = Color(0.18, 0.18, 0.22) if is_even else Color(0.12, 0.12, 0.15)
			mat.roughness = 0.9
			box.material_override = mat
			checker_root.add_child(box)
			
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(16.0, 1.0, 16.0)
	floor_col.shape = floor_shape
	floor_body.position = Vector3(0.0, float(PLATFORM_Y) - 0.5, 0.0)
	floor_body.add_child(floor_col) 
	checker_root.add_child(floor_body)
	
	# Wall barriers around the 16x16 deck to prevent entities from slipping off
	var walls_config: Array[Array] = [
		[Vector3(0, PLATFORM_Y + 5.0, -9.0), Vector3(18, 10, 2)], 
		[Vector3(0, PLATFORM_Y + 5.0, 9.0), Vector3(18, 10, 2)],  
		[Vector3(9.0, PLATFORM_Y + 5.0, 0), Vector3(2, 10, 18)],  
		[Vector3(-9.0, PLATFORM_Y + 5.0, 0), Vector3(2, 10, 18)]  
	]
	for w_data: Array in walls_config:
		var wb := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var ws := BoxShape3D.new()
		ws.size = w_data[1] as Vector3
		wc.shape = ws
		wb.position = w_data[0] as Vector3
		wb.add_child(wc)
		checker_root.add_child(wb)

	if PropRegistry.has_prop(203):
		_simulated_campfire = PropRegistry.create_prop(203, Vector3(4.5, 12.0, 4.5)) as StaticBody3D
		if is_instance_valid(_simulated_campfire):
			add_child(_simulated_campfire)


func _build_developer_dashboard() -> void:
	_canvas = CanvasLayer.new()
	_canvas.name = "DashboardLayer"
	add_child(_canvas)
	
	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 20)
	main_margin.add_theme_constant_override("margin_top", 20)
	main_margin.add_theme_constant_override("margin_right", 20)
	main_margin.add_theme_constant_override("margin_bottom", 20)
	_canvas.add_child(main_margin)
	
	var master_hbox := HBoxContainer.new()
	master_hbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(master_hbox)
	
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(250, 0)
	var l_style := StyleBoxFlat.new()
	l_style.bg_color = Color(0.06, 0.06, 0.08, 0.90)
	l_style.set_corner_radius_all(10)
	l_style.set_border_width_all(1)
	l_style.border_color = Color(0.3, 0.85, 1.0, 0.4)
	left_card.add_theme_stylebox_override("panel", l_style)
	master_hbox.add_child(left_card)
	
	var left_margin := MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 14)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_card.add_child(left_margin)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)
	
	var sel_title := Label.new()
	sel_title.text = tr("SHOWCASE_TESTPAD_HEADER")
	var sel_settings := LabelSettings.new()
	sel_settings.font_size = 15; sel_settings.font_color = Color(0.2, 0.85, 0.85)
	sel_title.label_settings = sel_settings
	left_vbox.add_child(sel_title)
	
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	_sidebar_vbox = VBoxContainer.new()
	_sidebar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_sidebar_vbox)
	
	_populate_developer_mobs_deck()
	
	var center_spacer := Control.new()
	center_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	master_hbox.add_child(center_spacer)
	
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(280, 0)
	right_card.add_theme_stylebox_override("panel", l_style)
	master_hbox.add_child(right_card)
	
	var right_margin := MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 16)
	right_margin.add_theme_constant_override("margin_top", 16)
	right_margin.add_theme_constant_override("margin_right", 16)
	right_margin.add_theme_constant_override("margin_bottom", 16)
	right_card.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_margin.add_child(right_vbox)
	
	var ctrl_title := Label.new()
	ctrl_title.text = tr("SHOWCASE_CONTROLS_HEADER")
	var ctrl_settings := LabelSettings.new()
	ctrl_settings.font_size = 14; ctrl_settings.font_color = Color(1.0, 0.85, 0.2)
	ctrl_title.label_settings = ctrl_settings
	right_vbox.add_child(ctrl_title)
	
	_chicken_checkbox = CheckButton.new()
	_chicken_checkbox.text = tr("SHOWCASE_CHICKEN_LURE")
	_chicken_checkbox.toggled.connect(_on_lure_chicken_toggled)
	right_vbox.add_child(_chicken_checkbox)
	
	_storm_checkbox = CheckButton.new()
	_storm_checkbox.text = tr("SHOWCASE_RAIN_OVERCAST")
	_storm_checkbox.toggled.connect(_on_rain_overcast_toggled)
	right_vbox.add_child(_storm_checkbox)
	
	var spawn_zombie_btn := Button.new()
	spawn_zombie_btn.text = tr("SHOWCASE_SPAWN_THREAT")
	spawn_zombie_btn.custom_minimum_size = Vector2(0, 36)
	_setup_button_style(spawn_zombie_btn, Color(0.75, 0.15, 0.15))
	spawn_zombie_btn.pressed.connect(_on_spawn_zombie_pressed)
	right_vbox.add_child(spawn_zombie_btn)
	
	var slowmo_lbl := Label.new()
	slowmo_lbl.text = tr("SHOWCASE_SPEED_SCALE")
	var ls_sm := LabelSettings.new(); ls_sm.font_size = 11; ls_sm.font_color = Color(0.7,0.7,0.75)
	slowmo_lbl.label_settings = ls_sm
	right_vbox.add_child(slowmo_lbl)
	
	_slowmo_slider = HSlider.new()
	_slowmo_slider.min_value = 0.1
	_slowmo_slider.max_value = 1.0
	_slowmo_slider.step = 0.1
	_slowmo_slider.value = 1.0
	_slowmo_slider.value_changed.connect(func(v: float) -> void: Engine.time_scale = v)
	right_vbox.add_child(_slowmo_slider)
	
	var sep := HSeparator.new()
	right_vbox.add_child(sep)
	
	var tel_header := Label.new()
	tel_header.text = tr("SHOWCASE_TELEMETRY_HEADER")
	tel_header.label_settings = ls_sm
	right_vbox.add_child(tel_header)
	
	_telemetry_label = Label.new()
	_telemetry_label.text = tr("SHOWCASE_TELEMETRY_EMPTY")
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var ts_tel := LabelSettings.new()
	ts_tel.font_size = 11; ts_tel.font_color = Color(0.85, 0.92, 1.0); ts_tel.line_spacing = 4
	_telemetry_label.label_settings = ts_tel
	right_vbox.add_child(_telemetry_label)
	
	var b_spacer := Control.new()
	b_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(b_spacer)
	
	var exit_btn := Button.new()
	exit_btn.text = tr("SHOWCASE_RETURN_MENU")
	exit_btn.custom_minimum_size = Vector2(0, 42)
	_setup_button_style(exit_btn, Color(0.2, 0.2, 0.24))
	exit_btn.pressed.connect(_on_exit_pressed)
	right_vbox.add_child(exit_btn)


func _populate_developer_mobs_deck() -> void:
	var keys: Array = MobRegistry._spawners.keys()
	keys.sort()
	for spawn_id: int in keys:
		var btn := Button.new()
		var raw_name := _get_mock_mob_name(spawn_id)
		btn.text = " " + tr("SHOWCASE_SPAWN_PREFIX") + " " + raw_name.to_upper()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_setup_button_style(btn, Color(0.12, 0.12, 0.14, 0.6))
		
		btn.pressed.connect(_on_spawn_test_subject_requested.bind(spawn_id))
		_sidebar_vbox.add_child(btn)


func _on_spawn_test_subject_requested(spawn_id: int) -> void:
	_flush_active_test_subject()
	
	var spawn_pos := Vector3(0.0, float(PLATFORM_Y) + 3.0, 0.0) 
	_active_test_subject = MobRegistry.create_mob(spawn_id, spawn_pos) as CharacterBody3D
	
	if is_instance_valid(_active_test_subject):
		add_child(_active_test_subject)
		print("[AIShowcaseRoom] Instantiated test subject spawn_id: ", spawn_id)
		_on_lure_chicken_toggled(_chicken_checkbox.button_pressed)


func _flush_active_test_subject() -> void:
	if is_instance_valid(_active_test_subject):
		_active_test_subject.queue_free()
		_active_test_subject = null
		
	for child in get_children():
		if child is CharacterBody3D and child != player and child != _active_test_subject:
			child.queue_free()


func _on_lure_chicken_toggled(button_pressed: bool) -> void:
	if is_instance_valid(player):
		var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			var slot_data := inventory.get_slot_data(6) 
			if is_instance_valid(slot_data):
				if button_pressed:
					slot_data.item_id = 16 
					slot_data.quantity = 1
				else:
					slot_data.item_id = -1 
					slot_data.quantity = 0
			inventory.inventory_changed.emit()


func _on_rain_overcast_toggled(button_pressed: bool) -> void:
	if is_instance_valid(_mock_weather_service):
		_mock_weather_service.set("current_weather", 1 if button_pressed else 0)


func _on_spawn_zombie_pressed() -> void:
	if MobRegistry.has_mob(10):
		var zombie_pos := Vector3(3.5, float(PLATFORM_Y) + 3.0, 3.5)
		var zombie := MobRegistry.create_mob(10, zombie_pos) as CharacterBody3D
		if is_instance_valid(zombie):
			add_child(zombie)


func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0
	_canvas.queue_free()
	var bootstrap: Node = get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")


func _update_diagnostic_telemetry(_delta: float) -> void:
	if not is_instance_valid(_telemetry_label):
		return
	if not is_instance_valid(_active_test_subject):
		_telemetry_label.text = tr("SHOWCASE_TELEMETRY_EMPTY")
		return
		
	var ai: Object = _active_test_subject.get_node_or_null("NPCAIComponent")
	var domain_entity: Object = _active_test_subject.get("domain_entity")
	
	var task_str := "SHOWCASE_TASK_IDLE"
	var current_hp := 0
	var state_details := ""
	
	if is_instance_valid(ai):
		var task_val: int = ai.get("current_task") as int
		task_str = _get_task_state_name(task_val)
		
		if _active_test_subject.has_meta("gargoyle_nocturnal_state"):
			var st: int = _active_test_subject.get_meta("gargoyle_nocturnal_state") as int
			state_details += tr("SHOWCASE_TEL_GOYLE") + ": %s\n" % (tr("SHOWCASE_TASK_IDLE") if st == 0 else "AWAKE")
		if _active_test_subject.has_meta("growlithe_lava_target"):
			var target: Vector3i = _active_test_subject.get_meta("growlithe_lava_target") as Vector3i
			state_details += tr("SHOWCASE_TEL_LAVA") + ": %s\n" % (str(target) if target.y != -999 else "NONE")
		if _active_test_subject.has_meta("druid_heal_target"):
			var target: String = str(_active_test_subject.get_meta("druid_heal_target"))
			state_details += tr("SHOWCASE_TEL_HEAL") + ": %s\n" % (target if target != "" else "NONE")
		if _active_test_subject.has_meta("avian_flight_state"):
			var st: int = _active_test_subject.get_meta("avian_flight_state") as int
			var state_names := {0: "SOARING", 1: "LANDING", 2: "PERCHED"}
			state_details += tr("SHOWCASE_TEL_FLIGHT") + ": %s\n" % state_names.get(st, "UNKNOWN")
			
	if is_instance_valid(domain_entity):
		current_hp = domain_entity.get("health") as int
		
	var host_pos: Vector3 = _active_test_subject.global_position
		
	_telemetry_label.text = (
		tr("SHOWCASE_TEL_NAME") + ": %s\n" % _active_test_subject.name +
		tr("SHOWCASE_TEL_HEALTH") + ": %d Hearts (%d HP)\n" % [floori(float(current_hp) / 2.0) if current_hp > 0 else 0, current_hp] +
		tr("SHOWCASE_TEL_COORDS") + ": [ X: %d, Y: %d, Z: %d ]\n" % [int(round(host_pos.x)), int(round(host_pos.y)), int(round(host_pos.z))] +
		tr("SHOWCASE_TEL_TASK") + ": %s\n\n" % tr(task_str) +
		tr("SHOWCASE_TEL_META_HEADER") + "\n" +
		(state_details if state_details != "" else tr("SHOWCASE_TEL_STANDARD") + "\n")
	)


func _get_mock_mob_name(spawn_id: int) -> String:
	match spawn_id:
		0: return "Wild Pig"
		1: return "Chicken"
		2: return "Sheep"
		3: return "Clay Cow"
		10: return "Cave Zombie"
		11: return "White Shark"
		12: return "Gothic Gargoyle"
		13: return "Sneaky Goblin"
		100: return "Gossip Villager"
		101: return "Merchant"
		102: return "Guard Knight"
		103: return "Farmer"
		104: return "Forest Druid"
		105: return "Cave Miner"
		106: return "Android"
		107: return "Iron Golem"
		201: return "Sea Turtle"
		204: return "Red Fox"
		205: return "Yellow Bird"
		206: return "Domestic Cat"
		207: return "Parrot"
		208: return "Beach Crab"
		209: return "Elephant"
		210: return "Octopus"
		211: return "Raccoon"
		212: return "Growlithe"
		213: return "Monkey"
		_: return "Unknown"


func _get_task_state_name(task_val: int) -> String:
	match task_val:
		0: return "SHOWCASE_TASK_IDLE"
		1: return "SHOWCASE_TASK_WANDER"
		2: return "SHOWCASE_TASK_EXAMINE"
		3: return "SHOWCASE_TASK_GREET"
		4: return "SHOWCASE_TASK_CHAT"
		5: return "SHOWCASE_TASK_PANIC"
		6: return "SHOWCASE_TASK_WORKING"
		_: return "SHOWCASE_TASK_IDLE"


func _setup_button_style(btn: Button, base_color: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = base_color
	sn.set_corner_radius_all(8)
	sn.border_width_bottom = 4
	sn.border_color = base_color.darkened(0.4)
	sn.content_margin_left = 12; sn.content_margin_right = 12
	sn.content_margin_top = 8; sn.content_margin_bottom = 8
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = base_color.lightened(0.1)
	
	var sp := sn.duplicate() as StyleBoxFlat
	sp.bg_color = base_color.darkened(0.3)
	sp.border_width_top = 4; sp.border_width_bottom = 0; sp.border_color = Color(0,0,0,0)
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))


func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s

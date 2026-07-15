# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/AIShowcaseDashboard.gd
# Description: Infrastructure UI Presenter managing the 2D developer dashboard.
#              Provides decoupled sliders, controls, and live 20Hz telemetry reports.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively 2D control panels 
#   and diagnostic telemetry readouts, completely decoupled from 3D space.
# - Open-Closed Principle (OCP): Queries behaviors polymorphically via 
#   `get_active_state_name` and duck-typing, removing raw entity checks.
# - Liskov Substitution Principle (LSP): Fully supports any CharacterBody3D subject.
# - Scope Correction (DIP): Localized physical constants to ensure complete 
#   compilation autonomy of the UI.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name AIShowcaseDashboard
extends CanvasLayer

# --- UI INTERACTIVE CONSTANTS (Section 5.3) ---
const SIDEBAR_WIDTH: float = 260.0
const PANEL_RIGHT_WIDTH: float = 290.0
const BUTTON_HEIGHT: float = 38.0
const SLIDER_SPEED_MIN: float = 0.1
const SLIDER_SPEED_MAX: float = 1.0
const PLATFORM_Y: int = 11

# --- COLOR PALETTE CONSTANTS ---
const COLOR_CARD_BACKGROUND := Color(0.06, 0.06, 0.08, 0.92)
const COLOR_CARD_BORDER := Color(0.3, 0.85, 1.0, 0.4)
const COLOR_LURE_TRUE := Color(0.2, 0.95, 0.35)

# --- 20HZ THROTTLING CONSTANTS (Rule 7.2) ---
const THROTTLE_INTERVAL_SEC: float = 0.05

var _showcase_room: AIShowcaseRoom
var _active_subject: CharacterBody3D = null
var _ui_accumulated_time: float = 0.0

# UI Node References
var _sidebar_vbox: VBoxContainer
var _telemetry_label: Label
var _chicken_checkbox: CheckButton
var _storm_checkbox: CheckButton
var _slowmo_slider: HSlider


func _ready() -> void:
	name = "AIShowcaseDashboard"
	_showcase_room = get_parent() as AIShowcaseRoom
	
	if is_instance_valid(_showcase_room):
		_showcase_room.subject_spawned.connect(_on_subject_spawned)
		_showcase_room.subject_despawned.connect(_on_subject_despawned)
		
	_build_dashboard_ui()


func _process(delta: float) -> void:
	if _active_subject == null:
		return
		
	_ui_accumulated_time += delta
	if _ui_accumulated_time >= THROTTLE_INTERVAL_SEC:
		_ui_accumulated_time = 0.0
		_update_live_telemetry_display()


func _build_dashboard_ui() -> void:
	var main_margin := MarginContainer.new()
	main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_dashboard_margins(main_margin)
	add_child(main_margin)
	
	var master_hbox := HBoxContainer.new()
	master_hbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(master_hbox)
	
	_build_left_sidebar_panel(master_hbox)
	_build_right_control_panel(master_hbox)


func _build_left_sidebar_panel(parent_hbox: HBoxContainer) -> void:
	var left_card := PanelContainer.new()
	left_card.custom_minimum_size = Vector2(SIDEBAR_WIDTH, 0.0)
	left_card.add_theme_stylebox_override("panel", _get_glass_panel_style())
	parent_hbox.add_child(left_card)
	
	var left_margin := MarginContainer.new()
	_apply_standard_panel_margins(left_margin)
	left_card.add_child(left_margin)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)
	
	_add_sidebar_catalog_header(left_vbox)
	_setup_sidebar_scroll_container(left_vbox)


func _add_sidebar_catalog_header(parent_vbox: VBoxContainer) -> void:
	var sel_title := Label.new()
	sel_title.text = tr("SHOWCASE_TITLE").to_upper()
	var sel_settings := LabelSettings.new()
	sel_settings.font_size = 15
	sel_settings.font_color = Color(0.2, 0.85, 0.85)
	sel_title.label_settings = sel_settings
	parent_vbox.add_child(sel_title)


func _setup_sidebar_scroll_container(parent_vbox: VBoxContainer) -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent_vbox.add_child(scroll)
	
	_sidebar_vbox = VBoxContainer.new()
	_sidebar_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sidebar_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_sidebar_vbox)
	
	_populate_sidebar_mobs_deck()


func _build_right_control_panel(parent_hbox: HBoxContainer) -> void:
	var center_spacer := Control.new()
	center_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent_hbox.add_child(center_spacer)
	
	var right_card := PanelContainer.new()
	right_card.custom_minimum_size = Vector2(PANEL_RIGHT_WIDTH, 0.0)
	right_card.add_theme_stylebox_override("panel", _get_glass_panel_style())
	parent_hbox.add_child(right_card)
	
	var right_margin := MarginContainer.new()
	_apply_standard_panel_margins(right_margin)
	right_card.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_margin.add_child(right_vbox)
	
	_populate_right_controls_and_telemetry(right_vbox)


func _populate_right_controls_and_telemetry(right_vbox: VBoxContainer) -> void:
	_add_control_header(right_vbox)
	_setup_interactive_checkbuttons(right_vbox)
	_add_spawn_zombie_button(right_vbox)
	_setup_speed_scale_slider(right_vbox)
	_add_telemetry_labels(right_vbox)
	_add_return_menu_button(right_vbox)


func _add_control_header(parent_vbox: VBoxContainer) -> void:
	var ctrl_title := Label.new()
	ctrl_title.text = tr("SHOWCASE_CONTROLS_HEADER")
	var ctrl_settings := LabelSettings.new()
	ctrl_settings.font_size = 14
	ctrl_settings.font_color = Color(1.0, 0.85, 0.2)
	ctrl_title.label_settings = ctrl_settings
	parent_vbox.add_child(ctrl_title)


func _setup_interactive_checkbuttons(parent_vbox: VBoxContainer) -> void:
	_chicken_checkbox = CheckButton.new()
	_chicken_checkbox.text = tr("SHOWCASE_CHICKEN_LURE")
	_chicken_checkbox.toggled.connect(_on_lure_chicken_toggled)
	parent_vbox.add_child(_chicken_checkbox)
	
	_storm_checkbox = CheckButton.new()
	_storm_checkbox.text = tr("SHOWCASE_RAIN_OVERCAST")
	_storm_checkbox.toggled.connect(_on_rain_overcast_toggled)
	parent_vbox.add_child(_storm_checkbox)


func _add_spawn_zombie_button(parent_vbox: VBoxContainer) -> void:
	var spawn_zombie_btn := Button.new()
	spawn_zombie_btn.text = tr("SHOWCASE_SPAWN_THREAT")
	spawn_zombie_btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_setup_button_style(spawn_zombie_btn, Color(0.75, 0.15, 0.15))
	spawn_zombie_btn.pressed.connect(_on_spawn_zombie_pressed)
	parent_vbox.add_child(spawn_zombie_btn)


func _setup_speed_scale_slider(parent_vbox: VBoxContainer) -> void:
	var slowmo_lbl := Label.new()
	slowmo_lbl.text = tr("SHOWCASE_SPEED_SCALE")
	var ls_sm := LabelSettings.new()
	ls_sm.font_size = 11
	ls_sm.font_color = Color(0.7, 0.7, 0.75)
	slowmo_lbl.label_settings = ls_sm
	parent_vbox.add_child(slowmo_lbl)
	
	_slowmo_slider = HSlider.new()
	_slowmo_slider.min_value = SLIDER_SPEED_MIN
	_slowmo_slider.max_value = SLIDER_SPEED_MAX
	_slowmo_slider.step = 0.1
	_slowmo_slider.value = 1.0
	_slowmo_slider.value_changed.connect(func(v: float) -> void: Engine.time_scale = v)
	parent_vbox.add_child(_slowmo_slider)


func _add_telemetry_labels(parent_vbox: VBoxContainer) -> void:
	var sep := HSeparator.new()
	parent_vbox.add_child(sep)
	
	var tel_header := Label.new()
	tel_header.text = tr("SHOWCASE_TELEMETRY_HEADER")
	var ls_tel := LabelSettings.new()
	ls_tel.font_size = 11
	ls_tel.font_color = Color(0.7, 0.7, 0.75)
	tel_header.label_settings = ls_tel
	parent_vbox.add_child(tel_header)
	
	_telemetry_label = Label.new()
	_telemetry_label.text = tr("SHOWCASE_TELEMETRY_EMPTY")
	_telemetry_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var ts_tel := LabelSettings.new()
	ts_tel.font_size = 11
	ts_tel.font_color = Color(0.85, 0.92, 1.0)
	ts_tel.line_spacing = 4
	_telemetry_label.label_settings = ts_tel
	parent_vbox.add_child(_telemetry_label)


func _add_return_menu_button(parent_vbox: VBoxContainer) -> void:
	var b_spacer := Control.new()
	b_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent_vbox.add_child(b_spacer)
	
	var exit_btn := Button.new()
	exit_btn.text = tr("SHOWCASE_RETURN_MENU")
	exit_btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	_setup_button_style(exit_btn, Color(0.2, 0.2, 0.24))
	exit_btn.pressed.connect(_on_exit_pressed)
	parent_vbox.add_child(exit_btn)


# ==============================================================================
# SENSORY EVENTS & BUTTON HANDLERS
# ==============================================================================

func _populate_sidebar_mobs_deck() -> void:
	var keys: Array = MobRegistry._spawners.keys()
	keys.sort()
	for spawn_id: int in keys:
		var btn := Button.new()
		var translation_key := _get_mob_translation_key(spawn_id)
		btn.text = " " + tr("SHOWCASE_SPAWN_PREFIX") + " " + tr(translation_key).to_upper()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_setup_button_style(btn, Color(0.12, 0.12, 0.14, 0.6))
		
		btn.pressed.connect(func() -> void:
			if is_instance_valid(_showcase_room):
				_showcase_room.spawn_test_subject(spawn_id)
		)
		_sidebar_vbox.add_child(btn)


func _on_subject_spawned(subject: CharacterBody3D) -> void:
	_active_subject = subject
	_ui_accumulated_time = THROTTLE_INTERVAL_SEC # Force immediate UI update


func _on_subject_despawned() -> void:
	_active_subject = null
	if is_instance_valid(_telemetry_label):
		_telemetry_label.text = tr("SHOWCASE_TELEMETRY_EMPTY")


func _on_lure_chicken_toggled(button_pressed: bool) -> void:
	if is_instance_valid(_showcase_room):
		var dummy_player := _showcase_room.player
		if is_instance_valid(dummy_player):
			var inventory: InventoryComponent = dummy_player.get("inventory") as InventoryComponent
			if is_instance_valid(inventory):
				var slot_data := inventory.get_slot_data(6) 
				if is_instance_valid(slot_data):
					slot_data.item_id = 16 if button_pressed else -1
					slot_data.quantity = 1 if button_pressed else 0
				inventory.inventory_changed.emit()


func _on_rain_overcast_toggled(button_pressed: bool) -> void:
	if is_instance_valid(_showcase_room):
		var weather_node := _showcase_room.get_node_or_null("WeatherService")
		if is_instance_valid(weather_node):
			weather_node.set("current_weather", 1 if button_pressed else 0)


func _on_spawn_zombie_pressed() -> void:
	if MobRegistry.has_mob(10) and is_instance_valid(_showcase_room):
		var zombie_pos := Vector3(3.5, float(PLATFORM_Y) + 3.0, 3.5)
		var zombie := MobRegistry.create_mob(10, zombie_pos) as CharacterBody3D
		if is_instance_valid(zombie):
			_showcase_room.add_child(zombie)


func _on_exit_pressed() -> void:
	Engine.time_scale = 1.0
	var bootstrap := get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")


# ==============================================================================
# 20HZ DIAGNOSTIC TELEMETRY LOGS (SRP/OCP - Section 7.2)
# ==============================================================================

func _update_live_telemetry_display() -> void:
	if not is_instance_valid(_telemetry_label) or not is_instance_valid(_active_subject):
		return
		
	var ai: Object = _active_subject.get_node_or_null("NPCAIComponent")
	var domain_entity: Object = _active_subject.get("domain_entity")
	
	var task_str := "SHOWCASE_TASK_IDLE"
	var current_hp := 0
	var state_details := ""
	
	if is_instance_valid(ai):
		var task_val: int = ai.get("current_task") as int
		task_str = _get_task_state_name(task_val)
		state_details = _gather_active_behavior_metadata()
			
	if is_instance_valid(domain_entity):
		current_hp = domain_entity.get("health") as int
		
	var host_pos: Vector3 = _active_subject.global_position
	var subject_key := _get_mob_translation_key(_active_subject.get("spawn_id") if "spawn_id" in _active_subject else -1)
	
	_telemetry_label.text = (
		tr("SHOWCASE_TEL_NAME") + ": %s\n" % tr(subject_key) +
		tr("SHOWCASE_TEL_HEALTH") + ": %d Hearts (%d HP)\n" % [floori(float(current_hp) / 2.0) if current_hp > 0 else 0, current_hp] +
		tr("SHOWCASE_TEL_COORDS") + ": [ X: %d, Y: %d, Z: %d ]\n" % [int(round(host_pos.x)), int(round(host_pos.y)), int(round(host_pos.z))] +
		tr("SHOWCASE_TEL_TASK") + ": %s\n\n" % tr(task_str) +
		tr("SHOWCASE_TEL_META_HEADER") + "\n" +
		(state_details if state_details != "" else tr("SHOWCASE_TEL_STANDARD") + "\n")
	)


func _gather_active_behavior_metadata() -> String:
	var state_details := ""
	
	# Pure OCP: query the AI Component behavior for metadata logging if it supports it
	var ai: Object = _active_subject.get_node_or_null("NPCAIComponent")
	if is_instance_valid(ai) and ai.get("active_behavior") != null:
		var behavior: IAIBehavior = ai.get("active_behavior") as IAIBehavior
		if is_instance_valid(behavior) and behavior.has_method("get_active_state_name"):
			var state_key := behavior.call("get_active_state_name", _active_subject) as String
			state_details += "• %s: %s\n" % [tr("SHOWCASE_TEL_META_HEADER").to_upper(), tr(state_key).to_upper()]
			
	return state_details


func _get_mob_translation_key(spawn_id: int) -> String:
	match spawn_id:
		0: return "NPC_NAME_PIG"
		1: return "NPC_NAME_CHICKEN"
		2: return "NPC_NAME_SHEEP"
		3: return "NPC_NAME_COW"
		10: return "NPC_NAME_ZOMBIE"
		11: return "NPC_NAME_SHARK"
		12: return "NPC_NAME_GARGOYLE"
		13: return "NPC_NAME_GOBLIN"
		50: return "NPC_NAME_LITHIC_LURKER"
		51: return "NPC_NAME_OBSIDIAN_COLOSSUS"
		100: return "NPC_NAME_VILLAGER"
		101: return "NPC_NAME_MERCHANT"
		102: return "NPC_NAME_GUARD"
		103: return "NPC_NAME_FARMER"
		104: return "NPC_NAME_DRUID"
		105: return "NPC_NAME_MINER"
		106: return "NPC_NAME_ANDROID"
		107: return "NPC_NAME_GOLEM"
		201: return "NPC_NAME_TURTLE"
		204: return "NPC_NAME_FOX"
		205: return "NPC_NAME_BIRD"
		206: return "NPC_NAME_CAT"
		207: return "NPC_NAME_PARROT"
		208: return "NPC_NAME_CRAB"
		209: return "NPC_NAME_ELEPHANT"
		210: return "NPC_NAME_OCTOPUS"
		211: return "NPC_NAME_RACCOON"
		212: return "NPC_NAME_GROWLITHE"
		213: return "NPC_NAME_MONKEY"
		_: return "INVENTORY_UNKNOWN"


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


# ==============================================================================
# STYLE UTILITIES (UI/UX Themes)
# ==============================================================================

func _get_glass_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BACKGROUND
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = COLOR_CARD_BORDER
	return style


func _apply_dashboard_margins(node: MarginContainer) -> void:
	node.add_theme_constant_override("margin_left", 20)
	node.add_theme_constant_override("margin_top", 20)
	node.add_theme_constant_override("margin_right", 20)
	node.add_theme_constant_override("margin_bottom", 20)


func _apply_standard_panel_margins(node: MarginContainer) -> void:
	node.add_theme_constant_override("margin_left", 14)
	node.add_theme_constant_override("margin_top", 14)
	node.add_theme_constant_override("margin_right", 14)
	node.add_theme_constant_override("margin_bottom", 14)


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

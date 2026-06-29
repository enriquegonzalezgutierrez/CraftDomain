# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI Controller acting as a decoupled Coordinator.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Delegates ALL interface 
#                rendering, drawing, and menu components to specialized widgets.
#              - Open-Closed Principle (OCP): All text titles, labels, and toasts
#                are fully i18n localized using tr() for future translation packs.
#              FIX: Removed obsolete _setup_damage_overlay() and _setup_crosshair()
#              calls from _ready() since they are now delegated to widgets.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/PlayerHUD.gd
# ==============================================================================
class_name PlayerHUD
extends Control

## Dependencies injected by the parent controller
var player: CharacterBody3D
var world_controller: Node3D

# Specialized Decoupled Sub-Widgets (SRP Compliant)
var minimap: MinimapWidget
var gps_panel: GPSPanelWidget
var quest_panel: QuestTrackerWidget

# Private Widget Instances (Instantiated programmatically to avoid God files)
var _fps_widget: Node
var _crosshair_widget: Control
var _damage_widget: ColorRect
var _hotbar_dock_widget: Control
var _pause_widget: Panel
var _world_map_overlay: MapOverlay # Fullscreen Tactical Map Reference

# Overlays & Dialogue manager
var dialogue_manager: DialogueManager
var _crafting_overlay: CraftingOverlay
var _inventory_overlay: InventoryOverlay

# Paths to extracted widget scripts
const FPS_WIDGET_PATH = "res://src/Infrastructure/UI/Widgets/FPSCounterWidget.gd"
const CROSSHAIR_WIDGET_PATH = "res://src/Infrastructure/UI/Widgets/CrosshairWidget.gd"
const DAMAGE_WIDGET_PATH = "res://src/Infrastructure/UI/Widgets/DamageOverlayWidget.gd"
const HOTBAR_DOCK_WIDGET_PATH = "res://src/Infrastructure/UI/Widgets/HotbarDockWidget.gd"
const PAUSE_MENU_WIDGET_PATH = "res://src/Infrastructure/UI/Widgets/PauseMenuWidget.gd"
const WORLD_MAP_WIDGET_PATH = "res://src/Infrastructure/UI/MapOverlay.gd"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Instantiate and setup all decoupled SRP UI widgets
	_setup_sub_components()
	_setup_dialogue_system()
	_setup_loading_screen()
	
	if is_instance_valid(player) and player.has_method("_sync_hud_counters"):
		player.call("_sync_hud_counters")
		
	# Trigger the first selection visually on the hotbar dock
	update_active_slot(0)

## Programmatically instantiates and wires extracted SRP widgets
func _setup_sub_components() -> void:
	# 1. Damage Flash Overlay
	var damage_script := load(DAMAGE_WIDGET_PATH) as Script
	if damage_script != null:
		_damage_widget = damage_script.new() as ColorRect
		add_child(_damage_widget)
		
	# 2. Reticle Crosshair
	var crosshair_script := load(CROSSHAIR_WIDGET_PATH) as Script
	if crosshair_script != null:
		_crosshair_widget = crosshair_script.new() as Control
		add_child(_crosshair_widget)
		
	# 3. FPS Counter
	var fps_script := load(FPS_WIDGET_PATH) as Script
	if fps_script != null:
		_fps_widget = fps_script.new() as Node
		add_child(_fps_widget)
		
	# 4. Minimap Widget
	minimap = MinimapWidget.new()
	minimap.player = player
	minimap.world_controller = world_controller
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -170
	minimap.offset_top = 20
	add_child(minimap)

	# 5. GPS Navigation panel
	gps_panel = GPSPanelWidget.new()
	gps_panel.player = player
	gps_panel.world_controller = world_controller
	gps_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	gps_panel.offset_top = 20
	gps_panel.offset_left = -250
	gps_panel.offset_right = 250
	add_child(gps_panel)

	# 6. Campaign Quest Tracker
	quest_panel = QuestTrackerWidget.new()
	quest_panel.player = player
	quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quest_panel.offset_left = 15
	quest_panel.offset_top = 50
	add_child(quest_panel)
	
	# 7. Hotbar Unified Dock (Hearts, Drumsticks, and Shortcuts)
	var hotbar_script := load(HOTBAR_DOCK_WIDGET_PATH) as Script
	if hotbar_script != null:
		_hotbar_dock_widget = hotbar_script.new() as Control
		_hotbar_dock_widget.set("player", player)
		_hotbar_dock_widget.set("hud_orchestrator", self)
		add_child(_hotbar_dock_widget)
		
	# 8. Pause Menu
	var pause_script := load(PAUSE_MENU_WIDGET_PATH) as Script
	if pause_script != null:
		_pause_widget = pause_script.new() as Panel
		_pause_widget.set("hud_orchestrator", self)
		add_child(_pause_widget)

func _setup_dialogue_system() -> void:
	dialogue_manager = DialogueManager.new()
	dialogue_manager.name = "DialogueManager"
	dialogue_manager.player = player
	add_child(dialogue_manager)

func _setup_loading_screen() -> void:
	var loading_screen := LoadingScreen.new(player)
	add_child(loading_screen)

func _process(_delta: float) -> void:
	if is_instance_valid(minimap):
		minimap.update_widget()
	if is_instance_valid(gps_panel):
		gps_panel.update_widget()
	if is_instance_valid(quest_panel):
		quest_panel.update_widget()

# ==============================================================================
# COORDINATION DELEGATION APIS (DIP/SRP Compliant)
# ==============================================================================

func open_dialogue(node: Resource, speaker_name: String) -> void:
	if is_instance_valid(dialogue_manager):
		dialogue_manager.open_dialogue(node, speaker_name)

func toggle_world_map(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_crafting_overlay) or is_instance_valid(_inventory_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_world_map_overlay): return
		_world_map_overlay = load(WORLD_MAP_WIDGET_PATH).new() as MapOverlay
		_world_map_overlay.player = player
		_world_map_overlay.closed.connect(func() -> void: toggle_world_map(false))
		add_child(_world_map_overlay)
		
		if is_instance_valid(player):
			player.set("is_active", false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_world_map_overlay):
			_world_map_overlay.queue_free()
			_world_map_overlay = null
		if is_instance_valid(player):
			player.set("is_active", true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_crafting_workshop(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_inventory_overlay) or is_instance_valid(_world_map_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_crafting_overlay): return
		_crafting_overlay = CraftingOverlay.new()
		_crafting_overlay.player = player
		_crafting_overlay.closed.connect(func() -> void: toggle_crafting_workshop(false))
		add_child(_crafting_overlay)
		
		if is_instance_valid(player):
			player.set("is_active", false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_crafting_overlay):
			_crafting_overlay.queue_free()
			_crafting_overlay = null
		if is_instance_valid(player):
			player.set("is_active", true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_inventory_backpack(p_visible: bool) -> void:
	if (_pause_widget and _pause_widget.visible) or is_instance_valid(_crafting_overlay) or is_instance_valid(_world_map_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_inventory_overlay): return
		_inventory_overlay = InventoryOverlay.new()
		_inventory_overlay.player = player
		_inventory_overlay.closed.connect(func() -> void: toggle_inventory_backpack(false))
		add_child(_inventory_overlay)
		
		if is_instance_valid(player):
			player.set("is_active", false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		if is_instance_valid(_inventory_overlay):
			_inventory_overlay.queue_free()
			_inventory_overlay = null
		if is_instance_valid(player):
			player.set("is_active", true)
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func toggle_pause_menu(p_visible: bool) -> void:
	if is_instance_valid(_pause_widget):
		if p_visible:
			if is_instance_valid(_crafting_overlay): toggle_crafting_workshop(false)
			if is_instance_valid(_inventory_overlay): toggle_inventory_backpack(false)
			if is_instance_valid(_world_map_overlay): toggle_world_map(false)
		_pause_widget.call("toggle_menu", p_visible)

func show_quest_notification(header: String, quest_title: String) -> void:
	var toast := Panel.new()
	toast.name = "QuestToast"
	toast.custom_minimum_size = Vector2(340, 75)
	toast.size = Vector2(340, 75)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_top = -90
	toast.offset_left = -170
	toast.offset_right = 170
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.7) 
	style.shadow_size = 8; style.shadow_color = Color(0, 0, 0, 0.3)
	toast.add_theme_stylebox_override("panel", style)
	add_child(toast)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	toast.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	var header_lbl := Label.new()
	header_lbl.text = "🏆 " + tr(header).to_upper()
	var hs := LabelSettings.new()
	hs.font_size = 11; hs.font_color = Color(1.0, 0.85, 0.2); hs.outline_size = 2; hs.outline_color = Color.BLACK
	header_lbl.label_settings = hs; header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = tr(quest_title)
	var ds := LabelSettings.new()
	ds.font_size = 13; ds.font_color = Color.WHITE; ds.outline_size = 2; ds.outline_color = Color.BLACK
	desc_lbl.label_settings = ds; desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	
	var toast_tween := create_tween()
	toast_tween.tween_property(toast, "offset_top", 25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(2.8)
	toast_tween.tween_property(toast, "offset_top", -90, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	toast_tween.tween_callback(toast.queue_free)

func update_active_slot(active_index: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_active_slot", active_index)

func update_slot_quantity(slot_index: int, item_id: int, quantity: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_slot_quantity", slot_index, item_id, quantity)

func update_health_display(current_hp: int) -> void:
	if is_instance_valid(_hotbar_dock_widget):
		_hotbar_dock_widget.call("update_health_display", current_hp)

func flash_damage_screen() -> void:
	if is_instance_valid(_damage_widget):
		_damage_widget.call("flash")

func is_any_menu_open() -> bool:
	return (
		(_pause_widget and _pause_widget.visible) or
		is_instance_valid(_crafting_overlay) or
		is_instance_valid(_inventory_overlay) or
		is_instance_valid(_world_map_overlay) or 
		(is_instance_valid(dialogue_manager) and is_instance_valid(dialogue_manager.active_dialogue))
	)

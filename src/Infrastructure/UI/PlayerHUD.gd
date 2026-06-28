# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller acting as a lightweight Orchestrator.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by delegating visual operations to widgets.
#              UX HIGH-FIDELITY REDESIGN (UNIFIED HUD DOCK):
#              - Unified, center-bottom docked modular hotbar (8.5% screen height).
#              - Seamless, direct sequential integration of backpack (🎒) and workshop (🛠️).
#              - Millimeter-aligned hearts (HP) and food (Drumsticks) bars.
#              - Elegant 3D-shaded block icon representation.
#              FIXED: Added the missing 'is_any_menu_open()' API function at the bottom.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/PlayerHUD.gd
# ==============================================================================
class_name PlayerHUD
extends Control

## Dependencies injected by the parent controller
var player: CharacterBody3D
var world_controller: Node3D

# Decoupled Sub-Widgets managed dynamically (SOLID SRP compliant)
var minimap: MinimapWidget
var gps_panel: GPSPanelWidget
var quest_panel: QuestTrackerWidget

# Sibling UI nodes managed locally
var _item_name_toast: Label
var _toast_tween: Tween
var hotbar_slots: Array[Panel] = []

# Dynamic Status Bars (Minecraft-style!)
var _hearts_container: HBoxContainer
var _food_container: HBoxContainer

# UX Overlays, Workshops & Backpacks
var damage_overlay: ColorRect
var _pause_overlay: Panel
var _settings_overlay: SettingsMenu
var dialogue_manager: DialogueManager
var _crafting_overlay: CraftingOverlay
var _inventory_overlay: InventoryOverlay

# Theme palette colors matching our Hotbar Block IDs
const BLOCK_COLORS = {
	-1: Color(0, 0, 0, 0),       
	1: Color(0.55, 0.55, 0.55), # Stone
	2: Color(0.55, 0.38, 0.25), # Dirt
	3: Color(0.42, 0.78, 0.25), # Grass
	4: Color(0.72, 0.55, 0.35), # Wood
	5: Color(0.25, 0.65, 0.18), # Leaves
	15: Color(1.0, 0.45, 0.0),  # Lava
	16: Color(0.92, 0.62, 0.62),# Chicken
	17: Color(0.75, 0.75, 0.80) # Sword
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_damage_overlay()
	_setup_crosshair()
	_setup_minimap()             
	_setup_navigation_gps_panel() 
	_setup_quest_tracker_panel()  
	
	_setup_unified_hotbar_dock() # Replaces old scattered buttons and bars
	_setup_item_name_toast()
	_setup_pause_menu()
	
	# Instantiate standard dialogue manager
	dialogue_manager = DialogueManager.new()
	dialogue_manager.name = "DialogueManager"
	dialogue_manager.player = player
	add_child(dialogue_manager)
	
	# Instantiate standard loading screen
	var loading_screen := LoadingScreen.new(player)
	add_child(loading_screen) 
	
	if is_instance_valid(player) and player.has_method("_sync_hud_counters"):
		player.call("_sync_hud_counters")
		
	# Trigger the first selection visually
	update_active_slot(0)

func _setup_damage_overlay() -> void:
	damage_overlay = ColorRect.new()
	damage_overlay.name = "DamageOverlay"
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_overlay)

func _setup_crosshair() -> void:
	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var draw_script := GDScript.new()
	var code := """extends Control
func _draw() -> void:
	var center := get_viewport_rect().size / 2.0
	var col := Color(1, 1, 1, 0.85)
	var shadow := Color(0, 0, 0, 0.5)
	
	draw_circle(center, 3.0, shadow)
	draw_line(center - Vector2(8, 0), center - Vector2(3, 0), shadow, 3.0)
	draw_line(center + Vector2(3, 0), center + Vector2(8, 0), shadow, 3.0)
	draw_line(center - Vector2(0, 8), center - Vector2(0, 3), shadow, 3.0)
	draw_line(center + Vector2(0, 3), center + Vector2(0, 8), shadow, 3.0)

	draw_circle(center, 1.5, col)
	draw_line(center - Vector2(7, 0), center - Vector2(4, 0), col, 2.0)
	draw_line(center + Vector2(4, 0), center + Vector2(7, 0), col, 2.0)
	draw_line(center - Vector2(0, 7), center - Vector2(0, 4), col, 2.0)
	draw_line(center + Vector2(0, 4), center + Vector2(0, 7), col, 2.0)
"""
	draw_script.source_code = code
	draw_script.reload()
	crosshair.set_script(draw_script)
	add_child(crosshair)

func _setup_minimap() -> void:
	minimap = MinimapWidget.new()
	minimap.player = player
	minimap.world_controller = world_controller
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -170
	minimap.offset_top = 20
	add_child(minimap)

func _setup_navigation_gps_panel() -> void:
	gps_panel = GPSPanelWidget.new()
	gps_panel.player = player
	gps_panel.world_controller = world_controller
	gps_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	gps_panel.offset_top = 20
	gps_panel.offset_left = -250
	gps_panel.offset_right = 250
	
	add_child(gps_panel)

func _setup_quest_tracker_panel() -> void:
	quest_panel = QuestTrackerWidget.new()
	quest_panel.player = player
	
	quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quest_panel.offset_left = 20
	quest_panel.offset_top = 80
	
	add_child(quest_panel)

## HIGH-FIDELITY HUDBAR DESIGN: Builds a single cohesive, highly polished bottom toolbar
func _setup_unified_hotbar_dock() -> void:
	# 1. Base Container centered at the bottom (PROPORTIONS SCALED UP BY 1.35x)
	var main_dock := Control.new()
	main_dock.name = "HudBottomDock"
	main_dock.custom_minimum_size = Vector2(760, 140)
	main_dock.size = Vector2(760, 140)
	main_dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	main_dock.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	main_dock.offset_bottom = -15
	main_dock.offset_top = -155
	main_dock.offset_left = -380
	main_dock.offset_right = 380
	add_child(main_dock)
	
	# 2. Status Containers (Perfect aligned, 1.4x larger font metrics)
	_hearts_container = HBoxContainer.new()
	_hearts_container.name = "HeartsContainer"
	_hearts_container.add_theme_constant_override("separation", 3)
	_hearts_container.custom_minimum_size = Vector2(200, 32)
	_hearts_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hearts_container.offset_left = 82 # Aligns perfectly above Slot 0
	_hearts_container.offset_bottom = -84 # floats 6px above the taller hotbar
	_hearts_container.offset_top = -116
	main_dock.add_child(_hearts_container)
	
	_food_container = HBoxContainer.new()
	_food_container.name = "FoodContainer"
	_food_container.alignment = BoxContainer.ALIGNMENT_END
	_food_container.add_theme_constant_override("separation", 3)
	_food_container.custom_minimum_size = Vector2(200, 32)
	_food_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_food_container.offset_right = -82 # Aligns perfectly above Slot 7
	_food_container.offset_bottom = -84 
	_food_container.offset_top = -116
	main_dock.add_child(_food_container)
	
	# 3. Unified Glassmorphic Hotbar Container (Holds Shortcuts + 8 slots)
	var hotbar_bg := Panel.new()
	hotbar_bg.name = "HotbarBackground"
	hotbar_bg.custom_minimum_size = Vector2(680, 78) # Increased height and width
	hotbar_bg.size = Vector2(680, 78)
	hotbar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_bg.offset_bottom = -4
	hotbar_bg.offset_top = -82
	hotbar_bg.offset_left = -340
	hotbar_bg.offset_right = 340
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14) # Smoother corner rounding
	style.bg_color = Color(0.04, 0.04, 0.05, 0.85)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.22, 0.22, 0.28, 0.7)
	style.shadow_size = 15
	style.shadow_color = Color(0, 0, 0, 0.6)
	hotbar_bg.add_theme_stylebox_override("panel", style)
	main_dock.add_child(hotbar_bg)
	
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10) # More spacing between cards
	hotbar_bg.add_child(hbox)
	
	# A. Left-docked Button: Backpack (🎒)
	var bp_btn := Button.new()
	bp_btn.name = "BackpackShortcut"
	bp_btn.text = "🎒"
	bp_btn.custom_minimum_size = Vector2(50, 54) # Match slots heights
	bp_btn.tooltip_text = "Open Backpack Inventory [I]"
	_setup_hud_shortcut_button_style(bp_btn)
	bp_btn.pressed.connect(func() -> void: toggle_inventory_backpack(not is_instance_valid(_inventory_overlay)))
	hbox.add_child(bp_btn)
	
	_add_hotkey_label(main_dock, "[I]", 40, true)
	
	# Splitter line
	var sep_left := VSeparator.new()
	sep_left.add_theme_constant_override("separation", 6)
	hbox.add_child(sep_left)
	
	# B. Middle Area: Slots 0 to 7 (UPGRADED TO 54x54 GIANTS SHAPES)
	for i in range(8):
		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(54, 54) # Large layout
		slot.pivot_offset = Vector2(27, 27) 
		
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(8)
		slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.6)
		slot.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot)
		
		# Giant Inner Color Icon Rect (Updated dynamically on sync)
		var icon := ColorRect.new()
		icon.name = "ItemIcon"
		icon.custom_minimum_size = Vector2(32, 32) # Shaded 3D voxel look
		icon.size = Vector2(32, 32)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		slot.add_child(icon)
		
		var qty_label := Label.new()
		qty_label.name = "QtyLabel"
		qty_label.text = ""
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		
		var label_style := LabelSettings.new()
		label_style.font_size = 15 # Larger counter font
		label_style.outline_size = 4
		label_style.outline_color = Color.BLACK
		qty_label.label_settings = label_style
		
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_bottom", -1)
		margin.add_child(qty_label)
		
		slot.add_child(margin)
		hotbar_slots.append(slot)
		
	# Splitter line
	var sep_right := VSeparator.new()
	sep_right.add_theme_constant_override("separation", 6)
	hbox.add_child(sep_right)
	
	# C. Right-docked Button: Workshop (🛠️)
	var cr_btn := Button.new()
	cr_btn.name = "WorkshopShortcut"
	cr_btn.text = "🛠️"
	cr_btn.custom_minimum_size = Vector2(50, 54)
	cr_btn.tooltip_text = "Open Crafting Workshop [C]"
	_setup_hud_shortcut_button_style(cr_btn)
	cr_btn.pressed.connect(func() -> void: toggle_crafting_workshop(not is_instance_valid(_crafting_overlay)))
	hbox.add_child(cr_btn)
	
	_add_hotkey_label(main_dock, "[C]", -40, false)
		
	# Draw initial state of status bars
	update_health_display(3)

## Private helper adding out-of-hbox helper shortcut labels to preserve alignment
func _add_hotkey_label(dock: Control, text_label: String, offset_val: int, is_left: bool) -> void:
	var label := Label.new()
	label.text = text_label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var out_style := LabelSettings.new()
	out_style.font_size = 9
	out_style.font_color = Color(0.65, 0.65, 0.7)
	out_style.outline_size = 2
	out_style.outline_color = Color.BLACK
	label.label_settings = out_style
	
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if is_left else Control.PRESET_BOTTOM_RIGHT)
	if is_left:
		label.offset_left = offset_val
		label.offset_right = offset_val + 40
	else:
		label.offset_right = offset_val
		label.offset_left = offset_val - 40
		
	label.offset_bottom = 2
	label.offset_top = -10
	dock.add_child(label)

func _setup_item_name_toast() -> void:
	_item_name_toast = Label.new()
	_item_name_toast.name = "ItemNameToast"
	_item_name_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_item_name_toast.offset_bottom = -140 # Aligns nicely above status bars
	_item_name_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style := LabelSettings.new()
	style.font_size = 18
	style.font_color = Color(1.0, 1.0, 1.0)
	style.outline_size = 5
	style.outline_color = Color.BLACK
	_item_name_toast.label_settings = style
	
	_item_name_toast.modulate.a = 0.0 
	add_child(_item_name_toast)

func _setup_pause_menu() -> void:
	_pause_overlay = Panel.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.45)
	_pause_overlay.add_theme_stylebox_override("panel", bg_style)
	
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	
	var title := Label.new()
	title.text = "GAME PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var title_style := LabelSettings.new()
	title_style.font_size = 32
	title_style.font_color = Color(1.0, 0.95, 0.85)
	title_style.outline_size = 4
	title_style.outline_color = Color.BLACK
	title.label_settings = title_style
	box.add_child(title)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)
	
	var resume_btn := Button.new()
	resume_btn.text = "RESUME GAME"
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer2)
	
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer3)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUIT TO MAIN MENU"
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)
	
	# STRICT MODE & CLEAN SRP: Stylize pause buttons directly inside scope (No more dynamic p_visible helper)
	var btn_size := Vector2(250, 48)
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	sn.set_corner_radius_all(10)
	sn.border_width_left = 1
	sn.border_width_top = 1
	sn.border_width_right = 1
	sn.border_width_bottom = 1
	sn.border_color = Color(0.25, 0.25, 0.3, 0.3)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9)
	
	for btn in [resume_btn, settings_btn, quit_btn]:
		btn.custom_minimum_size = btn_size
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sn)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_font_size_override("font_size", 14)
		
	_pause_overlay.visible = false
	add_child(_pause_overlay)

func _setup_hud_shortcut_button_style(btn: Button) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.12, 0.15, 0.4)
	sn.set_corner_radius_all(8)
	sn.border_width_left = 1
	sn.border_width_top = 1
	sn.border_width_right = 1
	sn.border_width_bottom = 1
	sn.border_color = Color(0.25, 0.25, 0.3, 0.3)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.18, 0.22, 0.7)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9) 
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 14)
	
	btn.pivot_offset = Vector2(25, 27) 
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_SINE)
	)

func _process(_delta: float) -> void:
	if is_instance_valid(minimap):
		minimap.update_widget()
	if is_instance_valid(gps_panel):
		gps_panel.update_widget()
	if is_instance_valid(quest_panel):
		quest_panel.update_widget()

func open_dialogue(node: Resource, speaker_name: String) -> void:
	if is_instance_valid(dialogue_manager):
		dialogue_manager.open_dialogue(node, speaker_name)

func toggle_crafting_workshop(p_visible: bool) -> void:
	if _pause_overlay.visible or is_instance_valid(_inventory_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_crafting_overlay):
			return
			
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
	if _pause_overlay.visible or is_instance_valid(_crafting_overlay):
		return 
		
	if p_visible:
		if is_instance_valid(_inventory_overlay):
			return
			
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
	if not is_instance_valid(_pause_overlay):
		return
		
	if p_visible:
		if is_instance_valid(_crafting_overlay):
			toggle_crafting_workshop(false)
		if is_instance_valid(_inventory_overlay):
			toggle_inventory_backpack(false)
		
	var tween := create_tween().set_parallel(true)
	
	if p_visible:
		_pause_overlay.visible = true
		_pause_overlay.modulate.a = 0.0
		_pause_overlay.scale = Vector2(0.96, 0.96)
		_pause_overlay.pivot_offset = Vector2(640, 360) 
		
		tween.tween_property(_pause_overlay, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(_pause_overlay, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(_pause_overlay, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(_pause_overlay, "scale", Vector2(0.96, 0.96), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		tween.chain().tween_callback(func() -> void:
			_pause_overlay.visible = false
			if is_instance_valid(_settings_overlay):
				_settings_overlay.queue_free()
		)

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
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.85, 0.2, 0.7) 
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
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
	header_lbl.text = "🏆 " + header.to_upper()
	var hs := LabelSettings.new()
	hs.font_size = 11
	hs.font_color = Color(1.0, 0.85, 0.2)
	hs.outline_size = 2
	hs.outline_color = Color.BLACK
	header_lbl.label_settings = hs
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header_lbl)
	
	var desc_lbl := Label.new()
	desc_lbl.text = quest_title
	var ds := LabelSettings.new()
	ds.font_size = 13
	ds.font_color = Color.WHITE
	ds.outline_size = 2
	ds.outline_color = Color.BLACK
	desc_lbl.label_settings = ds
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_lbl)
	
	var toast_tween := create_tween()
	toast_tween.tween_property(toast, "offset_top", 25, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	toast_tween.tween_interval(2.8)
	toast_tween.tween_property(toast, "offset_top", -90, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	toast_tween.tween_callback(toast.queue_free)

func _on_resume_pressed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	toggle_pause_menu(false)

func _on_settings_pressed() -> void:
	var sm_script: Script = load("res://src/Infrastructure/UI/SettingsMenu.gd")
	if sm_script != null:
		_settings_overlay = sm_script.new() as Control
		_settings_overlay.connect("closed", Callable(self, "_on_settings_closed"))
		add_child(_settings_overlay)

func _on_settings_closed() -> void:
	if is_instance_valid(_settings_overlay):
		_settings_overlay.queue_free()

func _on_quit_pressed() -> void:
	var bootstrap = get_node_or_null("/root/Bootstrap")
	if is_instance_valid(bootstrap) and bootstrap.has_method("return_to_main_menu"):
		bootstrap.call("return_to_main_menu")

func update_active_slot(active_index: int) -> void:
	for i in range(hotbar_slots.size()):
		var slot: Panel = hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		if style == null: continue
			
		var tween := create_tween()
			
		if i == active_index:
			style.bg_color = Color(0.25, 0.25, 0.25, 0.8)
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(1.0, 0.85, 0.2)
			
			tween.tween_property(slot, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			
			if is_instance_valid(player) and is_instance_valid(_item_name_toast):
				var inventory = player.get("inventory") as InventoryComponent
				if is_instance_valid(inventory):
					var item_name := inventory.get_slot_item_name(i)
					_item_name_toast.text = item_name.to_upper()
					_show_toast_notification()
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.2, 0.4)
			
			tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_toast_notification() -> void:
	if is_instance_valid(_toast_tween) and _toast_tween.is_running():
		_toast_tween.kill()
		
	_item_name_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8) 
	_toast_tween.tween_property(_item_name_toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

## HIGH-FIDELITY UPDATE: Dynamic 3D Voxel Shaded Block Icons inside HUD slots
func update_slot_quantity(slot_index: int, item_id: int, quantity: int) -> void:
	if slot_index >= 0 and slot_index < hotbar_slots.size():
		var slot: Panel = hotbar_slots[slot_index]
		var icon := slot.get_node_or_null("ItemIcon") as ColorRect
		var label := slot.get_node_or_null("MarginContainer/QtyLabel") as Label
		
		# 1. Update visual icon colors and apply an internal 3D voxel shadow relief!
		if is_instance_valid(icon):
			for child in icon.get_children():
				child.queue_free()
				
			icon.color = BLOCK_COLORS.get(item_id, Color(0, 0, 0, 0))
			icon.visible = (item_id != -1) 
			
			# If it is a solid block, draw a dark inner relief border representing a voxel edge
			if item_id >= 1 and item_id <= 15:
				var shadow := ColorRect.new()
				shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				shadow.offset_left = 3 
				shadow.offset_top = 3
				shadow.color = Color(0, 0, 0, 0.18) 
				shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.add_child(shadow)
				
		# 2. Update numeric stack count dynamically
		if is_instance_valid(label):
			if item_id == -1 or quantity == 0:
				label.text = ""
			elif quantity == -1:
				label.text = "" 
			else:
				label.text = str(quantity)

## HIGH-FIDELITY UPDATE: True Minecraft Hearts & Food/Drumsticks dynamic rendering (Font 20!)
func update_health_display(current_hp: int) -> void:
	if not is_instance_valid(_hearts_container) or not is_instance_valid(_food_container):
		return
		
	for child in _hearts_container.get_children(): child.queue_free()
	for child in _food_container.get_children(): child.queue_free()
	
	# 2. Redraw Hearts based on current health (max 3 HP - Font 20!)
	for i in range(3):
		var heart := Label.new()
		var hs := LabelSettings.new()
		hs.font_size = 20 # Increased visibility
		hs.outline_size = 4
		hs.outline_color = Color.BLACK
		
		if i < current_hp:
			heart.text = "❤" 
			hs.font_color = Color(0.95, 0.15, 0.15) 
		else:
			heart.text = "🖤" 
			hs.font_color = Color(0.22, 0.22, 0.26) 
			
		heart.label_settings = hs
		_hearts_container.add_child(heart)
		
	# 3. Redraw Food Drumsticks based on active Fried Chicken quantity in Backpack!
	var drumsticks_count := 0
	if is_instance_valid(player):
		var inventory = player.get("inventory") as InventoryComponent
		if is_instance_valid(inventory):
			drumsticks_count = inventory.get_item_total_quantity(16)
			
	var display_drumsticks := clamp(drumsticks_count, 1, 10)
	
	for i in range(display_drumsticks):
		var drumstick := Label.new()
		drumstick.text = "🍗"
		var ds := LabelSettings.new()
		ds.font_size = 20 # Match hearts font size
		ds.outline_size = 4
		ds.outline_color = Color.BLACK
		
		if drumsticks_count == 0:
			ds.font_color = Color(0.22, 0.22, 0.26)
		else:
			ds.font_color = Color(1.0, 0.7, 0.35) 
			
		drumstick.label_settings = ds
		_food_container.add_child(drumstick)

## FASE 1: Public API returning if any interactive glassmorphic menu is currently open on screen
func is_any_menu_open() -> bool:
	return (
		_pause_overlay.visible or
		is_instance_valid(_crafting_overlay) or
		is_instance_valid(_inventory_overlay) or
		(is_instance_valid(dialogue_manager) and is_instance_valid(dialogue_manager.active_dialogue))
	)

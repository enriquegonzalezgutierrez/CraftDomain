# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller acting as a lightweight Orchestrator.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by delegating visual operations to widgets.
#              UX UPGRADE (MINECRAFT STYLE): Decluttered the Hotbar. Removed 
#              static text tags from slots, shrunk slot sizes, placed quantities 
#              in the bottom right corner, and implemented a fading "Toast" label 
#              that shows the item name contextually and then disappears.
#              FIXED: Added color-coded procedural visual icons inside each slot 
#              to represent the selected materials clearly and avoid empty grey boxes.
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
var health_label: Label
var hotbar_slots: Array[Panel] = []

# UX Overlays
var damage_overlay: ColorRect
var _pause_overlay: Panel
var _settings_overlay: Control

# Modern 8-Slot Hotbar items mapping
const HOTBAR_ITEMS = ["Stone Block", "Dirt Block", "Grass Block", "Wood Log", "Leaves", "Lava Bucket", "Fried Chicken", "Wooden Sword"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_damage_overlay()
	_setup_crosshair()
	_setup_minimap()             
	_setup_navigation_gps_panel() 
	_setup_quest_tracker_panel()  
	
	_setup_hotbar()
	_setup_item_name_toast()
	_setup_health_display()
	_setup_pause_menu()
	
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
	
	# Positioning (Top Left under Health Bar)
	quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	quest_panel.offset_left = 20
	quest_panel.offset_top = 80
	
	add_child(quest_panel)

func _setup_hotbar() -> void:
	var hotbar_bg := Panel.new()
	hotbar_bg.name = "HotbarBackground"
	hotbar_bg.custom_minimum_size = Vector2(560, 70)
	hotbar_bg.size = Vector2(560, 70)
	
	hotbar_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hotbar_bg.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hotbar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	
	hotbar_bg.offset_left = -280
	hotbar_bg.offset_right = 280
	hotbar_bg.offset_bottom = -20
	hotbar_bg.offset_top = -90
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(12)
	style.bg_color = Color(0.05, 0.05, 0.05, 0.8)
	style.shadow_size = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	hotbar_bg.add_theme_stylebox_override("panel", style)
	add_child(hotbar_bg)
	
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_bg.add_child(hbox)
	
	# Primary palette colors representing each active item
	var item_colors = [
		Color(0.55, 0.55, 0.55), # Stone Block (Solid Grey)
		Color(0.55, 0.38, 0.25), # Dirt Block (Chocolate Soil Brown)
		Color(0.42, 0.78, 0.25), # Grass Block (Vibrant Green)
		Color(0.72, 0.55, 0.35), # Wood Log (Warm Oak Tan)
		Color(0.25, 0.65, 0.18), # Leaves (Forest Green)
		Color(1.0, 0.45, 0.0),   # Lava Bucket (Glowing Orange)
		Color(0.92, 0.62, 0.62), # Fried Chicken (Pinkish/Beige)
		Color(0.75, 0.75, 0.80)  # Wooden Sword (Steel Grey/Worn)
	]
	
	for i in range(8):
		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(46, 46)
		slot.pivot_offset = Vector2(23, 23) 
		
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(6)
		slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.6)
		slot.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot)
		
		# FIXED: Center-anchored minimalist procedural colored icon
		var icon := ColorRect.new()
		icon.name = "ItemIcon"
		icon.custom_minimum_size = Vector2(22, 22)
		icon.size = Vector2(22, 22)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		icon.color = item_colors[i]
		slot.add_child(icon)
		
		# Quantity label positioned on top of the colored icon (Minecraft style)
		var qty_label := Label.new()
		qty_label.name = "QtyLabel"
		qty_label.text = ""
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		
		var label_style := LabelSettings.new()
		label_style.font_size = 14
		label_style.outline_size = 4
		label_style.outline_color = Color.BLACK
		qty_label.label_settings = label_style
		
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_bottom", -2)
		margin.add_child(qty_label)
		
		slot.add_child(margin)
		hotbar_slots.append(slot)

func _setup_item_name_toast() -> void:
	_item_name_toast = Label.new()
	_item_name_toast.name = "ItemNameToast"
	_item_name_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_item_name_toast.offset_bottom = -85 
	_item_name_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var style := LabelSettings.new()
	style.font_size = 20
	style.font_color = Color(1.0, 1.0, 1.0)
	style.outline_size = 5
	style.outline_color = Color.BLACK
	_item_name_toast.label_settings = style
	
	_item_name_toast.modulate.a = 0.0 
	add_child(_item_name_toast)

func _setup_health_display() -> void:
	var health_bg := Panel.new()
	health_bg.name = "HealthBackground"
	health_bg.custom_minimum_size = Vector2(160, 45)
	health_bg.size = Vector2(160, 45)
	health_bg.grow_horizontal = ColorRect.GROW_DIRECTION_END
	health_bg.grow_vertical = ColorRect.GROW_DIRECTION_END
	health_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	health_bg.offset_left = 20
	health_bg.offset_top = 20
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(8)
	style.bg_color = Color(0.12, 0.12, 0.12, 0.5)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.25, 0.25, 0.8)
	style.shadow_size = 4
	style.shadow_color = Color(0, 0, 0, 0.2)
	health_bg.add_theme_stylebox_override("panel", style)
	add_child(health_bg)
	
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	health_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	health_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var label_style := LabelSettings.new()
	label_style.font_size = 18
	label_style.font_color = Color(0.95, 0.15, 0.15)
	label_style.outline_size = 4
	label_style.outline_color = Color.BLACK
	
	health_label.label_settings = label_style
	
	health_bg.add_child(health_label)
	update_health_display(3)

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
	resume_btn.custom_minimum_size = Vector2(250, 48)
	resume_btn.pressed.connect(_on_resume_pressed)
	box.add_child(resume_btn)
	
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer2)
	
	var settings_btn := Button.new()
	settings_btn.text = "SETTINGS"
	settings_btn.custom_minimum_size = Vector2(250, 48)
	settings_btn.pressed.connect(_on_settings_pressed)
	box.add_child(settings_btn)
	
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer3)
	
	var quit_btn := Button.new()
	quit_btn.text = "QUIT TO MAIN MENU"
	quit_btn.custom_minimum_size = Vector2(250, 48)
	quit_btn.pressed.connect(_on_quit_pressed)
	box.add_child(quit_btn)
	
	_pause_overlay.visible = false
	add_child(_pause_overlay)

func _process(_delta: float) -> void:
	if is_instance_valid(minimap):
		minimap.update_widget()
	if is_instance_valid(gps_panel):
		gps_panel.update_widget()
	if is_instance_valid(quest_panel):
		quest_panel.update_widget()

func open_dialogue(node: Resource, speaker_name: String) -> void:
	if is_instance_valid(player):
		var dm = player.get("dialogue_manager")
		if is_instance_valid(dm) and dm.has_method("open_dialogue"):
			dm.call("open_dialogue", node, speaker_name)

func toggle_pause_menu(p_visible: bool) -> void:
	if not is_instance_valid(_pause_overlay):
		return
		
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
	margin.add_theme_constant_override("margin_left", 14)
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
			
			# Trigger fading toast
			if is_instance_valid(_item_name_toast):
				_item_name_toast.text = HOTBAR_ITEMS[i].to_upper()
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

## MINECRAFT UX: Only numeric quantities in the bottom right over the custom color icon
func update_slot_quantity(slot_index: int, _item_name: String, quantity: int) -> void:
	if slot_index >= 0 and slot_index < hotbar_slots.size():
		var slot: Panel = hotbar_slots[slot_index]
		var label: Label = slot.get_node_or_null("MarginContainer/QtyLabel")
		if is_instance_valid(label):
			if quantity < 0:
				label.text = "" # Infinite (like the Sword) has no number
			else:
				label.text = str(quantity)

func update_health_display(current_hp: int) -> void:
	if is_instance_valid(health_label):
		var hearts_text: String = "HP: "
		for i in range(max(0, current_hp)):
			hearts_text += "❤ "
		health_label.text = hearts_text

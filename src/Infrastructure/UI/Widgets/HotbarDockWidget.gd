# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for building and managing
#              the unified bottom HUD dock, which includes:
#              - Backpack (🎒) and Workshop (🛠️) shortcut buttons.
#              - 8 dynamic quickbar slots.
#              - Floating Hearts (HP) and Drumsticks (Food) status bars.
#              - Item name selection toast notifications.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/Widgets/HotbarDockWidget.gd
# ==============================================================================
class_name HotbarDockWidget
extends Control

## Dependencies injected by the HUD orchestrator
var player: CharacterBody3D
var hud_orchestrator: PlayerHUD

# Internal UI node references
var _hotbar_slots: Array[Panel] = []
var _hearts_container: HBoxContainer
var _food_container: HBoxContainer
var _item_name_toast: Label
var _toast_tween: Tween

const BLOCK_COLORS = {
	-1: Color(0, 0, 0, 0),       
	1: Color(0.55, 0.55, 0.55), 2: Color(0.55, 0.38, 0.25), 
	3: Color(0.42, 0.78, 0.25), 4: Color(0.72, 0.55, 0.35), 
	5: Color(0.25, 0.65, 0.18), 15: Color(1.0, 0.45, 0.0),  
	16: Color(0.92, 0.62, 0.62), 17: Color(0.75, 0.75, 0.80) 
}

func _ready() -> void:
	name = "HotbarDockWidget"
	
	var main_dock := Control.new()
	main_dock.name = "HudBottomDock"
	main_dock.custom_minimum_size = Vector2(760, 140)
	main_dock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	main_dock.offset_bottom = -15
	main_dock.offset_top = -155
	main_dock.offset_left = -380
	main_dock.offset_right = 380
	add_child(main_dock)
	
	_hearts_container = HBoxContainer.new()
	_hearts_container.add_theme_constant_override("separation", 3)
	_hearts_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hearts_container.offset_left = 82 
	_hearts_container.offset_bottom = -84 
	main_dock.add_child(_hearts_container)
	
	_food_container = HBoxContainer.new()
	_food_container.alignment = BoxContainer.ALIGNMENT_END
	_food_container.add_theme_constant_override("separation", 3)
	_food_container.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_food_container.offset_right = -82 
	_food_container.offset_bottom = -84
	main_dock.add_child(_food_container)
	
	var hotbar_bg := _create_hotbar_background_panel()
	main_dock.add_child(hotbar_bg)
	
	var hbox := _create_hotbar_hbox(main_dock)
	hotbar_bg.add_child(hbox)
	
	_setup_item_name_toast()
	update_health_display(3)

func _create_hotbar_background_panel() -> Panel:
	var hotbar_bg := Panel.new()
	hotbar_bg.custom_minimum_size = Vector2(680, 78)
	hotbar_bg.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_bg.offset_bottom = -4
	hotbar_bg.offset_top = -82
	hotbar_bg.offset_left = -340
	hotbar_bg.offset_right = 340
	
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(14)
	style.bg_color = Color(0.04, 0.04, 0.05, 0.85)
	style.border_width_left = 2; style.border_width_top = 2; style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color(0.22, 0.22, 0.28, 0.7)
	style.shadow_size = 15; style.shadow_color = Color(0, 0, 0, 0.6)
	hotbar_bg.add_theme_stylebox_override("panel", style)
	return hotbar_bg

func _create_hotbar_hbox(main_dock: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	
	var bp_btn := _create_shortcut_button("🎒", tr("HUD_TOOLTIP_BACKPACK"))
	bp_btn.pressed.connect(_on_backpack_shortcut_pressed)
	hbox.add_child(bp_btn)
	_add_hotkey_label(main_dock, "[I]", 40, true)
	
	var sep_left := VSeparator.new()
	sep_left.add_theme_constant_override("separation", 6)
	hbox.add_child(sep_left)
	
	for i in range(8):
		_hotbar_slots.append(_create_hotbar_slot(i, hbox))
		
	var sep_right := VSeparator.new()
	sep_right.add_theme_constant_override("separation", 6)
	hbox.add_child(sep_right)
	
	var cr_btn := _create_shortcut_button("🛠️", tr("HUD_TOOLTIP_WORKSHOP"))
	cr_btn.pressed.connect(_on_workshop_shortcut_pressed)
	hbox.add_child(cr_btn)
	_add_hotkey_label(main_dock, "[C]", -40, false)
	
	return hbox

func _create_hotbar_slot(index: int, parent: HBoxContainer) -> Panel:
	var slot := Panel.new()
	slot.name = "Slot_%d" % index
	slot.custom_minimum_size = Vector2(54, 54)
	slot.pivot_offset = Vector2(27, 27)
	
	var slot_style := StyleBoxFlat.new()
	slot_style.set_corner_radius_all(8)
	slot_style.bg_color = Color(0.12, 0.12, 0.12, 0.6)
	slot.add_theme_stylebox_override("panel", slot_style)
	
	var icon := ColorRect.new(); icon.name = "ItemIcon"; icon.custom_minimum_size = Vector2(32, 32)
	icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER); slot.add_child(icon)
	
	var qty_label := Label.new(); qty_label.name = "QtyLabel"
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	var ls := LabelSettings.new(); ls.font_size = 15; ls.outline_size = 4; ls.outline_color = Color.BLACK
	qty_label.label_settings = ls
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	margin.add_theme_constant_override("margin_right", 4); margin.add_theme_constant_override("margin_bottom", -1)
	margin.add_child(qty_label); slot.add_child(margin)
	
	parent.add_child(slot)
	return slot

func _create_shortcut_button(text: String, tooltip: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(50, 54)
	btn.tooltip_text = tooltip
	btn.pivot_offset = Vector2(25, 27)
	
	var sn := StyleBoxFlat.new(); sn.bg_color = Color(0.12, 0.12, 0.15, 0.4); sn.set_corner_radius_all(8)
	sn.border_width_left = 1; sn.border_width_top = 1; sn.border_width_right = 1; sn.border_width_bottom = 1
	sn.border_color = Color(0.25, 0.25, 0.3, 0.3)
	var sh := sn.duplicate() as StyleBoxFlat; sh.bg_color = Color(0.18, 0.18, 0.22, 0.7)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9)
	
	btn.add_theme_stylebox_override("normal", sn); btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn); btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 14)
	
	btn.mouse_entered.connect(_on_shortcut_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_shortcut_hover.bind(btn, false))
	return btn

func _add_hotkey_label(dock: Control, text: String, offset: int, is_left: bool) -> void:
	var label := Label.new(); label.text = text; label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new(); ls.font_size = 9; ls.font_color = Color(0.65, 0.65, 0.7)
	ls.outline_size = 2; ls.outline_color = Color.BLACK; label.label_settings = ls
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT if is_left else Control.PRESET_BOTTOM_RIGHT)
	if is_left: label.offset_left = offset; label.offset_right = offset + 40
	else: label.offset_right = offset; label.offset_left = offset - 40
	label.offset_bottom = 2; label.offset_top = -10
	dock.add_child(label)

func _setup_item_name_toast() -> void:
	_item_name_toast = Label.new(); _item_name_toast.name = "ItemNameToast"
	_item_name_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_item_name_toast.offset_bottom = -140
	_item_name_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new(); ls.font_size = 18; ls.font_color = Color.WHITE
	ls.outline_size = 5; ls.outline_color = Color.BLACK
	_item_name_toast.label_settings = ls
	_item_name_toast.modulate.a = 0.0; add_child(_item_name_toast)

func _on_backpack_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator): hud_orchestrator.toggle_inventory_backpack(true)

func _on_workshop_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator): hud_orchestrator.toggle_crafting_workshop(true)

func _on_shortcut_hover(btn: Button, hover: bool) -> void:
	if is_instance_valid(btn):
		var target_scale := Vector2(1.08, 1.08) if hover else Vector2(1.0, 1.0)
		var tw := create_tween(); tw.tween_property(btn, "scale", target_scale, 0.08).set_trans(Tween.TRANS_SINE)

func update_active_slot(index: int) -> void:
	for i in range(_hotbar_slots.size()):
		var slot: Panel = _hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		if style == null: continue
		var tween := create_tween()
		if i == index:
			style.bg_color = Color(0.25, 0.25, 0.25, 0.8); style.border_width_left = 3
			style.border_width_top = 3; style.border_width_right = 3; style.border_width_bottom = 3
			style.border_color = Color(1.0, 0.85, 0.2)
			tween.tween_property(slot, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
			_show_toast_notification(index)
		else:
			style.bg_color = Color(0.12, 0.12, 0.12, 0.5); style.border_width_left = 1
			style.border_width_top = 1; style.border_width_right = 1; style.border_width_bottom = 1
			style.border_color = Color(0.2, 0.2, 0.2, 0.4)
			tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _show_toast_notification(index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_item_name_toast): return
	var inventory = player.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory): return
	var item_name := inventory.get_slot_item_name(index)
	_item_name_toast.text = item_name.to_upper()
	if is_instance_valid(_toast_tween) and _toast_tween.is_running(): _toast_tween.kill()
	_item_name_toast.modulate.a = 1.0; _toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_item_name_toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)

func update_slot_quantity(index: int, item_id: int, quantity: int) -> void:
	if index >= 0 and index < _hotbar_slots.size():
		var slot: Panel = _hotbar_slots[index]
		var icon := slot.get_node_or_null("ItemIcon") as ColorRect
		var label := slot.get_node_or_null("MarginContainer/QtyLabel") as Label
		if is_instance_valid(icon):
			for child in icon.get_children(): child.queue_free()
			icon.color = BLOCK_COLORS.get(item_id, Color(0,0,0,0)); icon.visible = (item_id != -1)
			if item_id >= 1 and item_id <= 15:
				var shadow := ColorRect.new()
				shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				shadow.offset_left = 3; shadow.offset_top = 3
				shadow.color = Color(0, 0, 0, 0.18)
				icon.add_child(shadow)
		if is_instance_valid(label):
			label.text = "" if item_id == -1 or quantity <= 0 else str(quantity)

func update_health_display(hp: int) -> void:
	if not is_instance_valid(_hearts_container) or not is_instance_valid(_food_container): return
	for child in _hearts_container.get_children(): child.queue_free()
	for child in _food_container.get_children(): child.queue_free()
	
	for i in range(3):
		var heart := Label.new(); var hs := LabelSettings.new()
		hs.font_size = 20; hs.outline_size = 4; hs.outline_color = Color.BLACK
		if i < hp: heart.text = "❤"; hs.font_color = Color(0.95, 0.15, 0.15)
		else: heart.text = "🖤"; hs.font_color = Color(0.22, 0.22, 0.26)
		heart.label_settings = hs; _hearts_container.add_child(heart)
		
	var food_count := 0
	if is_instance_valid(player):
		var inv = player.get("inventory") as InventoryComponent
		if is_instance_valid(inv): food_count = inv.get_item_total_quantity(16)
			
	var display_food := clamp(food_count, 0, 10)
	for i in range(display_food):
		var food := Label.new(); food.text = "🍗"; var ds := LabelSettings.new()
		ds.font_size = 20; ds.outline_size = 4; ds.outline_color = Color.BLACK
		ds.font_color = Color(1.0, 0.7, 0.35) if food_count > 0 else Color(0.22, 0.22, 0.26)
		food.label_settings = ds; _food_container.add_child(food)

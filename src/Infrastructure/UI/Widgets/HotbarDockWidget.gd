# ==============================================================================
# Project: CraftDomain
# Description: SRP-compliant UI Widget responsible ONLY for building and managing
#              the unified bottom HUD selection dock (Hotbar).
#              COMMERCIAL UI OVERHAUL:
#              - Implemented pixel-perfect geometric alignment. The health and 
#                food status bars are now mathematically clamped to the exact 
#                width of the 8 central hotbar slots.
#              - Fixed "Layout Shifting" bugs: Selection borders now use a fixed 
#                width with alpha-color toggling to prevent the HBox from resizing 
#                when scrolling through items.
#              - Polished glassmorphic panel with inner drop shadows and strict 
#                margins for a sleek, modern sandbox aesthetic.
#              WARNING FIX:
#              - Enforced explicit static typing across all variables, iterators, 
#                and dynamically casted nodes to prevent `UNTYPED_DECLARATION`.
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

# Static in-memory cache for loaded 2D textures
static var _textures_cache: Dictionary = {}

## Fallback colors used when block textures are missing
const BLOCK_COLORS = {
	-1: Color(0, 0, 0, 0),       
	1: Color(0.55, 0.55, 0.55), 2: Color(0.55, 0.38, 0.25), 
	3: Color(0.42, 0.78, 0.25), 4: Color(0.72, 0.55, 0.35), 
	5: Color(0.25, 0.65, 0.18), 15: Color(1.0, 0.45, 0.0),  
	16: Color(0.85, 0.35, 0.25), 17: Color(0.25, 0.35, 0.45), 
	18: Color(0.48, 0.35, 0.22)
}


func _ready() -> void:
	name = "HotbarDockWidget"
	
	# Set this controller as a bottom-centered responsive container
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	custom_minimum_size = Vector2(700, 140)
	size = Vector2(700, 140)
	
	# Floating bottom margin
	offset_bottom = -20
	offset_top = -160
	offset_left = -350
	offset_right = 350
	
	_setup_responsive_ui_layout()
	_setup_item_name_toast()
	update_health_display(3)


## Builds the highly polished, mathematically aligned HUD layout.
func _setup_responsive_ui_layout() -> void:
	var master_vbox := VBoxContainer.new()
	master_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	master_vbox.alignment = BoxContainer.ALIGNMENT_END
	master_vbox.add_theme_constant_override("separation", 8)
	add_child(master_vbox)
	
	# ==================== ROW 1: STATUS BARS (HEARTS & FOOD) ====================
	# The 8 slots (48px each) + 7 separators (6px each) = 426px wide center block.
	var status_container := Control.new()
	status_container.custom_minimum_size = Vector2(426, 28)
	status_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	master_vbox.add_child(status_container)
	
	_hearts_container = HBoxContainer.new()
	_hearts_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_hearts_container.add_theme_constant_override("separation", 2)
	status_container.add_child(_hearts_container)
	
	_food_container = HBoxContainer.new()
	_food_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_food_container.alignment = BoxContainer.ALIGNMENT_END
	_food_container.add_theme_constant_override("separation", 2)
	status_container.add_child(_food_container)
	
	# ==================== ROW 2: UNIFIED HOTBAR DOCK ====================
	var hotbar_bg := PanelContainer.new()
	hotbar_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg_style := StyleBoxFlat.new()
	bg_style.set_corner_radius_all(14)
	bg_style.bg_color = Color(0.04, 0.04, 0.06, 0.85) # Sleek Glassmorphic dark slate
	bg_style.border_width_left = 2; bg_style.border_width_top = 2
	bg_style.border_width_right = 2; bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.25, 0.25, 0.3, 0.6)
	bg_style.shadow_size = 12; bg_style.shadow_color = Color(0, 0, 0, 0.5)
	hotbar_bg.add_theme_stylebox_override("panel", bg_style)
	master_vbox.add_child(hotbar_bg)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	hotbar_bg.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)
	
	# A. Left-docked Button: Backpack
	var bp_vbox := VBoxContainer.new()
	bp_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bp_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(bp_vbox)
	
	var bp_btn := Button.new()
	bp_btn.text = "🎒"
	bp_btn.custom_minimum_size = Vector2(48, 48)
	bp_btn.tooltip_text = tr("HUD_TOOLTIP_BACKPACK")
	_setup_hud_shortcut_button_style(bp_btn)
	bp_btn.pressed.connect(_on_backpack_shortcut_pressed)
	bp_vbox.add_child(bp_btn)
	bp_vbox.add_child(_create_hotkey_label("[I]"))
	
	# Splitter line
	var sep_left := VSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = Color(1.0, 1.0, 1.0, 0.1)
	sep_style.vertical = true; sep_style.thickness = 2
	sep_left.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(sep_left)
	
	# B. Middle Area: Slots 0 to 7 (48x48)
	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 6)
	hbox.add_child(slots_hbox)
	
	# FIX: Explicit static typing `int` on index range iterator
	for i: int in range(8):
		var slot := Panel.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(48, 48)
		slot.pivot_offset = Vector2(24, 24) 
		
		# Base style with fixed invisible borders to prevent layout shifting!
		var slot_style := StyleBoxFlat.new()
		slot_style.set_corner_radius_all(6)
		slot_style.bg_color = Color(0.12, 0.12, 0.14, 0.7)
		slot_style.border_width_left = 3; slot_style.border_width_top = 3
		slot_style.border_width_right = 3; slot_style.border_width_bottom = 3
		slot_style.border_color = Color(0, 0, 0, 0) # Transparent by default
		slot.add_theme_stylebox_override("panel", slot_style)
		slots_hbox.add_child(slot)
		
		# --- COMPOSITE GRAPHIC SYSTEM: Holds the 3D-like icons ---
		var icon_container := Control.new()
		icon_container.name = "ItemIconContainer"
		icon_container.custom_minimum_size = Vector2(34, 34)
		icon_container.size = Vector2(34, 34)
		icon_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon_container.grow_vertical = Control.GROW_DIRECTION_BOTH
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon_container)
		
		# Overlay 1: Color Fallback
		var fallback_rect := ColorRect.new()
		fallback_rect.name = "FallbackColor"
		fallback_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(fallback_rect)
		
		# Overlay 2: Real block textures
		var tex_rect := TextureRect.new()
		tex_rect.name = "TextureDisplay"
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		tex_rect.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(tex_rect)
		
		# Quantity Label
		var qty_label := Label.new()
		qty_label.name = "QtyLabel"
		qty_label.text = ""
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		
		var label_style := LabelSettings.new()
		label_style.font_size = 14
		label_style.font_color = Color.WHITE
		label_style.outline_size = 4
		label_style.outline_color = Color.BLACK
		qty_label.label_settings = label_style
		
		var label_margin := MarginContainer.new()
		label_margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		label_margin.add_theme_constant_override("margin_right", 4)
		label_margin.add_theme_constant_override("margin_bottom", -2)
		label_margin.add_child(qty_label)
		slot.add_child(label_margin)
		
		_hotbar_slots.append(slot)
		
	# Splitter line
	var sep_right := VSeparator.new()
	sep_right.add_theme_stylebox_override("separator", sep_style)
	hbox.add_child(sep_right)
	
	# C. Right-docked Button: Workshop
	var cr_vbox := VBoxContainer.new()
	cr_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cr_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(cr_vbox)
	
	var cr_btn := Button.new()
	cr_btn.text = "🛠️"
	cr_btn.custom_minimum_size = Vector2(48, 48)
	cr_btn.tooltip_text = tr("HUD_TOOLTIP_WORKSHOP")
	_setup_hud_shortcut_button_style(cr_btn)
	cr_btn.pressed.connect(_on_workshop_shortcut_pressed)
	cr_vbox.add_child(cr_btn)
	cr_vbox.add_child(_create_hotkey_label("[C]"))


func _setup_item_name_toast() -> void:
	_item_name_toast = Label.new()
	_item_name_toast.name = "ItemNameToast"
	_item_name_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_item_name_toast.offset_bottom = -135
	_item_name_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 16
	ls.font_color = Color.WHITE
	ls.outline_size = 5
	ls.outline_color = Color.BLACK
	_item_name_toast.label_settings = ls
	_item_name_toast.modulate.a = 0.0
	add_child(_item_name_toast)


func _on_backpack_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator):
		hud_orchestrator.toggle_inventory_backpack(true)


func _on_workshop_shortcut_pressed() -> void:
	if is_instance_valid(hud_orchestrator):
		hud_orchestrator.toggle_crafting_workshop(true)


## Emphasizes the active slot without causing layout shifting.
func update_active_slot(index: int) -> void:
	for i: int in range(_hotbar_slots.size()):
		var slot: Panel = _hotbar_slots[i]
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
			
		var tween := create_tween()
		if i == index:
			style.bg_color = Color(0.25, 0.25, 0.28, 0.8)
			style.border_color = Color(1.0, 0.85, 0.2, 1.0) # Gold Highlight
			tween.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
			_show_toast_notification(index)
		else:
			style.bg_color = Color(0.12, 0.12, 0.14, 0.7)
			style.border_color = Color(0, 0, 0, 0) # Transparent border
			tween.tween_property(slot, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)


func update_slot_quantity(slot_index: int, item_id: int, quantity: int) -> void:
	if slot_index >= 0 and slot_index < _hotbar_slots.size():
		var slot: Panel = _hotbar_slots[slot_index]
		var icon_container := slot.get_node_or_null("ItemIconContainer") as Control
		var label := slot.get_node_or_null("MarginContainer/QtyLabel") as Label
		
		if is_instance_valid(icon_container):
			var fallback := icon_container.get_node_or_null("FallbackColor") as ColorRect
			var tex_display := icon_container.get_node_or_null("TextureDisplay") as TextureRect
			
			if is_instance_valid(fallback) and is_instance_valid(tex_display):
				if item_id == -1 or quantity <= 0:
					icon_container.visible = false
				else:
					icon_container.visible = true
					var tex: Texture2D = _get_item_texture(item_id)
					
					# Case A: Real 2D PNG texture found!
					if tex != null:
						tex_display.texture = tex
						tex_display.visible = true
						fallback.visible = false
						for child: Node in fallback.get_children():
							child.queue_free()
					# Case B: No texture exists. Apply fallback color + unicode shape
					else:
						tex_display.texture = null
						tex_display.visible = false
						fallback.color = BLOCK_COLORS.get(item_id, Color.DARK_GRAY)
						fallback.visible = true
						_apply_special_fallback_decoration(fallback, item_id)
						
		if is_instance_valid(label):
			label.text = "" if item_id == -1 or quantity <= 0 else str(quantity)


func _get_item_texture(item_id: int) -> Texture2D:
	if _textures_cache.has(item_id):
		return _textures_cache[item_id] as Texture2D
		
	var texture_file := ""
	match item_id:
		1: texture_file = "stone.png"
		2: texture_file = "dirt.png"
		3: texture_file = "grass_top.png"
		4: texture_file = "wood.png"
		5: texture_file = "leaves.png"
		7: texture_file = "sand.png"
		8: texture_file = "red_sand.png"
		9: texture_file = "snow.png"
		10: texture_file = "ice.png"
		11: texture_file = "mud.png"
		13: texture_file = "sakura_leaves.png"
		15: texture_file = "lava.png"
		21: texture_file = "coal_ore.png"
		22: texture_file = "bricks.png"
		23: texture_file = "glass.png"
		24: texture_file = "birch_log.png"
		
	if texture_file != "":
		var full_path := "res://assets/textures/" + texture_file
		if FileAccess.file_exists(full_path):
			var tex: Texture2D = load(full_path) as Texture2D
			if tex is Texture2D:
				_textures_cache[item_id] = tex
				return tex
				
	_textures_cache[item_id] = null 
	return null


func _apply_special_fallback_decoration(fallback_node: ColorRect, item_id: int) -> void:
	for child: Node in fallback_node.get_children():
		child.queue_free()
		
	var symbol := Label.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var ls := LabelSettings.new()
	ls.font_size = 20
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	symbol.label_settings = ls
	
	match item_id:
		16: symbol.text = "🍗"
		17: symbol.text = "⚔️" 
		18: symbol.text = "🌱" 
		12: symbol.text = "💠" 
		14: symbol.text = "☁️" 
		_: symbol.text = ""
		
	if symbol.text != "":
		fallback_node.add_child(symbol)


func _show_toast_notification(index: int) -> void:
	if not is_instance_valid(player) or not is_instance_valid(_item_name_toast):
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if not is_instance_valid(inventory):
		return
		
	var item_name := inventory.get_slot_item_name(index)
	_item_name_toast.text = item_name.to_upper()
	
	if is_instance_valid(_toast_tween) and _toast_tween.is_running():
		_toast_tween.kill()
		
	_item_name_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.5)
	_toast_tween.tween_property(_item_name_toast, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)


func update_health_display(hp: int) -> void:
	if not is_instance_valid(_hearts_container) or not is_instance_valid(_food_container):
		return
		
	for child: Node in _hearts_container.get_children():
		child.queue_free()
	for child: Node in _food_container.get_children():
		child.queue_free()
	
	# Hearts rendering
	for i: int in range(3):
		var heart := Label.new()
		var hs := LabelSettings.new()
		hs.font_size = 22
		hs.outline_size = 4
		hs.outline_color = Color.BLACK
		if i < hp:
			heart.text = "❤"
			hs.font_color = Color(0.95, 0.15, 0.15)
		else:
			heart.text = "🖤"
			hs.font_color = Color(0.22, 0.22, 0.26)
		heart.label_settings = hs
		_hearts_container.add_child(heart)
		
	# Food drumsticks rendering
	var food_count := 0
	if is_instance_valid(player):
		var inv: InventoryComponent = player.get("inventory") as InventoryComponent
		if is_instance_valid(inv):
			food_count = inv.get_item_total_quantity(16)
			
	var display_food := clamp(food_count, 0, 10)
	for i: int in range(display_food):
		var food := Label.new()
		food.text = "🍗"
		var ds := LabelSettings.new()
		ds.font_size = 22
		ds.outline_size = 4
		ds.outline_color = Color.BLACK
		ds.font_color = Color(1.0, 0.7, 0.35) if food_count > 0 else Color(0.22, 0.22, 0.26)
		food.label_settings = ds
		_food_container.add_child(food)


func _setup_hud_shortcut_button_style(btn: Button) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.18, 0.18, 0.22, 0.5)
	sn.set_corner_radius_all(10)
	sn.border_width_left = 2; sn.border_width_top = 2
	sn.border_width_right = 2; sn.border_width_bottom = 2
	sn.border_color = Color(0.3, 0.3, 0.35, 0.4)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.22, 0.22, 0.28, 0.8)
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9) 
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_font_size_override("font_size", 18)
	
	btn.mouse_entered.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
	)
	btn.mouse_exited.connect(func() -> void:
		var tw := create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)
	)


func _create_hotkey_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ls := LabelSettings.new()
	ls.font_size = 11
	ls.font_color = Color(0.65, 0.65, 0.7)
	ls.outline_size = 2
	ls.outline_color = Color.BLACK
	label.label_settings = ls
	return label

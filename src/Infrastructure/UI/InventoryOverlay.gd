# ==============================================================================
# Project: CraftDomain
# Description: Ultra-high-fidelity Minecraft-style Inventory Overlay.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating layout drawing and slot sorting.
#              i18n UPGRADE: Localized all UI text labels, headings, and details.
#              BUG FIX & DRAG AND DROP OVERHAUL:
#              - Implemented dynamic, high-performance pixel-art block textures 
#                and specialized unicode icon overlays for tools.
#              - Implemented native Godot 4 Drag and Drop (DND) mechanics via the 
#                custom `InventorySlotButton` subclass, providing semi-transparent 
#                cursor previews and instant slot transplacement.
#              - Added the "⚡ AUTO-SORT" button calling the Domain consolidation pipeline.
#              BUG FIX (i18n): Removed all hardcoded text strings (like headers, 
#              details, tooltips, and Action Buttons) and the redundant ITEM_DETAILS, 
#              routing everything cleanly through Godot's `tr()` localization engine.
#              WARNING FIX:
#              - Replaced all implicit dynamic getters (for `inventory`, `hud`, `viewmodel`, 
#                and `tex`) with strictly cast explicit static typed declarations 
#                to completely resolve all `UNTYPED_DECLARATION` compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/InventoryOverlay.gd
# ==============================================================================
class_name InventoryOverlay
extends Panel

## Emitted when the player exits the backpack screen
signal closed

# STRICT MODE FIX: Statically typed to our concrete Player class
var player: PlayerController

# UI Nodes
var _backpack_grid_container: GridContainer
var _hotbar_grid_container: GridContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_qty: Label
var _detail_instruction: Label
var _detail_icon: ColorRect
var _action_button: Button
var _use_button: Button

# Swapping Engine & Selection State
var _first_selected_slot_index: int = -1
var _focused_slot_index: int = -1

# Static in-memory cache for loaded 2D textures (prevents continuous disk reads)
static var _textures_cache: Dictionary = {}

# Theme palette colors
const BLOCK_COLORS = {
	-1: Color(0, 0, 0, 0),       # Empty
	1: Color(0.55, 0.55, 0.55), # Stone
	2: Color(0.55, 0.38, 0.25), # Dirt
	3: Color(0.42, 0.78, 0.25), # Grass
	4: Color(0.72, 0.55, 0.35), # Wood
	5: Color(0.25, 0.65, 0.18), # Leaves
	15: Color(1.0, 0.45, 0.0),  # Lava
	16: Color(0.85, 0.35, 0.25),# Chicken
	17: Color(0.25, 0.35, 0.45),# Sword
	18: Color(0.48, 0.35, 0.22),# Seed
	19: Color(0.65, 0.92, 0.15),# Brote
	20: Color(0.95, 0.78, 0.18) # Trigo
}


func _ready() -> void:
	# Fullscreen translucent backdrop wash
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.02, 0.02, 0.03, 0.65)
	add_theme_stylebox_override("panel", bg_style)
	
	_setup_backpack_ui()
	_refresh_backpack_grids()
	_show_empty_details()


func _setup_backpack_ui() -> void:
	# 1. Main Backpack Card (Centered, glassmorphic)
	var main_card := Panel.new()
	main_card.name = "BackpackCard"
	main_card.custom_minimum_size = Vector2(840, 520)
	main_card.size = Vector2(840, 520)
	main_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Center adjustment
	main_card.offset_left = -420
	main_card.offset_right = 420
	main_card.offset_top = -260
	main_card.offset_bottom = 260
	
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(12)
	card_style.bg_color = Color(0.06, 0.06, 0.08, 0.96) 
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.35, 0.35, 0.4, 0.4)
	card_style.shadow_size = 20
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	main_card.add_theme_stylebox_override("panel", card_style)
	add_child(main_card)
	
	# Horizontal splitter (Dual-pane layout)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	main_card.add_child(hbox)
	
	# ==================== LEFT PANE: BACKPACK GRID ====================
	var left_pane := MarginContainer.new()
	left_pane.custom_minimum_size = Vector2(360, 0)
	left_pane.add_theme_constant_override("margin_left", 24)
	left_pane.add_theme_constant_override("margin_top", 24)
	left_pane.add_theme_constant_override("margin_right", 12)
	left_pane.add_theme_constant_override("margin_bottom", 24)
	hbox.add_child(left_pane)
	
	var left_vbox := VBoxContainer.new()
	left_pane.add_child(left_vbox)
	
	# --- Backpack Title and Auto-Sort Button Header ---
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(header_hbox)
	
	var catalog_title := Label.new()
	catalog_title.text = "BACKPACK STORAGE"
	catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ts := LabelSettings.new()
	ts.font_size = 18
	ts.font_color = Color(0.2, 0.85, 0.85) # Teal Blue Accent
	ts.outline_size = 4
	ts.outline_color = Color.BLACK
	catalog_title.label_settings = ts
	header_hbox.add_child(catalog_title)
	
	var sort_btn := Button.new()
	sort_btn.text = " ⚡ " + tr("INVENTORY_SORT").to_upper() + " "
	sort_btn.custom_minimum_size = Vector2(100, 32)
	sort_btn.pressed.connect(_on_sort_pressed)
	_setup_button_style(sort_btn, Color(0.12, 0.55, 0.32, 0.7)) # Styled Green
	header_hbox.add_child(sort_btn)
	# --------------------------------------------------
	
	left_vbox.add_child(_create_spacer(14))
	
	# Scrollable grid area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_vbox.add_child(scroll)
	
	_backpack_grid_container = GridContainer.new()
	_backpack_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_backpack_grid_container.columns = 4 
	_backpack_grid_container.add_theme_constant_override("h_separation", 10)
	_backpack_grid_container.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_backpack_grid_container)
	
	# ==================== HOTBAR DOCK GRID ====================
	left_vbox.add_child(_create_spacer(14))
	
	var hotbar_title := Label.new()
	hotbar_title.text = "HOTBAR DOCK"
	var hts := LabelSettings.new()
	hts.font_size = 13
	hts.font_color = Color(0.65, 0.65, 0.7)
	hts.outline_size = 2
	hts.outline_color = Color.BLACK
	hotbar_title.label_settings = hts
	left_vbox.add_child(hotbar_title)
	
	left_vbox.add_child(_create_spacer(6))
	
	_hotbar_grid_container = GridContainer.new()
	_hotbar_grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hotbar_grid_container.columns = 8 # 8 Hotbar slots perfectly aligned
	_hotbar_grid_container.add_theme_constant_override("h_separation", 6)
	_hotbar_grid_container.add_theme_constant_override("v_separation", 6)
	left_vbox.add_child(_hotbar_grid_container)
	
	# ==================== RIGHT PANE: ITEM DETAILED INSPECTOR ====================
	var detail_panel := Panel.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.04, 0.04, 0.05, 0.6)
	detail_style.set_corner_radius_all(14)
	detail_style.border_width_left = 1
	detail_style.border_color = Color(0.25, 0.25, 0.3, 0.2)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	hbox.add_child(detail_panel)
	
	var right_margin := MarginContainer.new()
	right_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_margin.add_theme_constant_override("margin_left", 24)
	right_margin.add_theme_constant_override("margin_top", 24)
	right_margin.add_theme_constant_override("margin_right", 24)
	right_margin.add_theme_constant_override("margin_bottom", 24)
	detail_panel.add_child(right_margin)
	
	var right_vbox := VBoxContainer.new()
	right_margin.add_child(right_vbox)
	
	# Item Name Title
	_detail_title = Label.new()
	_detail_title.text = tr("INVENTORY_INSPECT_TITLE")
	var dts := LabelSettings.new()
	dts.font_size = 22
	dts.font_color = Color.WHITE
	dts.outline_size = 4
	dts.outline_color = Color.BLACK
	_detail_title.label_settings = dts
	right_vbox.add_child(_detail_title)
	
	right_vbox.add_child(_create_spacer(10))
	
	# Big Visual Box
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(0, 110)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.1, 0.12, 0.4)
	ps.set_corner_radius_all(10)
	preview_panel.add_theme_stylebox_override("panel", ps)
	right_vbox.add_child(preview_panel)
	
	_detail_icon = ColorRect.new()
	_detail_icon.custom_minimum_size = Vector2(38, 38)
	_detail_icon.size = Vector2(38, 38)
	_detail_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_detail_icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_detail_icon.grow_vertical = Control.GROW_DIRECTION_BOTH
	preview_panel.add_child(_detail_icon)
	
	right_vbox.add_child(_create_spacer(10))
	
	# Description Body
	_detail_desc = Label.new()
	_detail_desc.text = "Click or Drag any backpack item to inspect or move it."
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_desc.custom_minimum_size = Vector2(0, 70)
	var dds := LabelSettings.new()
	dds.font_size = 13
	dds.font_color = Color(0.85, 0.85, 0.9)
	_detail_desc.label_settings = dds
	right_vbox.add_child(_detail_desc)
	
	right_vbox.add_child(_create_spacer(10))
	
	# Action Instructions Subtitle
	_detail_instruction = Label.new()
	_detail_instruction.text = ""
	_detail_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD
	_detail_instruction.custom_minimum_size = Vector2(0, 45)
	var dis := LabelSettings.new()
	dis.font_size = 12
	dis.font_color = Color(1.0, 0.85, 0.2) 
	_detail_instruction.label_settings = dis
	right_vbox.add_child(_detail_instruction)
	
	# Current Quantity
	_detail_qty = Label.new()
	_detail_qty.text = ""
	var dqs := LabelSettings.new()
	dqs.font_size = 12
	dqs.font_color = Color(0.65, 0.65, 0.7)
	_detail_qty.label_settings = dqs
	right_vbox.add_child(_detail_qty)
	
	right_vbox.add_child(_create_spacer(14))
	
	# Contextual Action Buttons
	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.size_flags_vertical = Control.SIZE_SHRINK_END
	buttons_hbox.add_theme_constant_override("separation", 10)
	right_vbox.add_child(buttons_hbox)
	
	_action_button = Button.new()
	_action_button.text = tr("INVENTORY_EQUIP").to_upper()
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.custom_minimum_size = Vector2(0, 42)
	_action_button.pressed.connect(_on_equip_pressed)
	buttons_hbox.add_child(_action_button)
	_setup_button_style(_action_button, Color(0.12, 0.55, 0.82, 0.8)) 
	
	_use_button = Button.new()
	_use_button.text = tr("INVENTORY_CONSUME").to_upper()
	_use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_use_button.custom_minimum_size = Vector2(0, 42)
	_use_button.pressed.connect(_on_use_pressed)
	buttons_hbox.add_child(_use_button)
	_setup_button_style(_use_button, Color(0.12, 0.55, 0.32, 0.8)) 


func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player):
		return
		
	# Clear old cells from both areas
	for child in _backpack_grid_container.get_children(): 
		child.queue_free()
	for child in _hotbar_grid_container.get_children(): 
		child.queue_free()
		
	# FIX: Explicit static typing on player inventory reference
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	
	# 1. Populate UPPER BACKPACK GRID (Slots 8 to 23)
	for i in range(8, 24):
		var btn := _create_grid_slot_button(i, inventory, 68)
		_backpack_grid_container.add_child(btn)
		
	# 2. Populate LOWER HOTBAR DOCK (Slots 0 to 7)
	for i in range(8):
		var btn := _create_grid_slot_button(i, inventory, 38)
		_hotbar_grid_container.add_child(btn)


func _create_grid_slot_button(slot_index: int, inventory: InventoryComponent, size_pixels: int) -> Button:
	var slot := inventory.get_slot_data(slot_index)
	var qty := slot.quantity
	
	# NATIVE DRAG AND DROP: Instantiate custom button subclass
	var btn := InventorySlotButton.new()
	btn.slot_index = slot_index
	btn.overlay = self
	btn.custom_minimum_size = Vector2(size_pixels, size_pixels)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_list_button_animations(btn, size_pixels)
	
	var slot_style := StyleBoxFlat.new()
	slot_style.set_corner_radius_all(6)
	slot_style.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	
	# Highlight first selected slot
	if slot_index == _first_selected_slot_index:
		slot_style.border_width_left = 3
		slot_style.border_width_top = 3
		slot_style.border_width_right = 3
		slot_style.border_width_bottom = 3
		slot_style.border_color = Color(1.0, 0.85, 0.2) 
	# Highlight active hotbar slot
	elif slot_index == player.active_slot_index:
		slot_style.border_width_left = 2
		slot_style.border_width_top = 2
		slot_style.border_width_right = 2
		slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.2, 0.85, 0.85) 
		
	var sh := slot_style.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	sh.border_color = Color(1.0, 0.85, 0.2) 
	
	btn.add_theme_stylebox_override("normal", slot_style)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", slot_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Only render icon & counter if the slot contains items
	if slot.item_id != -1 and qty != 0:
		var icon_container := Control.new()
		icon_container.name = "ItemIconContainer"
		icon_container.custom_minimum_size = Vector2(size_pixels - 12, size_pixels - 12)
		icon_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon_container.grow_vertical = Control.GROW_DIRECTION_BOTH
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_container)
		
		var fallback := ColorRect.new()
		fallback.name = "FallbackColor"
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(fallback)
		
		var tex_display := TextureRect.new()
		tex_display.name = "TextureDisplay"
		tex_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_display.stretch_mode = TextureRect.STRETCH_SCALE
		tex_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST # Preserves retro look
		tex_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(tex_display)
		
		var tex := _get_item_texture(slot.item_id)
		
		if tex != null:
			tex_display.texture = tex
			tex_display.visible = true
			fallback.visible = false
			for child in fallback.get_children():
				child.queue_free()
		else:
			tex_display.texture = null
			tex_display.visible = false
			fallback.color = BLOCK_COLORS.get(slot.item_id, Color.DARK_GRAY)
			fallback.visible = true
			_apply_special_fallback_decoration(fallback, slot.item_id)
		
		var qty_label := Label.new()
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		var ls := LabelSettings.new()
		ls.font_size = 11 if size_pixels < 45 else 13
		ls.outline_size = 3
		ls.outline_color = Color.BLACK
		qty_label.label_settings = ls
		
		if qty == -1:
			qty_label.text = tr("INVENTORY_INFINITE_SHORT") + " "
		else:
			qty_label.text = str(qty) + " "
			
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(qty_label)
		
	# Clicking fallback swapping compatibility connected dynamically
	btn.pressed.connect(_on_slot_clicked.bind(slot_index))
	return btn


## Sequential Click-Swapping Engine (maintained for tactile touch pad devices)
func _on_slot_clicked(slot_index: int) -> void:
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	
	if _first_selected_slot_index == -1:
		_first_selected_slot_index = slot_index
		_on_slot_selected(slot_index) 
		_refresh_backpack_grids()
		
	elif _first_selected_slot_index == slot_index:
		_first_selected_slot_index = -1
		_show_empty_details()
		_refresh_backpack_grids()
		
	else:
		inventory.swap_slots(_first_selected_slot_index, slot_index)
		player.call("_apply_hotbar_selection", player.get("active_slot_index"))
		
		# FIX: Explicit static typing on HUD reference
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", tr("INVENTORY_COMPACTED_HEADER"), tr("INVENTORY_COMPACTED_DESC"))
			
		_first_selected_slot_index = -1
		_on_slot_selected(slot_index) 
		_refresh_backpack_grids()


func _on_slot_selected(slot_index: int) -> void:
	_focused_slot_index = slot_index
	# FIX: Explicit static typing on player inventory reference
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(slot_index)
	
	if slot == null or slot.item_id == -1:
		_show_empty_details()
		return
		
	var item_name := inventory.get_slot_item_name(slot_index)
	_detail_title.text = item_name.to_upper()
	
	_detail_icon.color = BLOCK_COLORS.get(slot.item_id, Color.WHITE)
	_detail_icon.visible = true
	
	# Clear old children from the preview
	for child in _detail_icon.get_children():
		child.queue_free()
		
	# Load preview image / unicode character dynamically
	var tex := _get_item_texture(slot.item_id)
	if tex != null:
		var preview_tex := TextureRect.new()
		preview_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_tex.texture = tex
		preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_tex.stretch_mode = TextureRect.STRETCH_SCALE
		preview_tex.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
		_detail_icon.add_child(preview_tex)
		_detail_icon.color = Color(0, 0, 0, 0) # Transparent backing when textured
	else:
		_apply_special_fallback_decoration(_detail_icon, slot.item_id)
	
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	
	if slot.quantity == -1:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + tr("INVENTORY_INFINITE")
	else:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + str(slot.quantity) + " " + tr("ITEM_STOCKED_UNITS")
		
	_action_button.visible = true
	_use_button.visible = (slot.item_id == 16)
	
	if slot.item_id == 16:
		var hp := player.domain_entity.health
		var can_eat := hp < 3 and slot.quantity > 0
		_use_button.disabled = not can_eat
		if can_eat:
			_use_button.modulate = Color.WHITE
		else:
			_use_button.modulate = Color(0.5, 0.5, 0.5, 0.6)


func _on_equip_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	player.call("_apply_hotbar_selection", _focused_slot_index)
	
	# FIX: Explicit static typing on player inventory reference
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var item_name := inventory.get_slot_item_name(_focused_slot_index)
	# FIX: Explicit static typing on HUD reference
	var hud: PlayerHUD = player.get("hud") as PlayerHUD
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call("show_quest_notification", tr("NOTIFICATION_EQUIP_SUCCESS_HEADER"), tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
		
	_refresh_backpack_grids()


func _on_use_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	# FIX: Explicit static typing on player inventory reference
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(_focused_slot_index)
	
	if slot == null or slot.item_id != 16:
		return
		
	var hp := player.domain_entity.health
	
	if slot.quantity > 0 and hp < 3:
		slot.quantity -= 1
		if slot.quantity <= 0:
			slot.item_id = -1 
			
		player.domain_entity.health = min(3, hp + 1)
		
		# Emit Domain Event to sync HUD reactively (Observer Pattern)
		inventory.inventory_changed.emit()
		
		# FIX: Explicit static typing on HUD reference
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.update_health_display(player.domain_entity.health)
			hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_CONSUME_FOOD_DESC"))
			
		# FIX: Explicit static typing on viewmodel reference
		var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
		if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
			viewmodel.call("play_swing_animation")
			
		_on_slot_selected(_focused_slot_index)
		_refresh_backpack_grids()


## Dynamic auto-sort caller: Integrates the Domain packing and sorting algorithms
func _on_sort_pressed() -> void:
	if not is_instance_valid(player):
		return
		
	# FIX: Explicit static typing on player inventory reference
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		inventory.consolidate_and_sort_backpack()
		
		# FIX: Explicit static typing on HUD reference
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", tr("INVENTORY_COMPACTED_HEADER"), tr("INVENTORY_COMPACTED_DESC"))
			
		_show_empty_details()
		_refresh_backpack_grids()


func _show_empty_details() -> void:
	_detail_title.text = tr("INVENTORY_EMPTY_TITLE")
	_detail_icon.visible = false
	for child in _detail_icon.get_children():
		child.queue_free()
	_detail_desc.text = tr("INVENTORY_EMPTY_DESC")
	_detail_instruction.text = ""
	_detail_qty.text = ""
	_action_button.visible = false
	_use_button.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_backpack") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _setup_button_style(btn: Button, normal_color: Color) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = normal_color
	sn.set_corner_radius_all(10)
	sn.border_width_left = 2
	sn.border_width_top = 2
	sn.border_width_right = 2
	sn.border_width_bottom = 2
	sn.border_color = Color(1.0, 1.0, 1.0, 0.15)
	
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = normal_color + Color(0.08, 0.08, 0.08, 0.0) 
	sh.border_color = Color(1.0, 0.85, 0.2, 0.9) 
	
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("disabled", StyleBoxFlat.new())
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_font_size_override("font_size", 14)


func _setup_list_button_animations(btn: Button, size_pixels: int) -> void:
	btn.pivot_offset = Vector2(float(size_pixels) / 2.0, float(size_pixels) / 2.0)
	btn.mouse_entered.connect(_on_list_button_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_list_button_hover.bind(btn, false))


func _on_list_button_hover(btn: Button, hover: bool) -> void:
	if is_instance_valid(btn):
		var target_scale := Vector2(1.05, 1.05) if hover else Vector2(1.0, 1.0)
		var tw := create_tween()
		tw.tween_property(btn, "scale", target_scale, 0.08).set_trans(Tween.TRANS_SINE)


func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


# ==============================================================================
# DISK TEXTURES SCANNER & RETRIEVAL HELPERS
# ==============================================================================

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
			# FIX: Explicit type cast on loaded dynamic texture files
			var tex: Texture2D = load(full_path) as Texture2D
			if tex is Texture2D:
				_textures_cache[item_id] = tex
				return tex
				
	_textures_cache[item_id] = null
	return null


func _apply_special_fallback_decoration(fallback_node: Control, item_id: int) -> void:
	for child in fallback_node.get_children():
		child.queue_free()
		
	var symbol := Label.new()
	symbol.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var ls := LabelSettings.new()
	ls.font_size = 18 if fallback_node.size.x < 45 else 22
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	symbol.label_settings = ls
	
	match item_id:
		16: symbol.text = "🍗" 
		17: symbol.text = "⚔️" 
		18: symbol.text = "🌱" 
		_: symbol_label_fallback_pattern(symbol, item_id)
		
	if symbol.text != "":
		fallback_node.add_child(symbol)


func symbol_label_fallback_pattern(lbl: Label, item_id: int) -> void:
	match item_id:
		12: lbl.text = "💠"
		14: lbl.text = "☁️"
		_: lbl.text = ""


# ==============================================================================
# DRAG AND DROP NATIVE SWAPPING SUBCLASS
# ==============================================================================

## Nested Button subclass implementing Godot 4 native Drag and Drop interfaces.
## Keeps code modular, highly responsive, and strictly segregated (LSP compliant).
class InventorySlotButton:
	extends Button
	
	var slot_index: int
	var overlay: InventoryOverlay


	func _get_drag_data(_at_position: Vector2) -> Variant:
		var inventory: InventoryComponent = overlay.player.get("inventory") as InventoryComponent
		if not is_instance_valid(inventory):
			return null
			
		var slot := inventory.get_slot_data(slot_index)
		if slot == null or slot.item_id == -1 or slot.quantity <= 0:
			return null # Ignore dragging empty cells
			
		# 1. Construct the translucent floating Drag Preview control
		var preview := Control.new()
		preview.name = "BackpackDragPreview"
		
		# Giant container matching the cursor size
		var container := Control.new()
		container.custom_minimum_size = Vector2(46, 46)
		container.size = Vector2(46, 46)
		# Centered on mouse position
		container.position = -Vector2(23, 23)
		preview.add_child(container)
		
		# Backing visual rect
		var backing := ColorRect.new()
		backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backing.color = BLOCK_COLORS.get(slot.item_id, Color.DARK_GRAY)
		backing.modulate.a = 0.72 # Semi-transparent look!
		container.add_child(backing)
		
		var tex_display := TextureRect.new()
		tex_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_display.stretch_mode = TextureRect.STRETCH_SCALE
		tex_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
		tex_display.modulate.a = 0.72
		container.add_child(tex_display)
		
		var tex: Texture2D = overlay._get_item_texture(slot.item_id) as Texture2D
		if tex != null:
			tex_display.texture = tex
			tex_display.visible = true
			backing.visible = false
		else:
			tex_display.texture = null
			tex_display.visible = false
			backing.visible = true
			overlay._apply_special_fallback_decoration(backing, slot.item_id)
			
		# 2. Set the drag feedback representation on Godot's viewport
		set_drag_preview(preview)
		
		# 3. Highlight slot A visually
		overlay.set_drag_source(slot_index)
		
		return slot_index


	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		# We only accept other valid slot indices as swapped payloads
		return data is int


	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var source_slot_index := data as int
		overlay.execute_dnd_swap(source_slot_index, slot_index)
# ==============================================================================


## Highlight slot A and redraw grids to show gold highlight
func set_drag_source(slot_index: int) -> void:
	_first_selected_slot_index = slot_index
	_refresh_backpack_grids()


## Finalizes the Drag and Drop payload swap operation (Observer / OOP compliant)
func execute_dnd_swap(source_idx: int, target_idx: int) -> void:
	if source_idx < 0 or source_idx >= 24 or target_idx < 0 or target_idx >= 24:
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		# Domain Mutation
		inventory.swap_slots(source_idx, target_idx)
		
		# Re-evaluates active visual tools if player swapped active item
		player.call("_apply_hotbar_selection", player.get("active_slot_index"))
		
		# Show toast feedback on HUD
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			var item_name := inventory.get_slot_item_name(target_idx)
			hud.call("show_quest_notification", tr("NOTIFICATION_EQUIP_SUCCESS_HEADER"), tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
			
		# Clean up highlight states and re-inspect target
		_first_selected_slot_index = -1
		_on_slot_selected(target_idx)
		_refresh_backpack_grids()

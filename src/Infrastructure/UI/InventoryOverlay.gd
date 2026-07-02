# ==============================================================================
# Project: CraftDomain
# Description: Ultra-high-fidelity Minecraft-style Inventory Overlay.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by isolating layout drawing and slot sorting.
#              STRICT MODE & MEMORY FIX: 
#              - Fixed variable mismatch resolving null get_children() crashes.
#              - Replaced all unstable C++ inline lambdas with robust native 
#                `Callable.bind()` references to prevent lambda memory leaks.
#              BUG FIX (DEAD CODE): Removed legacy calls to `_sync_hud_counters`.
#              Now emits `inventory_changed` properly to rely on reactive Domain Events.
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

# STRICT MODE FIX: Sequential Swapping Engine State declared properly at class level
var _first_selected_slot_index: int = -1
var _focused_slot_index: int = -1

# Interactive Item Descriptions (Educating the player on item utility!)
const ITEM_DETAILS = {
	1: {
		"desc": "A heavy, solid building block carved from deep crusts. Excellent for constructing durable shelters, towers, and structural fortresses.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) on any solid surface to place the block."
	},
	2: {
		"desc": "Rich, loose brown soil. The primary organic block of the flat plains. Ideal for molding landscapes or building simple soil ramparts.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) on any surface to place the block."
	},
	3: {
		"desc": "Vibrant grass turf. Over time, grass blocks spread organically onto adjacent dirt blocks under sunlight, turning cold dirt into lush plains.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) on any surface to place the block."
	},
	4: {
		"desc": "Solid oak wood logs chopped from tall forest canopies. A highly versatile structural material and the backbone of most recipe blueprints.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) on any surface to place the block."
	},
	5: {
		"desc": "Soft, packed leafy foliage. Ideal for building lightweight, organic structures like thatched roofs, rustic hedges, or compost piles.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) on any surface to place the block."
	},
	15: {
		"desc": "A bucket of highly volatile, glowing geothermal magma. Extremely dangerous if touched. Used primarily as reactor fuel for high-tier crafts.",
		"use": "EQUIP TO HAND: Swap to hotbar. Use Right-Click (or Q) to place flowing lava, or Right-Click on the Village Merchant to trade for food."
	},
	16: {
		"desc": "Delicious chicken crisped to golden perfection over hot geothermal lava. Highly therapeutic, smelling amazing and warm.",
		"use": "CONSUME FOOD: Click the USE/EAT button below, or equip it to hotbar and Right-Click to consume 1x chicken and heal 1 Heart (❤)."
	},
	17: {
		"desc": "A basic training broadsword carved from solid oak logs. It has infinite durability. Perfect for protecting the village plains against monsters.",
		"use": "EQUIP WEAPON: Equip it and use Left-Click (or E) to swing and attack cave zombies."
	},
	18: {
		"desc": "Plump wheat seeds gathered from forestry foliage. Can be planted on any fertile tilled soil or soft grass block to start your own crops.",
		"use": "PLANT SEEDS: Swap to hotbar. Aim at any Grass or Dirt block and Right-Click (or Q) to plant. Crops grow dynamically over time!"
	},
	20: {
		"desc": "Golden, sun-ripened wheat grains harvested from your mature crop fields. Essential raw material for elite survival baking recipes.",
		"use": "CRAFTING MATERIAL: Use this wheat in the Blueprint Workshop to craft valuable rations."
	}
}

# Theme palette colors
const BLOCK_COLORS = {
	-1: Color(0, 0, 0, 0),       # Empty
	1: Color(0.55, 0.55, 0.55), # Stone
	2: Color(0.55, 0.38, 0.25), # Dirt
	3: Color(0.42, 0.78, 0.25), # Grass
	4: Color(0.72, 0.55, 0.35), # Wood
	5: Color(0.25, 0.65, 0.18), # Leaves
	15: Color(1.0, 0.45, 0.0),  # Lava
	16: Color(0.92, 0.62, 0.62),# Chicken
	17: Color(0.75, 0.75, 0.80),# Sword
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
	main_card.offset_left = -400
	main_card.offset_right = 400
	main_card.offset_top = -240
	main_card.offset_bottom = 240
	
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
	
	var catalog_title := Label.new()
	catalog_title.text = "BACKPACK STORAGE"
	var ts := LabelSettings.new()
	ts.font_size = 18
	ts.font_color = Color(0.2, 0.85, 0.85) # Teal Blue Accent
	ts.outline_size = 4
	ts.outline_color = Color.BLACK
	catalog_title.label_settings = ts
	left_vbox.add_child(catalog_title)
	
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
	
	# ==================== HOTBAR DOCK GRID (FIXED) ====================
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
	_detail_title.text = "Inspect Item"
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
	_detail_desc.text = "Click any backpack item to inspect its usage and capabilities."
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
	_action_button.text = "EQUIP IN HAND"
	_action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_button.custom_minimum_size = Vector2(0, 42)
	_action_button.pressed.connect(_on_equip_pressed)
	buttons_hbox.add_child(_action_button)
	_setup_button_style(_action_button, Color(0.12, 0.55, 0.82, 0.8)) 
	
	_use_button = Button.new()
	_use_button.text = "CONSUME FOOD"
	_use_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_use_button.custom_minimum_size = Vector2(0, 42)
	_use_button.pressed.connect(_on_use_pressed)
	buttons_hbox.add_child(_use_button)
	_setup_button_style(_use_button, Color(0.12, 0.55, 0.32, 0.8)) 

func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player):
		return
		
	# Clear old cells from both areas
	for child in _backpack_grid_container.get_children(): child.queue_free()
	for child in _hotbar_grid_container.get_children(): child.queue_free()
		
	var inventory = player.get("inventory") as InventoryComponent
	
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
	
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(size_pixels, size_pixels)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	_setup_list_button_animations(btn, size_pixels)
	
	var slot_style := StyleBoxFlat.new()
	slot_style.set_corner_radius_all(6)
	slot_style.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	
	# HIGHLIGHT A: If this slot is the first selected slot in the Swapping Engine, glow it in Gold!
	if slot_index == _first_selected_slot_index:
		slot_style.border_width_left = 3
		slot_style.border_width_top = 3
		slot_style.border_width_right = 3
		slot_style.border_width_bottom = 3
		slot_style.border_color = Color(1.0, 0.85, 0.2) 
	# HIGHLIGHT B: If this slot is equipped in the player's hand, glow it in Teal!
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
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(size_pixels - 12, size_pixels - 18)
		icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icon.grow_horizontal = Control.GROW_DIRECTION_BOTH
		icon.grow_vertical = Control.GROW_DIRECTION_BOTH
		icon.color = BLOCK_COLORS.get(slot.item_id, Color.WHITE)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		
		var qty_label := Label.new()
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		
		var ls := LabelSettings.new()
		ls.font_size = 11 if size_pixels < 45 else 13
		ls.outline_size = 3
		ls.outline_color = Color.BLACK
		qty_label.label_settings = ls
		
		if qty == -1:
			qty_label.text = "INF " 
		else:
			qty_label.text = str(qty) + " "
			
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(qty_label)
		
	# MEMORY SECURITY FIX: Connect utilizing safe C++ native Callable.bind()
	btn.pressed.connect(_on_slot_clicked.bind(slot_index))
	return btn

## FASE 1 WORKSPACE: Sequential Swapping Engine (Sorting logic)
func _on_slot_clicked(slot_index: int) -> void:
	var inventory = player.get("inventory") as InventoryComponent
	
	# Case 1: No previous slot selected - Select slot A
	if _first_selected_slot_index == -1:
		_first_selected_slot_index = slot_index
		_on_slot_selected(slot_index) # Open inspector details
		_refresh_backpack_grids()
		
	# Case 2: Clicked the same slot twice - Deselect
	elif _first_selected_slot_index == slot_index:
		_first_selected_slot_index = -1
		_show_empty_details()
		_refresh_backpack_grids()
		
	# Case 3: Clicked slot B - Execute swap transaction!
	else:
		inventory.swap_slots(_first_selected_slot_index, slot_index)
		
		# Re-evaluates active visual tools if player swapped active item
		player.call("_apply_hotbar_selection", player.get("active_slot_index"))
		
		# Log info toast on HUD
		var hud = player.get("hud")
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "Inventory Sorted", "Swapped slot %d with slot %d!" % [_first_selected_slot_index, slot_index])
			
		# Reset swap engine
		_first_selected_slot_index = -1
		_on_slot_selected(slot_index) # Inspect the newly placed item
		_refresh_backpack_grids()

func _on_slot_selected(slot_index: int) -> void:
	_focused_slot_index = slot_index
	var inventory = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(slot_index)
	
	if slot == null or slot.item_id == -1:
		_show_empty_details()
		return
		
	var item_name := inventory.get_slot_item_name(slot_index)
	_detail_title.text = item_name.to_upper()
	_detail_icon.color = BLOCK_COLORS.get(slot.item_id, Color.WHITE)
	_detail_icon.visible = true
	
	# Dynamically read localized item lore and usage guide from TranslationServer (OCP)
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	
	if slot.quantity == -1:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + tr("INVENTORY_INFINITE")
	else:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + str(slot.quantity) + " units"
		
	# Setup actions
	_action_button.visible = true
	_use_button.visible = (slot.item_id == 16) # Only Fried Chicken is consumable
	
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
	
	var inventory = player.get("inventory") as InventoryComponent
	var item_name := inventory.get_slot_item_name(_focused_slot_index)
	var hud = player.get("hud")
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call("show_quest_notification", "Item Equipped", "Active tool swapped to: " + item_name.to_upper())
		
	_refresh_backpack_grids()

func _on_use_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	var inventory = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(_focused_slot_index)
	
	if slot == null or slot.item_id != 16:
		return
		
	var hp := player.domain_entity.health
	
	if slot.quantity > 0 and hp < 3:
		slot.quantity -= 1
		if slot.quantity <= 0:
			slot.item_id = -1 # Clear if fully eaten
			
		player.domain_entity.health = min(3, hp + 1)
		
		# Emit Domain Event to sync HUD reactively (SRP / Observer Pattern)
		inventory.inventory_changed.emit()
		
		var hud = player.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.update_health_display(player.domain_entity.health)
			hud.show_quest_notification("YUMMY!", "Consumed 1x Fried Chicken! Healed 1 Heart.")
			
		var viewmodel = player.get("viewmodel")
		if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
			viewmodel.call("play_swing_animation")
			
		_on_slot_selected(_focused_slot_index)
		_refresh_backpack_grids()

func _show_empty_details() -> void:
	_detail_title.text = tr("INVENTORY_EMPTY_TITLE")
	_detail_icon.visible = false
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

# STRICT MODE FIX: Renamed argument to "size_pixels" to resolve shadowing property warnings from base Control class
func _setup_list_button_animations(btn: Button, size_pixels: int) -> void:
	btn.pivot_offset = Vector2(float(size_pixels) / 2.0, float(size_pixels) / 2.0)
	
	# MEMORY SECURITY FIX: Connect utilizing safe C++ native Callable.bind() to eliminate lambda leaks
	btn.mouse_entered.connect(_on_list_button_hover.bind(btn, true))
	btn.mouse_exited.connect(_on_list_button_hover.bind(btn, false))

## Private helper supporting memory-safe hover scaling tweens on list buttons
func _on_list_button_hover(btn: Button, hover: bool) -> void:
	if is_instance_valid(btn):
		var target_scale := Vector2(1.05, 1.05) if hover else Vector2(1.0, 1.0)
		var tw := create_tween()
		tw.tween_property(btn, "scale", target_scale, 0.08).set_trans(Tween.TRANS_SINE)

func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s

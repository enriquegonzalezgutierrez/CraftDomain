# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure UI controller representing an interactive, 
#              glassmorphic 24-slot inventory and backpack inspector.
#              Supports native drag-and-drop operations and sorting.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Coordinates only the layout grids, 
#   details panel selections, and high-level button clicks. Drag-and-drop data 
#   and slot-rendering tasks are delegated to `InventorySlotWidget.gd`.
# - Open-Closed Principle (OCP): Completely deleted the duplicate color dictionary. 
#   Fallback slots and the inspector icon query colors dynamically from `BlockLibrary`.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/UI/InventoryOverlay.gd
# ==============================================================================
class_name InventoryOverlay
extends Panel

## Emitted when the player exits the backpack screen
signal closed

## Strictly-typed reference to the active Player Controller
var player: PlayerController

# UI Node References
var _backpack_grid_container: GridContainer
var _hotbar_grid_container: GridContainer
var _detail_title: Label
var _detail_desc: Label
var _detail_qty: Label
var _detail_instruction: Label
var _detail_icon: ColorRect
var _action_button: Button
var _use_button: Button

# Internal selection state tracking
var _first_selected_slot_index: int = -1
var _focused_slot_index: int = -1


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
	# 1. Main Card Container (Centered, glassmorphic panel)
	var main_card := Panel.new()
	main_card.name = "BackpackCard"
	main_card.custom_minimum_size = Vector2(840, 520)
	main_card.size = Vector2(840, 520)
	main_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	main_card.offset_left = -420
	main_card.offset_right = 420
	main_card.offset_top = -260
	main_card.offset_bottom = 260
	
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(12)
	card_style.bg_color = Color(0.06, 0.06, 0.08, 0.96) 
	card_style.border_width_left = 2; card_style.border_width_top = 2
	card_style.border_width_right = 2; card_style.border_width_bottom = 2
	card_style.border_color = Color(0.35, 0.35, 0.4, 0.4)
	card_style.shadow_size = 20
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	main_card.add_theme_stylebox_override("panel", card_style)
	add_child(main_card)
	
	# Horizontal Splitter Container (Dual-pane layout)
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
	
	# Header HBox (Backpack title & Auto-sort action button)
	var header_hbox := HBoxContainer.new()
	header_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(header_hbox)
	
	var catalog_title := Label.new()
	catalog_title.text = tr("INVENTORY_BACKPACK_STORAGE").to_upper() # Localized
	catalog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ts := LabelSettings.new()
	ts.font_size = 18
	ts.font_color = Color(0.2, 0.85, 0.85) 
	ts.outline_size = 4
	ts.outline_color = Color.BLACK
	catalog_title.label_settings = ts
	header_hbox.add_child(catalog_title)
	
	var sort_btn := Button.new()
	sort_btn.text = " ⚡ " + tr("INVENTORY_SORT").to_upper() + " "
	sort_btn.custom_minimum_size = Vector2(100, 32)
	sort_btn.pressed.connect(_on_sort_pressed)
	_setup_button_style(sort_btn, Color(0.12, 0.55, 0.32, 0.7)) 
	header_hbox.add_child(sort_btn)
	
	left_vbox.add_child(_create_spacer(14))
	
	# Scrollable grid container for the 16 backpack storage cells (slots 8 to 23)
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
	hotbar_title.text = tr("INVENTORY_HOTBAR_DOCK").to_upper() # Localized
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
	_hotbar_grid_container.columns = 8 
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
	
	# Dynamic Title Label
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
	
	# Large 3D-Like Preview Box panel
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
	
	# Localized Description Text
	_detail_desc = Label.new()
	_detail_desc.text = tr("INVENTORY_EMPTY_DESC")
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
	
	# Stock Quantity Label
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


## Clears, compiles, and redraws both the hotbar dock and upper storage grids.
func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player):
		return
		
	for child: Node in _backpack_grid_container.get_children(): 
		child.queue_free()
	for child: Node in _hotbar_grid_container.get_children(): 
		child.queue_free()
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	
	# 1. Populate UPPER STORAGE GRID (Slots 8 to 23) using the decoupled widget
	for i: int in range(8, 24):
		var btn := _create_grid_slot_button(i, inventory, 68)
		_backpack_grid_container.add_child(btn)
		
	# 2. Populate LOWER QUICKBAR DOCK (Slots 0 to 7) using the decoupled widget
	for i: int in range(8):
		var btn := _create_grid_slot_button(i, inventory, 38)
		_hotbar_grid_container.add_child(btn)


## Programmatically constructs a grid button supporting native Drag and Drop.
func _create_grid_slot_button(slot_index: int, inventory: InventoryComponent, size_pixels: int) -> Button:
	var slot := inventory.get_slot_data(slot_index)
	var qty: int = slot.quantity
	
	var btn := InventorySlotWidget.new()
	btn.slot_index = slot_index
	btn.overlay = self
	btn.custom_minimum_size = Vector2(size_pixels, size_pixels)
	
	# Build layout StyleBoxes
	var slot_style := StyleBoxFlat.new()
	slot_style.set_corner_radius_all(6)
	slot_style.bg_color = Color(0.12, 0.12, 0.15, 0.6)
	
	if slot_index == _first_selected_slot_index:
		slot_style.border_width_left = 3; slot_style.border_width_top = 3
		slot_style.border_width_right = 3; slot_style.border_width_bottom = 3
		slot_style.border_color = Color(1.0, 0.85, 0.2) 
	elif slot_index == player.active_slot_index:
		slot_style.border_width_left = 2; slot_style.border_width_top = 2
		slot_style.border_width_right = 2; slot_style.border_width_bottom = 2
		slot_style.border_color = Color(0.2, 0.85, 0.85) 
		
	var sh := slot_style.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.18, 0.22, 0.8)
	sh.border_color = Color(1.0, 0.85, 0.2) 
	
	btn.add_theme_stylebox_override("normal", slot_style)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", slot_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Render icon and counter labels
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
		tex_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
		tex_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(tex_display)
		
		# Delegate rendering extraction statically to the decoupled widget
		var tex := btn._get_item_texture(slot.item_id)
		
		if tex != null:
			tex_display.texture = tex
			tex_display.visible = true
			fallback.visible = false
		else:
			tex_display.texture = null
			tex_display.visible = false
			
			var def: BlockDefinition = BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
			# Symmetrical fallback: if not a block, renders a clean dark background (OCP!)
			fallback.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
			
			fallback.visible = true
			btn._apply_special_fallback_decoration(fallback, slot.item_id)
		
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
		
	btn.pressed.connect(_on_slot_clicked.bind(slot_index))
	return btn


## Clicking Swapping fallback interface (useful for tactile layouts)
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
		
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", tr("INVENTORY_COMPACTED_HEADER"), tr("INVENTORY_COMPACTED_DESC"))
			
		_first_selected_slot_index = -1
		_on_slot_selected(slot_index) 
		_refresh_backpack_grids()


## Redraws the details information panel based on the selected slot index.
func _on_slot_selected(slot_index: int) -> void:
	_focused_slot_index = slot_index
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(slot_index)
	
	if slot == null or slot.item_id == -1:
		_show_empty_details()
		return
		
	var item_name := inventory.get_slot_item_name(slot_index)
	_detail_title.text = item_name.to_upper()
	
	# Leverage the domain block library to obtain colors dynamically, completely removing local dictionaries
	var def: BlockDefinition = BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
	_detail_icon.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
	_detail_icon.visible = true
	
	for child: Node in _detail_icon.get_children():
		child.queue_free()
		
	# Leverage the decoupled helper statically to render preview icons
	var helper := InventorySlotWidget.new()
	var tex := helper._get_item_texture(slot.item_id)
	
	if tex != null:
		var preview_tex := TextureRect.new()
		preview_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview_tex.texture = tex
		preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_tex.stretch_mode = TextureRect.STRETCH_SCALE
		preview_tex.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
		_detail_icon.add_child(preview_tex)
		_detail_icon.color = Color(0, 0, 0, 0) # Transparent background
	else:
		helper._apply_special_fallback_decoration(_detail_icon, slot.item_id)
		
	helper.queue_free() # Clean up auxiliary helper instantly
	
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	
	if slot.quantity == -1:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + tr("INVENTORY_INFINITE")
	else:
		_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + str(slot.quantity) + " " + tr("ITEM_STOCKED_UNITS")
		
	_action_button.visible = true
	_use_button.visible = (slot.item_id == 16)
	
	if slot.item_id == 16:
		var hp: int = player.domain_entity.health
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
	
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var item_name := inventory.get_slot_item_name(_focused_slot_index)
	var hud: PlayerHUD = player.get("hud") as PlayerHUD
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		hud.call("show_quest_notification", tr("NOTIFICATION_EQUIP_SUCCESS_HEADER"), tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
		
	_refresh_backpack_grids()


func _on_use_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	var slot := inventory.get_slot_data(_focused_slot_index)
	
	if slot == null or slot.item_id != 16:
		return
		
	var hp: int = player.domain_entity.health
	
	if slot.quantity > 0 and hp < 3:
		slot.quantity -= 1
		if slot.quantity <= 0:
			slot.item_id = -1 
			
		player.domain_entity.health = min(3, hp + 1)
		
		# Emit Domain Event to sync observers
		inventory.inventory_changed.emit()
		
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud):
			hud.update_health_display(player.domain_entity.health)
			hud.show_quest_notification(tr("NOTIFICATION_CONSUME_FOOD_HEADER"), tr("NOTIFICATION_CONSUME_FOOD_DESC"))
			
		var viewmodel: PlayerViewModel = player.get("viewmodel") as PlayerViewModel
		if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
			viewmodel.call("play_swing_animation")
			
		_on_slot_selected(_focused_slot_index)
		_refresh_backpack_grids()


## Sorting pipeline coordinator: Calls Domain sorting algorithms
func _on_sort_pressed() -> void:
	if not is_instance_valid(player):
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		inventory.consolidate_and_sort_backpack()
		
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", tr("INVENTORY_COMPACTED_HEADER"), tr("INVENTORY_COMPACTED_DESC"))
			
		_show_empty_details()
		_refresh_backpack_grids()


func _show_empty_details() -> void:
	_detail_title.text = tr("INVENTORY_EMPTY_TITLE")
	_detail_icon.visible = false
	for child: Node in _detail_icon.get_children():
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


func _create_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


# ==============================================================================
# VIEW COORDINATION ROUTERS FOR DECOUPLED SLOT WIDGETS
# ==============================================================================

## Highlights slot A and updates display grids.
func set_drag_source(slot_index: int) -> void:
	_first_selected_slot_index = slot_index
	_refresh_backpack_grids()


## Finalizes the Drag-and-Drop swapping payload.
func execute_dnd_swap(source_idx: int, target_idx: int) -> void:
	if source_idx < 0 or source_idx >= 24 or target_idx < 0 or target_idx >= 24:
		return
		
	var inventory: InventoryComponent = player.get("inventory") as InventoryComponent
	if is_instance_valid(inventory):
		inventory.swap_slots(source_idx, target_idx)
		player.call("_apply_hotbar_selection", player.get("active_slot_index"))
		
		var hud: PlayerHUD = player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			var item_name := inventory.get_slot_item_name(target_idx)
			hud.call("show_quest_notification", tr("NOTIFICATION_EQUIP_SUCCESS_HEADER"), tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
			
		_first_selected_slot_index = -1
		_on_slot_selected(target_idx)
		_refresh_backpack_grids()

# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/InventoryOverlay.gd
# Description: Glassmorphic 24-slot inventory and backpack inspector.
#              Corrected: Replaced unstable dynamic anchor solvers with 
#              deterministic manual margin offsets to guarantee centered icons.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventoryOverlay
extends Panel

signal closed

# Declarative StyleBox theme resources preloaded to fulfill Rule 7.1
const STYLE_SLOT_NORMAL := preload("res://assets/themes/style_slot_normal.tres")
const STYLE_SLOT_SELECTED := preload("res://assets/themes/style_slot_selected.tres")
const STYLE_SLOT_ACTIVE := preload("res://assets/themes/style_slot_active.tres")
const STYLE_SLOT_HOVER := preload("res://assets/themes/style_slot_hover.tres")

@export var player: PlayerController

@onready var _backpack_grid_container: GridContainer = $BackpackCard/HBoxContainer/LeftPane/LeftVBox/ScrollContainer/BackpackGridContainer
@onready var _hotbar_grid_container: GridContainer = $BackpackCard/HBoxContainer/LeftPane/LeftVBox/HotbarGridContainer
@onready var _detail_title: Label = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/DetailTitle
@onready var _detail_desc: Label = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/DetailDesc
@onready var _detail_qty: Label = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/DetailQty
@onready var _detail_instruction: Label = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/DetailInstruction
@onready var _detail_icon: ColorRect = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/PreviewPanel/DetailIcon
@onready var _action_button: Button = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/ButtonsHBox/ActionButton
@onready var _use_button: Button = $BackpackCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/ButtonsHBox/UseButton
@onready var _sort_btn: Button = $BackpackCard/HBoxContainer/LeftPane/LeftVBox/HeaderHBox/SortButton

var _first_selected_slot_index: int = -1
var _focused_slot_index: int = -1


func _ready() -> void:
	_sort_btn.pressed.connect(_on_sort_pressed)
	_action_button.pressed.connect(_on_equip_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	
	# Localize Sort button dynamically to guarantee language Pack compatibility
	_sort_btn.text = " ⚡ " + tr("INVENTORY_SORT").to_upper()
	
	_refresh_backpack_grids()
	_show_empty_details()


func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player): return
		
	for child: Node in _backpack_grid_container.get_children(): child.queue_free()
	for child: Node in _hotbar_grid_container.get_children(): child.queue_free()
		
	var inventory := player.inventory as InventoryComponent
	for i: int in range(8, 24):
		_backpack_grid_container.add_child(_create_grid_slot_button(i, inventory, 68))
	for i: int in range(8):
		_hotbar_grid_container.add_child(_create_grid_slot_button(i, inventory, 38))


func _create_grid_slot_button(slot_index: int, inventory: InventoryComponent, size_pixels: int) -> Button:
	var btn := InventorySlotWidget.new()
	btn.slot_index = slot_index
	btn.overlay = self
	btn.custom_minimum_size = Vector2(size_pixels, size_pixels)
	
	_apply_slot_styles(btn, slot_index)
	
	var slot := inventory.get_slot_data(slot_index)
	if slot.item_id != -1 and slot.quantity != 0:
		_build_slot_contents(btn, slot, size_pixels)
		
	btn.pressed.connect(_on_slot_clicked.bind(slot_index))
	return btn


func _apply_slot_styles(btn: Button, slot_index: int) -> void:
	var style := STYLE_SLOT_NORMAL
	if slot_index == _first_selected_slot_index:
		style = STYLE_SLOT_SELECTED
	elif slot_index == player.active_slot_index:
		style = STYLE_SLOT_ACTIVE
		
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", STYLE_SLOT_HOVER)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _build_slot_contents(btn: Button, slot: InventoryComponent.SlotData, size_pixels: int) -> void:
	var icon_container := _create_icon_container(size_pixels)
	btn.add_child(icon_container)
	
	_setup_item_icon(icon_container, slot)
	_setup_quantity_label(btn, slot.quantity, size_pixels)


func _create_icon_container(size_pixels: int) -> Control:
	var container := Control.new()
	container.name = "ItemIconContainer"
	
	# ALIGNMENT FIXED: Use TOP_LEFT anchor and enforce precise manual margins 
	# to bypass any SceneTree timing or layout-solver scaling bugs.
	container.anchors_preset = Control.PRESET_TOP_LEFT
	
	var margin := 6 if size_pixels > 45 else 4
	container.position = Vector2(margin, margin)
	container.size = Vector2(size_pixels - margin * 2, size_pixels - margin * 2)
	
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


func _setup_item_icon(container: Control, slot: InventoryComponent.SlotData) -> void:
	var fallback := ColorRect.new()
	fallback.name = "FallbackColor"
	fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(fallback)
	
	var tex_display := TextureRect.new()
	tex_display.name = "TextureDisplay"
	tex_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_display.stretch_mode = TextureRect.STRETCH_SCALE
	tex_display.texture_filter = TextureRect.TEXTURE_FILTER_NEAREST
	tex_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(tex_display)
	
	var helper := InventorySlotWidget.new()
	var tex := helper._get_item_texture(slot.item_id)
	
	if tex != null:
		tex_display.texture = tex
		tex_display.visible = true
		fallback.visible = false
	else:
		var def := BlockLibrary.get_definition(slot.item_id as BlockType.Type)
		fallback.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
		fallback.visible = true
		helper._apply_special_fallback_decoration(fallback, slot.item_id)
	helper.queue_free()


func _setup_quantity_label(btn: Button, quantity: int, size_pixels: int) -> void:
	var qty_label := Label.new()
	qty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var ls := LabelSettings.new()
	ls.font_size = 11 if size_pixels < 45 else 13
	ls.outline_size = 3
	ls.outline_color = Color.BLACK
	qty_label.label_settings = ls
	
	qty_label.text = tr("INVENTORY_INFINITE_SHORT") if quantity == -1 else str(quantity)
	btn.add_child(qty_label)


func _on_slot_clicked(slot_index: int) -> void:
	var inventory := player.inventory as InventoryComponent
	
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
		_first_selected_slot_index = -1
		_on_slot_selected(slot_index) 
		_refresh_backpack_grids()


func _on_slot_selected(slot_index: int) -> void:
	_focused_slot_index = slot_index
	var inventory := player.inventory as InventoryComponent
	var slot := inventory.get_slot_data(slot_index)
	
	if slot == null or slot.item_id == -1:
		_show_empty_details()
		return
		
	_populate_slot_details(inventory, slot, slot_index)
	_update_slot_action_buttons(slot)


func _populate_slot_details(inventory: InventoryComponent, slot: InventoryComponent.SlotData, slot_index: int) -> void:
	var item_name := inventory.get_slot_item_name(slot_index)
	_detail_title.text = item_name.to_upper()
	
	var def := BlockLibrary.get_definition(slot.item_id as BlockType.Type)
	_detail_icon.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
	_detail_icon.visible = true
	
	for child in _detail_icon.get_children(): child.queue_free()
	_apply_details_icon_preview(slot)
	
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + (tr("INVENTORY_INFINITE") if slot.quantity == -1 else str(slot.quantity) + " " + tr("ITEM_STOCKED_UNITS"))


func _apply_details_icon_preview(slot: InventoryComponent.SlotData) -> void:
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
		_detail_icon.color = Color(0, 0, 0, 0)
	else:
		helper._apply_special_fallback_decoration(_detail_icon, slot.item_id)
	helper.queue_free()


func _update_slot_action_buttons(slot: InventoryComponent.SlotData) -> void:
	_action_button.visible = true
	var strategy: ItemUsageStrategy = ItemStrategyRegistry.get_strategy(slot.item_id) as ItemUsageStrategy
	var is_consumable := (strategy != null and strategy is ConsumableItemStrategy)
	_use_button.visible = is_consumable
	
	if is_consumable:
		var hp: int = player.domain_entity.health
		var can_eat := hp < 3 and slot.quantity > 0
		_use_button.disabled = not can_eat
		_use_button.modulate = Color.WHITE if can_eat else Color(0.5, 0.5, 0.5, 0.6)


func _on_equip_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player): return
		
	player.call("_apply_hotbar_selection", _focused_slot_index)
	var inventory := player.inventory as InventoryComponent
	var item_name := inventory.get_slot_item_name(_focused_slot_index)
	var hud := player.hud as PlayerHUD
	if is_instance_valid(hud):
		hud.show_quest_notification("NOTIFICATION_EQUIP_SUCCESS_HEADER", tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
	_refresh_backpack_grids()


func _on_use_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player): return
		
	var inventory_comp := player.inventory as InventoryComponent
	var slot := inventory_comp.get_slot_data(_focused_slot_index)
	if slot == null: return
		
	var strategy := ItemStrategyRegistry.get_strategy(slot.item_id) as ItemUsageStrategy
	if strategy == null or not (strategy is ConsumableItemStrategy): return
		
	var world_modifier: IWorldModifier = null
	var world_ctrl := player.world_controller as WorldController
	if is_instance_valid(world_ctrl): world_modifier = world_ctrl.world_modifier
		
	if strategy.can_use(player.domain_entity, inventory_comp, Vector3i.ZERO, Vector3.ZERO, null):
		strategy.use(player.domain_entity, inventory_comp, Vector3i.ZERO, Vector3.ZERO, world_modifier)
		
		var viewmodel := player.viewmodel as PlayerViewModel
		if is_instance_valid(viewmodel): viewmodel.play_swing_animation()
			
		_on_slot_selected(_focused_slot_index)
		_refresh_backpack_grids()


func _on_sort_pressed() -> void:
	if not is_instance_valid(player): return
	var inventory := player.inventory as InventoryComponent
	if is_instance_valid(inventory):
		inventory.consolidate_and_sort_backpack()
		_show_empty_details()
		_refresh_backpack_grids()


func _show_empty_details() -> void:
	_detail_title.text = tr("INVENTORY_EMPTY_TITLE")
	_detail_icon.visible = false
	for child: Node in _detail_icon.get_children(): child.queue_free()
	_detail_desc.text = tr("INVENTORY_EMPTY_DESC")
	_detail_instruction.text = ""
	_detail_qty.text = ""
	_action_button.visible = false
	_use_button.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_backpack") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func set_drag_source(slot_index: int) -> void:
	_first_selected_slot_index = slot_index
	_refresh_backpack_grids()


func execute_dnd_swap(source_idx: int, target_idx: int) -> void:
	if source_idx < 0 or source_idx >= 24 or target_idx < 0 or target_idx >= 24: return
		
	var inventory := player.inventory as InventoryComponent
	if is_instance_valid(inventory):
		inventory.swap_slots(source_idx, target_idx)
		player.call("_apply_hotbar_selection", player.get("active_slot_index"))
		
		var hud := player.hud as PlayerHUD
		if is_instance_valid(hud):
			var item_name := inventory.get_slot_item_name(target_idx)
			hud.show_quest_notification("NOTIFICATION_EQUIP_SUCCESS_HEADER", tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
			
		_first_selected_slot_index = -1
		_on_slot_selected(target_idx)
		_refresh_backpack_grids()

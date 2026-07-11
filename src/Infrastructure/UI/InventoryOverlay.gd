# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/InventoryOverlay.gd
# Description: Glassmorphic 24-slot inventory and backpack inspector.
#              Renders grid slots and handles item actions and DND events.
#              Layout and structural offsets are strictly defined in .tscn.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventoryOverlay
extends Panel

signal closed

@export var player: PlayerController

# Static UI Node References (Bound from .tscn)
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

# Internal selection state tracking
var _first_selected_slot_index: int = -1
var _focused_slot_index: int = -1


func _ready() -> void:
	_sort_btn.pressed.connect(_on_sort_pressed)
	_action_button.pressed.connect(_on_equip_pressed)
	_use_button.pressed.connect(_on_use_pressed)
	
	_refresh_backpack_grids()
	_show_empty_details()


## Clears, compiles, and redraws both the hotbar dock and upper storage grids
func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player):
		return
		
	for child: Node in _backpack_grid_container.get_children(): 
		child.queue_free()
	for child: Node in _hotbar_grid_container.get_children(): 
		child.queue_free()
		
	var inventory := player.inventory as InventoryComponent
	
	# 1. Populate UPPER STORAGE GRID (Slots 8 to 23)
	for i: int in range(8, 24):
		_backpack_grid_container.add_child(_create_grid_slot_button(i, inventory, 68))
		
	# 2. Populate LOWER QUICKBAR DOCK (Slots 0 to 7)
	for i: int in range(8):
		_hotbar_grid_container.add_child(_create_grid_slot_button(i, inventory, 38))


func _create_grid_slot_button(slot_index: int, inventory: InventoryComponent, size_pixels: int) -> Button:
	var btn := InventorySlotWidget.new()
	btn.slot_index = slot_index
	btn.overlay = self
	btn.custom_minimum_size = Vector2(size_pixels, size_pixels)
	
	var slot := inventory.get_slot_data(slot_index)
	var qty := slot.quantity
	
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
		
		var tex := btn._get_item_texture(slot.item_id)
		
		if tex != null:
			tex_display.texture = tex
			tex_display.visible = true
			fallback.visible = false
		else:
			tex_display.texture = null
			tex_display.visible = false
			
			var def: BlockDefinition = BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
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
		
		qty_label.text = tr("INVENTORY_INFINITE_SHORT") if qty == -1 else str(qty)
		qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(qty_label)
		
	btn.pressed.connect(_on_slot_clicked.bind(slot_index))
	return btn


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
		
	var item_name := inventory.get_slot_item_name(slot_index)
	_detail_title.text = item_name.to_upper()
	
	var def: BlockDefinition = BlockLibrary.get_definition(slot.item_id as BlockType.Type) as BlockDefinition
	_detail_icon.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.12, 0.12, 0.15)
	_detail_icon.visible = true
	
	for child: Node in _detail_icon.get_children():
		child.queue_free()
		
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
	
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + (tr("INVENTORY_INFINITE") if slot.quantity == -1 else str(slot.quantity) + " " + tr("ITEM_STOCKED_UNITS"))
	
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
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	player.call("_apply_hotbar_selection", _focused_slot_index)
	var inventory := player.inventory as InventoryComponent
	var item_name := inventory.get_slot_item_name(_focused_slot_index)
	var hud := player.hud as PlayerHUD
	if is_instance_valid(hud):
		hud.show_quest_notification("NOTIFICATION_EQUIP_SUCCESS_HEADER", tr("NOTIFICATION_EQUIP_SUCCESS_DESC") + ": " + item_name.to_upper())
	_refresh_backpack_grids()


func _on_use_pressed() -> void:
	if _focused_slot_index == -1 or not is_instance_valid(player):
		return
		
	var inventory_comp := player.inventory as InventoryComponent
	var slot := inventory_comp.get_slot_data(_focused_slot_index)
	if slot == null:
		return
		
	var strategy := ItemStrategyRegistry.get_strategy(slot.item_id) as ItemUsageStrategy
	if strategy == null or not (strategy is ConsumableItemStrategy):
		return
		
	var world_modifier: IWorldModifier = null
	var world_ctrl := player.world_controller as WorldController
	if is_instance_valid(world_ctrl):
		world_modifier = world_ctrl.world_modifier
		
	if strategy.can_use(player.domain_entity, inventory_comp, Vector3i.ZERO, Vector3.ZERO, null):
		strategy.use(player.domain_entity, inventory_comp, Vector3i.ZERO, Vector3.ZERO, world_modifier)
		
		var viewmodel := player.viewmodel as PlayerViewModel
		if is_instance_valid(viewmodel):
			viewmodel.play_swing_animation()
			
		_on_slot_selected(_focused_slot_index)
		_refresh_backpack_grids()


func _on_sort_pressed() -> void:
	if not is_instance_valid(player):
		return
	var inventory := player.inventory as InventoryComponent
	if is_instance_valid(inventory):
		inventory.consolidate_and_sort_backpack()
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


func set_drag_source(slot_index: int) -> void:
	_first_selected_slot_index = slot_index
	_refresh_backpack_grids()


func execute_dnd_swap(source_idx: int, target_idx: int) -> void:
	if source_idx < 0 or source_idx >= 24 or target_idx < 0 or target_idx >= 24:
		return
		
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

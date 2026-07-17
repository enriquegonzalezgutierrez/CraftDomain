# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/InventoryOverlay.gd
# Description: Glassmorphic 24-slot inventory and backpack inspector.
#              SOLID COMPLIANCE:
#              - Rule 7.1: Purged all procedural UI generation (ColorRect.new, 
#                TextureRect.new, Label.new). Delegates directly to InventorySlotWidget.
#              - Single Responsibility Principle (SRP): Focuses strictly on layout 
#                coordination, logic routing, and drag-and-drop orchestration.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventoryOverlay
extends Panel

signal closed

const SLOT_WIDGET_SCENE := preload("res://src/Infrastructure/UI/Widgets/inventory_slot_widget.tscn")

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
	
	_sort_btn.text = " ⚡ " + tr("INVENTORY_SORT").to_upper()
	
	_refresh_backpack_grids()
	_show_empty_details()


func _refresh_backpack_grids() -> void:
	if not is_instance_valid(player): 
		return
		
	_clear_container(_backpack_grid_container)
	_clear_container(_hotbar_grid_container)
		
	for i: int in range(8, 24):
		_backpack_grid_container.add_child(_create_grid_slot_widget(i, 68))
	for i: int in range(8):
		_hotbar_grid_container.add_child(_create_grid_slot_widget(i, 38))


func _clear_container(container: Control) -> void:
	for child: Node in container.get_children():
		child.queue_free()


func _create_grid_slot_widget(slot_index: int, size_pixels: int) -> InventorySlotWidget:
	var widget := SLOT_WIDGET_SCENE.instantiate() as InventorySlotWidget
	widget.custom_minimum_size = Vector2(size_pixels, size_pixels)
	
	var is_selected := (slot_index == _first_selected_slot_index)
	var is_active := (slot_index == player.active_slot_index)
	
	# Duck-typing call to decouple specific logic requirements
	if widget.has_method("initialize_slot"):
		widget.call("initialize_slot", slot_index, self, is_selected, is_active)
		
	widget.pressed.connect(func() -> void: _on_slot_clicked(slot_index))
	return widget


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
	
	_detail_icon.visible = true
	_detail_icon.color = Color(0, 0, 0, 0)
	_clear_container(_detail_icon)
	
	# Reuse the slot widget as a pure visual display for the detail panel (DRY/OCP)
	var preview_widget := SLOT_WIDGET_SCENE.instantiate() as InventorySlotWidget
	preview_widget.custom_minimum_size = _detail_icon.size
	preview_widget.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_icon.add_child(preview_widget)
	
	if preview_widget.has_method("initialize_display_only"):
		preview_widget.call("initialize_display_only", slot.item_id, slot.quantity)
	
	_detail_desc.text = tr("ITEM_" + str(slot.item_id) + "_DESC")
	_detail_instruction.text = tr("ITEM_USAGE_PREFIX") + ": " + tr("ITEM_" + str(slot.item_id) + "_USE")
	
	var qty_str := tr("INVENTORY_INFINITE") if slot.quantity == -1 else str(slot.quantity) + " " + tr("ITEM_STOCKED_UNITS")
	_detail_qty.text = tr("ITEM_STOCKED_PREFIX") + ": " + qty_str


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
	_clear_container(_detail_icon)
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

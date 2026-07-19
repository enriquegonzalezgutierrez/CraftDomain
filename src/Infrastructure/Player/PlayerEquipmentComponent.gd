# ==============================================================================
# Pathfile: res://src/Infrastructure/Player/PlayerEquipmentComponent.gd
# Description: Infrastructure Component responsible for managing the player's 
#              hotbar selection, active tool types, and viewmodel synchronization.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages equipment states 
#   and tool bindings, decoupling inventory logic from the physics controller.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlayerEquipmentComponent
extends Node

var player: CharacterBody3D

var active_slot_index: int = 0
var active_build_type: BlockType.Type = BlockType.Type.AIR
var is_item_selected: bool = false


func initialize(p_player: CharacterBody3D) -> void:
	player = p_player
	name = "PlayerEquipmentComponent"


func process_hotbar_inputs(input_comp: PlayerInputComponent) -> void:
	if not is_instance_valid(input_comp): 
		return
		
	var selection := input_comp.get_active_hotkey_selection()
	if selection != -1: 
		apply_hotbar_selection(selection)


func scroll_hotbar(direction: int) -> void:
	var new_slot := active_slot_index + direction
	if new_slot > 7: new_slot = 0
	elif new_slot < 0: new_slot = 7
	
	apply_hotbar_selection(new_slot)


func apply_hotbar_selection(slot: int) -> void:
	active_slot_index = slot
	
	var hud := player.get("hud") as PlayerHUD if is_instance_valid(player) else null
	if is_instance_valid(hud) and hud.has_method("update_active_slot"): 
		hud.update_active_slot(slot)
	
	var inv_comp := player.get("inventory") as InventoryComponent if is_instance_valid(player) else null
	if not is_instance_valid(inv_comp): 
		return
	
	var slot_data := inv_comp.get_slot_data(slot)
	if slot_data == null or slot_data.item_id == -1 or slot_data.quantity == 0:
		_clear_held_tool()
		return
		
	_equip_item_by_id(slot_data.item_id)


func _equip_item_by_id(item_id: int) -> void:
	var visual_comp := player.get("visual_component") as PlayerVisualComponent
	if is_instance_valid(visual_comp) and visual_comp.has_method("update_held_tool"): 
		visual_comp.update_held_tool(item_id)
		
	var tool_type: PlayerViewModel.ToolType = PlayerViewModel.get_tool_type_for_item(item_id)
	_set_viewmodel_tool(tool_type)
	
	var block_def := BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
	is_item_selected = (block_def != null and block_def.type != 0)
	active_build_type = (item_id as BlockType.Type) if is_item_selected else BlockType.Type.AIR


func _clear_held_tool() -> void:
	is_item_selected = false
	active_build_type = BlockType.Type.AIR
	_set_viewmodel_tool(PlayerViewModel.ToolType.NONE)
	
	var visual_comp := player.get("visual_component") as PlayerVisualComponent
	if is_instance_valid(visual_comp) and visual_comp.has_method("update_held_tool"): 
		visual_comp.update_held_tool(-1)


func _set_viewmodel_tool(tool_id: PlayerViewModel.ToolType) -> void:
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel) and viewmodel.has_method("switch_to_tool"): 
		viewmodel.switch_to_tool(tool_id)

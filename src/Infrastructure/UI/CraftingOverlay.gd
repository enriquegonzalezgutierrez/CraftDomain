# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/CraftingOverlay.gd
# Description: Glassmorphic dual-pane Blueprint Workshop overlay.
#              SOLID COMPLIANCE: 
#              - Rule 7.1 (Declarative UI): Procedural StyleBox and Node instantiations 
#                purged. Delegates visual construction to decoupled .tscn widgets.
#              - Single Responsibility Principle (SRP): Acts exclusively as a 
#                state mediator between the Domain CraftingService and UI widgets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CraftingOverlay
extends Panel

signal closed

const RECIPE_BTN_SCENE := preload("res://src/Infrastructure/UI/Widgets/recipe_button_widget.tscn")
const REQ_ROW_SCENE := preload("res://src/Infrastructure/UI/Widgets/requirement_row_widget.tscn")

@export var player: CharacterBody3D

@onready var _recipes_list: VBoxContainer = $WorkshopCard/HBoxContainer/LeftPane/LeftVBox/ScrollContainer/RecipesList
@onready var _detail_title: Label = $WorkshopCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/DetailTitle
@onready var _detail_icon: ColorRect = $WorkshopCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/PreviewPanel/DetailIcon
@onready var _detail_requirements_box: VBoxContainer = $WorkshopCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/RequirementsBox
@onready var _craft_button: Button = $WorkshopCard/HBoxContainer/DetailPanel/RightMargin/RightVBox/CraftButton

var _selected_recipe: Recipe = null


func _ready() -> void:
	_populate_recipes_list()
	_show_empty_details()
	_craft_button.pressed.connect(_on_craft_pressed)


func _populate_recipes_list() -> void:
	var all_recipes := RecipeRegistry.get_all_recipes()
	for recipe: Recipe in all_recipes:
		var btn := RECIPE_BTN_SCENE.instantiate()
		
		# Duck-typing check to ensure safe initialization
		if btn.has_method("initialize_recipe"):
			btn.call("initialize_recipe", recipe)
			
		if btn.has_signal("recipe_clicked"):
			btn.connect("recipe_clicked", _on_recipe_selected)
			
		_recipes_list.add_child(btn)


func _show_empty_details() -> void:
	_detail_title.text = tr("CRAFTING_SELECT_BLUEPRINT")
	_detail_icon.visible = false
	_detail_requirements_box.visible = false
	_craft_button.visible = false


func _on_recipe_selected(recipe: Recipe) -> void:
	_selected_recipe = recipe
	_detail_title.text = tr(recipe.recipe_name).to_upper() + " (x" + str(recipe.output_quantity) + ")"
	
	var def := BlockLibrary.get_definition(recipe.output_item_index as BlockType.Type) as BlockDefinition
	_detail_icon.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.15, 0.15, 0.18)
	
	_detail_icon.visible = true
	_detail_requirements_box.visible = true
	_craft_button.visible = true
	
	_refresh_checklist()


func _refresh_checklist() -> void:
	if _selected_recipe == null or not is_instance_valid(player): 
		return
		
	_clear_requirements_box()
	
	var inventory := player.get("inventory") as IInventory
	var can_craft_current := CraftingService.can_craft(inventory, _selected_recipe)
	
	_populate_requirements(inventory)
	_update_craft_button_state(can_craft_current)


func _clear_requirements_box() -> void:
	for child: Node in _detail_requirements_box.get_children():
		child.queue_free()


func _populate_requirements(inventory: IInventory) -> void:
	for item_id: int in _selected_recipe.inputs.keys():
		var required_qty := _selected_recipe.inputs[item_id] as int
		var current_qty := inventory.get_item_total_quantity(item_id) as int
		var item_name := InventoryComponent.get_item_name_by_id(item_id)
		
		var row := REQ_ROW_SCENE.instantiate()
		if row.has_method("initialize_requirement"):
			row.call("initialize_requirement", item_name, current_qty, required_qty)
			
		_detail_requirements_box.add_child(row)


func _update_craft_button_state(can_craft: bool) -> void:
	_craft_button.disabled = not can_craft
	_craft_button.modulate = Color.WHITE if can_craft else Color(0.5, 0.5, 0.5, 0.7)


func _on_craft_pressed() -> void:
	if _selected_recipe == null or not is_instance_valid(player): 
		return
		
	var inventory := player.get("inventory") as IInventory
	if CraftingService.craft(inventory, _selected_recipe):
		_trigger_success_feedback()
		_refresh_checklist()


func _trigger_success_feedback() -> void:
	var viewmodel := player.get("viewmodel") as PlayerViewModel
	if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
		viewmodel.call("play_swing_animation")
		
	AudioService.play_sfx_static("craft_clink")
		
	var hud := player.get("hud") as PlayerHUD
	if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
		var loc_header := tr("NOTIFICATION_CRAFTING_SUCCESS_HEADER")
		var loc_desc := tr("NOTIFICATION_CRAFTING_SUCCESS_DESC") + ": " + tr(_selected_recipe.recipe_name)
		hud.call("show_quest_notification", loc_header, loc_desc)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("craft_item") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

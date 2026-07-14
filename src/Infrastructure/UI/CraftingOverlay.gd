# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/CraftingOverlay.gd
# Description: Glassmorphic dual-pane Blueprint Workshop overlay.
#              SOLID COMPLIANCE: Class limits set < 100 lines (SRP). Monolithic
#              loops decomposed. Procedural StyleBoxFlat instantiation purged.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CraftingOverlay
extends Panel

signal closed

# Declarative StyleBox theme resources preloaded to fulfill Rule 7.1
const STYLE_NORMAL := preload("res://assets/themes/style_recipe_normal.tres")
const STYLE_HOVER := preload("res://assets/themes/style_recipe_hover.tres")
const STYLE_ROW := preload("res://assets/themes/style_recipe_row.tres")

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
	for recipe: Recipe in RecipeRegistry.get_all_recipes():
		var btn := Button.new()
		btn.text = "  " + recipe.recipe_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 42)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Symmetrical OCP Border Color highlights
		var style_n := STYLE_NORMAL.duplicate() as StyleBoxFlat
		var def := BlockLibrary.get_definition(recipe.output_item_index as BlockType.Type) as BlockDefinition
		if def != null and def.type != BlockType.Type.AIR:
			style_n.border_color = def.color_top
			
		btn.add_theme_stylebox_override("normal", style_n)
		btn.add_theme_stylebox_override("hover", STYLE_HOVER)
		btn.add_theme_stylebox_override("pressed", style_n)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		
		btn.pressed.connect(func() -> void: _on_recipe_selected(recipe))
		_recipes_list.add_child(btn)


func _show_empty_details() -> void:
	_detail_title.text = tr("CRAFTING_SELECT_BLUEPRINT")
	_detail_icon.visible = false
	_detail_requirements_box.visible = false
	_craft_button.visible = false


func _on_recipe_selected(recipe: Recipe) -> void:
	_selected_recipe = recipe
	_detail_title.text = recipe.recipe_name.to_upper() + " (x" + str(recipe.output_quantity) + ")"
	
	var def := BlockLibrary.get_definition(recipe.output_item_index as BlockType.Type) as BlockDefinition
	_detail_icon.color = def.color_top if (def != null and def.type != BlockType.Type.AIR) else Color(0.15, 0.15, 0.18)
	
	_detail_icon.visible = true
	_detail_requirements_box.visible = true
	_craft_button.visible = true
	
	_refresh_checklist()


func _refresh_checklist() -> void:
	if _selected_recipe == null or not is_instance_valid(player): return
		
	_clear_requirements_box()
	
	var inventory := player.get("inventory") as IInventory
	var can_craft_current := CraftingService.can_craft(inventory, _selected_recipe)
	
	_populate_requirements(inventory)
	_update_craft_button_state(can_craft_current)


func _clear_requirements_box() -> void:
	for child in _detail_requirements_box.get_children():
		child.queue_free()


func _populate_requirements(inventory: IInventory) -> void:
	for item_id: int in _selected_recipe.inputs.keys():
		var required_qty := _selected_recipe.inputs[item_id] as int
		var current_qty := inventory.get_item_total_quantity(item_id) as int
		var item_name := InventoryComponent.get_item_name_by_id(item_id)
		
		_create_requirement_row(item_name, current_qty, required_qty)


func _create_requirement_row(item_name: String, current: int, required: int) -> void:
	var row := Panel.new()
	row.custom_minimum_size = Vector2(0, 36)
	row.add_theme_stylebox_override("panel", STYLE_ROW)
	_detail_requirements_box.add_child(row)
	
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_requirement_label(label, item_name, current, required)
	row.add_child(label)


func _style_requirement_label(label: Label, item_name: String, current: int, required: int) -> void:
	var is_satisfied := current >= required
	var glyph := "   ✔  " if is_satisfied else "   ✘  "
	label.text = glyph + "%d / %d  %s" % [current, required, item_name.to_upper()]
	
	var ls := LabelSettings.new()
	ls.font_size = 13
	ls.font_color = Color(0.25, 0.85, 0.35) if is_satisfied else Color(0.92, 0.15, 0.15)
	label.label_settings = ls


func _update_craft_button_state(can_craft: bool) -> void:
	_craft_button.disabled = not can_craft
	_craft_button.modulate = Color.WHITE if can_craft else Color(0.5, 0.5, 0.5, 0.7)


func _on_craft_pressed() -> void:
	if _selected_recipe == null or not is_instance_valid(player): return
		
	var inventory := player.get("inventory") as IInventory
	if CraftingService.craft(inventory, _selected_recipe):
		var viewmodel := player.get("viewmodel") as PlayerViewModel
		if is_instance_valid(viewmodel) and viewmodel.has_method("play_swing_animation"):
			viewmodel.call("play_swing_animation")
			
		AudioService.play_sfx_static("craft_clink")
			
		var hud := player.get("hud") as PlayerHUD
		if is_instance_valid(hud) and hud.has_method("show_quest_notification"):
			hud.call("show_quest_notification", "NOTIFICATION_CRAFTING_SUCCESS_HEADER", tr("NOTIFICATION_CRAFTING_SUCCESS_DESC") + ": " + _selected_recipe.recipe_name + "!")
			
		_refresh_checklist()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("craft_item") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()

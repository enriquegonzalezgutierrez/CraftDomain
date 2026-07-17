# ==============================================================================
# Pathfile: res://src/Infrastructure/UI/Widgets/RecipeButtonWidget.gd
# Description: Infrastructure UI Widget representing a selectable recipe button.
#              SOLID COMPLIANCE:
#              - Single Responsibility Principle (SRP): Handles only its own state
#                and emits a cleanly typed selection signal.
#              - Rule 7.1: Extracts style overriding from the parent coordinator.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name RecipeButtonWidget
extends Button

signal recipe_clicked(recipe: Recipe)

var _assigned_recipe: Recipe = null


func _ready() -> void:
	pressed.connect(_on_pressed)


## Initializes the widget with a domain Recipe and updates localized visuals
func initialize_recipe(recipe: Recipe) -> void:
	_assigned_recipe = recipe
	text = "  " + tr(recipe.recipe_name)
	_apply_dynamic_border_color()


func _apply_dynamic_border_color() -> void:
	if _assigned_recipe == null:
		return

	var def := BlockLibrary.get_definition(_assigned_recipe.output_item_index as BlockType.Type) as BlockDefinition
	if def != null and def.type != BlockType.Type.AIR:
		_override_normal_border_color(def.color_top)


func _override_normal_border_color(color: Color) -> void:
	var base_style := get_theme_stylebox("normal")
	if base_style is StyleBoxFlat:
		var unique_style := base_style.duplicate() as StyleBoxFlat
		unique_style.border_color = color
		add_theme_stylebox_override("normal", unique_style)
		add_theme_stylebox_override("pressed", unique_style)


func _on_pressed() -> void:
	if _assigned_recipe != null:
		recipe_clicked.emit(_assigned_recipe)
		AudioService.play_sfx_static("ui_click")

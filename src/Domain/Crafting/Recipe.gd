# ==============================================================================
# Pathfile: res://src/Domain/Crafting/Recipe.gd
# Description: Pure Domain Resource defining a crafting recipe.
#              Encapsulates input ingredient requirements and output parameters.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name Recipe
extends Resource

## Unique identifier for the recipe (e.g., "craft_sword", "craft_planks")
@export var recipe_id: String = ""

## Human-readable localization key or name for the UI (e.g., "ITEM_WOODEN_SWORD")
@export var recipe_name: String = ""

## Maps required item ID (int) to the required quantity (int).
## Example: { 4: 2 } means "Requires 2 units of Wood Log (ID 4)"
@export var inputs: Dictionary = {}

## The item ID produced by crafting this recipe (e.g., 17 for Wooden Sword).
@export var output_item_index: int = -1

## The amount of items produced by a single crafting transaction.
@export var output_quantity: int = 1
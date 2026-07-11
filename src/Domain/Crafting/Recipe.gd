# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Crafting System / Value Objects)
# Class: Recipe
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# Description: Pure Domain Resource defining a crafting recipe.
#              Contains the required input ingredients and the resulting output.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Pure data structure completely 
#   decoupled from JSON parsing, inventory logic, or UI.
# ==============================================================================
class_name Recipe
extends Resource

## Unique identifier for the recipe (e.g., "craft_sword", "craft_planks")
@export var recipe_id: String = ""

## Human-readable name for the UI (e.g., "Wooden Sword")
@export var recipe_name: String = ""

## Maps required inventory slot index (int) to the required quantity (int).
## Example: { 3: 2 } means "Requires 2 units of Wood Log (Slot 3)"
@export var inputs: Dictionary = {}

## The inventory slot index where the crafted item will be placed.
## Example: 7 (Wooden Sword) or 0 (Stone Block)
@export var output_item_index: int = -1

## The amount of items produced by a single crafting execution.
@export var output_quantity: int = 1

# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service orchestrating recipe execution.
#              Checks ingredient requirements and modifies inventory stocks.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only manages crafting logic.
#              - Dependency Inversion Principle (DIP): Depends strictly on the
#                abstract interface `IInventory`, allowing recipe evaluations.
#              WARNING FIX:
#              - Added explicit static typing `int` to the inputs keys loop iterators 
#                (including `item_id`) to completely resolve `UNTYPED_DECLARATION` 
#                compiler warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Crafting/CraftingService.gd
# ==============================================================================
class_name CraftingService
extends RefCounted

## Validates if the given inventory contains enough ingredients to craft the recipe.
## Returns true if all criteria are satisfied, false otherwise.
static func can_craft(inventory: IInventory, recipe: Recipe) -> bool:
	if inventory == null or recipe == null:
		return false
		
	# 1. Validate if the inventory contains the total aggregate sum of each ingredient
	# FIX: Added explicit static typing `int` to the inputs key loop iterator
	for item_id: int in recipe.inputs.keys():
		var required_qty := recipe.inputs[item_id] as int
		
		# DIP INVERSION: We query the generic total quantity of this ID, regardless of slot placement
		if inventory.get_item_total_quantity(item_id) < required_qty:
			return false
			
	# 2. Validate if the inventory has enough open slot capacity to receive the manufactured output
	if not inventory.can_receive_item(recipe.output_item_index, recipe.output_quantity):
		return false
		
	return true

## Executes the crafting transaction, consuming the inputs and granting the output.
## Returns true if the operation completed successfully, false otherwise.
static func craft(inventory: IInventory, recipe: Recipe) -> bool:
	if not can_craft(inventory, recipe):
		return false
		
	# 1. Consume input ingredients across the entire backpack grid
	# FIX: Added explicit static typing `int` to the inputs key loop iterator
	for item_id: int in recipe.inputs.keys():
		var required_qty := recipe.inputs[item_id] as int
		inventory.consume_item(item_id, required_qty)
		
	# 2. Grant manufactured output item (appends to existing stack or fills an empty slot)
	inventory.add_item(recipe.output_item_index, recipe.output_quantity)
	
	# ==========================================================================
	# INCREMENT ACTIVE QUEST PROGRESSION ON CRAFTING
	# ==========================================================================
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.required_item_index == recipe.output_item_index:
		active_q.progress_counter = min(active_q.required_quantity, active_q.progress_counter + recipe.output_quantity)
	
	print("[CraftingService] Crafted successfully: ", recipe.recipe_name)
	return true

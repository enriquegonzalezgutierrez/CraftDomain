# ==============================================================================
# Pathfile: res://src/Domain/Crafting/CraftingService.gd
# Description: Pure Domain Service orchestrating recipe validation and execution.
#              Consumes ingredients and awards output items on inventory grids.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CraftingService
extends RefCounted


## Validates if the given inventory contains enough ingredients to craft the recipe.
static func can_craft(inventory: IInventory, recipe: Recipe) -> bool:
	if inventory == null or recipe == null:
		return false
		
	for item_id: int in recipe.inputs.keys():
		var required_qty := recipe.inputs[item_id] as int
		if inventory.get_item_total_quantity(item_id) < required_qty:
			return false
			
	return inventory.can_receive_item(recipe.output_item_index, recipe.output_quantity)


## Executes the crafting transaction, consuming inputs and granting the output.
static func craft(inventory: IInventory, recipe: Recipe) -> bool:
	if not can_craft(inventory, recipe):
		return false
		
	_consume_recipe_inputs(inventory, recipe)
	inventory.add_item(recipe.output_item_index, recipe.output_quantity)
	_update_quest_progress_on_craft(recipe)
	
	print("[CraftingService] Crafted successfully: ", recipe.recipe_name)
	return true


static func _consume_recipe_inputs(inventory: IInventory, recipe: Recipe) -> void:
	for item_id: int in recipe.inputs.keys():
		var required_qty := recipe.inputs[item_id] as int
		inventory.consume_item(item_id, required_qty)


static func _update_quest_progress_on_craft(recipe: Recipe) -> void:
	var active_q := QuestService.get_active_quest()
	if active_q != null and active_q.required_item_index == recipe.output_item_index:
		var new_progress := active_q.progress_counter + recipe.output_quantity
		active_q.progress_counter = min(active_q.required_quantity, new_progress)
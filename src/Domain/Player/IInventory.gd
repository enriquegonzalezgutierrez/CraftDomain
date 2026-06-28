# ==============================================================================
# Project: CraftDomain
# Description: Segregated Interface defining the contract for advanced stackable
#              inventory operations, supporting dynamic ID-based item queries.
#              SOLID COMPLIANCE: Adheres strictly to the Interface Segregation 
#              Principle (ISP) and Dependency Inversion Principle (DIP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/IInventory.gd
# ==============================================================================
class_name IInventory
extends RefCounted

## Returns the total accumulated quantity of a specific Item ID across all stacks.
func get_item_total_quantity(_item_id: int) -> int:
	assert(false, "[IInventory] get_item_total_quantity() must be implemented.")
	return 0

## Adds a specific quantity of an Item ID, auto-filling existing stacks or empty slots.
## Returns true if the items were successfully stored, false if the inventory is full.
func add_item(_item_id: int, _quantity: int) -> bool:
	assert(false, "[IInventory] add_item() must be implemented.")
	return false

## Consumes a specific quantity of an Item ID, deducting from stacks across the grid.
func consume_item(_item_id: int, _quantity: int) -> void:
	assert(false, "[IInventory] consume_item() must be implemented.")

## Checks if the inventory has enough space to receive a specific quantity of an Item ID.
func can_receive_item(_item_id: int, _quantity: int) -> bool:
	assert(false, "[IInventory] can_receive_item() must be implemented.")
	return false

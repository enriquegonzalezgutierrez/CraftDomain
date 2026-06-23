# ==============================================================================
# Project: CraftDomain
# Description: Segregated Interface defining the contract for inventory operations,
#              fully separating items/currency transaction logic from physics bodies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/IInventory.gd
# ==============================================================================
class_name IInventory
extends RefCounted

## Abstract contract: Returns the current quantity of a specific slot index.
func get_slot_quantity(_slot_index: int) -> int:
	assert(false, "[IInventory] get_slot_quantity() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Modifies the quantity of a specific slot index.
func modify_slot_quantity(_slot_index: int, _delta: int) -> void:
	assert(false, "[IInventory] modify_slot_quantity() must be implemented by concrete subclass.")

## Abstract contract: Checks if a slot index can be modified by a certain delta.
func can_modify_slot_quantity(_slot_index: int, _delta: int) -> bool:
	assert(false, "[IInventory] can_modify_slot_quantity() must be implemented by concrete subclass.")
	return false

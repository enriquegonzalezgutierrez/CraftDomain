# ==============================================================================
# Pathfile: res://src/Domain/Player/InventorySortingService.gd
# Description: Pure Domain Service responsible for consolidating and sorting
#              inventory backpack slots (8 to 23) in ascending order.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Handles exclusively list sorting algorithms,
#   isolating sorting logic from the concrete InventoryComponent state.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventorySortingService
extends RefCounted


## Consolidates fragmented item stacks and sorts the backpack storage area
## (slots 8 to 23) in ascending order, leaving the active Hotbar (slots 0 to 7) untouched.
static func consolidate_and_sort_backpack(slots: Array, max_stack_limit: int) -> void:
	var consolidated := _gather_and_consolidate(slots)
	_clear_backpack_slots(slots)
	_repopulate_sorted_slots(slots, consolidated, max_stack_limit)


static func _gather_and_consolidate(slots: Array) -> Dictionary:
	var consolidated: Dictionary = {} # item_id (int) -> total_qty (int)
	
	for i in range(8, 24):
		var slot: Variant = slots[i]
		if slot != null and slot.item_id != -1 and slot.quantity > 0:
			if not consolidated.has(slot.item_id):
				consolidated[slot.item_id] = 0
			consolidated[slot.item_id] += slot.quantity
			
	return consolidated


static func _clear_backpack_slots(slots: Array) -> void:
	for i in range(8, 24):
		slots[i] = InventoryComponent.SlotData.new(-1, 0)


static func _repopulate_sorted_slots(slots: Array, consolidated: Dictionary, max_stack_limit: int) -> void:
	var sorted_item_ids := consolidated.keys()
	sorted_item_ids.sort()
	
	var current_slot_index := 8
	for item_id: int in sorted_item_ids:
		var total_qty: int = consolidated[item_id]
		current_slot_index = _distribute_item_stacks(slots, item_id, total_qty, current_slot_index, max_stack_limit)


static func _distribute_item_stacks(slots: Array, item_id: int, total_qty: int, start_index: int, max_stack_limit: int) -> int:
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else max_stack_limit
	var idx := start_index
	
	while total_qty > 0 and idx < 24:
		var pack_qty := min(total_qty, max_stack)
		slots[idx] = InventoryComponent.SlotData.new(item_id, pack_qty, max_stack)
		total_qty -= pack_qty
		idx += 1
		
	return idx

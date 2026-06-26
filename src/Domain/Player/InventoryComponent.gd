# ==============================================================================
# Project: CraftDomain
# Description: Concrete domain component managing dynamic inventory slots, items,
#              building blocks, and quantity modifications.
#              UPDATED: Added a Smart Voxel Routing algorithm to map untracked 
#              mined blocks (Sand, Mud, Snow, Ice, Neon) into active slots
#              so players never lose resources while terraforming.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/InventoryComponent.gd
# ==============================================================================
class_name InventoryComponent
extends IInventory

## Structure representing an individual Inventory Slot
class SlotData:
	var name: String
	var quantity: int
	var build_type: BlockType.Type
	var is_block: bool
	
	func _init(p_name: String, p_quantity: int, p_build_type: BlockType.Type, p_is_block: bool) -> void:
		name = p_name
		quantity = p_quantity
		build_type = p_build_type
		is_block = p_is_block

# List of all active slot data: Array[SlotData]
var _slots: Array[SlotData] = []

func _init() -> void:
	# Register our 8 quick-slots dynamically on initialization
	_slots.append(SlotData.new("Stone", 64, BlockType.Type.STONE, true))         # Slot 0
	_slots.append(SlotData.new("Dirt", 64, BlockType.Type.DIRT, true))           # Slot 1
	_slots.append(SlotData.new("Grass", 64, BlockType.Type.GRASS, true))         # Slot 2
	_slots.append(SlotData.new("Wood", 16, BlockType.Type.WOOD, true))           # Slot 3
	_slots.append(SlotData.new("Leaves", 16, BlockType.Type.LEAVES, true))       # Slot 4
	_slots.append(SlotData.new("Lava Bucket", 3, BlockType.Type.LAVA, true))     # Slot 5 (Currency & Placement)
	_slots.append(SlotData.new("Fried Chicken", 0, BlockType.Type.AIR, false))   # Slot 6 (Food)
	_slots.append(SlotData.new("Wooden Sword", -1, BlockType.Type.AIR, false))   # Slot 7 (Weapon)

## Concrete Implementation: Returns the current quantity of a specific slot index.
func get_slot_quantity(slot_index: int) -> int:
	if slot_index >= 0 and slot_index < _slots.size():
		return _slots[slot_index].quantity
	return 0

## Concrete Implementation: Modifies the quantity of a specific slot index.
func modify_slot_quantity(slot_index: int, delta: int) -> void:
	if slot_index >= 0 and slot_index < _slots.size():
		var slot := _slots[slot_index]
		if slot.quantity != -1: # Skip modification if item is infinite
			slot.quantity = max(0, slot.quantity + delta)

## Concrete Implementation: Checks if a slot index can be modified by a certain delta.
func can_modify_slot_quantity(slot_index: int, delta: int) -> bool:
	if slot_index >= 0 and slot_index < _slots.size():
		var slot := _slots[slot_index]
		if slot.quantity == -1: # Infinite items can always pass
			return true
		return (slot.quantity + delta) >= 0
	return false

## Helper: Checks if the slot contains a buildable solid block
func is_block_slot(slot_index: int) -> bool:
	if slot_index >= 0 and slot_index < _slots.size():
		return _slots[slot_index].is_block
	return false

## Helper: Returns the block type of the selected slot
func get_slot_build_type(slot_index: int) -> BlockType.Type:
	if slot_index >= 0 and slot_index < _slots.size():
		return _slots[slot_index].build_type
	return BlockType.Type.AIR

## Helper: Returns the full name of the slot item
func get_slot_item_name(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < _slots.size():
		return _slots[slot_index].name
	return ""

## Helper: Adds 1 block to its corresponding slot based on its BlockType (Mining collection)
## UPDATED: Routes exotic block types to closest inventory equivalents to ensure solid UX.
func add_block_by_type(block_type: BlockType.Type) -> void:
	var target_type := block_type
	
	# Smart Routing: Map biome-specific blocks to closest inventory match
	match block_type:
		BlockType.Type.SAND, BlockType.Type.RED_SAND, BlockType.Type.MUD:
			target_type = BlockType.Type.DIRT # Sand and mud route to Dirt
		BlockType.Type.SNOW, BlockType.Type.ICE, BlockType.Type.NEON_CYAN, BlockType.Type.NEON_MAGENTA:
			target_type = BlockType.Type.STONE # Ice, snow, and neon route to Stone
		BlockType.Type.CLOUD:
			target_type = BlockType.Type.LEAVES # Clouds route to Leaves
			
	for slot in _slots:
		if slot.is_block and slot.build_type == target_type:
			slot.quantity += 1
			break

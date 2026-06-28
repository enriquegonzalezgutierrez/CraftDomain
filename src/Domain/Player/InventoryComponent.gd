# ==============================================================================
# Project: CraftDomain
# Description: Concrete domain component managing a 24-slot stackable inventory grid.
#              Slots 0-7 represent the active Hotbar. Slots 8-23 represent the Backpack.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) and implements `IInventory` (DIP).
#              FEATURES: Advanced item stacking (up to 64), empty slot auto-discovery,
#              global item-id quantity aggregation, slot swapping, and complete 
#              self-serialization/deserialization for save files (SRP).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/InventoryComponent.gd
# ==============================================================================
class_name InventoryComponent
extends IInventory

## Slot Data Value Object representing an individual cell in the grid
class SlotData:
	var item_id: int = -1 # -1 represents EMPTY (AIR)
	var quantity: int = 0
	var max_stack: int = 64
	
	func _init(p_item_id: int, p_quantity: int, p_max_stack: int = 64) -> void:
		item_id = p_item_id
		quantity = p_quantity
		max_stack = p_max_stack

# Array of 24 strictly managed inventory slots (0-7 Hotbar, 8-23 Backpack)
var _slots: Array[SlotData] = []

func _init() -> void:
	_slots.resize(24)
	_setup_starting_survival_inventory()

## Populates the inventory with starting survival supplies to keep gameplay immediately active
func _setup_starting_survival_inventory() -> void:
	# Slots 0 to 7: Active Quickbar
	_slots[0] = SlotData.new(1, 64)   # 64x Stone Block (ID 1)
	_slots[1] = SlotData.new(2, 64)   # 64x Dirt Block (ID 2)
	_slots[2] = SlotData.new(3, 64)   # 64x Grass Block (ID 3)
	_slots[3] = SlotData.new(4, 16)   # 16x Wood Log (ID 4)
	_slots[4] = SlotData.new(5, 16)   # 16x Shrubbery Leaves (ID 5)
	_slots[5] = SlotData.new(15, 3)   # 3x Lava Bucket (ID 15)
	_slots[6] = SlotData.new(16, 5)   # 5x Fried Chicken (ID 16 - Food)
	_slots[7] = SlotData.new(17, -1, 1)  # 1x Wooden Sword (ID 17 - Infinite weapon, max_stack 1)
	
	# Slots 8 to 23: Backpack Storage (Starts completely empty)
	for i in range(8, 24):
		_slots[i] = SlotData.new(-1, 0)

# ==============================================================================
# IInventory INTERFACE CONCRETE IMPLEMENTATION (Strict DIP Compliance)
# ==============================================================================

## Returns the accumulated quantity of an Item ID across all 24 grid slots
func get_item_total_quantity(item_id: int) -> int:
	var total := 0
	for slot in _slots:
		if slot.item_id == item_id:
			# If slot is infinite, return infinite marker safely
			if slot.quantity == -1:
				return 9999
			total += slot.quantity
	return total

## Distributes and stores a specific quantity of an Item ID safely
func add_item(item_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return true
		
	# Weapons (ID 17) do not stack
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	var remaining := quantity
	
	# Pass 1: Try to fill existing stacks of this item that are not full
	if not is_weapon:
		for slot in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack and slot.quantity != -1:
				var available_space := slot.max_stack - slot.quantity
				var add_amount := min(remaining, available_space)
				slot.quantity += add_amount
				remaining -= add_amount
				if remaining <= 0:
					return true
					
	# Pass 2: Place the remaining items in the first available empty slots
	while remaining > 0:
		var empty_index := _find_first_empty_slot_index()
		if empty_index == -1:
			return false # Inventory is completely full!
			
		var slot := _slots[empty_index]
		var add_amount := min(remaining, max_stack)
		
		slot.item_id = item_id
		slot.quantity = add_amount
		slot.max_stack = max_stack
		remaining -= add_amount
		
	return true

## Deducts a specific quantity of an Item ID across all stacks (e.g. Crafting consumption)
func consume_item(item_id: int, quantity: int) -> void:
	var remaining := quantity
	
	# Loop backward from Backpack to Hotbar to preserve quickbar items first
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return # Infinite items are never consumed
				
			var take_amount := min(slot.quantity, remaining)
			slot.quantity -= take_amount
			remaining -= take_amount
			
			if slot.quantity <= 0:
				# Reset slot to empty
				slot.item_id = -1
				slot.quantity = 0
				
			if remaining <= 0:
				break

## Evaluates if there is enough stack capacity or empty cells to store a quantity of an Item ID
func can_receive_item(item_id: int, quantity: int) -> bool:
	var remaining := quantity
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	
	# Check space in existing stacks
	if not is_weapon:
		for slot in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack:
				remaining -= (slot.max_stack - slot.quantity)
				if remaining <= 0:
					return true
					
	# Check space in empty slots
	for slot in _slots:
		if slot.item_id == -1:
			remaining -= max_stack
			if remaining <= 0:
				return true
				
	return false

# ==============================================================================
# BACKPACK AUXILIARY SERVICES (Used by UI presentation layer)
# ==============================================================================

## Swaps the contents of two slots (Used for Minecraft-style sorting/rearranging)
func swap_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= _slots.size() or index_b < 0 or index_b >= _slots.size():
		return
		
	var temp := _slots[index_a]
	_slots[index_a] = _slots[index_b]
	_slots[index_b] = temp

## Returns the slot data of a specific index safely
func get_slot_data(index: int) -> SlotData:
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return null

## Returns the item name corresponding to an index for tooltips and text overlays
func get_slot_item_name(index: int) -> String:
	var slot := get_slot_data(index)
	if slot == null or slot.item_id == -1:
		return "Empty"
		
	match slot.item_id:
		1: return "Stone Block"
		2: return "Dirt Block"
		3: return "Grass Block"
		4: return "Wood Log"
		5: return "Leaves"
		7: return "Sand"
		8: return "Red Sand"
		9: return "Snow"
		10: return "Ice"
		11: return "Mud"
		12: return "Neon Cyan"
		13: return "Neon Magenta"
		14: return "Cloud"
		15: return "Lava Bucket"
		16: return "Fried Chicken"
		17: return "Wooden Sword"
		_: return "Unknown block"

## Helper to find the first completely empty slot index
func _find_first_empty_slot_index() -> int:
	for i in range(_slots.size()):
		if _slots[i].item_id == -1:
			return i
	return -1

## Dynamic routing for collected blocks mined in the world (OCP compliant)
func add_block_by_type(block_type: BlockType.Type) -> void:
	var target_id := int(block_type)
	
	# Smart Routing: Map biome-specific exotic blocks to their nearest base item equivalents
	match block_type:
		BlockType.Type.SAND, BlockType.Type.RED_SAND, BlockType.Type.MUD:
			target_id = 2 # Map to Dirt (ID 2)
		BlockType.Type.SNOW, BlockType.Type.ICE, BlockType.Type.NEON_CYAN, BlockType.Type.NEON_MAGENTA:
			target_id = 1 # Map to Stone (ID 1)
		BlockType.Type.CLOUD:
			target_id = 5 # Map to Leaves (ID 5)
			
	var _success := add_item(target_id, 1)

# ==============================================================================
# FASE 1 SERIALIZATION SERVICES (Strict SRP Compliance)
# ==============================================================================

## Packs and returns the 24 slots data into an easily serializable Array of Dictionaries (For saving)
func get_serialize_data() -> Array:
	var data: Array = []
	for slot in _slots:
		data.append({
			"item_id": slot.item_id,
			"quantity": slot.quantity,
			"max_stack": slot.max_stack
		})
	return data

## Restores and deserializes the entire 24-slot inventory state from loaded save file data
func deserialize_data(data: Array) -> void:
	if data.size() == 0:
		return
		
	_slots.clear()
	# Load whatever saved slots are present (safeguarded to maximum of 24)
	for i in range(min(data.size(), 24)):
		var s_data := data[i] as Dictionary
		var item_id := s_data["item_id"] as int
		var quantity := s_data["quantity"] as int
		var max_stack := s_data["max_stack"] as int if s_data.has("max_stack") else 64
		
		_slots.append(SlotData.new(item_id, quantity, max_stack))
		
	# Self-Healing: If the loaded data has fewer than 24 slots, pad the rest with empty cells
	while _slots.size() < 24:
		_slots.append(SlotData.new(-1, 0))

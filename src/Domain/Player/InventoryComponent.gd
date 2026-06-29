# ==============================================================================
# Project: CraftDomain
# Description: Concrete domain component managing a 24-slot stackable inventory grid.
#              Slots 0-7 represent the active Hotbar. Slots 8-23 represent the Backpack.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) and implements `IInventory` (DIP).
#              i18n UPGRADE: Stripped hardcoded English block names.
#              ROBUSTNESS FIX: Added strict array boundaries protection to prevent
#              out-of-bounds crashes when querying newly added crop IDs (like ID 20).
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

## Populates the inventory with starting survival supplies
func _setup_starting_survival_inventory() -> void:
	# Slots 0 to 7: Active Quickbar
	_slots[0] = SlotData.new(1, 64)   # 64x Stone Block (ID 1)
	_slots[1] = SlotData.new(2, 64)   # 64x Dirt Block (ID 2)
	_slots[2] = SlotData.new(3, 64)   # 64x Grass Block (ID 3)
	_slots[3] = SlotData.new(4, 16)   # 16x Wood Log (ID 4)
	_slots[4] = SlotData.new(5, 16)   # 16x Shrubbery Leaves (ID 5)
	_slots[5] = SlotData.new(15, 3)   # 3x Lava Bucket (ID 15)
	_slots[6] = SlotData.new(16, 5)   # 5x Fried Chicken (ID 16)
	_slots[7] = SlotData.new(17, -1, 1)  # 1x Wooden Sword (ID 17 - Infinite)
	
	# Slot 8: Starting farming seeds
	_slots[8] = SlotData.new(18, 16)  # 16x Crop Seeds (ID 18)
	
	# Slots 9 to 23: Backpack Storage (Empty)
	for i in range(9, 24):
		_slots[i] = SlotData.new(-1, 0)

# ==============================================================================
# IInventory INTERFACE CONCRETE IMPLEMENTATION (Strict DIP Compliance)
# ==============================================================================

func get_item_total_quantity(item_id: int) -> int:
	var total := 0
	for slot in _slots:
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return 9999
			total += slot.quantity
	return total

func add_item(item_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return true
		
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	var remaining := quantity
	
	if not is_weapon:
		for slot in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack and slot.quantity != -1:
				var available_space := slot.max_stack - slot.quantity
				var add_amount := min(remaining, available_space)
				slot.quantity += add_amount
				remaining -= add_amount
				if remaining <= 0:
					return true
					
	while remaining > 0:
		var empty_index := _find_first_empty_slot_index()
		if empty_index == -1:
			return false 
			
		var slot := _slots[empty_index]
		var add_amount := min(remaining, max_stack)
		
		slot.item_id = item_id
		slot.quantity = add_amount
		slot.max_stack = max_stack
		remaining -= add_amount
		
	return true

func consume_item(item_id: int, quantity: int) -> void:
	var remaining := quantity
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return 
				
			var take_amount := min(slot.quantity, remaining)
			slot.quantity -= take_amount
			remaining -= take_amount
			
			if slot.quantity <= 0:
				slot.item_id = -1
				slot.quantity = 0
				
			if remaining <= 0:
				break

func can_receive_item(item_id: int, quantity: int) -> bool:
	var remaining := quantity
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	
	if not is_weapon:
		for slot in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack:
				remaining -= (slot.max_stack - slot.quantity)
				if remaining <= 0:
					return true
					
	for slot in _slots:
		if slot.item_id == -1:
			remaining -= max_stack
			if remaining <= 0:
				return true
				
	return false

# ==============================================================================
# BACKPACK AUXILIARY SERVICES 
# ==============================================================================

func swap_slots(index_a: int, index_b: int) -> void:
	if index_a < 0 or index_a >= _slots.size() or index_b < 0 or index_b >= _slots.size():
		return
		
	var temp := _slots[index_a]
	_slots[index_a] = _slots[index_b]
	_slots[index_b] = temp

## FIXED: Added strict boundary protection to prevent out-of-bounds crashes
func get_slot_data(index: int) -> SlotData:
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return null

## FIXED: Added boundary protection mapping to prevent out-of-bounds crashes on checklist queries
func get_slot_quantity(index: int) -> int:
	if index >= 0 and index < _slots.size():
		return _slots[index].quantity
	return 0

## SRP / OCP COMPLIANT ROUTING: Dynamically reads translated strings from Domain Library
func get_slot_item_name(index: int) -> String:
	var slot := get_slot_data(index)
	if slot == null or slot.item_id == -1:
		return tr("INVENTORY_EMPTY")
		
	var def := BlockLibrary.get_definition(slot.item_id as BlockType.Type)
	if def != null and def.type != BlockType.Type.AIR:
		return def.get_localized_name()
		
	match slot.item_id:
		16: return tr("ITEM_FRIED_CHICKEN")
		17: return tr("ITEM_WOODEN_SWORD")
		_: return tr("INVENTORY_UNKNOWN")

func _find_first_empty_slot_index() -> int:
	for i in range(_slots.size()):
		if _slots[i].item_id == -1:
			return i
	return -1

func add_block_by_type(block_type: BlockType.Type) -> void:
	var target_id := int(block_type)
	
	match block_type:
		BlockType.Type.SAND, BlockType.Type.RED_SAND, BlockType.Type.MUD:
			target_id = 2 
		BlockType.Type.SNOW, BlockType.Type.ICE, BlockType.Type.NEON_CYAN, BlockType.Type.NEON_MAGENTA:
			target_id = 1 
		BlockType.Type.CLOUD:
			target_id = 5 
			
	if block_type == BlockType.Type.LEAVES and randf() < 0.25:
		var _seed_success := add_item(18, 1) 
			
	var _success := add_item(target_id, 1)

# ==============================================================================
# SERIALIZATION SERVICES 
# ==============================================================================

func get_serialize_data() -> Array:
	var data: Array = []
	for slot in _slots:
		data.append({
			"item_id": slot.item_id,
			"quantity": slot.quantity,
			"max_stack": slot.max_stack
		})
	return data

func deserialize_data(data: Array) -> void:
	if data.size() == 0:
		return
		
	if data[0] is float or data[0] is int:
		_setup_starting_survival_inventory() 
		return
		
	_slots.clear()
	for i in range(min(data.size(), 24)):
		var s_data := data[i] as Dictionary
		var item_id := s_data["item_id"] as int
		var quantity := s_data["quantity"] as int
		var max_stack := s_data["max_stack"] as int if s_data.has("max_stack") else 64
		
		_slots.append(SlotData.new(item_id, quantity, max_stack))
		
	while _slots.size() < 24:
		_slots.append(SlotData.new(-1, 0))

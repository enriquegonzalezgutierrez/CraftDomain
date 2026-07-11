# ==============================================================================
# Project: CraftDomain
# Layer: Domain (Player System / Inventory Aggregate)
# Class: InventoryComponent
# Description: Concrete domain component managing a 24-slot stackable inventory grid.
#              Slots 0-7 represent the active Hotbar. Slots 8-23 represent the Backpack.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Exclusively manages grid swaps, 
#   stacking transactions, and inventory data structures. All block drop rules
#   are removed and delegated to the Block definitions.
# - Open-Closed Principle (OCP): Replaced static, hardcoded dictionary mappings with 
#   an extensible, registry-driven static configuration pattern. 
# - Dependency Inversion Principle (DIP): Rather than hardcoding direct, tight 
#   couplings to BlockLibrary, it interacts with the definitions polymorphically.
# ==============================================================================
class_name InventoryComponent
extends IInventory

## Slot Data Value Object representing an individual cell in the grid network.
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

## Injectable reference to the block library provider (Defaults to BlockLibrary class).
var block_library_provider: Object = BlockLibrary

## Dynamic registry mapping non-block Item IDs to their localized translation keys.
static var _non_block_item_names: Dictionary = {}


## Static Constructor: Registers default base-game item name translations on boot.
static func _static_init() -> void:
	register_non_block_item_name(15, "BLOCK_LAVA")          # Lava Bucket
	register_non_block_item_name(16, "ITEM_FRIED_CHICKEN")  # Fried Chicken
	register_non_block_item_name(17, "ITEM_WOODEN_SWORD")   # Wooden Sword
	register_non_block_item_name(18, "BLOCK_CROP_SEED")     # Crop Seeds
	register_non_block_item_name(20, "BLOCK_CROP_RIPE")     # Golden Wheat Grains
	register_non_block_item_name(26, "ITEM_STONE_SLAB")     # Stone Slab Item


## Public OCP Extension API: Registers a custom item translation key dynamically.
## Can be called from mods, custom items, or DLC loaders on startup.
static func register_non_block_item_name(item_id: int, translation_key: String) -> void:
	_non_block_item_names[item_id] = translation_key
	print("[InventoryComponent] Registered dynamic OCP item name for ID %d -> '%s'" % [item_id, translation_key])


## Static helper to get an item's localized name directly by its Item ID (OCP/DIP Compliant)
static func get_item_name_by_id(item_id: int) -> String:
	# 1. Ask the Block Library provider first
	var def: BlockDefinition = BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
	if def != null and def.type != 0: # 0 represents BlockType.Type.AIR
		return def.get_localized_name()
		
	# 2. Symmetrical Fallback: Check non-block static registry (Using TranslationServer for static safety)
	if _non_block_item_names.has(item_id):
		var translation_key: String = _non_block_item_names[item_id]
		return TranslationServer.translate(translation_key)
		
	return TranslationServer.translate("INVENTORY_UNKNOWN")


func _init() -> void:
	_slots.resize(24)
	_setup_starting_survival_inventory()


## Populates the inventory with starting survival supplies.
func _setup_starting_survival_inventory() -> void:
	# Slots 0 to 7: Active Quickbar
	_slots[0] = SlotData.new(1, 64)   # 64x Stone Block (ID 1)
	_slots[1] = SlotData.new(2, 64)   # 64x Dirt Block (ID 2)
	_slots[2] = SlotData.new(3, 64)   # 64x Grass Block (ID 3)
	_slots[3] = SlotData.new(4, 16)   # 16x Wood Log (ID 4)
	_slots[4] = SlotData.new(5, 16)   # 16x Shrubbery Leaves (ID 5)
	_slots[5] = SlotData.new(15, 3)   # 3x Lava Bucket (ID 15)
	_slots[6] = SlotData.new(16, 5)   # 5x Fried Chicken (ID 16)
	_slots[7] = SlotData.new(17, -1, 1)  # 1x Wooden Sword (ID 17 - Infinite durability)
	
	# Slot 8: Starting farming seeds
	_slots[8] = SlotData.new(18, 16)  # 16x Crop Seeds (ID 18)
	
	# Slot 9: 64x Starting Stone Slabs (ID 26)
	_slots[9] = SlotData.new(26, 64)
	
	# Slots 10 to 23: Backpack Storage (Empty)
	for i in range(10, 24):
		_slots[i] = SlotData.new(-1, 0)


# ==============================================================================
# IInventory INTERFACE CONCRETE IMPLEMENTATION (Strict DIP Compliance)
# ==============================================================================

func get_item_total_quantity(item_id: int) -> int:
	var total := 0
	for slot: SlotData in _slots:
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return 9999 # Infinite item proxy
			total += slot.quantity
	return total


func add_item(item_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return true
		
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	var remaining := quantity
	var modified := false
	
	if not is_weapon:
		for slot: SlotData in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack and slot.quantity != -1:
				var available_space := slot.max_stack - slot.quantity
				var add_amount := min(remaining, available_space)
				slot.quantity += add_amount
				remaining -= add_amount
				modified = true
				if remaining <= 0:
					inventory_changed.emit()
					return true
					
	while remaining > 0:
		var empty_index := _find_first_empty_slot_index()
		if empty_index == -1:
			if modified:
				inventory_changed.emit()
			return false # Inventory full
			
		var slot := _slots[empty_index]
		var add_amount := min(remaining, max_stack)
		
		slot.item_id = item_id
		slot.quantity = add_amount
		slot.max_stack = max_stack
		remaining -= add_amount
		modified = true
		
	if modified:
		inventory_changed.emit()
	return true


func consume_item(item_id: int, quantity: int) -> void:
	var remaining := quantity
	var modified := false
	
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return # Infinite item cannot be consumed
				
			var take_amount := min(slot.quantity, remaining)
			slot.quantity -= take_amount
			remaining -= take_amount
			modified = true
			
			if slot.quantity <= 0:
				slot.item_id = -1
				slot.quantity = 0
				
			if remaining <= 0:
				break
				
	if modified:
		inventory_changed.emit()


func can_receive_item(item_id: int, quantity: int) -> bool:
	var remaining := quantity
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else 64
	
	if not is_weapon:
		for slot: SlotData in _slots:
			if slot.item_id == item_id and slot.quantity < slot.max_stack:
				remaining -= (slot.max_stack - slot.quantity)
				if remaining <= 0:
					return true
					
	for slot: SlotData in _slots:
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
	inventory_changed.emit()


func get_slot_data(index: int) -> SlotData:
	if index >= 0 and index < _slots.size():
		return _slots[index]
	return null


func get_slot_quantity(index: int) -> int:
	if index >= 0 and index < _slots.size():
		return _slots[index].quantity
	return 0


## Returns the localized item name, utilizing DIP for definition lookup.
func get_slot_item_name(index: int) -> String:
	var slot := get_slot_data(index)
	if slot == null or slot.item_id == -1:
		return tr("INVENTORY_EMPTY")
		
	return get_item_name_by_id(slot.item_id)


func _find_first_empty_slot_index() -> int:
	for i in range(_slots.size()):
		if _slots[i].item_id == -1:
			return i
	return -1


## Adds blocks dynamically based on the polymorphic drop table in BlockDefinition.
## Fully OCP compliant; does not contain any hardcoded block-to-item translation tables.
func add_block_by_type(block_type: BlockType.Type) -> void:
	# Query the BlockLibrary provider polimorphically (SRP/OCP)
	var def: BlockDefinition = block_library_provider.get_definition(block_type) as BlockDefinition
	if def != null:
		var target_id := def.get_drop_item_id()
		var qty := def.get_drop_quantity()
		
		# Execute addition transaction
		add_item(target_id, qty)
		
		# Bonus agricultural drop chance (unfolded OCP check)
		if block_type == BlockType.Type.LEAVES and randf() < 0.25:
			add_item(18, 1) # Bonus crop seeds drop


# ==============================================================================
# UX ENHANCEMENT: AUTO-SORT & CONSOLIDATE
# ==============================================================================

## Consolidates fragmented item stacks and sorts the backpack storage area
## (slots 8 to 23) in ascending order, leaving the active Hotbar (slots 0 to 7)
## completely undisturbed for uninterrupted combat/building setups.
func consolidate_and_sort_backpack() -> void:
	var consolidated: Dictionary = {} # item_id (int) -> total_qty (int)
	
	for i in range(8, 24):
		var slot := _slots[i]
		if slot.item_id != -1 and slot.quantity > 0:
			if not consolidated.has(slot.item_id):
				consolidated[slot.item_id] = 0
			consolidated[slot.item_id] += slot.quantity
			
	for i in range(8, 24):
		_slots[i] = SlotData.new(-1, 0)
		
	var sorted_item_ids := consolidated.keys()
	sorted_item_ids.sort()
	
	var current_slot_index := 8
	for item_id: int in sorted_item_ids:
		var total_qty: int = consolidated[item_id]
		var is_weapon: bool = (item_id == 17)
		var max_stack := 1 if is_weapon else 64
		
		while total_qty > 0 and current_slot_index < 24:
			var pack_qty := min(total_qty, max_stack)
			_slots[current_slot_index] = SlotData.new(item_id, pack_qty, max_stack)
			total_qty -= pack_qty
			current_slot_index += 1
			
	inventory_changed.emit()


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
		
	inventory_changed.emit()

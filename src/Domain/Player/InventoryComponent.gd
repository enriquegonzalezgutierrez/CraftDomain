# ==============================================================================
# Pathfile: res://src/Domain/Player/InventoryComponent.gd
# Description: Concrete domain component managing a 24-slot stackable inventory grid.
#              SOLID COMPLIANCE: Class limits set < 300 lines (SRP). Complex sorting
#              delegated to InventorySortingService. Inline methods structured < 20 lines.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name InventoryComponent
extends IInventory

class SlotData:
	var item_id: int = -1 
	var quantity: int = 0
	var max_stack: int = 64
	
	func _init(p_item_id: int, p_quantity: int, p_max_stack: int = 64) -> void:
		item_id = p_item_id
		quantity = p_quantity
		max_stack = p_max_stack

const MAX_STACK_SIZE: int = 64
const TOTAL_SLOTS: int = 24

var _slots: Array[SlotData] = []
var block_library_provider: Object = BlockLibrary

static var _non_block_item_names: Dictionary = {}


static func _static_init() -> void:
	register_non_block_item_name(15, "BLOCK_LAVA")          
	register_non_block_item_name(16, "ITEM_FRIED_CHICKEN")  
	register_non_block_item_name(17, "ITEM_WOODEN_SWORD")   
	register_non_block_item_name(18, "BLOCK_CROP_SEED")     
	register_non_block_item_name(20, "BLOCK_CROP_RIPE")     
	register_non_block_item_name(26, "ITEM_STONE_SLAB")     


static func register_non_block_item_name(item_id: int, translation_key: String) -> void:
	_non_block_item_names[item_id] = translation_key
	print("[InventoryComponent] Registered dynamic OCP item name for ID %d -> '%s'" % [item_id, translation_key])


static func get_item_name_by_id(item_id: int) -> String:
	var def: BlockDefinition = BlockLibrary.get_definition(item_id as BlockType.Type) as BlockDefinition
	if def != null and def.type != 0: 
		return def.get_localized_name()
		
	if _non_block_item_names.has(item_id):
		var translation_key: String = _non_block_item_names[item_id]
		return TranslationServer.translate(translation_key)
		
	return TranslationServer.translate("INVENTORY_UNKNOWN")


func _init() -> void:
	_slots.resize(TOTAL_SLOTS)
	_setup_starting_survival_inventory()


func _setup_starting_survival_inventory() -> void:
	_slots[0] = SlotData.new(1, 64)   
	_slots[1] = SlotData.new(2, 64)   
	_slots[2] = SlotData.new(3, 64)   
	_slots[3] = SlotData.new(4, 16)   
	_slots[4] = SlotData.new(5, 16)   
	_slots[5] = SlotData.new(15, 3)   
	_slots[6] = SlotData.new(16, 5)   
	_slots[7] = SlotData.new(17, -1, 1)  
	_slots[8] = SlotData.new(18, 16)  
	_slots[9] = SlotData.new(26, 64)
	
	for i in range(10, TOTAL_SLOTS):
		_slots[i] = SlotData.new(-1, 0)


func get_item_total_quantity(item_id: int) -> int:
	var total := 0
	for slot: SlotData in _slots:
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return 9999 
			total += slot.quantity
	return total


func add_item(item_id: int, quantity: int) -> bool:
	if quantity <= 0:
		return true
		
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else MAX_STACK_SIZE
	var remaining := quantity
	
	if not is_weapon:
		remaining = _fill_existing_stacks(item_id, remaining)
		if remaining <= 0:
			inventory_changed.emit()
			return true
			
	var success := _fill_empty_slots(item_id, remaining, max_stack)
	if success:
		inventory_changed.emit()
	return success


func _fill_existing_stacks(item_id: int, remaining: int) -> int:
	for slot: SlotData in _slots:
		if slot.item_id == item_id and slot.quantity < slot.max_stack and slot.quantity != -1:
			var available_space := slot.max_stack - slot.quantity
			var add_amount := min(remaining, available_space)
			slot.quantity += add_amount
			remaining -= add_amount
			if remaining <= 0:
				break
	return remaining


func _fill_empty_slots(item_id: int, remaining: int, max_stack: int) -> bool:
	var modified := false
	while remaining > 0:
		var empty_index := _find_first_empty_slot_index()
		if empty_index == -1:
			return modified 
			
		var slot := _slots[empty_index]
		var add_amount := min(remaining, max_stack)
		
		slot.item_id = item_id
		slot.quantity = add_amount
		slot.max_stack = max_stack
		remaining -= add_amount
		modified = true
	return modified


func consume_item(item_id: int, quantity: int) -> void:
	var remaining := quantity
	var modified := false
	
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if slot.item_id == item_id:
			if slot.quantity == -1:
				return 
			remaining = _deduct_from_slot(slot, remaining)
			modified = true
			if remaining <= 0:
				break
				
	if modified:
		inventory_changed.emit()


func _deduct_from_slot(slot: SlotData, remaining: int) -> int:
	var take_amount := min(slot.quantity, remaining)
	slot.quantity -= take_amount
	if slot.quantity <= 0:
		slot.item_id = -1
		slot.quantity = 0
	return remaining - take_amount


func can_receive_item(item_id: int, quantity: int) -> bool:
	var remaining := quantity
	var is_weapon := (item_id == 17)
	var max_stack := 1 if is_weapon else MAX_STACK_SIZE
	
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


func add_block_by_type(block_type: BlockType.Type) -> void:
	var def: BlockDefinition = block_library_provider.get_definition(block_type) as BlockDefinition
	if def != null:
		var target_id := def.get_drop_item_id()
		var qty := def.get_drop_quantity()
		
		add_item(target_id, qty)
		
		if block_type == BlockType.Type.LEAVES and randf() < 0.25:
			add_item(18, 1) 


func consolidate_and_sort_backpack() -> void:
	InventorySortingService.consolidate_and_sort_backpack(_slots, MAX_STACK_SIZE)
	inventory_changed.emit()


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
	for i in range(min(data.size(), TOTAL_SLOTS)):
		var s_data := data[i] as Dictionary
		var item_id := s_data["item_id"] as int
		var quantity := s_data["quantity"] as int
		var max_stack := s_data["max_stack"] as int if s_data.has("max_stack") else MAX_STACK_SIZE
		
		_slots.append(SlotData.new(item_id, quantity, max_stack))
		
	while _slots.size() < TOTAL_SLOTS:
		_slots.append(SlotData.new(-1, 0))
		
	inventory_changed.emit()

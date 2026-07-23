# ==============================================================================
# Pathfile: res://src/Domain/Life/TradingService.gd
# Description: Pure Domain Service orchestrating secure trade transactions 
#              between inventories. Completely decoupled from physics and UI.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name TradingService
extends RefCounted


## Validates if an ID-based trade transaction can safely occur.
static func can_execute_id_trade(
	buyer_inv: IInventory,
	cost_item_id: int,
	cost_qty: int,
	reward_item_id: int,
	reward_qty: int
) -> bool:
	if buyer_inv == null:
		return false
		
	if buyer_inv.get_item_total_quantity(cost_item_id) < cost_qty:
		return false
		
	if not buyer_inv.can_receive_item(reward_item_id, reward_qty):
		return false
		
	return true


## Executes the ID-based trade transaction, modifying inventory stocks.
static func execute_id_trade(
	buyer_inv: IInventory,
	cost_item_id: int,
	cost_qty: int,
	reward_item_id: int,
	reward_qty: int
) -> bool:
	if not can_execute_id_trade(buyer_inv, cost_item_id, cost_qty, reward_item_id, reward_qty):
		return false
		
	buyer_inv.consume_item(cost_item_id, cost_qty)
	var added: bool = buyer_inv.add_item(reward_item_id, reward_qty)
	return added


# ==============================================================================
# LEGACY SLOT-BASED APIS (Maintained for backward compatibility)
# ==============================================================================

static func can_execute_trade(
	buyer_inv: IInventory,
	cost_slot: int,
	cost_qty: int,
	reward_slot: int,
	reward_qty: int,
	seller_inv: IInventory = null
) -> bool:
	var buyer_comp := buyer_inv as InventoryComponent
	if buyer_comp == null or buyer_comp.get_slot_quantity(cost_slot) < cost_qty:
		return false
		
	var slot_data := buyer_comp.get_slot_data(reward_slot)
	if slot_data != null and slot_data.item_id != -1 and slot_data.item_id != slot_data.item_id:
		return false
		
	return _can_seller_fulfill_slot(seller_inv, reward_slot, reward_qty)


static func _can_seller_fulfill_slot(seller_inv: IInventory, reward_slot: int, reward_qty: int) -> bool:
	if seller_inv == null:
		return true
	var seller_comp := seller_inv as InventoryComponent
	if seller_comp == null:
		return false
	return seller_comp.get_slot_quantity(reward_slot) >= reward_qty


static func execute_trade(
	buyer_inv: IInventory,
	cost_slot: int,
	cost_qty: int,
	reward_slot: int,
	reward_qty: int,
	seller_inv: IInventory = null
) -> bool:
	if not can_execute_trade(buyer_inv, cost_slot, cost_qty, reward_slot, reward_qty, seller_inv):
		return false
		
	_apply_buyer_slot_trade(buyer_inv as InventoryComponent, cost_slot, cost_qty, reward_slot, reward_qty)
	_apply_seller_slot_trade(seller_inv as InventoryComponent, cost_slot, cost_qty, reward_slot, reward_qty)
	return true


static func _apply_buyer_slot_trade(buyer_comp: InventoryComponent, cost_slot: int, cost_qty: int, reward_slot: int, reward_qty: int) -> void:
	if buyer_comp == null: return
	var cost_data := buyer_comp.get_slot_data(cost_slot)
	var reward_data := buyer_comp.get_slot_data(reward_slot)
	
	if cost_data != null:
		cost_data.quantity -= cost_qty
		if cost_data.quantity <= 0:
			cost_data.item_id = -1
			cost_data.quantity = 0
			
	if reward_data != null:
		reward_data.quantity += reward_qty


static func _apply_seller_slot_trade(seller_comp: InventoryComponent, cost_slot: int, cost_qty: int, reward_slot: int, reward_qty: int) -> void:
	if seller_comp == null: return
	var reward_data := seller_comp.get_slot_data(reward_slot)
	var cost_data := seller_comp.get_slot_data(cost_slot)
	
	if reward_data != null:
		reward_data.quantity -= reward_qty
		if reward_data.quantity <= 0:
			reward_data.item_id = -1
			reward_data.quantity = 0
			
	if cost_data != null:
		cost_data.quantity += cost_qty

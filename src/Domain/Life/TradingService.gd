# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service orchestrating secure trade transactions 
#              between inventories. Completely decoupled from physical simulation,
#              user interface systems, and concrete player/NPC node controllers.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Only manages trade logic.
#              - Dependency Inversion Principle (DIP): Operates entirely on the 
#                abstract IInventory interface.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/TradingService.gd
# ==============================================================================
class_name TradingService
extends RefCounted

## Validates if an ID-based trade transaction can safely occur.
## Checks if the buyer has sufficient items to pay the cost, and if there is
## enough remaining grid capacity to receive the transaction rewards.
static func can_execute_id_trade(
	buyer_inv: IInventory,
	cost_item_id: int,
	cost_qty: int,
	reward_item_id: int,
	reward_qty: int
) -> bool:
	if buyer_inv == null:
		return false
		
	# Verify the buyer can afford the cost of the trade
	if buyer_inv.get_item_total_quantity(cost_item_id) < cost_qty:
		return false
		
	# Verify the buyer has sufficient inventory grid capacity to receive the rewards
	if not buyer_inv.can_receive_item(reward_item_id, reward_qty):
		return false
		
	return true


## Executes the ID-based trade transaction, modifying inventory stocks.
## Returns true if the transaction completed successfully, false otherwise.
static func execute_id_trade(
	buyer_inv: IInventory,
	cost_item_id: int,
	cost_qty: int,
	reward_item_id: int,
	reward_qty: int
) -> bool:
	if not can_execute_id_trade(buyer_inv, cost_item_id, cost_qty, reward_item_id, reward_qty):
		return false
		
	# Deduct the payment cost across the inventory grid
	buyer_inv.consume_item(cost_item_id, cost_qty)
	
	# Grant the reward items to the buyer
	var added: bool = buyer_inv.add_item(reward_item_id, reward_qty)
	
	return added


# ==============================================================================
# LEGACY SLOT-BASED APIS (Maintained for backward compatibility)
# ==============================================================================

## Legacy validator based on absolute slot indexes.
static func can_execute_trade(
	buyer_inv: IInventory,
	cost_slot: int,
	cost_qty: int,
	reward_slot: int,
	reward_qty: int,
	seller_inv: IInventory = null
) -> bool:
	if buyer_inv == null:
		return false
		
	# Slot-based capacity queries are handled dynamically on the concrete inventory component
	var inventory_comp := buyer_inv as InventoryComponent
	if inventory_comp == null:
		return false
		
	if inventory_comp.get_slot_quantity(cost_slot) < cost_qty:
		return false
		
	# Simple capacity evaluation
	var slot_data := inventory_comp.get_slot_data(reward_slot)
	if slot_data != null and slot_data.item_id != -1 and slot_data.item_id != slot_data.item_id:
		return false
		
	if seller_inv != null:
		var seller_comp := seller_inv as InventoryComponent
		if seller_comp == null:
			return false
		if seller_comp.get_slot_quantity(reward_slot) < reward_qty:
			return false
			
	return true


## Legacy slot-based transaction executor.
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
		
	var buyer_comp := buyer_inv as InventoryComponent
	var seller_comp := seller_inv as InventoryComponent
	
	if buyer_comp != null:
		var cost_data := buyer_comp.get_slot_data(cost_slot)
		var reward_data := buyer_comp.get_slot_data(reward_slot)
		
		if cost_data != null:
			cost_data.quantity -= cost_qty
			if cost_data.quantity <= 0:
				cost_data.item_id = -1
				cost_data.quantity = 0
				
		if reward_data != null:
			if reward_data.item_id == -1:
				# Attempt to inherit the context ID if slot was empty
				pass
			reward_data.quantity += reward_qty
			
	if seller_comp != null:
		var reward_data := seller_comp.get_slot_data(reward_slot)
		var cost_data := seller_comp.get_slot_data(cost_slot)
		
		if reward_data != null:
			reward_data.quantity -= reward_qty
			if reward_data.quantity <= 0:
				reward_data.item_id = -1
				reward_data.quantity = 0
				
		if cost_data != null:
			cost_data.quantity += cost_qty
			
	return true

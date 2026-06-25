# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Service orchestrating secure trade transactions 
#              between inventories. Fully decoupled from game physics,
#              UI, and infrastructure entities.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Life/TradingService.gd
# ==============================================================================
class_name TradingService
extends RefCounted

## Validates if a trade transaction can occur based on inventory capacity and cost constraints.
## Returns true if the buyer can afford the cost and (optional) the seller has enough stock.
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
		
	# Verify the buyer can afford to lose the cost item quantity
	if not buyer_inv.can_modify_slot_quantity(cost_slot, -cost_qty):
		return false
		
	# Verify the buyer can receive the reward item quantity safely
	if not buyer_inv.can_modify_slot_quantity(reward_slot, reward_qty):
		return false
		
	# If a concrete seller inventory is provided, validate its constraints as well
	if seller_inv != null:
		if not seller_inv.can_modify_slot_quantity(reward_slot, -reward_qty):
			return false
		if not seller_inv.can_modify_slot_quantity(cost_slot, cost_qty):
			return false
			
	return true

## Executes the trade transaction by modifying the inventory slots.
## Returns true if the transaction completed successfully, false otherwise.
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
		
	# Perform the transaction on the buyer's side
	buyer_inv.modify_slot_quantity(cost_slot, -cost_qty)
	buyer_inv.modify_slot_quantity(reward_slot, reward_qty)
	
	# Perform the transaction on the seller's side if present
	if seller_inv != null:
		seller_inv.modify_slot_quantity(reward_slot, -reward_qty)
		seller_inv.modify_slot_quantity(cost_slot, cost_qty)
		
	return true

# ==============================================================================
# Project: CraftDomain
# Description: Concrete Domain Strategy implementing the behavior of consumable items.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Exclusively manages the 
#                resource deduction and player healing transaction.
#              - Open-Closed Principle (OCP): Fully generic and open to any new 
#                food or potion items by parameterizing IDs and heal amounts.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/ConsumableItemStrategy.gd
# ==============================================================================
class_name ConsumableItemStrategy
extends ItemUsageStrategy

var item_id: int
var heal_amount: int


func _init(p_item_id: int, p_heal_amount: int) -> void:
	item_id = p_item_id
	heal_amount = p_heal_amount


## Concrete implementation: Returns true if the player is damaged and has stock.
func can_use(player_health: VoxelEntity, inventory: IInventory, _target_coord: Vector3i, _normal: Vector3, _world_state: WorldState) -> bool:
	return player_health.health < 3 and inventory.get_item_total_quantity(item_id) > 0


## Concrete implementation: Deducts food stock and restores player health.
func use(player_health: VoxelEntity, inventory: IInventory, _target_coord: Vector3i, _normal: Vector3, _world_controller: Node3D) -> void:
	inventory.consume_item(item_id, 1)
	player_health.health = min(3, player_health.health + heal_amount)

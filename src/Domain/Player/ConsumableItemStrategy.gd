# ==============================================================================
# Pathfile: res://src/Domain/Player/ConsumableItemStrategy.gd
# Description: Concrete Domain Strategy managing consumable food and potion usage.
#              Deducts item stocks and applies health restorations to entities.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ConsumableItemStrategy
extends ItemUsageStrategy

const MAX_PLAYER_HEALTH: int = 3

var item_id: int
var heal_amount: int


func _init(p_item_id: int, p_heal_amount: int) -> void:
	item_id = p_item_id
	heal_amount = p_heal_amount


## Evaluates if the player is damaged and holds available stock of this item.
func can_use(player_health: VoxelEntity, inventory: IInventory, _target_coord: Vector3i, _normal: Vector3, _world_state: WorldState) -> bool:
	if player_health == null or inventory == null:
		return false
	return player_health.health < MAX_PLAYER_HEALTH and inventory.get_item_total_quantity(item_id) > 0


## Consumes one item unit from inventory and restores target entity health.
func use(player_health: VoxelEntity, inventory: IInventory, _target_coord: Vector3i, _normal: Vector3, _world_modifier: IWorldModifier) -> void:
	if inventory != null and player_health != null:
		inventory.consume_item(item_id, 1)
		player_health.health = min(MAX_PLAYER_HEALTH, player_health.health + heal_amount)
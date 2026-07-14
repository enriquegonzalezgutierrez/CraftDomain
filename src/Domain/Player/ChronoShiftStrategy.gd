# ==============================================================================
# Pathfile: res://src/Domain/Player/ChronoShiftStrategy.gd
# Description: Concrete Domain Strategy implementing the chronological shift
#              mechanic. Swaps the active world timeline when placing
#              the Shard of the Past on an ancient pedestal.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChronoShiftStrategy
extends ItemUsageStrategy

# Unique Item ID for the Shard of the Past relic
const RELIC_PAST_ITEM_ID: int = 86

# Block ID representing the ancient Temple Pedestal (Chiseled Stone Bricks)
const PEDESTAL_BLOCK_ID: int = 57


func _init() -> void:
	pass


## Concrete Contract: Returns true if the player holds the Shard of the Past 
## and targets an active Chiseled Stone Bricks pedestal.
func can_use(
	_player_health: VoxelEntity, 
	inventory: IInventory, 
	target_coord: Vector3i, 
	_normal: Vector3, 
	world_state: WorldState
) -> bool:
	if inventory.get_item_total_quantity(RELIC_PAST_ITEM_ID) <= 0:
		return false
		
	var target_block := world_state.get_block(target_coord)
	return target_block == PEDESTAL_BLOCK_ID


## Concrete Contract: Triggers the timeline swap.
## DIP Compliance: Communicates through IWorldModifier to read the active 
## timeline state and dispatch the swap transaction neutrally.
func use(
	_player_health: VoxelEntity, 
	_inventory: IInventory, 
	_target_coord: Vector3i, 
	_normal: Vector3, 
	world_modifier: IWorldModifier
) -> void:
	if world_modifier.has_method("get_active_timeline") and world_modifier.has_method("swap_world_timeline"):
		var current_timeline: int = world_modifier.call("get_active_timeline") as int
		
		# Present = 0, Past = 1 (Toggles between 0 and 1)
		var target_timeline := 1 if current_timeline == 0 else 0
		
		world_modifier.call("swap_world_timeline", target_timeline)

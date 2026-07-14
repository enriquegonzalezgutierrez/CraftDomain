# ==============================================================================
# Pathfile: res://src/Domain/Player/ChronoScytheStrategy.gd
# Description: Concrete Domain Strategy implementing the usage logic for the
#              Chrono-Scythe tool. Restores unweaved void rifts and corrupted 
#              blocks to their natural/original state.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name ChronoScytheStrategy
extends ItemUsageStrategy

# Unique Item ID for the Chrono-Scythe
const CHRONO_SCYTHE_ITEM_ID: int = 85

# Block IDs involved in corruption and static decay
const GLITCH_STATIC_ID: int = 90  # Representation of flat grey static
const VOID_AIR_ID: int = 0         # Unweaved empty void gaps in solid structures


func _init() -> void:
	pass


## Concrete Contract: Returns true if the player holds the Chrono-Scythe 
## and targets a recognized corrupted or unweaved coordinate.
func can_use(
	_player_health: VoxelEntity, 
	inventory: IInventory, 
	target_coord: Vector3i, 
	_normal: Vector3, 
	world_state: WorldState
) -> bool:
	if inventory.get_item_total_quantity(CHRONO_SCYTHE_ITEM_ID) <= 0:
		return false
		
	var target_block := world_state.get_block(target_coord)
	return _is_corrupted_block(target_block, target_coord, world_state)


## Concrete Contract: Executes the block restoration transaction.
## Passes the coordinate back to the world modifier adapter to calculate 
## and apply the uncorrupted state.
func use(
	_player_health: VoxelEntity, 
	_inventory: IInventory, 
	target_coord: Vector3i, 
	_normal: Vector3, 
	world_modifier: IWorldModifier
) -> void:
	var restored_type := _calculate_restored_type(target_coord, world_modifier)
	world_modifier.set_block_globally(target_coord, restored_type)


func _is_corrupted_block(type: int, coord: Vector3i, world_state: WorldState) -> bool:
	if type == GLITCH_STATIC_ID:
		return true
		
	# Check if an empty air block represents an unweaved rift gap (enclosed by solid blocks)
	if type == VOID_AIR_ID:
		return _is_enclosed_void_rift(coord, world_state)
		
	return false


func _is_enclosed_void_rift(coord: Vector3i, world_state: WorldState) -> bool:
	var below_block := world_state.get_block(coord + Vector3i(0, -1, 0))
	# A void rift gap sits directly on top of solid bedrock or structures
	return BlockType.is_solid(below_block)


func _calculate_restored_type(coord: Vector3i, _world_modifier: IWorldModifier) -> BlockType.Type:
	# Symmetrical fallback: if we cannot calculate the original noise height,
	# we default to restoring stone to patch the hole safely.
	var restored := BlockType.Type.STONE
	
	# Future enhancement: Query _world_modifier/generator for seed-based block restoration
	if coord.y == 11:
		restored = BlockType.Type.GRASS
	elif coord.y < 11:
		restored = BlockType.Type.STONE
		
	return restored

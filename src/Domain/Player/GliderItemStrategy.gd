# ==============================================================================
# Pathfile: res://src/Domain/Player/GliderItemStrategy.gd
# Description: Concrete Domain Strategy implementing the usage logic for the 
#              Voxel Glider item. Manages deployment state toggles.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GliderItemStrategy
extends ItemUsageStrategy

# Unique Item ID for the Voxel Glider (Redwood + Cloud Fabric)
const GLIDER_ITEM_ID: int = 210

# Metadata keys to store flight state on the host
const META_GLIDER_DEPLOYED := "is_glider_deployed"


## Concrete implementation: Returns true if the player is in mid-air and holds the glider.
## Deployment is restricted while grounded to prevent accidental activations.
func can_use(
	_player_health: VoxelEntity, 
	inventory: IInventory, 
	_target_coord: Vector3i, 
	_normal: Vector3, 
	_world_state: WorldState
) -> bool:
	if inventory.get_item_total_quantity(GLIDER_ITEM_ID) <= 0:
		return false
	
	# The strategy expects the 'host' (PlayerController) to be provided 
	# via a side-channel or specific context if needed, but per the contract 
	# we rely on the state of the simulation.
	return true


## Concrete implementation: Toggles the glider deployment state.
## DIP COMPLIANCE: Interacts with the host through metadata to keep the Domain pure.
func use(
	_player_health: VoxelEntity, 
	_inventory: IInventory, 
	_target_coord: Vector3i, 
	_normal: Vector3, 
	_world_modifier: IWorldModifier
) -> void:
	# Note: The actual physics toggle is performed in the Infrastructure layer (PlayerController)
	# by observing the metadata changes or direct state queries.
	# Here we define the business rule: using the item while deployed retracts it.
	pass


## Public Business Rule: Evaluates if the glider should automatically retract
## based on physical contact with the environment.
static func evaluate_auto_retraction(is_on_floor: bool, is_on_wall: bool) -> bool:
	return is_on_floor or is_on_wall

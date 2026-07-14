# ==============================================================================
# Pathfile: res://src/Domain/Player/DataLinkerStrategy.gd
# Description: Concrete Domain Strategy implementing the usage logic for the
#              Data-Linker cyber tool. Validates terminal blocks and dispatches
#              a UI overlay request through the abstract WorldModifier boundary.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name DataLinkerStrategy
extends ItemUsageStrategy

# Unique Item ID for the Data-Linker cyber tool
const DATA_LINKER_ITEM_ID: int = 87

# Block ID representing the Cyber Terminal (Neon Magenta Conduit)
const TERMINAL_BLOCK_ID: int = 13


func _init() -> void:
	pass


## Concrete Contract: Returns true if the player holds the Data-Linker 
## and targets an active Neon Magenta cyber terminal.
func can_use(
	_player_health: VoxelEntity, 
	inventory: IInventory, 
	target_coord: Vector3i, 
	_normal: Vector3, 
	world_state: WorldState
) -> bool:
	if inventory.get_item_total_quantity(DATA_LINKER_ITEM_ID) <= 0:
		return false
		
	var target_block := world_state.get_block(target_coord)
	return target_block == TERMINAL_BLOCK_ID


## Concrete Contract: Triggers the hacking minigame.
## DIP Compliance: Communicates through IWorldModifier to request the 
## presentation layer to open the Hacking Terminal UI.
func use(
	_player_health: VoxelEntity, 
	_inventory: IInventory, 
	_target_coord: Vector3i, 
	_normal: Vector3, 
	world_modifier: IWorldModifier
) -> void:
	# Dispatch the UI trigger polymorphically to avoid coupling the Domain with Control nodes
	if world_modifier.has_method("open_hacking_terminal"):
		world_modifier.call("open_hacking_terminal")

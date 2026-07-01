# ==============================================================================
# Project: CraftDomain
# Description: Concrete Domain Strategy implementing the behavior of placeable blocks.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Exclusively manages the 
#                adjacent block target offset and block placement transactions.
#              - Open-Closed Principle (OCP): Parameterized to support placing any 
#                valid voxel material dynamically.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/PlaceableBlockStrategy.gd
# ==============================================================================
class_name PlaceableBlockStrategy
extends ItemUsageStrategy

var item_id: int
var block_type: BlockType.Type


func _init(p_item_id: int, p_block_type: BlockType.Type) -> void:
	item_id = p_item_id
	block_type = p_block_type


## Concrete implementation: Returns true if the adjacent coordinate is buildable (air/liquids) and we have stock.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var build_coord := target_coord + Vector3i(normal)
	var target_block := world_state.get_block(build_coord)
	
	# Can overwrite air and non-solid liquids like water
	return target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER


## Concrete implementation: Places the block on the calculated adjacent coordinate.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_controller: Node3D) -> void:
	inventory.consume_item(item_id, 1)
	
	var build_coord := target_coord + Vector3i(normal)
	var world_ctrl := world_controller as WorldController
	if is_instance_valid(world_ctrl):
		world_ctrl.set_block_globally(build_coord, block_type)

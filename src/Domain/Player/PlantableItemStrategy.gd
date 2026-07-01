# ==============================================================================
# Project: CraftDomain
# Description: Concrete Domain Strategy implementing the behavior of plantable seed items.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Exclusively manages the 
#                soil validity verification, seed consumption, and crop block placement.
#              - Open-Closed Principle (OCP): Fully generic and open to any new 
#                agricultural crop types by parameterizing IDs and target blocks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/PlantableItemStrategy.gd
# ==============================================================================
class_name PlantableItemStrategy
extends ItemUsageStrategy

var item_id: int
var crop_block_type: BlockType.Type


func _init(p_item_id: int, p_crop_block_type: BlockType.Type) -> void:
	item_id = p_item_id
	crop_block_type = p_crop_block_type


## Concrete implementation: Returns true if placed on top of fertile soil (Grass/Dirt) and we have stock.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if normal.y != 1.0: # Farming seeds can only be sown on the top face of blocks
		return false
		
	if inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var soil_type := world_state.get_block(target_coord)
	if soil_type != BlockType.Type.GRASS and soil_type != BlockType.Type.DIRT:
		return false
		
	var crop_coord := target_coord + Vector3i(0, 1, 0)
	return world_state.get_block(crop_coord) == BlockType.Type.AIR


## Concrete implementation: Sows the parameterized crop sprout on the block above.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, _normal: Vector3, world_controller: Node3D) -> void:
	inventory.consume_item(item_id, 1)
	
	var crop_coord := target_coord + Vector3i(0, 1, 0)
	var world_ctrl := world_controller as WorldController
	if is_instance_valid(world_ctrl):
		world_ctrl.set_block_globally(crop_coord, crop_block_type)

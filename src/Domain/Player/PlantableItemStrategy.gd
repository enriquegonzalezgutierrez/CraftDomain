# ==============================================================================
# Pathfile: res://src/Domain/Player/PlantableItemStrategy.gd
# Description: Concrete Domain Strategy managing agricultural crop seed planting.
#              Verifies fertile soil validity and places sprout block types above.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlantableItemStrategy
extends ItemUsageStrategy

var item_id: int
var crop_block_type: BlockType.Type


func _init(p_item_id: int = -1, p_crop_block_type: BlockType.Type = BlockType.Type.AIR) -> void:
	item_id = p_item_id
	crop_block_type = p_crop_block_type


## Evaluates if placed on top face of fertile soil with available inventory stock.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory == null or world_state == null or round(normal.y) != 1:
		return false
		
	if inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var soil_type := world_state.get_block(target_coord)
	if soil_type != BlockType.Type.GRASS and soil_type != BlockType.Type.DIRT:
		return false
		
	var crop_coord := target_coord + Vector3i(0, 1, 0)
	return world_state.get_block(crop_coord) == BlockType.Type.AIR


## Consumes seed stock and plants the crop sprout on the block above.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, _normal: Vector3, world_modifier: IWorldModifier) -> void:
	if inventory != null:
		inventory.consume_item(item_id, 1)
		
	var crop_coord := target_coord + Vector3i(0, 1, 0)
	if is_instance_valid(world_modifier):
		world_modifier.set_block_globally(crop_coord, crop_block_type)

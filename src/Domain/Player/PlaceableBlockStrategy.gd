# ==============================================================================
# Pathfile: res://src/Domain/Player/PlaceableBlockStrategy.gd
# Description: Concrete Domain Strategy managing placement of structural blocks.
#              Calculates build coordinate offsets based on surface collision normals.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name PlaceableBlockStrategy
extends ItemUsageStrategy

var item_id: int
var block_type: BlockType.Type


func _init(p_item_id: int = -1, p_block_type: BlockType.Type = BlockType.Type.AIR) -> void:
	item_id = p_item_id
	block_type = p_block_type


## Validates if the target adjacent coordinate is replaceable and inventory stock exists.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory == null or world_state == null or inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var build_coord := target_coord + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	var target_block := world_state.get_block(build_coord)
	
	return target_block == BlockType.Type.AIR or target_block == BlockType.Type.WATER


## Consumes one item unit from inventory and places the block globally in the world.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_modifier: IWorldModifier) -> void:
	if inventory != null:
		inventory.consume_item(item_id, 1)
		
	var build_coord := target_coord + Vector3i(round(normal.x), round(normal.y), round(normal.z))
	if is_instance_valid(world_modifier):
		world_modifier.set_block_globally(build_coord, block_type)

# ==============================================================================
# Pathfile: res://src/Domain/Player/SlabPlacementStrategy.gd
# Description: Concrete Domain Strategy managing placement and fusion rules
#              for half-height slab blocks, including double-slab merging.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name SlabPlacementStrategy
extends ItemUsageStrategy

var item_id: int


func _init(p_item_id: int) -> void:
	item_id = p_item_id


## Validates if there is stock and the coordinate allows slab placement or merging.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory == null or world_state == null or inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var target_block := world_state.get_block(target_coord)
	var rounded_normal := Vector3i(round(normal.x), round(normal.y), round(normal.z))
	
	if _is_slab_mergeable(target_block, rounded_normal.y):
		return true
		
	var build_coord := target_coord + rounded_normal
	var build_block := world_state.get_block(build_coord)
	return build_block == BlockType.Type.AIR or build_block == BlockType.Type.WATER


## Places or merges slabs depending on the collision face and hit location.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_modifier: IWorldModifier) -> void:
	if inventory != null:
		inventory.consume_item(item_id, 1)
		
	var target_block := world_modifier.get_block_globally(target_coord)
	var rounded_normal := Vector3i(round(normal.x), round(normal.y), round(normal.z))
	
	if _try_merge_slabs(target_block, rounded_normal.y, target_coord, world_modifier):
		return
		
	_place_adjacent_slab(target_coord, rounded_normal, world_modifier)


func _is_slab_mergeable(target_block: BlockType.Type, normal_y: int) -> bool:
	var is_bottom_merge := target_block == BlockType.Type.STONE_SLAB_BOTTOM and normal_y == 1
	var is_top_merge := target_block == BlockType.Type.STONE_SLAB_TOP and normal_y == -1
	return is_bottom_merge or is_top_merge


func _try_merge_slabs(target_block: BlockType.Type, normal_y: int, target_coord: Vector3i, world_modifier: IWorldModifier) -> bool:
	if _is_slab_mergeable(target_block, normal_y):
		world_modifier.set_block_globally(target_coord, BlockType.Type.STONE)
		return true
	return false


func _place_adjacent_slab(target_coord: Vector3i, rounded_normal: Vector3i, world_modifier: IWorldModifier) -> void:
	var build_coord := target_coord + rounded_normal
	if rounded_normal.y == 1:
		world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_BOTTOM)
	elif rounded_normal.y == -1:
		world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_TOP)
	else:
		var fraction_y := world_modifier.get_last_hit_fractional_y()
		var slab_type := BlockType.Type.STONE_SLAB_BOTTOM if fraction_y < 0.5 else BlockType.Type.STONE_SLAB_TOP
		world_modifier.set_block_globally(build_coord, slab_type)
# ==============================================================================
# Project: CraftDomain
# Description: Concrete Domain Strategy implementing the advanced placement 
#              and fusion rules for Slab blocks.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively manages target coordinate 
#   evaluation, top/bottom orientation selection, and double-slab merging.
# - Open-Closed Principle (OCP): Extends ItemUsageStrategy, allowing slabs to 
#   be placed without altering the player interaction or physics scripts.
# - Dependency Inversion Principle (DIP): Communicates strictly through the 
#   IWorldModifier abstract interface to read and write blocks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/Player/SlabPlacementStrategy.gd
# ==============================================================================
class_name SlabPlacementStrategy
extends ItemUsageStrategy

var item_id: int # Represented by ID 26 (Stone Slab)


func _init(p_item_id: int) -> void:
	item_id = p_item_id


## Concrete Implementation: Returns true if there is stock and the space is buildable or mergeable.
func can_use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_state: WorldState) -> bool:
	if inventory.get_item_total_quantity(item_id) <= 0:
		return false
		
	var target_block := world_state.get_block(target_coord)
	var rounded_normal := Vector3i(round(normal.x), round(normal.y), round(normal.z))
	
	# CASE 1: DOUBLE-SLAB MERGING (Top/Bottom fusion into a Full Block)
	# A. Clicked top face of a BOTTOM slab
	if target_block == BlockType.Type.STONE_SLAB_BOTTOM and rounded_normal.y == 1:
		return true
	# B. Clicked bottom face of a TOP slab
	if target_block == BlockType.Type.STONE_SLAB_TOP and rounded_normal.y == -1:
		return true
		
	# CASE 2: STANDARD ADJACENT PLACEMENT
	var build_coord := target_coord + rounded_normal
	var build_block := world_state.get_block(build_coord)
	
	return build_block == BlockType.Type.AIR or build_block == BlockType.Type.WATER


## Concrete Implementation: Solves orientation fractions and places or merges the slabs.
func use(_player_health: VoxelEntity, inventory: IInventory, target_coord: Vector3i, normal: Vector3, world_modifier: IWorldModifier) -> void:
	inventory.consume_item(item_id, 1)
	
	var target_block := world_modifier.get_block_globally(target_coord)
	var rounded_normal := Vector3i(round(normal.x), round(normal.y), round(normal.z))
	
	# ==========================================================================
	# MERGING TRANSACTION (Replace halves with a full solid Stone block)
	# ==========================================================================
	if target_block == BlockType.Type.STONE_SLAB_BOTTOM and rounded_normal.y == 1:
		world_modifier.set_block_globally(target_coord, BlockType.Type.STONE)
		return
		
	if target_block == BlockType.Type.STONE_SLAB_TOP and rounded_normal.y == -1:
		world_modifier.set_block_globally(target_coord, BlockType.Type.STONE)
		return
		
	# ==========================================================================
	# ADJACENT PLACEMENT TRANSACTION
	# ==========================================================================
	var build_coord := target_coord + rounded_normal
	
	if rounded_normal.y == 1:
		# Direct placement on a top face always yields a bottom slab
		world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_BOTTOM)
	elif rounded_normal.y == -1:
		# Direct placement on a bottom face always yields a top slab
		world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_TOP)
	else:
		# Side face click: Read fractional coordinate from the adapter to determine top/bottom
		var fraction_y := world_modifier.get_last_hit_fractional_y()
		if fraction_y < 0.5:
			world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_BOTTOM)
		else:
			world_modifier.set_block_globally(build_coord, BlockType.Type.STONE_SLAB_TOP)

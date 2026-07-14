# ==============================================================================
# Pathfile: res://src/Domain/World/IWorldModifier.gd
# Description: Domain interface defining the contract for modifying and reading 
#              voxel blocks, chronological timelines, and UI triggers globally. 
#              Resolves Layer Leakage and Dependency Inversion (DIP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IWorldModifier
extends RefCounted


## Abstract Contract: Modifies a block at the specified global coordinates.
func set_block_globally(_global_pos: Vector3i, _type: BlockType.Type) -> void:
	assert(false, "[IWorldModifier] set_block_globally() must be implemented.")


## Abstract Contract: Queries the block type at the specified global coordinates.
func get_block_globally(_global_pos: Vector3i) -> BlockType.Type:
	assert(false, "[IWorldModifier] get_block_globally() must be implemented.")
	return BlockType.Type.AIR


## Abstract Contract: Returns the fractional height Y coordinate [0.0 to 1.0] of 
## the last raycast collision. Used by strategies to solve top/bottom alignments.
func get_last_hit_fractional_y() -> float:
	assert(false, "[IWorldModifier] get_last_hit_fractional_y() must be implemented.")
	return 0.5


## Abstract Contract: Returns the active timeline index (0 = Present, 1 = Past).
func get_active_timeline() -> int:
	assert(false, "[IWorldModifier] get_active_timeline() must be implemented.")
	return 0


## Abstract Contract: Swaps the active chronological timeline globally.
func swap_world_timeline(_timeline: int) -> void:
	assert(false, "[IWorldModifier] swap_world_timeline() must be implemented.")


## Abstract Contract: Dispatches a request to the presentation layer to open the Hacking UI.
func open_hacking_terminal() -> void:
	assert(false, "[IWorldModifier] open_hacking_terminal() must be implemented.")

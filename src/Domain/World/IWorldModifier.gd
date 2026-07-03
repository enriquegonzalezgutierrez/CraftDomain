# ==============================================================================
# Project: CraftDomain
# Description: Domain interface defining the contract for modifying voxel blocks 
#              globally. Resolves Layer Leakage and Dependency Inversion (DIP) 
#              violations by allowing Domain strategies to interact with 
#              abstractions rather than concrete Infrastructure classes.
# SOLID COMPLIANCE: 
# - Dependency Inversion Principle (DIP): High-level domain strategies depend 
#   on this abstraction rather than concrete Infrastructure controllers.
# - Interface Segregation Principle (ISP): Declares only the block modification 
#   contract required by block-placement strategies.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IWorldModifier.gd
# ==============================================================================
class_name IWorldModifier
extends RefCounted

## Abstract Contract: Modifies a block at the specified global coordinates.
## Must be implemented by the concrete Infrastructure coordinator.
func set_block_globally(_global_pos: Vector3i, _type: BlockType.Type) -> void:
	assert(false, "[IWorldModifier] set_block_globally() must be implemented.")

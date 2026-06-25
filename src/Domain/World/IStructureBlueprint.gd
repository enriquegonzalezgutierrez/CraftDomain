# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface defining the strategic contract for any
#              procedural voxel structure or decoration. Enables strict OCP compliance
#              by decoupling construction algorithms into independent classes.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IStructureBlueprint.gd
# ==============================================================================
class_name IStructureBlueprint
extends RefCounted

## Abstract contract: Returns the unique integer identifier representing this structure.
func get_structure_id() -> int:
	assert(false, "[IStructureBlueprint] get_structure_id() must be implemented by concrete subclass.")
	return 0

## Abstract contract: Executes the voxel-by-voxel block modification algorithms
## inside the target Chunk grid at the specified coordinates.
func build_structure(_chunk: Chunk, _start_x: int, _start_z: int, _ground_y: int) -> void:
	assert(false, "[IStructureBlueprint] build_structure() must be implemented by concrete subclass.")

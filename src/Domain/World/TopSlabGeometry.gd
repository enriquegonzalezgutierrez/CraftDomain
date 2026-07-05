# ==============================================================================
# Project: CraftDomain
# Description: Concrete Voxel Geometry strategy representing a top slab block 
#              occupying the upper half of a voxel coordinate (Y: 0.5 to 1.0).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the dimensions, 
#   collision vertices, and non-distorting UV mapping for a top slab.
# - Liskov Substitution Principle (LSP): Fully satisfies the IVoxelGeometry 
#   contract signatures without alterations.
# STABILIZATION FIX:
# - Restored original physics-proven winding order for TOP and BOTTOM faces 
#   to guarantee 100% stable gravity and collision support in Godot Physics.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/TopSlabGeometry.gd
# ==============================================================================
class_name TopSlabGeometry
extends IVoxelGeometry

# Cached dictionary of collision vertices to avoid dynamic memory allocation overhead.
# WINDING ORDER RESTORATION: Reverted to the original, stable game coordinates scaled to top half.
var _vertices: Dictionary = {
	Vector3i(0, 1, 0): PackedVector3Array([Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]), # TOP
	Vector3i(0, -1, 0): PackedVector3Array([Vector3(0, 0.5, 0), Vector3(1, 0.5, 0), Vector3(1, 0.5, 1), Vector3(0, 0.5, 1)]), # BOTTOM
	Vector3i(1, 0, 0): PackedVector3Array([Vector3(1, 0.5, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0.5, 0)]), # RIGHT
	Vector3i(-1, 0, 0): PackedVector3Array([Vector3(0, 0.5, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0.5, 1)]), # LEFT
	Vector3i(0, 0, 1): PackedVector3Array([Vector3(0, 0.5, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0.5, 1)]), # FRONT
	Vector3i(0, 0, -1): PackedVector3Array([Vector3(1, 0.5, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0)])  # BACK
}


## Concrete Implementation: Returns a half-height bounding box floated to the top.
func get_aabb() -> AABB:
	return AABB(Vector3(0.0, 0.5, 0.0), Vector3(1.0, 0.5, 1.0))


## Concrete Implementation: Returns the offset, outward-facing CW vertices.
func get_face_collision_vertices(direction: Vector3i) -> PackedVector3Array:
	return _vertices.get(direction, PackedVector3Array())


## Concrete Implementation: Standardizes textures to map the upper half of 
## the texture file to the lateral faces to prevent stretching.
func get_face_uv_rect(direction: Vector3i) -> Rect2:
	if direction.y != 0:
		# Top and Bottom faces render with the full texture
		return Rect2(0.0, 0.0, 1.0, 1.0)
		
	# Side faces render only the top half of the texture [Offset Y: 0.0, Height: 0.5]
	return Rect2(0.0, 0.0, 1.0, 0.5)


## Concrete Implementation: A top slab only completely covers the block above it.
func is_face_opaque(direction: Vector3i) -> bool:
	return direction.y == 1

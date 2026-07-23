# ==============================================================================
# Pathfile: res://src/Domain/World/BottomSlabGeometry.gd
# Description: Concrete Voxel Geometry strategy representing a bottom slab block 
#              occupying the lower half of a voxel coordinate (Y: 0.0 to 0.5).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name BottomSlabGeometry
extends IVoxelGeometry

# Cached dictionary of collision vertices to avoid dynamic memory allocation overhead.
var _vertices: Dictionary = {
	Vector3i(0, 1, 0): PackedVector3Array([Vector3(0, 0.5, 1), Vector3(1, 0.5, 1), Vector3(1, 0.5, 0), Vector3(0, 0.5, 0)]), # TOP
	Vector3i(0, -1, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]), # BOTTOM
	Vector3i(1, 0, 0): PackedVector3Array([Vector3(1, 0, 1), Vector3(1, 0.5, 1), Vector3(1, 0.5, 0), Vector3(1, 0, 0)]), # RIGHT
	Vector3i(-1, 0, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0.5, 1), Vector3(0, 0, 1)]), # LEFT
	Vector3i(0, 0, 1): PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 0.5, 1), Vector3(1, 0.5, 1), Vector3(1, 0, 1)]), # FRONT
	Vector3i(0, 0, -1): PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 0.5, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0)])  # BACK
}


## Concrete Implementation: Returns a half-height bounding box aligned to the bottom.
func get_aabb() -> AABB:
	return AABB(Vector3.ZERO, Vector3(1.0, 0.5, 1.0))


## Concrete Implementation: Returns the scaled, outward-facing CW vertices.
func get_face_collision_vertices(direction: Vector3i) -> PackedVector3Array:
	return _vertices.get(direction, PackedVector3Array())


## Concrete Implementation: Standardizes textures to map the lower half of 
## the texture file to the lateral faces to prevent stretching.
func get_face_uv_rect(direction: Vector3i) -> Rect2:
	if direction.y != 0:
		# Top and Bottom faces render with the full texture
		return Rect2(0.0, 0.0, 1.0, 1.0)
		
	# Side faces render only the bottom half of the texture [Offset Y: 0.5, Height: 0.5]
	return Rect2(0.0, 0.5, 1.0, 0.5)


## Concrete Implementation: A bottom slab only completely covers the block beneath it.
func is_face_opaque(direction: Vector3i) -> bool:
	return direction.y == -1

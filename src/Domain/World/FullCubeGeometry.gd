# ==============================================================================
# Pathfile: res://src/Domain/World/FullCubeGeometry.gd
# Description: Concrete Voxel Geometry strategy representing a standard 
#              1x1x1 solid cube block.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name FullCubeGeometry
extends IVoxelGeometry

# Cached dictionary of collision vertices to avoid dynamic memory allocation overhead.
var _vertices: Dictionary = {
	Vector3i(0, 1, 0): PackedVector3Array([Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)]), # TOP
	Vector3i(0, -1, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)]), # BOTTOM
	Vector3i(1, 0, 0): PackedVector3Array([Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)]), # RIGHT
	Vector3i(-1, 0, 0): PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]), # LEFT
	Vector3i(0, 0, 1): PackedVector3Array([Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]), # FRONT
	Vector3i(0, 0, -1): PackedVector3Array([Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)])  # BACK
}


## Concrete Implementation: Returns a full 1x1x1 bounding box.
func get_aabb() -> AABB:
	return AABB(Vector3.ZERO, Vector3.ONE)


## Concrete Implementation: Returns the mathematically verified outward-facing CW vertices.
func get_face_collision_vertices(direction: Vector3i) -> PackedVector3Array:
	return _vertices.get(direction, PackedVector3Array())


## Concrete Implementation: Returns a full (0, 0, 1, 1) UV rect since the texture covers the entire face.
func get_face_uv_rect(_direction: Vector3i) -> Rect2:
	return Rect2(0.0, 0.0, 1.0, 1.0)


## Concrete Implementation: A full cube always completely covers all adjacent faces.
func is_face_opaque(_direction: Vector3i) -> bool:
	return true

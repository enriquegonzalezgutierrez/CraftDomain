# ==============================================================================
# Pathfile: res://src/Domain/World/CrossQuadGeometry.gd
# Description: Voxel Geometry strategy representing intersecting diagonal quads
#              (X-shape) used for rendering non-solid vegetation (flowers, grass).
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the vertices,
#   UV coordinate layouts, and occlusion rules for cross-quad shapes.
# - Liskov Substitution Principle (LSP): Fully implements IVoxelGeometry.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name CrossQuadGeometry
extends IVoxelGeometry

# Pre-calculated vertices for the two intersecting vertical diagonal planes
var _vertices: Dictionary = {
	Vector3i(1, 0, 1): PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0),
		Vector3(1.0, 1.0, 1.0),
		Vector3(1.0, 0.0, 1.0)
	]),
	Vector3i(-1, 0, 1): PackedVector3Array([
		Vector3(1.0, 0.0, 0.0),
		Vector3(1.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 1.0),
		Vector3(0.0, 0.0, 1.0)
	])
}


## Concrete Contract: Returns a standard bounding box for raycast selections
func get_aabb() -> AABB:
	return AABB(Vector3.ZERO, Vector3.ONE)


## Concrete Contract: Maps orthogonal directions (UP/DOWN) to diagonal vertices
## to integrate seamlessly with the cubic face loop of ChunkMesher (OCP)
func get_face_collision_vertices(direction: Vector3i) -> PackedVector3Array:
	if direction.y == 1:
		return _vertices[Vector3i(1, 0, 1)] # Diagonal A
	elif direction.y == -1:
		return _vertices[Vector3i(-1, 0, 1)] # Diagonal B
	return PackedVector3Array()


## Concrete Contract: Vegetation quads map the full texture plane
func get_face_uv_rect(_direction: Vector3i) -> Rect2:
	return Rect2(0.0, 0.0, 1.0, 1.0)


## Concrete Contract: Cross-quads are completely translucent and never block light
func is_face_opaque(_direction: Vector3i) -> bool:
	return false

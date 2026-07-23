# ==============================================================================
# Pathfile: res://src/Domain/World/IVoxelGeometry.gd
# Description: Pure Domain Interface defining geometric bounds, collision, 
#              meshing, and occlusion culling rules for voxel shapes.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name IVoxelGeometry
extends RefCounted


## Returns the physical bounding box (AABB) of this geometry shape.
## Used for player collision boundaries and bounding checks.
func get_aabb() -> AABB:
	assert(false, "[IVoxelGeometry] get_aabb() must be implemented by concrete subclass.")
	return AABB()


## Returns the custom 3D collision vertices array for a specific face (Y=1, Y=-1, etc.).
func get_face_collision_vertices(_direction: Vector3i) -> PackedVector3Array:
	assert(false, "[IVoxelGeometry] get_face_collision_vertices() must be implemented by concrete subclass.")
	return PackedVector3Array()


## Returns the UV offset and scaling rect for rendering this face without texture stretching.
func get_face_uv_rect(_direction: Vector3i) -> Rect2:
	assert(false, "[IVoxelGeometry] get_face_uv_rect() must be implemented by concrete subclass.")
	return Rect2(0, 0, 1, 1)


## Returns true if this shape completely covers the face in the given direction.
func is_face_opaque(_direction: Vector3i) -> bool:
	assert(false, "[IVoxelGeometry] is_face_opaque() must be implemented by concrete subclass.")
	return false

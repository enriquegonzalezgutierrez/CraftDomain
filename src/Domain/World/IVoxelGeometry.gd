# ==============================================================================
# Project: CraftDomain
# Description: Pure Domain Interface defining the geometric bounds, collision, 
#              meshing, and occlusion culling rules for different voxel shapes.
# SOLID COMPLIANCE:
# - Single Responsibility Principle (SRP): Exclusively defines the geometric 
#   contract, separating voxel dimensions from physics servers or rendering pipelines.
# - Open-Closed Principle (OCP): Enables adding infinite custom shapes (Slabs, 
#   Stairs, Fences, Walls) by extending this interface without modifying the 
#   meshing or interaction loops.
# - Liskov Substitution Principle (LSP): Subclasses must implement all methods, 
#   ensuring they can be polymorphically processed by the chunk meshing engine.
# WARNING RESOLUTION:
# - Prefixed unused abstract parameters with an underscore (`_direction`) to 
#   perfectly satisfy Godot's static analyzer and clear all compilation warnings.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Domain/World/IVoxelGeometry.gd
# ==============================================================================
class_name IVoxelGeometry
extends RefCounted


## Returns the physical bounding box (AABB) of this geometry shape.
## Used for player collision boundaries and bounding checks.
func get_aabb() -> AABB:
	assert(false, "[IVoxelGeometry] get_aabb() must be implemented by concrete subclass.")
	return AABB()


## Returns the custom 3D collision vertices array for a specific face (Y=1, Y=-1, etc.).
## Vertices must be arranged in Clockwise (CW) winding order for Godot's physics engine.
func get_face_collision_vertices(_direction: Vector3i) -> PackedVector3Array:
	assert(false, "[IVoxelGeometry] get_face_collision_vertices() must be implemented by concrete subclass.")
	return PackedVector3Array()


## Returns the UV offset and scaling rect for rendering this face without texture stretching.
## The Rect2 coordinates represent: (Offset_X, Offset_Y, Size_Width, Size_Height).
func get_face_uv_rect(_direction: Vector3i) -> Rect2:
	assert(false, "[IVoxelGeometry] get_face_uv_rect() must be implemented by concrete subclass.")
	return Rect2(0, 0, 1, 1)


## Returns true if this shape completely covers the face in the given direction.
## Used by the occlusion culling algorithm to determine if adjacent block faces should be hidden.
func is_face_opaque(_direction: Vector3i) -> bool:
	assert(false, "[IVoxelGeometry] is_face_opaque() must be implemented by concrete subclass.")
	return false

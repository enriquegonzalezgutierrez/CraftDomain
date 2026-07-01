# ==============================================================================
# Project: CraftDomain
# Description: Pure Infrastructure Data Carrier representing a completed
#              background generation and rendering task.
#              SOLID COMPLIANCE: SRP compliant by isolating data transfer 
#              structures into a globally registered RefCounted class.
#              OPTIMIZATION: Swapped individual block transform array with a
#              single merged collision vertices array to avoid PhysicsServer3D bottlenecks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/GeneratedChunkTask.gd
# ==============================================================================
class_name GeneratedChunkTask
extends RefCounted

var chunk: Chunk
var multimesh_data: Dictionary = {} # BlockType.Type -> PackedFloat32Array
var collision_vertices: PackedVector3Array = PackedVector3Array()
var liquid_meshes: Dictionary = {} # BlockType.Type -> ArrayMesh 
var is_rebuild: bool = false

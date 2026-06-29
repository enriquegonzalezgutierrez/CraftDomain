# ==============================================================================
# Project: CraftDomain
# Description: Pure Infrastructure Data Carrier representing a completed
#              background generation and rendering task.
#              SOLID COMPLIANCE: SRP compliant by isolating data transfer 
#              structures into a globally registered RefCounted class.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/World/GeneratedChunkTask.gd
# ==============================================================================
class_name GeneratedChunkTask
extends RefCounted

var chunk: Chunk
var multimesh_data: Dictionary = {} # BlockType.Type -> PackedFloat32Array
var collision_transforms: Array[Transform3D] = []
var liquid_meshes: Dictionary = {} # BlockType.Type -> ArrayMesh 
var is_rebuild: bool = false

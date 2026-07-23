# ==============================================================================
# Pathfile: res://src/Infrastructure/World/GeneratedChunkTask.gd
# Description: Infrastructure Data Carrier representing a completed background 
#              generation, multimesh, and pre-compiled collision shape task.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name GeneratedChunkTask
extends RefCounted

var chunk: Chunk
var multimesh_data: Dictionary = {} # BlockType.Type -> PackedFloat32Array
var collision_shape: ConcavePolygonShape3D = null # Precompiled shape resource from background thread
var liquid_meshes: Dictionary = {} # BlockType.Type -> ArrayMesh 
var is_rebuild: bool = false

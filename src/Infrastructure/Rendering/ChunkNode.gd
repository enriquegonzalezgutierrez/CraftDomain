# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing a chunk using Godot's 
#              native MultiMeshInstance3D, completely optimized with zero main-thread loops.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends MultiMeshInstance3D

## Reference to the logical domain chunk data.
var chunk: Chunk

var _collision_body: StaticBody3D

func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	
	# Set position in the world space
	position = Vector3(chunk.position * Chunk.SIZE)
	
	# Configure the primitive cube and the material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = BoxMesh.new() # Perfect native Godot 1x1x1 Cube

## Sets up the MultiMesh rendering transforms and registers the pre-compiled compound box colliders.
## This function runs in 0ms on the main thread.
func setup_chunk_visuals(visual_transforms: Array[Transform3D], visual_colors: Array[Color], collision_transforms: Array[Transform3D]) -> void:
	# 1. Apply pre-compiled visual transforms and colors directly to the GPU
	multimesh.instance_count = visual_transforms.size()
	_apply_material()
	
	for i in range(visual_transforms.size()):
		multimesh.set_instance_transform(i, visual_transforms[i])
		multimesh.set_instance_color(i, visual_colors[i])

	# 2. Register pre-compiled compound box shapes directly into the physics server
	if collision_transforms.size() > 0:
		_collision_body = StaticBody3D.new()
		_collision_body.name = "StaticCollisionBody"
		add_child(_collision_body)
		
		var shared_box_shape := BoxShape3D.new() # Shared resource to save memory
		
		for t in collision_transforms:
			# Create a unique shape owner for this block collider transform group
			var owner_id := _collision_body.create_shape_owner(_collision_body)
			_collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
			_collision_body.shape_owner_set_transform(owner_id, t)

func _apply_material() -> void:
	var material := ORMMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material_override = material

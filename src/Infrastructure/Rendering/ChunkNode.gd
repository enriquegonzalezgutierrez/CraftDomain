# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing a chunk using Godot's 
#              native MultiMeshInstance3D with high-performance compound box shape collisions.
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
func setup_chunk_visuals(collision_transforms: Array[Transform3D]) -> void:
	# 1. Gather all solid blocks and assign transforms
	var solid_coords: Array[Vector3] = []
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if BlockType.is_solid(chunk.get_block(x, y, z)):
					solid_coords.append(Vector3(x, y, z))
					
	multimesh.instance_count = solid_coords.size()
	_apply_material()
	
	for i in range(solid_coords.size()):
		var local_pos := solid_coords[i]
		var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
		var inst_transform := Transform3D(Basis(), transform_pos)
		multimesh.set_instance_transform(i, inst_transform)
		
		# Apply stylized shading variance
		var block_def := BlockLibrary.get_definition(chunk.get_block(int(local_pos.x), int(local_pos.y), int(local_pos.z)))
		var shade_noise: float = 0.9 + 0.1 * sin(local_pos.x * 1.4 + local_pos.y * 2.3 + local_pos.z * 3.7)
		multimesh.set_instance_color(i, block_def.color_top * shade_noise)

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

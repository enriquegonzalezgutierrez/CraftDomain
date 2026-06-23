# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure controller node representing a chunk using Godot's 
#              native MultiMeshInstance3D with procedural block instance shading.
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

## Updates the visible MultiMesh instances and physics collisions.
func update_mesh() -> void:
	# 1. Count how many solid blocks we need to render
	var solid_count: int = 0
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				if BlockType.is_solid(chunk.get_block(x, y, z)):
					solid_count += 1
	
	multimesh.instance_count = solid_count
	
	# Clear previous collisions
	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
		_collision_body = null
		
	if solid_count == 0:
		return
		
	_collision_body = StaticBody3D.new()
	_collision_body.name = "StaticCollisionBody"
	add_child(_collision_body)
	
	_apply_material()
	
	# 2. Populate positions, colors, and physical colliders
	var instance_index: int = 0
	var box_shape := BoxShape3D.new() # Single shape reference shared for efficiency
	
	for x in range(Chunk.SIZE):
		for y in range(Chunk.SIZE):
			for z in range(Chunk.SIZE):
				var block_type: BlockType.Type = chunk.get_block(x, y, z)
				if not BlockType.is_solid(block_type):
					continue
					
				var block_def: BlockDefinition = BlockLibrary.get_definition(block_type)
				var local_pos := Vector3(x, y, z)
				
				# Place the perfect native cube instance (offsetting by 0.5 to center it)
				var transform_pos := local_pos + Vector3(0.5, 0.5, 0.5)
				var inst_transform := Transform3D(Basis(), transform_pos)
				multimesh.set_instance_transform(instance_index, inst_transform)
				
				# Apply a deterministic shading noise based on spatial coordinates
				# This acts as a procedural pattern that makes individual blocks highly distinct.
				var shade_noise: float = 0.9 + 0.1 * sin(float(x) * 1.4 + float(y) * 2.3 + float(z) * 3.7)
				var shaded_color := block_def.color_top * shade_noise
				multimesh.set_instance_color(instance_index, shaded_color)
				
				# 3. Add corresponding physics collider box
				var collision_shape := CollisionShape3D.new()
				collision_shape.shape = box_shape
				collision_shape.position = transform_pos
				_collision_body.add_child(collision_shape)
				
				instance_index += 1

func _apply_material() -> void:
	var material := ORMMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material_override = material

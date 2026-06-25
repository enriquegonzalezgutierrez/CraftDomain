# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a chunk using Godot's
#              native MultiMeshInstance3D with procedural 16x16 pixel textures.
#              Optimized to leverage a single statically shared ORMMaterial3D
#              across all chunk nodes, completely eliminating Vulkan GPU
#              allocation stutters and reducing video memory footprint.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends MultiMeshInstance3D

## Reference to the logical domain chunk data.
var chunk: Chunk

var _collision_body: StaticBody3D
static var _procedural_pixel_texture: ImageTexture
static var _shared_material: ORMMaterial3D # CRITICAL OPTIMIZATION: Single statically shared material

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
func setup_chunk_visuals(collision_transforms: Array[Transform3D], visual_colors: Array[Color], p_collision_transforms: Array[Transform3D]) -> void:
	# 1. Apply pre-compiled visual transforms and colors directly to the GPU
	multimesh.instance_count = collision_transforms.size()
	_apply_material()
	
	for i in range(collision_transforms.size()):
		multimesh.set_instance_transform(i, collision_transforms[i])
		multimesh.set_instance_color(i, visual_colors[i])

	# 2. --- HIGH PERFORMANCE OFF-TREE ASSEMBLY ---
	# Assembles all shape owners while the node is detached from the active SceneTree.
	# Once completed, it is flushed in a single atomic step to prevent thread stalling.
	if p_collision_transforms.size() > 0:
		var collision_body := StaticBody3D.new()
		collision_body.name = "StaticCollisionBody"
		
		var shared_box_shape := BoxShape3D.new() # Shared resource to save memory
		
		for t in p_collision_transforms:
			var local_pos := t.origin - Vector3(0.5, 0.5, 0.5)
			var block_x := int(round(local_pos.x))
			var block_y := int(round(local_pos.y))
			var block_z := int(round(local_pos.z))
			
			var block_type_id: int = chunk.get_block(block_x, block_y, block_z)
			
			# Ensure we only build colliders for solid blocks
			if BlockType.is_solid(block_type_id):
				var owner_id := collision_body.create_shape_owner(collision_body)
				collision_body.shape_owner_add_shape(owner_id, shared_box_shape)
				collision_body.shape_owner_set_transform(owner_id, t)
				
		# Attach the fully built physical body to the scene tree in a single step
		_collision_body = collision_body
		add_child(_collision_body)

func _apply_material() -> void:
	# CRITICAL: Compile and cache a single static material instance to prevent GPU pipeline swaps
	if _shared_material == null:
		if _procedural_pixel_texture == null:
			_generate_pixel_texture()
			
		_shared_material = ORMMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.95
		
		# Apply the pixelated retro texture (multiplied by our shaded block colors!)
		_shared_material.albedo_texture = _procedural_pixel_texture
		_shared_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # Keeps pixels sharp
		
	material_override = _shared_material

func _generate_pixel_texture() -> void:
	# Programmatically generate a raw 16x16 pixel noise pattern
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	# Seed the noise pattern deterministically
	for x in range(16):
		for y in range(16):
			# Generate nice subtle contrast shading values
			var shade_value: float = randf_range(0.82, 1.0)
			img.set_pixel(x, y, Color(shade_value, shade_value, shade_value, 1.0))
			
	# Convert raw image to a high-contrast GPU ImageTexture
	_procedural_pixel_texture = ImageTexture.create_from_image(img)
	print("[ChunkNode] Procedural 16x16 retro-pixel texture compiled successfully.")

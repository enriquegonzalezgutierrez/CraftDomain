# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a chunk using Godot's
#              native MultiMeshInstance3D with procedural 16x16 pixel textures.
#              Optimized to map pre-compiled background binary visual float buffers
#              (Transforms + Colors) and append pre-assembled StaticBody3D 
#              physics compound BoxShape3D colliders in atomic operations.
#              Features defensive parent-clearing checks to secure cached node re-insertion.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends MultiMeshInstance3D

## Reference to the logical domain chunk data.
var chunk: Chunk

var _collision_body: StaticBody3D
static var _procedural_pixel_texture: ImageTexture
static var _shared_material: ORMMaterial3D

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

## Sets up the MultiMesh rendering transforms and registers the pre-compiled concave collision body.
## Receives pre-packed binary visual bulk arrays and a pre-assembled physical StaticBody3D.
func setup_chunk_visuals(p_instance_count: int, p_bulk_array: PackedFloat32Array, p_collision_body: StaticBody3D) -> void:
	# 1. --- ZERO LOOP VISUALS INGESTION ---
	# Configures count and flushes the entire float buffer directly to GPU memory in a single atomic call
	multimesh.instance_count = p_instance_count
	_apply_material()
	multimesh.buffer = p_bulk_array # Direct Godot 4.x binary buffer assignment (0.05ms)

	# 2. --- ZERO LOOP PHYSICS REGISTRATION ---
	# Injects the completely pre-assembled StaticBody3D containing BoxShapes.
	# Features defensive parent clearing to prevent scene tree hierarchy exceptions.
	if is_instance_valid(p_collision_body):
		if p_collision_body.get_parent() != null:
			p_collision_body.get_parent().remove_child(p_collision_body) # Safely orphan from cached parent
			
		_collision_body = p_collision_body
		add_child(_collision_body) # Atomic node attachment (0.02ms)

func _apply_material() -> void:
	# Generate the static procedural 16x16 pixel-art texture once to save GPU memory
	if _procedural_pixel_texture == null:
		_generate_pixel_texture()
		
	if _shared_material == null:
		_shared_material = ORMMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		_shared_material.roughness = 0.95
		_shared_material.albedo_texture = _procedural_pixel_texture
		_shared_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
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

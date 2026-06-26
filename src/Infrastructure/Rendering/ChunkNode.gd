# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a chunk using Godot's
#              native MultiMeshInstance3D with procedural 16x16 pixel textures.
#              UPDATED: Reduced material roughness to 0.65 to enable high-end 
#              SDFGI light bounces and SSR reflections for that "RTX" look.
#              FIXED: Recreates the MultiMesh object entirely inside setup_chunk_visuals()
#              to force Godot to flush GPU memory and correctly draw newly placed blocks!
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

## Sets up the MultiMesh rendering transforms and registers the pre-compiled concave collision body.
## FIXED: Swaps the MultiMesh object dynamically to force Godot's GPU renderer to update instances!
func setup_chunk_visuals(p_instance_count: int, p_bulk_array: PackedFloat32Array, p_collision_body: StaticBody3D) -> void:
	# 1. --- FORCE GPU BUFFER RE-ALLOCATION ---
	# Swapping the MultiMesh object entirely forces Godot 4 to flush and redraw
	var new_mm := MultiMesh.new()
	new_mm.transform_format = MultiMesh.TRANSFORM_3D
	new_mm.use_colors = true
	new_mm.mesh = BoxMesh.new() # Native 1x1x1 Cube
	
	new_mm.instance_count = p_instance_count
	new_mm.buffer = p_bulk_array
	
	# Atomic reference swap (0.01ms)
	multimesh = new_mm
	_apply_material()

	# 2. --- ZERO LOOP PHYSICS REGISTRATION ---
	if is_instance_valid(p_collision_body):
		if p_collision_body.get_parent() != null:
			p_collision_body.get_parent().remove_child(p_collision_body) # Safely orphan from cached parent
			
		_collision_body = p_collision_body
		add_child(_collision_body) # Atomic node attachment

func _apply_material() -> void:
	# Generate the static procedural 16x16 pixel-art texture once to save GPU memory
	if _procedural_pixel_texture == null:
		_generate_pixel_texture()
		
	if _shared_material == null:
		_shared_material = ORMMaterial3D.new()
		_shared_material.vertex_color_use_as_albedo = true
		
		# UPGRADE: Reduced roughness to 0.65 to enable beautiful Godot 4 SDFGI and SSR bounces!
		_shared_material.roughness = 0.65 
		
		_shared_material.albedo_texture = _procedural_pixel_texture
		_shared_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	material_override = _shared_material

func _generate_pixel_texture() -> void:
	# Programmatically generate a raw 16x16 pixel noise pattern
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	
	for x in range(16):
		for y in range(16):
			var shade_value: float = randf_range(0.82, 1.0)
			img.set_pixel(x, y, Color(shade_value, shade_value, shade_value, 1.0))
			
	_procedural_pixel_texture = ImageTexture.create_from_image(img)
	print("[ChunkNode] Procedural 16x16 retro-pixel texture compiled successfully.")

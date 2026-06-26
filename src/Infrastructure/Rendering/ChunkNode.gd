# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a chunk. Upgraded from
#              a single MultiMesh to a Node3D container that dynamically manages
#              individual MultiMeshInstance3D nodes per BlockType.
#              SOLID COMPLIANCE: Adheres to OCP and SRP by isolating material 
#              and rendering logic from the physical chunk data.
#              FIXED: Implemented a custom GPU Voxel Triplanar Shader to blend 
#              texture transparency channels with base procedural colors. This
#              completely eliminates AI-generated black pixel artifacts on solid blocks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data.
var chunk: Chunk

## Collision body reference
var _collision_body: StaticBody3D

## Active registered MultiMeshInstance3D children: BlockType.Type -> MultiMeshInstance3D
var _multimeshes: Dictionary = {}

## Static cache of materials and textures to save GPU memory across all chunks
static var _materials_cache: Dictionary = {}
static var _loaded_textures: Dictionary = {}
static var _textures_preloaded: bool = false

## Static reference to our custom blending shader
static var _triplanar_shader: Shader

## Base directory where user custom textures are stored
const TEXTURE_DIR := "res://assets/textures/"

## File names mapping for custom PBR albedo textures
const TEXTURE_MAP = {
	BlockType.Type.STONE: "stone.png",
	BlockType.Type.DIRT: "dirt.png",
	BlockType.Type.GRASS: "grass_top.png",
	BlockType.Type.WOOD: "wood.png",
	BlockType.Type.LEAVES: "leaves.png",
	BlockType.Type.SAND: "sand.png",
	BlockType.Type.RED_SAND: "red_sand.png"
}

func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	
	# Set position in the world space
	position = Vector3(chunk.position * Chunk.SIZE)
	
	# Pre-load textures instantly on the first chunk init to avoid mid-game physics lag
	_preload_all_textures()

## Static Preloader: Reads high-res files from disk once on application start
static func _preload_all_textures() -> void:
	if _textures_preloaded:
		return
	_textures_preloaded = true
	
	print("[ChunkNode] Pre-loading custom textures into GPU memory to prevent physics lag...")
	for block_type in TEXTURE_MAP.keys():
		var file_path = TEXTURE_DIR + TEXTURE_MAP[block_type]
		if FileAccess.file_exists(file_path):
			var tex = load(file_path)
			if tex is Texture2D:
				_loaded_textures[block_type] = tex
				print("  -> Successfully cached: ", TEXTURE_MAP[block_type], " (", tex.get_width(), "x", tex.get_height(), ")")

## Compiles and caches our custom voxel shader to blend texture alpha gaps with solid colors
static func _get_triplanar_shader() -> Shader:
	if _triplanar_shader == null:
		_triplanar_shader = Shader.new()
		_triplanar_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
		
		uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
		uniform vec4 block_color : source_color;
		uniform float roughness_val : hint_range(0.0, 1.0) = 0.75;
		
		varying vec3 power_normal;
		varying vec3 triplanar_pos;
		
		void vertex() {
			// Compute razor-sharp triplanar blending weights
			power_normal = pow(abs(NORMAL), vec3(150.0));
			power_normal /= (power_normal.x + power_normal.y + power_normal.z);
			triplanar_pos = VERTEX;
		}
		
		void fragment() {
			// Project texture onto 3 coordinate planes
			vec4 col_x = texture(albedo_texture, triplanar_pos.zy);
			vec4 col_y = texture(albedo_texture, triplanar_pos.xz);
			vec4 col_z = texture(albedo_texture, triplanar_pos.xy);
			
			// Blend based on normal weights
			vec4 tex_color = col_x * power_normal.x + col_y * power_normal.y + col_z * power_normal.z;
			
			// --- ALPHA BLENDING FIX ---
			// Mixes the solid base block color under any transparent texture pixel, 
			// completely preventing transparent cutouts from rendering as black.
			ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
			ROUGHNESS = roughness_val;
		}
		"""
	return _triplanar_shader

## Configures the segmented MultiMeshes and registers the physics body.
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D) -> void:
	# 1. Clear old visual MultiMeshes if they exist
	for mesh_instance in _multimeshes.values():
		if is_instance_valid(mesh_instance):
			mesh_instance.queue_free()
	_multimeshes.clear()
	
	# 2. Re-create a visual MultiMeshInstance3D for each BlockType present in the chunk
	for block_type in p_multimesh_data.keys():
		var transforms: Array = p_multimesh_data[block_type]
		if transforms.size() == 0:
			continue
			
		var mm_instance := MultiMeshInstance3D.new()
		mm_instance.name = "MM_" + BlockType.Type.keys()[block_type]
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false 
		mm.mesh = BoxMesh.new() # Native 1x1x1 Cube
		mm.instance_count = transforms.size()
		
		# Pack transforms into the float buffer
		var bulk_array := PackedFloat32Array()
		bulk_array.resize(transforms.size() * 12)
		
		for i in range(transforms.size()):
			var t: Transform3D = transforms[i]
			var offset := i * 12
			bulk_array[offset + 0] = t.basis.x.x
			bulk_array[offset + 1] = t.basis.y.x
			bulk_array[offset + 2] = t.basis.z.x
			bulk_array[offset + 3] = t.origin.x
			bulk_array[offset + 4] = t.basis.x.y
			bulk_array[offset + 5] = t.basis.y.y
			bulk_array[offset + 6] = t.basis.z.y
			bulk_array[offset + 7] = t.origin.y
			bulk_array[offset + 8] = t.basis.x.z
			bulk_array[offset + 9] = t.basis.y.z
			bulk_array[offset + 10] = t.basis.z.z
			bulk_array[offset + 11] = t.origin.z
			
		mm.buffer = bulk_array
		mm_instance.multimesh = mm
		
		# Apply specialized material
		mm_instance.material_override = _get_material_for_block(block_type)
		
		add_child(mm_instance)
		_multimeshes[block_type] = mm_instance

	# 3. Register physical Concave Collision body (Main-Thread Sync)
	if is_instance_valid(_collision_body):
		if _collision_body.get_parent() == self:
			remove_child(_collision_body)
		_collision_body.queue_free()
		_collision_body = null
		
	if is_instance_valid(p_collision_body):
		_collision_body = p_collision_body
		add_child(_collision_body)

## Generates or retrieves a cached material with smart PBR features
func _get_material_for_block(block_type: BlockType.Type) -> Material:
	if _materials_cache.has(block_type):
		return _materials_cache[block_type]
		
	var def := BlockLibrary.get_definition(block_type)
	
	# Water
	if block_type == BlockType.Type.WATER:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.12, 0.45, 0.85, 0.65) 
		mat.roughness = 0.05 
		mat.metallic = 0.1
		_materials_cache[block_type] = mat
		return mat
	
	# Lava
	elif block_type == BlockType.Type.LAVA:
		var mat := ORMMaterial3D.new()
		mat.albedo_color = def.color_top
		mat.roughness = 0.9
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0) 
		mat.emission_energy_multiplier = 1.8
		_materials_cache[block_type] = mat
		return mat
		
	# Clouds & Ice
	elif block_type == BlockType.Type.CLOUD or block_type == BlockType.Type.ICE:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.4
		_materials_cache[block_type] = mat
		return mat
		
	# Standard blocks (Solid & Leaves)
	else:
		var has_custom_texture := false
		if _loaded_textures.has(block_type):
			var tex: Texture2D = _loaded_textures[block_type]
			has_custom_texture = true
			
			# SPECIAL HANDLING FOR LEAVES: Keep them transparent with standard alpha scissor
			if block_type == BlockType.Type.LEAVES:
				var mat := ORMMaterial3D.new()
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				mat.albedo_texture = tex
				mat.uv1_triplanar = true
				mat.uv1_triplanar_sharpness = 150.0
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mat.alpha_scissor_threshold = 0.5
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				_materials_cache[block_type] = mat
				return mat
			
			# SOLID BLOCKS (Stone, Dirt, Wood, Sand, Red Sand)
			# Apply our custom GPU Blending Shader to safely replace alpha black holes with base colors
			else:
				var mat := ShaderMaterial.new()
				mat.shader = _get_triplanar_shader()
				mat.set_shader_parameter("albedo_texture", tex)
				mat.set_shader_parameter("block_color", def.color_top)
				mat.set_shader_parameter("roughness_val", 0.75)
				_materials_cache[block_type] = mat
				return mat
					
		if not has_custom_texture:
			var mat := ORMMaterial3D.new()
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mat.albedo_color = def.color_top
			mat.roughness = 0.7 
			_materials_cache[block_type] = mat
			return mat
			
	return null

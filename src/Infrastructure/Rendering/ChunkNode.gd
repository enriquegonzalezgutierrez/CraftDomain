# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a chunk. Upgraded from
#              a single MultiMesh to a Node3D container that dynamically manages
#              individual MultiMeshInstance3D nodes per BlockType.
#              SOLID COMPLIANCE: Adheres to OCP and SRP by isolating material 
#              and rendering logic from the physical chunk data.
#              UPDATED: Added a friendly Format Analyzer helper inside the static
#              preload log to print human-readable Vulkan/OpenGL texture formats.
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

## Static references to our custom PBR shaders (SRP compliant)
static var _triplanar_shader: Shader
static var _leaves_wind_shader: Shader

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

## Static Preloader with Smart Diagnostic Logging (OCP compliant)
static func _preload_all_textures() -> void:
	if _textures_preloaded:
		return
	_textures_preloaded = true
	
	print("\n[ChunkNode] ========================================================")
	print("[ChunkNode] STATIC BOOTLOADER: Pre-loading custom textures...")
	
	for block_type in TEXTURE_MAP.keys():
		var file_path = TEXTURE_DIR + TEXTURE_MAP[block_type]
		if FileAccess.file_exists(file_path):
			var tex = load(file_path)
			if tex is Texture2D:
				_loaded_textures[block_type] = tex
				
				# Get raw image to analyze the import compression format
				var img: Image = tex.get_image()
				var fmt_name := "Unknown"
				var is_normal_map := false
				
				if img != null:
					var format: Image.Format = img.get_format()
					fmt_name = _get_friendly_format_name(format)
					is_normal_map = (format == Image.FORMAT_RG8 or format == Image.FORMAT_RGTC_RG)
				
				print("  -> CACHED SUCCESS: '", TEXTURE_MAP[block_type], "' (", tex.get_width(), "x", tex.get_height(), ") | Format: ", fmt_name)
				
				if is_normal_map:
					print("     [WARNING] '", TEXTURE_MAP[block_type], "' is imported as a NormalMap instead of a Texture2D!")
					print("     [WARNING] To fix this: Select '", TEXTURE_MAP[block_type], "' in your FileSystem dock, go to the Import tab next to Scene, change 'Import As' to 'Texture2D', and click Reimport.")
			else:
				print("  -> [ERROR] File exists but is not a valid Texture2D: ", file_path)
		else:
			print("  -> Fallback Active: '", TEXTURE_MAP[block_type], "' is missing on disk. Using procedural colors.")
			
	print("[ChunkNode] ========================================================\n")

## Helper to translate Godot's raw image formats into friendly human-readable strings
static func _get_friendly_format_name(format: Image.Format) -> String:
	match format:
		Image.FORMAT_L8: return "L8 (Grayscale)"
		Image.FORMAT_LA8: return "LA8 (Grayscale with Alpha)"
		Image.FORMAT_R8: return "R8 (Red Channel)"
		Image.FORMAT_RG8: return "RG8 (NORMAL MAP - Uncompressed)"
		Image.FORMAT_RGB8: return "RGB8 (Classic Color)"
		Image.FORMAT_RGBA8: return "RGBA8 (Vibrant Color with Alpha)"
		Image.FORMAT_DXT1: return "DXT1 (Compressed - No Alpha)"
		Image.FORMAT_DXT5: return "DXT5 (Compressed - With Alpha)"
		Image.FORMAT_RGTC_R: return "RGTC_R"
		Image.FORMAT_RGTC_RG: return "RGTC_RG (NORMAL MAP - Compressed BC5)"
		_: return "Other (" + str(format) + ")"

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
			power_normal = pow(abs(NORMAL), vec3(150.0));
			power_normal /= (power_normal.x + power_normal.y + power_normal.z);
			triplanar_pos = VERTEX;
		}
		
		void fragment() {
			vec4 col_x = texture(albedo_texture, triplanar_pos.zy);
			vec4 col_y = texture(albedo_texture, triplanar_pos.xz);
			vec4 col_z = texture(albedo_texture, triplanar_pos.xy);
			
			vec4 tex_color = col_x * power_normal.x + col_y * power_normal.y + col_z * power_normal.z;
			
			ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
			ROUGHNESS = roughness_val;
		}
		"""
	return _triplanar_shader

## Compiles and caches our custom leaves shader with wind-sway and organic rounding
static func _get_leaves_wind_shader() -> Shader:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = Shader.new()
		_leaves_wind_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
		
		uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
		uniform vec4 block_color : source_color;
		uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
		
		varying vec3 power_normal;
		varying vec3 triplanar_pos;
		
		void vertex() {
			power_normal = pow(abs(NORMAL), vec3(150.0));
			power_normal /= (power_normal.x + power_normal.y + power_normal.z);
			triplanar_pos = VERTEX;
			
			// 1. ORGANIC VOXEL FLUFFINESS
			float round_wave = sin(TIME * 2.0 + VERTEX.x * 2.5 + VERTEX.y * 3.5) * 0.05;
			VERTEX.xyz += NORMAL * round_wave;
			
			// 2. WIND SWAY
			float wind_x = sin(TIME * 2.2 + VERTEX.x * 3.0 + VERTEX.y * 2.0) * 0.04;
			float wind_z = cos(TIME * 1.8 + VERTEX.z * 2.5 + VERTEX.y * 3.0) * 0.03;
			VERTEX.x += wind_x;
			VERTEX.z += wind_z;
		}
		
		void fragment() {
			vec4 col_x = texture(albedo_texture, triplanar_pos.zy);
			vec4 col_y = texture(albedo_texture, triplanar_pos.xz);
			vec4 col_z = texture(albedo_texture, triplanar_pos.xy);
			
			vec4 tex_color = col_x * power_normal.x + col_y * power_normal.y + col_z * power_normal.z;
			
			// Alpha Scissor transparent cutout for leaves
			if (tex_color.a < 0.4) {
				discard;
			}
			
			ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
			ROUGHNESS = roughness_val;
		}
		"""
	return _leaves_wind_shader

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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat
		
	# Clouds & Ice
	elif block_type == BlockType.Type.CLOUD or block_type == BlockType.Type.ICE:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.4
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat
		
	# Standard blocks (Solid & Leaves)
	else:
		var has_custom_texture := false
		if _loaded_textures.has(block_type):
			var tex: Texture2D = _loaded_textures[block_type]
			has_custom_texture = true
			
			# SPECIAL FOLIAGE SHADER: Applies vertex waving and rounds square block corners
			if block_type == BlockType.Type.LEAVES:
				var mat := ShaderMaterial.new()
				mat.shader = _get_leaves_wind_shader()
				mat.set_shader_parameter("albedo_texture", tex)
				mat.set_shader_parameter("block_color", def.color_top)
				mat.set_shader_parameter("roughness_val", 0.85)
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

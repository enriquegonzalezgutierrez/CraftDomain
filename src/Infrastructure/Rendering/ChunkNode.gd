# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a single chunk.
#              Manages individual MultiMeshInstance3D nodes per BlockType to 
#              support customized material shading (PBR, Water, Lava, and Wind-Sway).
#              PERFORMANCE UPGRADE: 
#              - Accepts pre-compiled PackedFloat32Array buffers directly from 
#                background threads to achieve zero-cost Main Thread instantiation.
#              - Triplanar Shaders optimized from 3 texture reads down to exactly 
#                1 texture read per pixel, vastly increasing GPU fill-rate!
#              FIX: Resolved Integer Division warning by casting division explicitly.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data.
var chunk: Chunk

## Collision body reference
var _collision_body: StaticBody3D

## Active registered MultiMeshInstance3D and MeshInstance3D children: BlockType.Type -> Node
var _multimeshes: Dictionary = {}

## Static cache of materials and textures to save GPU memory across all chunks
static var _materials_cache: Dictionary = {}
static var _loaded_textures: Dictionary = {}
static var _textures_preloaded: bool = false

## Static references to custom PBR shaders
static var _triplanar_shader: Shader
static var _leaves_wind_shader: Shader

## Base directory where user custom textures are stored
const TEXTURE_DIR := "res://assets/textures/"

## File names mapping for custom albedo textures
const TEXTURE_MAP = {
	BlockType.Type.STONE: "stone.png",
	BlockType.Type.DIRT: "dirt.png",
	BlockType.Type.GRASS: "grass_top.png",
	BlockType.Type.WOOD: "wood.png",
	BlockType.Type.LEAVES: "leaves.png",
	BlockType.Type.SAND: "sand.png",
	BlockType.Type.RED_SAND: "red_sand.png",
	BlockType.Type.NEON_MAGENTA: "sakura_leaves.png"
}

func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	
	# Set position in the world space
	position = Vector3(chunk.position * Chunk.SIZE)
	_preload_all_textures()

## Static Preloader with Smart Diagnostic Logging
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
			else:
				print("  -> [ERROR] File exists but is not a valid Texture2D: ", file_path)
		else:
			print("  -> Fallback Active: '", TEXTURE_MAP[block_type], "' is missing on disk. Using procedural colors.")
			
	print("[ChunkNode] ========================================================\n")

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
## OPTIMIZED: 1 Texture read per pixel instead of 3!
static func _get_triplanar_shader() -> Shader:
	if _triplanar_shader == null:
		_triplanar_shader = Shader.new()
		_triplanar_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
		
		uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
		uniform vec4 block_color : source_color;
		uniform float roughness_val : hint_range(0.0, 1.0) = 0.75;
		
		varying vec3 triplanar_pos;
		
		void vertex() {
			triplanar_pos = VERTEX;
		}
		
		void fragment() {
			vec3 abs_n = abs(NORMAL);
			vec2 uv = triplanar_pos.xy;
			
			// Extract correct UV map based on box normal facing direction (Single read!)
			if (abs_n.x > 0.5) {
				uv = triplanar_pos.zy;
			} else if (abs_n.y > 0.5) {
				uv = triplanar_pos.xz;
			}
			
			vec4 tex_color = texture(albedo_texture, uv);
			
			ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
			ROUGHNESS = roughness_val;
		}
		"""
	return _triplanar_shader

## Compiles and caches our custom leaves shader with wind-sway and organic rounding
## OPTIMIZED: 1 Texture read per pixel instead of 3!
static func _get_leaves_wind_shader() -> Shader:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = Shader.new()
		_leaves_wind_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
		
		uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
		uniform vec4 block_color : source_color;
		uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
		
		varying vec3 triplanar_pos;
		
		void vertex() {
			triplanar_pos = VERTEX;
			
			// 1. ORGANIC VOXEL FLUFFINESS
			float round_wave = sin(TIME * 2.0 + VERTEX.x * 2.5 + VERTEX.y * 3.5) * 0.05;
			VERTEX.xyz += NORMAL * round_wave;
			
			// 2. WIND SWAY
			VERTEX.x += sin(TIME * 1.5 + VERTEX.y) * 0.08;
		}
		
		void fragment() {
			vec3 abs_n = abs(NORMAL);
			vec2 uv = triplanar_pos.xy;
			
			// Extract correct UV map based on box normal facing direction (Single read!)
			if (abs_n.x > 0.5) {
				uv = triplanar_pos.zy;
			} else if (abs_n.y > 0.5) {
				uv = triplanar_pos.xz;
			}
			
			vec4 tex_color = texture(albedo_texture, uv);
			
			if (tex_color.a < 0.4) {
				discard;
			}
			
			ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
			ROUGHNESS = roughness_val;
		}
		"""
	return _leaves_wind_shader

## Configures the segmented MultiMeshes and registers the physics body.
## OPTIMIZED: Directly injects the pre-compiled PackedFloat32Array from the background thread.
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_liquid_meshes: Dictionary = {}) -> void:
	# 1. Clear old visual nodes if they exist
	for node in _multimeshes.values():
		if is_instance_valid(node):
			node.queue_free()
	_multimeshes.clear()
	
	# 2. Re-create a visual MultiMeshInstance3D for terrain blocks
	for block_type in p_multimesh_data.keys():
		var bulk_array: PackedFloat32Array = p_multimesh_data[block_type]
		
		# FIX: Safe integer division casting to resolve GDScript warning
		var instance_count: int = int(bulk_array.size() / 12.0)
		
		if instance_count == 0:
			continue
			
		var mm_instance := MultiMeshInstance3D.new()
		mm_instance.name = "MM_" + BlockType.Type.keys()[block_type]
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = false 
		mm.mesh = BoxMesh.new() 
		mm.instance_count = instance_count
		mm.buffer = bulk_array # Direct instantaneous zero-cost assignment!
		
		mm_instance.multimesh = mm
		mm_instance.material_override = _get_material_for_block(block_type)
		
		add_child(mm_instance)
		_multimeshes[block_type] = mm_instance

	# 3. HYBRID ADDITION: Create continuous MeshInstance3D nodes for liquids!
	for block_type in p_liquid_meshes.keys():
		var mesh: ArrayMesh = p_liquid_meshes[block_type]
		if mesh == null:
			continue
			
		var mi := MeshInstance3D.new()
		mi.name = "Liquid_" + BlockType.Type.keys()[block_type]
		mi.mesh = mesh
		mi.material_override = _get_material_for_block(block_type)
		
		add_child(mi)
		_multimeshes[block_type] = mi # Safe registration for unified unloads!

	# 4. Register physical Concave Collision body (Main-Thread Sync)
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
		mat.albedo_color = Color(0.05, 0.35, 0.82, 0.84) 
		mat.roughness = 0.08 
		mat.metallic = 0.15
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
			
			# SPECIAL FOLIAGE SHADER
			if block_type == BlockType.Type.LEAVES or block_type == BlockType.Type.NEON_MAGENTA:
				var mat := ShaderMaterial.new()
				mat.shader = _get_leaves_wind_shader()
				mat.set_shader_parameter("albedo_texture", tex)
				mat.set_shader_parameter("block_color", def.color_top)
				mat.set_shader_parameter("roughness_val", 0.85)
				_materials_cache[block_type] = mat
				return mat
			
			# SOLID BLOCKS
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

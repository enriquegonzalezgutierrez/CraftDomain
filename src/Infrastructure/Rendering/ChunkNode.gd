# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a single chunk in 3D.
#              Manages discrete MultiMeshInstance3D and MeshInstance3D nodes 
#              per active BlockType to apply custom materials efficiently.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Handles chunk mesh assembly 
#                and material binding, delegating shader calculations to external files.
#              - Open-Closed Principle (OCP): Loads compiled shaders from external
#                resources.
#              TEXTURE OVERHAUL UPGRADE:
#              - Expanded `TEXTURE_MAP` to include snow, ice, mud, lava, and birch bark.
#              - Configured custom emission maps for textured Lava and translucency 
#                parameters for textured Ice/Glass blocks.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data.
var chunk: Chunk

## Collision body reference.
var _collision_body: StaticBody3D

## Active registered MultiMeshInstance3D and MeshInstance3D children: BlockType.Type -> Node
var _multimeshes: Dictionary = {}

## Static cache of compiled materials and loaded textures to save GPU memory.
static var _materials_cache: Dictionary = {}
static var _loaded_textures: Dictionary = {}
static var _textures_preloaded: bool = false

## Shared geometry cache (Flyweight Pattern)
static var _shared_box_mesh: BoxMesh = null

## Static references to compiled Shader resources.
static var _triplanar_shader: Shader
static var _leaves_wind_shader: Shader

## Base directory where custom texture assets are stored.
const TEXTURE_DIR := "res://assets/textures/"

## File names mapping for custom block albedo textures.
## UPGRADED: Expanded to support the 5 new custom tileable pixel-art textures.
const TEXTURE_MAP = {
	BlockType.Type.STONE: "stone.png",
	BlockType.Type.DIRT: "dirt.png",
	BlockType.Type.GRASS: "grass_top.png",
	BlockType.Type.WOOD: "wood.png",
	BlockType.Type.LEAVES: "leaves.png",
	BlockType.Type.SAND: "sand.png",
	BlockType.Type.RED_SAND: "red_sand.png",
	BlockType.Type.NEON_MAGENTA: "sakura_leaves.png",
	BlockType.Type.COAL_ORE: "coal_ore.png",
	BlockType.Type.BRICKS: "bricks.png",
	BlockType.Type.GLASS: "glass.png",
	
	# New textured overhaul blocks
	BlockType.Type.SNOW: "snow.png",
	BlockType.Type.ICE: "ice.png",
	BlockType.Type.MUD: "mud.png",
	BlockType.Type.LAVA: "lava.png",
	BlockType.Type.BIRCH_LOG: "birch_log.png"
}


func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	
	# Position in 3D grid space
	position = Vector3(chunk.position * Chunk.SIZE)
	_preload_all_textures()


## Static texture caching to prevent CPU execution stalls during real-time generation.
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
				var img: Image = tex.get_image()
				var fmt_name := "Unknown"
				
				if img != null:
					var format: Image.Format = img.get_format()
					fmt_name = _get_friendly_format_name(format)
					
				print("  -> CACHED SUCCESS: '", TEXTURE_MAP[block_type], "' (", tex.get_width(), "x", tex.get_height(), ") | Format: ", fmt_name)
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


## Lazy loading getter for the shared static BoxMesh instance.
static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
	return _shared_box_mesh


## Loads and returns the compiled triplanar shader resource.
static func _get_triplanar_shader() -> Shader:
	if _triplanar_shader == null:
		_triplanar_shader = load("res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader")
	return _triplanar_shader


## Loads and returns the compiled wind-sway foliage shader resource.
static func _get_leaves_wind_shader() -> Shader:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader")
	return _leaves_wind_shader


## Public Gaze API: Checks if the chunk node possesses an active collision body.
func has_collision_body() -> bool:
	return is_instance_valid(_collision_body)


## Dynamic Physics LOD API: Injects and registers a static collision body directly
func set_collision_body(p_collision_body: StaticBody3D) -> void:
	if is_instance_valid(_collision_body):
		if _collision_body.get_parent() == self:
			remove_child(_collision_body)
		_collision_body.queue_free()
		
	_collision_body = p_collision_body
	if is_instance_valid(_collision_body):
		add_child(_collision_body)


## Configures the segmented MultiMeshes and registers the physics collision body.
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_liquid_meshes: Dictionary = {}) -> void:
	var active_types: Dictionary = {}
	
	# 1. Update/Recycle Solid block MultiMeshes
	for block_type in p_multimesh_data.keys():
		var bulk_array: PackedFloat32Array = p_multimesh_data[block_type]
		var instance_count: int = int(bulk_array.size() / 12.0)
		
		if instance_count == 0:
			continue
			
		active_types[block_type] = true
		
		if _multimeshes.has(block_type) and _multimeshes[block_type] is MultiMeshInstance3D:
			var mm_instance: MultiMeshInstance3D = _multimeshes[block_type]
			var mm: MultiMesh = mm_instance.multimesh
			if mm != null:
				mm.instance_count = instance_count
				mm.buffer = bulk_array
			mm_instance.visible = true
		else:
			if _multimeshes.has(block_type):
				var old_node = _multimeshes[block_type]
				if is_instance_valid(old_node):
					old_node.queue_free()
					
			var mm_instance := MultiMeshInstance3D.new()
			mm_instance.name = "MM_" + str(block_type)
			
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = false 
			mm.mesh = _get_shared_box_mesh()
			mm.instance_count = instance_count
			mm.buffer = bulk_array
			
			mm_instance.multimesh = mm
			mm_instance.material_override = _get_material_for_block(block_type)
			
			add_child(mm_instance)
			_multimeshes[block_type] = mm_instance

	# 2. Update/Recycle Liquid block MeshInstances
	for block_type in p_liquid_meshes.keys():
		var mesh: ArrayMesh = p_liquid_meshes[block_type]
		if mesh == null:
			continue
			
		active_types[block_type] = true
		
		if _multimeshes.has(block_type) and _multimeshes[block_type] is MeshInstance3D:
			var mi: MeshInstance3D = _multimeshes[block_type]
			mi.mesh = mesh
			mi.visible = true
		else:
			if _multimeshes.has(block_type):
				var old_node = _multimeshes[block_type]
				if is_instance_valid(old_node):
					old_node.queue_free()
					
			var mi := MeshInstance3D.new()
			mi.name = "Liquid_" + str(block_type)
			mi.mesh = mesh
			mi.material_override = _get_material_for_block(block_type)
			
			add_child(mi)
			_multimeshes[block_type] = mi

	# 3. Clean up / Hibernate inactive block meshes
	for block_type in _multimeshes.keys():
		if not active_types.has(block_type):
			var node = _multimeshes[block_type]
			if is_instance_valid(node):
				if node is MultiMeshInstance3D:
					var mm: MultiMesh = node.multimesh
					if mm != null:
						mm.instance_count = 0
					node.visible = false
				elif node is MeshInstance3D:
					node.mesh = null
					node.visible = false

	# 4. Register physical Concave Collision body on the Main Thread
	if is_instance_valid(_collision_body):
		if _collision_body.get_parent() == self:
			remove_child(_collision_body)
		_collision_body.queue_free()
		_collision_body = null
		
	if is_instance_valid(p_collision_body):
		_collision_body = p_collision_body
		add_child(_collision_body)


## Generates or retrieves a cached material with customized PBR features.
func _get_material_for_block(block_type: BlockType.Type) -> Material:
	if _materials_cache.has(block_type):
		return _materials_cache[block_type]
		
	var def := BlockLibrary.get_definition(block_type)
	
	# Water Setup
	if block_type == BlockType.Type.WATER:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.05, 0.35, 0.82, 0.84) 
		mat.roughness = 0.08 
		mat.metallic = 0.15
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat
	
	# Lava Setup (Upgraded with emissive albedo texture blending)
	elif block_type == BlockType.Type.LAVA:
		var mat := ORMMaterial3D.new()
		mat.albedo_color = def.color_top
		mat.roughness = 0.95
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0) 
		mat.emission_energy_multiplier = 1.8
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type]
			mat.emission_texture = _loaded_textures[block_type]
		_materials_cache[block_type] = mat
		return mat
		
	# Clouds Setup (Translucent flat voxel clouds)
	elif block_type == BlockType.Type.CLOUD:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat

	# Ice and Glass Setup (Upgraded with transparency and texture blending)
	elif block_type == BlockType.Type.ICE or block_type == BlockType.Type.GLASS:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.1
		mat.metallic = 0.2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type]
		_materials_cache[block_type] = mat
		return mat
		
	# Standard textured or solid blocks
	else:
		var has_custom_texture := false
		if _loaded_textures.has(block_type):
			var tex: Texture2D = _loaded_textures[block_type]
			has_custom_texture = true
			
			# Wind-swaying leaves & blossom canopies
			if block_type == BlockType.Type.LEAVES or block_type == BlockType.Type.NEON_MAGENTA:
				var mat := ShaderMaterial.new()
				mat.shader = _get_leaves_wind_shader()
				mat.set_shader_parameter("albedo_texture", tex)
				mat.set_shader_parameter("block_color", def.color_top)
				mat.set_shader_parameter("roughness_val", 0.85)
				_materials_cache[block_type] = mat
				return mat
			
			# Standard triplanar blocks
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

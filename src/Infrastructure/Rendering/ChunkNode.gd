# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a single chunk in 3D.
#              Manages discrete MultiMeshInstance3D and MeshInstance3D children 
#              per active BlockType to apply custom materials efficiently.
#              Includes detailed texture telemetry logging to diagnose load failures.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles chunk mesh assembly 
#   and material binding.
# - Dependency Inversion Principle (DIP): Depends on Domain-level Chunk representations.
# - Open-Closed Principle (OCP): Generalizes liquid and solid custom geometries.
# OPAQUE FAR-LOD CULLING OPTIMIZATION (Milestone 10):
# - Modified `_get_material_for_block` to disable transparency (`TRANSPARENCY_DISABLED`)
#   for distant chunks (Water, Glass, Ice, Clouds).
# - This completely bypasses expensive alpha blending passes on the GPU horizon,
#   releasing massive pixel fillrate overhead and boosting FPS significantly.
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
static var _distant_materials_cache: Dictionary = {} 
static var _loaded_textures: Dictionary = {}
static var _loaded_normals: Dictionary = {}
static var _loaded_ambients: Dictionary = {}
static var _loaded_speculars: Dictionary = {}
static var _textures_preloaded: bool = false

## Shared geometry cache (Flyweight Pattern)
static var _shared_box_mesh: BoxMesh = null

## Procedural Bevel Normal Map cache
static var _procedural_bevel_normal: ImageTexture = null

## Static references to compiled Shader resources.
static var _leaves_wind_shader: Shader
static var _water_shader: Shader 

## Base directory where custom texture assets are stored.
const TEXTURE_DIR := "res://assets/textures/"

## File names mapping for custom block albedo textures.
const TEXTURE_MAP = {
	BlockType.Type.STONE: "stone.png",
	BlockType.Type.DIRT: "dirt.png",
	BlockType.Type.GRASS: "grass_top.png",
	BlockType.Type.WOOD: "wood.png",
	BlockType.Type.LEAVES: "leaves.png",
	BlockType.Type.SAND: "sand.png",
	BlockType.Type.RED_SAND: "red_sand.png",
	BlockType.Type.NEON_CYAN: "leaves.png", 
	BlockType.Type.NEON_MAGENTA: "sakura_leaves.png",
	BlockType.Type.COAL_ORE: "coal_ore.png",
	BlockType.Type.BRICKS: "bricks.png",
	BlockType.Type.GLASS: "glass.png",
	BlockType.Type.SNOW: "snow.png",
	BlockType.Type.ICE: "ice.png",
	BlockType.Type.MUD: "mud.png",
	BlockType.Type.LAVA: "lava.png",
	BlockType.Type.BIRCH_LOG: "birch_log.png",
	BlockType.Type.ROAD: "road.png",
	
	# Slabs reuse standard Stone textures
	BlockType.Type.STONE_SLAB_BOTTOM: "stone.png",
	BlockType.Type.STONE_SLAB_TOP: "stone.png"
}


func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	position = Vector3(chunk.position * Chunk.SIZE)
	_preload_all_textures()


## Static texture caching to prevent CPU execution stalls during real-time generation.
static func _preload_all_textures() -> void:
	if _textures_preloaded:
		return
	_textures_preloaded = true
	
	print("[TextureTelemetry] Starting static texture preloading cycle...")
	var successfully_loaded := 0
	var missing_or_failed := 0
	
	for block_type: BlockType.Type in TEXTURE_MAP.keys():
		var base_file_name: String = TEXTURE_MAP[block_type]
		var base_name := base_file_name.get_basename()
		
		# 1. Preload Albedo Map using ResourceLoader (Export-Safe)
		var file_path: String = TEXTURE_DIR + base_file_name
		if ResourceLoader.exists(file_path):
			var tex: Resource = load(file_path)
			if tex is Texture2D:
				_loaded_textures[block_type] = tex
				successfully_loaded += 1
			else:
				missing_or_failed += 1
		else:
			missing_or_failed += 1
				
		# 2. Preload companion Normal Maps
		var normal_path := TEXTURE_DIR + base_name + "_normal.png"
		if ResourceLoader.exists(normal_path):
			var normal_tex: Resource = load(normal_path)
			if normal_tex is Texture2D:
				_loaded_normals[block_type] = normal_tex
				
		# 3. Preload companion Ambient Occlusion Maps
		var ambient_path := TEXTURE_DIR + base_name + "_ambient.png"
		if ResourceLoader.exists(ambient_path):
			var ambient_tex: Resource = load(ambient_path)
			if ambient_tex is Texture2D:
				_loaded_ambients[block_type] = ambient_tex
				
		# 4. Preload companion Specular Maps
		var specular_path := TEXTURE_DIR + base_name + "_specular.png"
		if ResourceLoader.exists(specular_path):
			var specular_tex: Resource = load(specular_path)
			if specular_tex is Texture2D:
				_loaded_speculars[block_type] = specular_tex

	print("[TextureTelemetry] Preloading finished. Total loaded albedos: ", successfully_loaded, " | Missing/Failed: ", missing_or_failed)


## Lazy loading getter for the shared static BoxMesh instance.
static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3(1.002, 1.002, 1.002) # Symmetrical overlap to prevent seam gaps
	return _shared_box_mesh


## Mathematical Procedural Normal Map Generator:
## Bakes a flawless, spherical 64x64 edge bevel map directly into RAM on boot.
static func _get_procedural_bevel_normal() -> ImageTexture:
	if _procedural_bevel_normal != null:
		return _procedural_bevel_normal
		
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bevel_width := 6.0 # Controls the width of the rounded edge (6 pixels of bevel)
	
	# Loop through every pixel to calculate spherical slope normals
	for x: int in range(size):
		for y: int in range(size):
			# 1. Calculate horizontal slope
			var dx := 0.0
			if x < bevel_width:
				dx = -1.0 * (1.0 - (float(x) / bevel_width))
			elif x >= size - bevel_width:
				dx = 1.0 * ((float(x) - (size - bevel_width)) / bevel_width)
				
			# 2. Calculate vertical slope
			var dy := 0.0
			if y < bevel_width:
				dy = -1.0 * (1.0 - (float(y) / bevel_width))
			elif y >= size - bevel_width:
				dy = 1.0 * ((float(y) - (size - bevel_width)) / bevel_width)
				
			# 3. Calculate Z vector pointing out of the texture
			var nx := dx
			var ny := -dy # Invert Y for Godot normal map convention (Y-up)
			var nz := sqrt(clamp(1.0 - (nx * nx + ny * ny), 0.0, 1.0))
			
			# Normalize vector to ensure spherical light dispersion
			var vec := Vector3(nx, ny, nz).normalized()
			
			# Map from [-1.0, 1.0] to [0, 255] RGB color bytes
			var r := int((vec.x + 1.0) * 127.5)
			var g := int((vec.y + 1.0) * 127.5)
			var b := int((vec.z + 1.0) * 127.5)
			
			img.set_pixel(x, y, Color8(r, g, b, 255))
			
	_procedural_bevel_normal = ImageTexture.create_from_image(img)
	return _procedural_bevel_normal


## Loads and returns the compiled wind-sway foliage shader resource.
static func _get_leaves_wind_shader() -> Shader:
	if _leaves_wind_shader == null:
		if ResourceLoader.exists("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader"):
			_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader") as Shader
	return _leaves_wind_shader


## Programmatically compiles and returns an animated water wave shader.
static func _get_water_shader() -> Shader:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx;
		
		// Sourced programmatically from global uniforms mapped by WeatherService
		global uniform vec2 wind_vector;
		global uniform float wind_strength;
		
		uniform vec4 deep_water_color : source_color = vec4(0.01, 0.18, 0.42, 0.95);
		uniform vec4 shallow_water_color : source_color = vec4(0.12, 0.55, 0.78, 0.65);
		uniform float depth_distance : hint_range(0.1, 10.0) = 3.5;
		uniform float foam_distance : hint_range(0.01, 2.0) = 0.35;
		
		uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;
		
		void vertex() {
			// WAVE DISPLACEMENT SENSITIVE TO DYNAMIC WIND VECTOR!
			vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
			
			// Project world coords along the active wind vector direction
			float wind_dot = dot(world_pos.xz, normalize(wind_vector));
			
			// Waves scale dynamically during storm cycles
			float wave_height = 0.08 * (1.0 + wind_strength * 0.35);
			
			// Push vertices upward forming physical ripples traveling in wind direction
			float wave = sin(wind_dot * 1.5 - TIME * (2.2 + wind_strength * 0.4)) * wave_height;
			VERTEX.y += wave;
		}
		
		void fragment() {
			float depth_raw = texture(depth_texture, SCREEN_UV).r;
			vec4 upk = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
			upk.xyz /= upk.w;
			float depth_diff = -upk.z + VERTEX.z;
			
			float depth_factor = clamp(depth_diff / depth_distance, 0.0, 1.0);
			vec4 final_color = mix(shallow_water_color, deep_water_color, depth_factor);
			
			vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
			
			// FOAM PANNING SENSITIVE TO WIND DIRECTION!
			// Shifting coordinate spaces smoothly along the wind vector
			vec2 foam_uv = world_pos.xz * 0.4 - (wind_vector * TIME * 0.12);
			
			float wave_1 = sin(foam_uv.x * 2.2 + TIME * 0.5) * cos(foam_uv.y * 2.2 + TIME * 0.4);
			float wave_2 = cos(foam_uv.x * 1.1 - TIME * 0.3) * sin(foam_uv.y * 1.4 + TIME * 0.5);
			float wave_blend = (wave_1 + wave_2) * 0.04 + 0.96;
			
			float foam_factor = clamp(depth_diff / foam_distance, 0.0, 1.0);
			
			// Thick storm foam scaling on heavy winds
			float storm_foam_scale = 1.0 + (wind_strength * 0.35);
			vec3 foam_color = vec3(0.98, 0.98, 1.0) * (sin(TIME * 3.5 + (foam_uv.x + foam_uv.y) * 5.0) * 0.12 * storm_foam_scale + 0.88);
			
			ALBEDO = mix(foam_color, final_color.rgb * wave_blend, foam_factor);
			ALPHA = mix(0.92, final_color.a, foam_factor);
			ROUGHNESS = 0.06;
			METALLIC = 0.12;
		}
		"""
	return _water_shader


## Public Gaze API: Checks if the chunk node possesses an active collision body.
func has_collision_body() -> bool:
	return is_instance_valid(_collision_body)


## Dynamic Physics LOD API: Injects and registers a static collision body directly.
func set_collision_body(p_collision_body: StaticBody3D) -> void:
	if is_instance_valid(_collision_body):
		if _collision_body.get_parent() == self:
			remove_child(_collision_body)
		_collision_body.queue_free()
		
	_collision_body = p_collision_body
	if is_instance_valid(_collision_body):
		add_child(_collision_body)


## Configures the segmented MultiMeshes and registers the physics collision body.
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_custom_meshes: Dictionary = {}, p_is_distant: bool = false) -> void:
	var active_types: Dictionary = {}
	
	# 1. Update/Recycle Solid block MultiMeshes (Standard full cubes)
	for block_type: BlockType.Type in p_multimesh_data.keys():
		var bulk_array: PackedFloat32Array = p_multimesh_data[block_type]
		var instance_count: int = int(bulk_array.size() / 12.0)
		
		if instance_count == 0:
			continue
			
		active_types[block_type] = true
		
		if _multimeshes.has(block_type) and _multimeshes[block_type] is MultiMeshInstance3D:
			var mm_instance: MultiMeshInstance3D = _multimeshes[block_type] as MultiMeshInstance3D
			
			var new_mm := MultiMesh.new()
			new_mm.transform_format = MultiMesh.TRANSFORM_3D
			new_mm.use_colors = false 
			new_mm.mesh = _get_shared_box_mesh()
			new_mm.instance_count = instance_count
			new_mm.buffer = bulk_array
			
			mm_instance.multimesh = new_mm
			mm_instance.material_override = _get_material_for_block(block_type, p_is_distant)
			mm_instance.visible = true
		else:
			if _multimeshes.has(block_type):
				var old_node: Node = _multimeshes[block_type] as Node
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
			mm_instance.material_override = _get_material_for_block(block_type, p_is_distant)
			
			add_child(mm_instance)
			_multimeshes[block_type] = mm_instance

	# 2. Update/Recycle Solid Custom Mesh and Liquid instances
	for block_type: BlockType.Type in p_custom_meshes.keys():
		var mesh: ArrayMesh = p_custom_meshes[block_type] as ArrayMesh
		if mesh == null:
			continue
			
		active_types[block_type] = true
		
		if _multimeshes.has(block_type) and _multimeshes[block_type] is MeshInstance3D:
			var mi: MeshInstance3D = _multimeshes[block_type] as MeshInstance3D
			mi.mesh = mesh
			mi.material_override = _get_material_for_block(block_type, p_is_distant)
			mi.visible = true
		else:
			if _multimeshes.has(block_type):
				var old_node: Node = _multimeshes[block_type] as Node
				if is_instance_valid(old_node):
					old_node.queue_free()
					
			var mi := MeshInstance3D.new()
			mi.name = "CustomMesh_" + str(block_type)
			mi.mesh = mesh
			mi.material_override = _get_material_for_block(block_type, p_is_distant)
			
			add_child(mi)
			_multimeshes[block_type] = mi

	# 3. Clean up / Hibernate inactive block meshes
	for block_type: BlockType.Type in _multimeshes.keys():
		if not active_types.has(block_type):
			var node: Node = _multimeshes[block_type] as Node
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


## Swaps the materials on the GPU instantly (O(1)) without CPU overhead.
func update_lod_materials(p_is_distant: bool) -> void:
	for block_type: BlockType.Type in _multimeshes.keys():
		var node: Node = _multimeshes[block_type] as Node
		if is_instance_valid(node):
			node.material_override = _get_material_for_block(block_type, p_is_distant)


## Generates or retrieves a cached material with customized PBR features.
## LOD CULLING: Far chunks disable alpha transparency completely on Water, Glass, and Ice.
func _get_material_for_block(block_type: BlockType.Type, is_distant: bool) -> Material:
	var def := BlockLibrary.get_definition(block_type)
	
	if is_distant:
		if _distant_materials_cache.has(block_type):
			return _distant_materials_cache[block_type] as Material
			
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_color = def.color_top
		mat.roughness = 1.0 
		mat.metallic_specular = 0.0
		# ANISOTROPIC applied even to distant meshes for flawless horizon scaling
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		
		# --- OPAQUE FAR-LOD TRANSPARENCY BYPASS ---
		# Far water, glass, and ice disable blending, saving huge pixel fillrate overhead.
		if block_type == BlockType.Type.WATER:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(0.08, 0.35, 0.65) # Opaque deep ocean blue
		elif block_type == BlockType.Type.GLASS:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(0.40, 0.60, 0.70) # Opaque solid cyan-gray
		elif block_type == BlockType.Type.ICE:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(0.45, 0.75, 0.85) # Opaque solid ice blue
		elif block_type == BlockType.Type.CLOUD:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color = Color(0.95, 0.95, 0.95) # Opaque clean white
			
		_distant_materials_cache[block_type] = mat
		return mat
		
	if _materials_cache.has(block_type):
		return _materials_cache[block_type] as Material
		
	# Water Setup: Apply dynamic animated waves Shader Material
	if block_type == BlockType.Type.WATER:
		var mat := ShaderMaterial.new()
		mat.shader = _get_water_shader()
		_materials_cache[block_type] = mat
		return mat
	
	# Lava Setup
	elif block_type == BlockType.Type.LAVA:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.color_top
		mat.roughness = 0.95
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0) 
		mat.emission_energy_multiplier = 1.8
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
			mat.emission_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat
		
	# Clouds Setup
	elif block_type == BlockType.Type.CLOUD:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat

	# Transparent Glass
	elif block_type == BlockType.Type.GLASS:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.28) 
		mat.roughness = 0.05 
		mat.metallic = 0.1
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat

	# Ice Setup
	elif block_type == BlockType.Type.ICE:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.2, 0.2, 0.1)
		mat.roughness = 0.1
		mat.metallic = 0.2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat
		
	# Standard blocks
	else:
		var has_custom_texture := false
		var tex: Texture2D = null
		
		if _loaded_textures.has(block_type):
			tex = _loaded_textures[block_type] as Texture2D
			has_custom_texture = true
			
		# Wind-swaying leaves (Uses specialized shader if available)
		if (block_type == BlockType.Type.LEAVES or block_type == BlockType.Type.NEON_MAGENTA) and has_custom_texture:
			var leaf_shader := _get_leaves_wind_shader()
			if leaf_shader != null:
				var leaf_mat := ShaderMaterial.new()
				leaf_mat.shader = leaf_shader
				leaf_mat.set_shader_parameter("albedo_texture", tex)
				leaf_mat.set_shader_parameter("block_color", def.color_top)
				leaf_mat.set_shader_parameter("roughness_val", 0.85)
				_materials_cache[block_type] = leaf_mat
				return leaf_mat
		
		# ======================================================================
		# CORE OPTIMIZATION: NATIVE GODOT PBR MATERIAL
		# ======================================================================
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def.color_top
		mat.roughness = _roughness_val_by_block(block_type)
		
		# Moiré Fix: Anisotropic filtering smooths horizontal lines
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC 
		
		if has_custom_texture:
			mat.albedo_texture = tex
			
			var adapter_type := RenderingServer.get_video_adapter_type()
			var is_low_end := (adapter_type == 1 or adapter_type == 4) 
			
			if not is_low_end:
				# ==============================================================
				# SELECTIVE PROCEDURAL BEVEL SHADOW INJECTION
				# ==============================================================
				if _should_apply_bevel(block_type):
					mat.normal_enabled = true
					mat.normal_scale = 0.55 # Balanced bevel highlight intensity
					mat.normal_texture = _get_procedural_bevel_normal()
				
				if _loaded_ambients.has(block_type):
					mat.ao_enabled = true
					mat.ao_light_affect = 0.5
					mat.ao_texture = _loaded_ambients[block_type] as Texture2D
					
		# Special Emissive Cyber Glow setup for Neon basin block types
		if block_type == BlockType.Type.NEON_CYAN or block_type == BlockType.Type.NEON_MAGENTA:
			mat.emission_enabled = true
			mat.emission = def.color_top
			mat.emission_energy_multiplier = 1.5
			if has_custom_texture:
				mat.emission_texture = tex
				
		_materials_cache[block_type] = mat
		return mat


## Evaluates block types and returns true if they should have procedural bevel highlights.
## Keeps terrain, roads, and oceans flat to blend seamlessly into homogeneous plains.
static func _should_apply_bevel(type: BlockType.Type) -> bool:
	match type:
		BlockType.Type.STONE, \
		BlockType.Type.ROAD, \
		BlockType.Type.SAND, \
		BlockType.Type.RED_SAND, \
		BlockType.Type.SNOW, \
		BlockType.Type.MUD, \
		BlockType.Type.GRASS, \
		BlockType.Type.ICE, \
		BlockType.Type.WATER, \
		BlockType.Type.LAVA:
			return false # Natural landscapes and paving highways stay homogeneous!
		_:
			return true # Construction blocks (wood, bricks, glass, logs, etc.) get the bevels!


## Static Helper: Returns standard physical roughness values per BlockType.
func _roughness_val_by_block(type: BlockType.Type) -> float:
	match type:
		BlockType.Type.STONE, BlockType.Type.ROAD:
			return 0.55
		BlockType.Type.GLASS:
			return 0.05
		_:
			return 0.85

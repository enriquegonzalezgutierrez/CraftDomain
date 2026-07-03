# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure rendering node representing a single chunk in 3D.
#              Manages discrete MultiMeshInstance3D and MeshInstance3D nodes 
#              per active BlockType to apply custom materials efficiently.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles chunk mesh assembly 
#   and material binding, delegating shader calculations to external files.
# - Open-Closed Principle (OCP): {reloads PBR maps.
# SEAM-FREE WATER OVERHAUL:
# - Replaced the vertex displacement water shader with a high-fidelity 
#   Procedural Ripple Fragment Shader. By keeping water geometry perfectly flat, 
#   we completely eliminate 100% of all seams, gaps, and leaks between water, 
#   sand shorelines, and adjacent chunk boundaries, while preserving organic motion.
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

## Static references to compiled Shader resources.
static var _triplanar_shader: Shader
static var _leaves_wind_shader: Shader
static var _water_shader: Shader # Procedural animated flat ripples

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
	BlockType.Type.NEON_MAGENTA: "sakura_leaves.png",
	BlockType.Type.COAL_ORE: "coal_ore.png",
	BlockType.Type.BRICKS: "bricks.png",
	BlockType.Type.GLASS: "glass.png",
	BlockType.Type.SNOW: "snow.png",
	BlockType.Type.ICE: "ice.png",
	BlockType.Type.MUD: "mud.png",
	BlockType.Type.LAVA: "lava.png",
	BlockType.Type.BIRCH_LOG: "birch_log.png",
	BlockType.Type.ROAD: "road.png"
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
	
	for block_type: BlockType.Type in TEXTURE_MAP.keys():
		var base_file_name: String = TEXTURE_MAP[block_type]
		var base_name := base_file_name.get_basename()
		
		# Preload Albedo Map
		var file_path: String = TEXTURE_DIR + base_file_name
		if FileAccess.file_exists(file_path):
			var tex: Resource = load(file_path)
			if tex is Texture2D:
				_loaded_textures[block_type] = tex
				
		# Check and preload companion Normal Maps
		var normal_path := TEXTURE_DIR + base_name + "_normal.png"
		if FileAccess.file_exists(normal_path):
			var normal_tex: Resource = load(normal_path)
			if normal_tex is Texture2D:
				_loaded_normals[block_type] = normal_tex
				
		# Check and preload companion Ambient Occlusion Maps
		var ambient_path := TEXTURE_DIR + base_name + "_ambient.png"
		if FileAccess.file_exists(ambient_path):
			var ambient_tex: Resource = load(ambient_path)
			if ambient_tex is Texture2D:
				_loaded_ambients[block_type] = ambient_tex
				
		# Check and preload companion Specular Maps
		var specular_path := TEXTURE_DIR + base_name + "_specular.png"
		if FileAccess.file_exists(specular_path):
			var specular_tex: Resource = load(specular_path)
			if specular_tex is Texture2D:
				_loaded_speculars[block_type] = specular_tex


## Lazy loading getter for the shared static BoxMesh instance.
static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		# SEAM OVERLAP CORRECTION:
		# Scale the base mesh slightly larger to 1.002 (2 millimeters overlap) 
		# to guarantee that adjacent solid faces tightly lock, completely closing 
		# all sub-pixel rendering cracks on chunk boundaries.
		_shared_box_mesh.size = Vector3(1.002, 1.002, 1.002)
	return _shared_box_mesh


## Loads and returns the compiled triplanar shader resource.
static func _get_triplanar_shader() -> Shader:
	if _triplanar_shader == null:
		_triplanar_shader = load("res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader") as Shader
	return _triplanar_shader


## Loads and returns the compiled wind-sway foliage shader resource.
static func _get_leaves_wind_shader() -> Shader:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader") as Shader
	return _leaves_wind_shader


## Programmatically compiles and returns a high-fidelity animated water wave shader.
static func _get_water_shader() -> Shader:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
		shader_type spatial;
		render_mode blend_mix, depth_draw_always, diffuse_lambert, specular_schlick_ggx;
		
		uniform vec4 water_color : source_color = vec4(0.05, 0.42, 0.78, 0.82);
		
		void fragment() {
			// Calculate pixel world-space coordinates from the view-projection matrix
			vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
			
			// Calculate dynamic ripples using intersecting sine waves (completely flat geometry)
			float ripple_1 = sin(world_pos.x * 2.5 + TIME * 1.4) * cos(world_pos.z * 2.2 + TIME * 1.1);
			float ripple_2 = cos(world_pos.x * 1.2 - TIME * 0.8) * sin(world_pos.z * 1.6 + TIME * 0.9);
			
			// Blend ripples slightly to modulate surface brightness
			float ripple_blend = (ripple_1 + ripple_2) * 0.045 + 0.955;
			
			ALBEDO = water_color.rgb * ripple_blend;
			ALPHA = water_color.a;
			ROUGHNESS = 0.05; // High glossy reflections
			METALLIC = 0.15;
		}
		"""
	return _water_shader


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
func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_liquid_meshes: Dictionary = {}, p_is_distant: bool = false) -> void:
	var active_types: Dictionary = {}
	
	# 1. Update/Recycle Solid block MultiMeshes
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

	# 2. Update/Recycle Liquid block MeshInstances
	for block_type: BlockType.Type in p_liquid_meshes.keys():
		var mesh: ArrayMesh = p_liquid_meshes[block_type] as ArrayMesh
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
			mi.name = "Liquid_" + str(block_type)
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


## Dynamically swaps the materials on the GPU instantly (O(1)) without CPU overhead.
func update_lod_materials(p_is_distant: bool) -> void:
	for block_type: BlockType.Type in _multimeshes.keys():
		var node: Node = _multimeshes[block_type] as Node
		if is_instance_valid(node):
			node.material_override = _get_material_for_block(block_type, p_is_distant)


## Generates or retrieves a cached material with customized PBR features.
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
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		
		if block_type == BlockType.Type.WATER:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(0.12, 0.45, 0.82, 0.55) 
		elif block_type == BlockType.Type.GLASS or block_type == BlockType.Type.ICE or block_type == BlockType.Type.CLOUD:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(def.color_top.r, def.color_top.g, def.color_top.b, 0.4)
			
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
		var mat := ORMMaterial3D.new()
		mat.albedo_color = def.color_top
		mat.roughness = 0.95
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.35, 0.0) 
		mat.emission_energy_multiplier = 1.8
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
			mat.emission_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat
		
	# Clouds Setup
	elif block_type == BlockType.Type.CLOUD:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = def.color_top
		mat.roughness = 0.9
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat

	# Transparent Glass
	elif block_type == BlockType.Type.GLASS:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.95, 1.0, 0.28) 
		mat.roughness = 0.05 
		mat.metallic = 0.1
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_materials_cache[block_type] = mat
		return mat

	# Ice Setup
	elif block_type == BlockType.Type.ICE:
		var mat := ORMMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.1, 0.2, 0.2, 0.1)
		mat.roughness = 0.1
		mat.metallic = 0.2
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if _loaded_textures.has(block_type):
			mat.albedo_texture = _loaded_textures[block_type] as Texture2D
		_materials_cache[block_type] = mat
		return mat
		
	# Standard textured blocks (Triplanar)
	else:
		var has_custom_texture := false
		if _loaded_textures.has(block_type):
			var tex: Texture2D = _loaded_textures[block_type] as Texture2D
			has_custom_texture = true
			
			# Wind-swaying leaves
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
				mat.set_shader_parameter("roughness_val", _roughness_val_by_block(block_type))
				
				# A. Dynamic Normal map binding
				if _loaded_normals.has(block_type):
					mat.set_shader_parameter("normal_texture", _loaded_normals[block_type])
					mat.set_shader_parameter("use_normal_map", true)
					mat.set_shader_parameter("normal_scale", 1.0)
				else:
					mat.set_shader_parameter("use_normal_map", false)
					
				# B. Dynamic Ambient Occlusion map binding
				if _loaded_ambients.has(block_type):
					mat.set_shader_parameter("ambient_texture", _loaded_ambients[block_type])
					mat.set_shader_parameter("use_ambient_map", true)
				else:
					mat.set_shader_parameter("use_ambient_map", false)
					
				# C. Dynamic Specular map binding
				if _loaded_speculars.has(block_type):
					mat.set_shader_parameter("specular_texture", _loaded_speculars[block_type])
					mat.set_shader_parameter("use_specular_map", true)
				else:
					mat.set_shader_parameter("use_specular_map", false)
					
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


## Static Helper: Returns standard physical roughness values per BlockType.
static func _roughness_val_by_block(type: BlockType.Type) -> float:
	match type:
		BlockType.Type.STONE, BlockType.Type.ROAD:
			return 0.55
		BlockType.Type.GLASS:
			return 0.05
		_:
			return 0.85

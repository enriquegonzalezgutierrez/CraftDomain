# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Rendering / Presentation)
# Class: ChunkNode
# Description: High-performance rendering node representing a single 3D Chunk.
#              Orchestrates MultiMeshInstance3D segments and PBR materials.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively mesh assembly 
#   and material binding, delegating block data to the Domain BlockLibrary.
# - Open-Closed Principle (OCP): COMPLETELY DECOUPLED. All hardcoded texture 
#   maps and 'if/elif' material chains have been purged. The renderer now 
#   dynamically consumes visual attributes from the BlockDefinition strategies.
# SHADER ARCHITECTURE FIX:
# - Extracted the inline water shader logic into an external .gdshader file 
#   (`liquid_water.gdshader`), matching the architecture of the foliage and sky 
#   shaders, keeping GDScript clean.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/ChunkNode.gd
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data.
var chunk: Chunk

## Collision body reference.
var _collision_body: StaticBody3D

## Active registered MultiMeshInstance3D and MeshInstance3D children: int -> Node
var _multimeshes: Dictionary = {}

## Static caches to minimize GPU state changes and prevent frame stiction
static var _materials_cache: Dictionary = {}
static var _distant_materials_cache: Dictionary = {} 
static var _loaded_textures: Dictionary = {}
static var _textures_preloaded: bool = false
static var _shared_box_mesh: BoxMesh = null

## Static references to compiled Shader resources
static var _leaves_wind_shader: Shader
static var _water_shader: Shader 

const TEXTURE_DIR := "res://assets/textures/"


func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	position = Vector3(chunk.position * Chunk.SIZE)
	_preload_dynamic_textures()


## OCP PRELOADER: Scans the BlockLibrary and caches all required assets dynamically.
static func _preload_dynamic_textures() -> void:
	if _textures_preloaded:
		return
	_textures_preloaded = true
	
	print("[ChunkNode] Starting OCP dynamic texture preloading...")
	var success_count := 0
	
	for b_id: int in BlockLibrary._definitions.keys():
		var def: BlockDefinition = BlockLibrary.get_definition(b_id)
		if def.texture_file_name == "":
			continue
			
		var path := TEXTURE_DIR + def.texture_file_name
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_loaded_textures[b_id] = tex
				success_count += 1
				
	print("[ChunkNode] Dynamic preloading finished. Total assets cached: ", success_count)


static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3(1.002, 1.002, 1.002) 
	return _shared_box_mesh


## POLYMORPHIC MATERIAL FACTORY:
## Instead of match-casing IDs, it evaluates the 'rendering_type' and PBR 
## properties defined in the Domain.
func _get_material_for_block(block_id: int, is_distant: bool) -> Material:
	var def := BlockLibrary.get_definition(block_id)
	
	# 1. Check Distant LOD Cache (Vertex Shading Optimization)
	if is_distant:
		if _distant_materials_cache.has(block_id):
			return _distant_materials_cache[block_id]
			
		var d_mat := StandardMaterial3D.new()
		d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		d_mat.albedo_color = def.color_top
		d_mat.roughness = 1.0
		
		# For distant transparent units, we force opaqueness to save fillrate
		if def.is_transparent:
			d_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
		_distant_materials_cache[block_id] = d_mat
		return d_mat
		
	# 2. Check Standard Material Cache
	if _materials_cache.has(block_id):
		return _materials_cache[block_id]
		
	# 3. CONSTRUCT NEW MATERIAL BASED ON DOMAIN CONTRACT
	var mat: Material
	
	match def.rendering_type:
		"foliage":
			mat = _create_foliage_material(def, block_id)
		"liquid_water", "liquid_lava":
			mat = _create_liquid_material(def)
		_:
			mat = _create_standard_pbr_material(def, block_id)
			
	_materials_cache[block_id] = mat
	return mat


func _create_standard_pbr_material(def: BlockDefinition, block_id: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = def.color_top
	m.roughness = def.roughness
	m.metallic = def.metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	
	if def.is_transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if _loaded_textures.has(block_id):
		m.albedo_texture = _loaded_textures[block_id]
		
	if def.is_emissive:
		m.emission_enabled = true
		m.emission = def.emission_color
		m.emission_energy_multiplier = def.emission_energy
		if m.albedo_texture != null:
			m.emission_texture = m.albedo_texture
			
	return m


func _create_foliage_material(def: BlockDefinition, block_id: int) -> ShaderMaterial:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader")
		
	var sm := ShaderMaterial.new()
	sm.shader = _leaves_wind_shader
	sm.set_shader_parameter("block_color", def.color_top)
	if _loaded_textures.has(block_id):
		sm.set_shader_parameter("albedo_texture", _loaded_textures[block_id])
	return sm


func _create_liquid_material(def: BlockDefinition) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = load("res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader")
		
	var sm := ShaderMaterial.new()
	sm.shader = _water_shader
	sm.set_shader_parameter("shallow_water_color", def.color_top)
	sm.set_shader_parameter("deep_water_color", def.color_bottom)
	return sm


# ==============================================================================
# INFRASTRUCTURE LIFECYCLE APIS
# ==============================================================================

func setup_chunk_visuals(p_multimesh_data: Dictionary, p_collision_body: StaticBody3D, p_custom_meshes: Dictionary = {}, p_is_distant: bool = false) -> void:
	var active_ids: Dictionary = {}
	
	# 1. Update/Recycle MultiMeshes
	for b_id: int in p_multimesh_data.keys():
		var bulk_array: PackedFloat32Array = p_multimesh_data[b_id]
		var count := int(bulk_array.size() / 12.0)
		if count == 0: continue
		active_ids[b_id] = true
		
		_ensure_multimesh_instance(b_id, count, bulk_array, p_is_distant)

	# 2. Update Custom Meshes (Liquids/Slabs)
	for b_id: int in p_custom_meshes.keys():
		var mesh: ArrayMesh = p_custom_meshes[b_id]
		if mesh == null: continue
		active_ids[b_id] = true
		_ensure_mesh_instance(b_id, mesh, p_is_distant)

	# 3. Clean-up inactive segments
	for b_id: int in _multimeshes.keys():
		if not active_ids.has(b_id):
			var node: Node = _multimeshes[b_id] as Node
			if is_instance_valid(node):
				node.visible = false

	# 4. Collision management
	_update_collision(p_collision_body)


## Updates Level-of-Detail materials across all sub-meshes polymorphically
func update_lod_materials(is_distant: bool) -> void:
	for b_id: int in _multimeshes.keys():
		var node: Node = _multimeshes[b_id] as Node
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).material_override = _get_material_for_block(b_id, is_distant)


## Returns true if a valid collision body is currently attached
func has_collision_body() -> bool:
	return is_instance_valid(_collision_body)


## Sets or clears the collision body
func set_collision_body(body: StaticBody3D) -> void:
	_update_collision(body)


func _ensure_multimesh_instance(b_id: int, count: int, buffer: PackedFloat32Array, is_distant: bool) -> void:
	var mm_inst: MultiMeshInstance3D
	if _multimeshes.has(b_id) and _multimeshes[b_id] is MultiMeshInstance3D:
		mm_inst = _multimeshes[b_id]
	else:
		mm_inst = MultiMeshInstance3D.new()
		add_child(mm_inst)
		_multimeshes[b_id] = mm_inst
		
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _get_shared_box_mesh()
	mm.instance_count = count
	mm.buffer = buffer
	mm_inst.multimesh = mm
	mm_inst.material_override = _get_material_for_block(b_id, is_distant)
	mm_inst.visible = true


func _ensure_mesh_instance(b_id: int, mesh: ArrayMesh, is_distant: bool) -> void:
	var mi: MeshInstance3D
	if _multimeshes.has(b_id) and _multimeshes[b_id] is MeshInstance3D:
		mi = _multimeshes[b_id]
	else:
		mi = MeshInstance3D.new()
		add_child(mi)
		_multimeshes[b_id] = mi
		
	mi.mesh = mesh
	mi.material_override = _get_material_for_block(b_id, is_distant)
	mi.visible = true


func _update_collision(new_body: StaticBody3D) -> void:
	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
	_collision_body = new_body
	if is_instance_valid(_collision_body):
		add_child(_collision_body)

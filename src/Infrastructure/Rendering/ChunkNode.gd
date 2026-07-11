# ==============================================================================
# Project: CraftDomain
# Layer: Infrastructure (Rendering / Chunk Node Representation)
# Class: ChunkNode
# Description: High-performance rendering node representing a single 3D Chunk.
#              Orchestrates MultiMeshInstance3D segments and PBR materials.
# SOLID COMPLIANCE: 
# - Single Responsibility Principle (SRP): Handles exclusively 3D mesh compilation 
#   and material binding, delegating physical disk I/O and texture loading to 
#   the decoupled `TextureRegistry` service.
# - Open-Closed Principle (OCP): Completely closed to modifications. All rigid 
#   material-type conditional checks are removed. The renderer queries visual 
#   PBR attributes polimorphically from the block definitions.
# - Liskov Substitution Principle (LSP): Fully compatible with standard Node3D 
#   hierarchies, managing active visibility and culling.
# ==============================================================================
class_name ChunkNode
extends Node3D

## Reference to the logical domain chunk data.
var chunk: Chunk

## Collision body reference.
var _collision_body: StaticBody3D

## Active registered MultiMeshInstance3D and MeshInstance3D children: int (block_id) -> Node
var _multimeshes: Dictionary = {}

## Static material caches to minimize GPU state changes and prevent frame stiction
static var _materials_cache: Dictionary = {}
static var _distant_materials_cache: Dictionary = {} 
static var _shared_box_mesh: BoxMesh = null

## Static references to compiled Shader resources
static var _leaves_wind_shader: Shader
static var _water_shader: Shader 


func _init(p_chunk: Chunk) -> void:
	chunk = p_chunk
	name = "Chunk_%d_%d_%d" % [chunk.position.x, chunk.position.y, chunk.position.z]
	position = Vector3(chunk.position * Chunk.SIZE)


static func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3(1.002, 1.002, 1.002) 
	return _shared_box_mesh


## POLYMORPHIC MATERIAL FACTORY:
## Instead of matching specific IDs, it evaluates the 'rendering_type' and PBR 
## properties defined in the Domain Block files.
func _get_material_for_block(block_id: int, is_distant: bool) -> Material:
	var def := BlockLibrary.get_definition(block_id) as BlockDefinition
	if def == null:
		return null
		
	# 1. Check Distant LOD Cache (Vertex Shading Optimization)
	if is_distant:
		if _distant_materials_cache.has(block_id):
			return _distant_materials_cache[block_id] as Material
			
		var d_mat := StandardMaterial3D.new()
		d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		d_mat.albedo_color = def.color_top
		d_mat.roughness = 1.0
		
		# For distant transparent units, force opaqueness to save fillrate
		if def.is_transparent:
			d_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			
		_distant_materials_cache[block_id] = d_mat
		return d_mat
		
	# 2. Check Standard Material Cache
	if _materials_cache.has(block_id):
		return _materials_cache[block_id] as Material
		
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
	
	# SRP RESOLUTION: Fetch texture dynamically from the decoupled static TextureRegistry
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		m.albedo_texture = tex
		
	if def.is_emissive:
		m.emission_enabled = true
		m.emission = def.emission_color
		m.emission_energy_multiplier = def.emission_energy
		if m.albedo_texture != null:
			m.emission_texture = m.albedo_texture
			
	return m


func _create_foliage_material(def: BlockDefinition, block_id: int) -> ShaderMaterial:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader") as Shader
		
	var sm := ShaderMaterial.new()
	sm.shader = _leaves_wind_shader
	sm.set_shader_parameter("block_color", def.color_top)
	
	# SRP RESOLUTION: Fetch texture dynamically from the decoupled static TextureRegistry
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		sm.set_shader_parameter("albedo_texture", tex)
	return sm


func _create_liquid_material(def: BlockDefinition) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = load("res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader") as Shader
		
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
		var mesh := p_custom_meshes[b_id] as ArrayMesh
		if mesh == null: continue
		active_ids[b_id] = true
		_ensure_mesh_instance(b_id, mesh, p_is_distant)

	# 3. Clean-up inactive segments
	# FIXED: Erasure sweeps from dictionary to prevent memory leaks and freed-instance crashes!
	var registered_keys := _multimeshes.keys()
	for b_id: int in registered_keys:
		if not active_ids.has(b_id):
			var node := _multimeshes[b_id] as Node
			if is_instance_valid(node):
				node.queue_free() 
			_multimeshes.erase(b_id) # <--- CRITICAL GODOT 4 MEMORY FIX

	# 4. Collision management
	_update_collision(p_collision_body)


## Updates Level-of-Detail materials across all sub-meshes polymorphically.
func update_lod_materials(is_distant: bool) -> void:
	for b_id: int in _multimeshes.keys():
		var node := _multimeshes[b_id] as Node
		if node is GeometryInstance3D:
			var mat := _get_material_for_block(b_id, is_distant)
			if mat != null:
				(node as GeometryInstance3D).material_override = mat


## Returns true if a valid collision body is currently attached.
func has_collision_body() -> bool:
	return is_instance_valid(_collision_body)


## Sets or clears the collision body.
func set_collision_body(body: StaticBody3D) -> void:
	_update_collision(body)


func _ensure_multimesh_instance(b_id: int, count: int, buffer: PackedFloat32Array, is_distant: bool) -> void:
	var mm_inst: MultiMeshInstance3D
	
	# GODOT 4 MEMORY SAFETY SHIELD: Wrap 'is' checks with is_instance_valid to prevent crashes!
	if _multimeshes.has(b_id) and is_instance_valid(_multimeshes[b_id]) and _multimeshes[b_id] is MultiMeshInstance3D:
		mm_inst = _multimeshes[b_id] as MultiMeshInstance3D
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
	
	var mat := _get_material_for_block(b_id, is_distant)
	if mat != null:
		mm_inst.material_override = mat
	mm_inst.visible = true


func _ensure_mesh_instance(b_id: int, mesh: ArrayMesh, is_distant: bool) -> void:
	var mi: MeshInstance3D
	
	# GODOT 4 MEMORY SAFETY SHIELD: Wrap 'is' checks with is_instance_valid to prevent crashes!
	if _multimeshes.has(b_id) and is_instance_valid(_multimeshes[b_id]) and _multimeshes[b_id] is MeshInstance3D:
		mi = _multimeshes[b_id] as MeshInstance3D
	else:
		mi = MeshInstance3D.new()
		add_child(mi)
		_multimeshes[b_id] = mi
		
	mi.mesh = mesh
	var mat := _get_material_for_block(b_id, is_distant)
	if mat != null:
		mi.material_override = mat
	mi.visible = true


func _update_collision(new_body: StaticBody3D) -> void:
	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
	_collision_body = new_body
	if is_instance_valid(_collision_body):
		add_child(_collision_body)

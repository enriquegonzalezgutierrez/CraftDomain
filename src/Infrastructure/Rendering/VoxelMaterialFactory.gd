# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/VoxelMaterialFactory.gd
# Description: Infrastructure Factory managing the compilation, caching, and 
#              PBR parameters mapping of block materials. Decouples shader 
#              creation from ChunkNodes (SRP / OCP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelMaterialFactory
extends RefCounted

# Static shared resources to minimize draw calls and prevent frame stiction
static var _materials_cache: Dictionary = {}
static var _distant_materials_cache: Dictionary = {} 

static var _leaves_wind_shader: Shader
static var _water_shader: Shader


## Dynamic API: Resolves and returns the PBR material from cache or compiles a new one
static func get_material(block_id: int, is_distant: bool) -> Material:
	if is_distant:
		return _get_cached_distant_material(block_id)
	return _get_cached_standard_material(block_id)


static func _get_cached_distant_material(block_id: int) -> Material:
	if _distant_materials_cache.has(block_id):
		return _distant_materials_cache[block_id] as Material
		
	var mat := _compile_distant_material(block_id)
	_distant_materials_cache[block_id] = mat
	return mat


static func _get_cached_standard_material(block_id: int) -> Material:
	if _materials_cache.has(block_id):
		return _materials_cache[block_id] as Material
		
	var mat := _compile_standard_material(block_id)
	_materials_cache[block_id] = mat
	return mat


static func _compile_distant_material(block_id: int) -> StandardMaterial3D:
	var def := BlockLibrary.get_definition(block_id)
	var d_mat := StandardMaterial3D.new()
	
	# Low-end Vertex shading optimization for far LODs
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	d_mat.albedo_color = def.color_top if def != null else Color.GRAY
	d_mat.roughness = 1.0
	
	if def != null and def.is_transparent:
		d_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		
	return d_mat


static func _compile_standard_material(block_id: int) -> Material:
	var def := BlockLibrary.get_definition(block_id)
	if def == null:
		return null
		
	match def.rendering_type:
		"foliage":
			return _compile_foliage_material(def, block_id)
		"liquid_water", "liquid_lava":
			return _compile_liquid_material(def)
		_:
			return _compile_pbr_solid_material(def, block_id)


static func _compile_pbr_solid_material(def: BlockDefinition, block_id: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = def.color_top
	m.roughness = def.roughness
	m.metallic = def.metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	
	if def.is_transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		m.albedo_texture = tex
		
	_apply_emissive_settings(m, def)
	return m


static func _apply_emissive_settings(m: StandardMaterial3D, def: BlockDefinition) -> void:
	if def.is_emissive:
		m.emission_enabled = true
		m.emission = def.emission_color
		m.emission_energy_multiplier = def.emission_energy
		if m.albedo_texture != null:
			m.emission_texture = m.albedo_texture


static func _compile_foliage_material(def: BlockDefinition, block_id: int) -> ShaderMaterial:
	if _leaves_wind_shader == null:
		_leaves_wind_shader = load("res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader") as Shader
		
	var sm := ShaderMaterial.new()
	sm.shader = _leaves_wind_shader
	sm.set_shader_parameter("block_color", def.color_top)
	
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		sm.set_shader_parameter("albedo_texture", tex)
	return sm


static func _compile_liquid_material(def: BlockDefinition) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = load("res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader") as Shader
		
	var sm := ShaderMaterial.new()
	sm.shader = _water_shader
	sm.set_shader_parameter("shallow_water_color", def.color_top)
	sm.set_shader_parameter("deep_water_color", def.color_bottom)
	return sm


## Clears cache to prevent memory leaks on graphics profile changes
static func clear_factory_cache() -> void:
	_materials_cache.clear()
	_distant_materials_cache.clear()

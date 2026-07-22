# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/VoxelMaterialFactory.gd
# Description: Infrastructure Factory managing compilation, pre-warming, and
#              caching of PBR block materials, triplanar shaders, and crystal water.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelMaterialFactory
extends RefCounted

const TRIPLANAR_SHADER_PATH: String = "res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader"
const FOLIAGE_SHADER_PATH: String = "res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader"
const COLOR_DIAGNOSTIC_ERROR := Color(1.0, 0.0, 1.0)

static var _materials_cache: Dictionary = {}
static var _distant_materials_cache: Dictionary = {} 

static var _triplanar_blocks_shader: Shader
static var _leaves_wind_shader: Shader
static var _error_fallback_material: StandardMaterial3D
static var _lock: Mutex = Mutex.new()


## Pre-compiles and caches all materials into VRAM on startup.
static func warm_up_material_pipelines() -> void:
	_ensure_fallback_initialized()
	var _air := BlockLibrary.get_definition(0)
	
	for b_id: int in BlockLibrary._definitions.keys():
		var _std := get_material(b_id, false)
		var _dist := get_material(b_id, true)
		
	print("[VoxelMaterialFactory] Realistic PBR Water & Triplanar Warm-up completed.")


## Resolves and returns the PBR material from RAM cache.
static func get_material(block_id: int, is_distant: bool) -> Material:
	_ensure_fallback_initialized()
	
	var mat: Material = null
	_lock.lock()
	mat = _get_cached_distant_material(block_id) if is_distant else _get_cached_standard_material(block_id)
	_lock.unlock()
	
	return mat if mat != null else _error_fallback_material


static func _ensure_fallback_initialized() -> void:
	_lock.lock()
	if _error_fallback_material == null:
		_error_fallback_material = StandardMaterial3D.new()
		_error_fallback_material.albedo_color = COLOR_DIAGNOSTIC_ERROR
		_error_fallback_material.roughness = 1.0
	_lock.unlock()


static func _get_cached_distant_material(block_id: int) -> Material:
	if _distant_materials_cache.has(block_id):
		return _distant_materials_cache[block_id] as Material
		
	var mat := _compile_distant_material(block_id)
	if mat != null:
		_distant_materials_cache[block_id] = mat
	return mat


static func _get_cached_standard_material(block_id: int) -> Material:
	if _materials_cache.has(block_id):
		return _materials_cache[block_id] as Material
		
	var mat := _compile_standard_material(block_id)
	if mat != null:
		_materials_cache[block_id] = mat
	return mat


static func _compile_distant_material(block_id: int) -> StandardMaterial3D:
	var def := BlockLibrary.get_definition(block_id)
	if def == null: return null
	
	var d_mat := StandardMaterial3D.new()
	d_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	d_mat.albedo_color = def.color_top
	d_mat.roughness = 1.0
	if def.is_transparent:
		d_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return d_mat


static func _compile_standard_material(block_id: int) -> Material:
	var def := BlockLibrary.get_definition(block_id)
	if def == null: return null
		
	match def.rendering_type:
		"foliage": return _compile_foliage_material(def, block_id)
		"liquid_water", "liquid_lava": return _compile_liquid_material(def, block_id)
		_: return _compile_pbr_solid_material(def, block_id)


static func _compile_pbr_solid_material(def: BlockDefinition, b_id: int) -> Material:
	if _triplanar_blocks_shader == null and ResourceLoader.exists(TRIPLANAR_SHADER_PATH):
		_triplanar_blocks_shader = load(TRIPLANAR_SHADER_PATH) as Shader
		
	if _triplanar_blocks_shader != null:
		return _compile_triplanar_shader_material(def, b_id)
		
	return _compile_fallback_standard_material(def, b_id)


static func _compile_triplanar_shader_material(def: BlockDefinition, b_id: int) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = _triplanar_blocks_shader
	sm.set_shader_parameter("albedo_color", def.color_top)
	sm.set_shader_parameter("roughness", def.roughness)
	sm.set_shader_parameter("metallic", def.metallic)
	
	var tex := TextureRegistry.get_block_texture(b_id)
	if tex != null:
		sm.set_shader_parameter("texture_albedo", tex)
		
	return sm


static func _compile_fallback_standard_material(def: BlockDefinition, b_id: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = def.color_top
	m.roughness = def.roughness
	m.metallic = def.metallic
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	if def.is_transparent: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	var tex := TextureRegistry.get_block_texture(b_id)
	if tex != null: m.albedo_texture = tex
		
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
	if _leaves_wind_shader == null and ResourceLoader.exists(FOLIAGE_SHADER_PATH):
		_leaves_wind_shader = load(FOLIAGE_SHADER_PATH) as Shader
		
	var sm := ShaderMaterial.new()
	sm.shader = _leaves_wind_shader
	sm.set_shader_parameter("block_color", def.color_top)
	
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		sm.set_shader_parameter("albedo_texture", tex)
	return sm


## Restores the crystal-clear, realistic PBR water material with water.png texture.
static func _compile_liquid_material(_def: BlockDefinition, block_id: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.52, 0.85, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.12
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	
	var tex := TextureRegistry.get_block_texture(block_id)
	if tex != null:
		m.albedo_texture = tex
		
	return m


static func clear_factory_cache() -> void:
	_lock.lock()
	_materials_cache.clear()
	_distant_materials_cache.clear()
	_lock.unlock()

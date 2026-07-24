# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/VoxelMaterialFactory.gd
# Description: Infrastructure Factory managing compilation, pre-warming, and
#              caching of PBR block materials, triplanar shaders, and 
#              wind-driven ocean water materials with puddle calmness dampening.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name VoxelMaterialFactory
extends RefCounted

const TRIPLANAR_SHADER_PATH: String = "res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader"
const FOLIAGE_SHADER_PATH: String = "res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader"
const WATER_SHADER_PATH: String = "res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader"
const COLOR_DIAGNOSTIC_ERROR := Color(1.0, 0.0, 1.0)

# --- OCEAN WATER SURF CONSTANTS ---
const SHALLOW_WATER_COLOR := Color(0.12, 0.58, 0.78, 0.60)
const DEEP_WATER_COLOR := Color(0.01, 0.12, 0.32, 0.95)
const FOAM_COLOR := Color(0.96, 0.98, 1.00, 0.98)

const BASE_WAVE_AMPLITUDE: float = 0.08
const WAVE_FREQUENCY: float = 0.75
const WAVE_SPEED: float = 1.80
const WAVE_STEEPNESS: float = 1.20

const PUDDLE_DEPTH_THRESHOLD: float = 0.60
const SHORE_SWASH_REACH: float = 1.40
const EDGE_FADE_DISTANCE: float = 0.20

const FOAM_THRESHOLD: float = 0.35
const FOAM_TIGHTNESS: float = 3.00
const FOAM_NOISE_SCALE: float = 1.20

const WATER_ROUGHNESS: float = 0.03
const WATER_METALLIC: float = 0.08

static var _materials_cache: Dictionary = {}
static var _distant_materials_cache: Dictionary = {} 

static var _triplanar_blocks_shader: Shader
static var _leaves_wind_shader: Shader
static var _water_shader: Shader
static var _error_fallback_material: StandardMaterial3D

static var _water_normal_noise_texture_a: NoiseTexture2D
static var _water_normal_noise_texture_b: NoiseTexture2D
static var _lock: Mutex = Mutex.new()


## Pre-compiles and caches all materials into VRAM on startup.
static func warm_up_material_pipelines() -> void:
	_ensure_fallback_initialized()
	var _air := BlockLibrary.get_definition(0)
	
	for b_id: int in BlockLibrary._definitions.keys():
		var _std := get_material(b_id, false)
		var _dist := get_material(b_id, true)
		
	print("[VoxelMaterialFactory] Realistic Wind-Driven Water & PBR Warm-up completed.")


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


## Compiles animated wind-driven ocean water shaders with Gerstner waves and crest foam.
static func _compile_liquid_material(def: BlockDefinition, block_id: int) -> Material:
	if _water_shader == null and ResourceLoader.exists(WATER_SHADER_PATH):
		_water_shader = load(WATER_SHADER_PATH) as Shader
		
	if _water_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = _water_shader
		_apply_water_shader_uniforms(sm)
		return sm
		
	return _compile_fallback_standard_material(def, block_id)


static func _apply_water_shader_uniforms(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("shallow_water_color", SHALLOW_WATER_COLOR)
	sm.set_shader_parameter("deep_water_color", DEEP_WATER_COLOR)
	sm.set_shader_parameter("foam_color", FOAM_COLOR)
	sm.set_shader_parameter("base_wave_amplitude", BASE_WAVE_AMPLITUDE)
	sm.set_shader_parameter("wave_frequency", WAVE_FREQUENCY)
	sm.set_shader_parameter("wave_speed", WAVE_SPEED)
	sm.set_shader_parameter("wave_steepness", WAVE_STEEPNESS)
	_apply_water_secondary_uniforms(sm)


static func _apply_water_secondary_uniforms(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("puddle_depth_threshold", PUDDLE_DEPTH_THRESHOLD)
	sm.set_shader_parameter("shore_swash_reach", SHORE_SWASH_REACH)
	sm.set_shader_parameter("edge_fade_distance", EDGE_FADE_DISTANCE)
	sm.set_shader_parameter("foam_threshold", FOAM_THRESHOLD)
	sm.set_shader_parameter("foam_tightness", FOAM_TIGHTNESS)
	sm.set_shader_parameter("foam_noise_scale", FOAM_NOISE_SCALE)
	_apply_water_texture_and_pbr_uniforms(sm)


static func _apply_water_texture_and_pbr_uniforms(sm: ShaderMaterial) -> void:
	sm.set_shader_parameter("roughness_val", WATER_ROUGHNESS)
	sm.set_shader_parameter("metallic_val", WATER_METALLIC)
	sm.set_shader_parameter("normal_map_a", _get_or_create_water_noise_a())
	sm.set_shader_parameter("normal_map_b", _get_or_create_water_noise_b())


static func _get_or_create_water_noise_a() -> NoiseTexture2D:
	if _water_normal_noise_texture_a != null:
		return _water_normal_noise_texture_a
		
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	
	_water_normal_noise_texture_a = NoiseTexture2D.new()
	_water_normal_noise_texture_a.width = 512
	_water_normal_noise_texture_a.height = 512
	_water_normal_noise_texture_a.seamless = true
	_water_normal_noise_texture_a.as_normal_map = true
	_water_normal_noise_texture_a.bump_strength = 2.5
	_water_normal_noise_texture_a.noise = noise
	
	return _water_normal_noise_texture_a


static func _get_or_create_water_noise_b() -> NoiseTexture2D:
	if _water_normal_noise_texture_b != null:
		return _water_normal_noise_texture_b
		
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 101
	noise.frequency = 0.065
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	
	_water_normal_noise_texture_b = NoiseTexture2D.new()
	_water_normal_noise_texture_b.width = 512
	_water_normal_noise_texture_b.height = 512
	_water_normal_noise_texture_b.seamless = true
	_water_normal_noise_texture_b.as_normal_map = true
	_water_normal_noise_texture_b.bump_strength = 1.8
	_water_normal_noise_texture_b.noise = noise
	
	return _water_normal_noise_texture_b


static func clear_factory_cache() -> void:
	_lock.lock()
	_materials_cache.clear()
	_distant_materials_cache.clear()
	_lock.unlock()

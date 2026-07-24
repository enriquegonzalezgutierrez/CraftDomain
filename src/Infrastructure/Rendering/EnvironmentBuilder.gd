# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# Description: Builder responsible for constructing world lighting, sky,
#              atmospheric horizon fog, ground mist materials, and cinematic 
#              AgX post-processing.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

const ADAPTER_TYPE_INTEGRATED := 1
const ADAPTER_TYPE_CPU := 4
const CLOUD_TEXTURE_PATH := "res://assets/textures/sky_clouds_fbm.png"
const SKY_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader"
const MIST_SHADER_PATH := "res://src/Infrastructure/Rendering/Shaders/magical_swamp_mist.gdshader"

# Atmospheric Horizon Baseline Constants
const DEFAULT_HORIZON_FOG_COLOR := Color(0.78, 0.88, 0.95)
const LOW_END_FOG_BEGIN: float = 40.0
const LOW_END_FOG_END: float = 80.0
const HIGH_END_FOG_BEGIN: float = 65.0
const HIGH_END_FOG_END: float = 120.0


## Constructs and configures the High-Quality Directional Sun Light.
static func build_sun() -> DirectionalLight3D:
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	
	var adapter_type := RenderingServer.get_video_adapter_type()
	var is_low_end := (adapter_type == ADAPTER_TYPE_INTEGRATED or adapter_type == ADAPTER_TYPE_CPU)
	
	if is_low_end:
		_setup_low_end_sun(sun_light)
	else:
		_setup_high_end_sun(sun_light)
		
	sun_light.light_color = Color(0.99, 0.96, 0.92) 
	sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-42)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
	return sun_light


static func _setup_low_end_sun(sun_light: DirectionalLight3D) -> void:
	sun_light.shadow_enabled = false
	sun_light.light_energy = 1.2
	sun_light.light_indirect_energy = 1.0


static func _setup_high_end_sun(sun_light: DirectionalLight3D) -> void:
	sun_light.shadow_enabled = true
	sun_light.shadow_bias = 0.03
	sun_light.shadow_normal_bias = 1.2
	sun_light.shadow_blur = 1.5
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_blend_splits = true
	sun_light.directional_shadow_fade_start = 0.85
	sun_light.directional_shadow_max_distance = 80.0
	sun_light.light_energy = 1.8
	sun_light.light_indirect_energy = 2.0


## Constructs and configures the complete WorldEnvironment.
static func build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	_setup_sky_material(environment)
	
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.52, 0.62) 
	environment.ambient_light_energy = 1.45 
	
	var adapter_type := RenderingServer.get_video_adapter_type()
	var is_low_end := (adapter_type == ADAPTER_TYPE_INTEGRATED or adapter_type == ADAPTER_TYPE_CPU)
	
	if is_low_end:
		_setup_low_end_profile(environment)
	else:
		_setup_high_end_profile(environment)
		
	environment.volumetric_fog_enabled = false
	environment.ssr_enabled = false
	
	world_environment.environment = environment
	return world_environment


static func _setup_sky_material(environment: Environment) -> void:
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	
	if ResourceLoader.exists(SKY_SHADER_PATH):
		sky_material.shader = load(SKY_SHADER_PATH) as Shader
		
	if ResourceLoader.exists(CLOUD_TEXTURE_PATH):
		var noise_tex := load(CLOUD_TEXTURE_PATH) as Texture2D
		if noise_tex != null:
			sky_material.set_shader_parameter("cloud_texture", noise_tex)
	
	sky.sky_material = sky_material
	environment.sky = sky


static func _setup_low_end_profile(environment: Environment) -> void:
	environment.ssao_enabled = false
	environment.glow_enabled = false
	environment.adjustment_enabled = false
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	
	_configure_fog_parameters(environment, LOW_END_FOG_BEGIN, LOW_END_FOG_END)


static func _setup_high_end_profile(environment: Environment) -> void:
	_configure_ssao_parameters(environment)
	
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.05 
	environment.tonemap_white = 1.00
	
	_configure_glow_parameters(environment)
	_configure_fog_parameters(environment, HIGH_END_FOG_BEGIN, HIGH_END_FOG_END)
	
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08 
	environment.adjustment_saturation = 1.35


static func _configure_ssao_parameters(environment: Environment) -> void:
	environment.ssao_enabled = true
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 2.0 
	environment.ssao_power = 2.2
	environment.ssao_detail = 0.65


static func _configure_glow_parameters(environment: Environment) -> void:
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.05
	environment.glow_bloom = 0.22
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT


static func _configure_fog_parameters(environment: Environment, fog_begin: float, fog_end: float) -> void:
	environment.fog_enabled = true
	environment.fog_light_color = DEFAULT_HORIZON_FOG_COLOR
	
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = fog_begin
	environment.fog_depth_end = fog_end
	
	environment.fog_sky_affect = 0.0


## Constructs and configures a ShaderMaterial for low-lying ground mist volumes
static func build_swamp_mist_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	if ResourceLoader.exists(MIST_SHADER_PATH):
		mat.shader = load(MIST_SHADER_PATH) as Shader
		
	var noise_tex := VoxelMaterialFactory._get_or_create_water_noise_a()
	mat.set_shader_parameter("noise_tex", noise_tex)
	return mat

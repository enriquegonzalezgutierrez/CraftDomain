# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# Description: Builder responsible for constructing the world lighting, sky,
#              and post-processing. 
#              PERFORMANCE & VISUAL UPGRADE: Forced fog_sky_affect to 0.0 for 
#              crystal clear skies, and injected dedicated cloud FBM textures.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

const ADAPTER_TYPE_INTEGRATED := 1
const ADAPTER_TYPE_CPU := 4
const CLOUD_TEXTURE_PATH := "res://assets/textures/sky_clouds_fbm.png"


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


static func _get_custom_sky_shader() -> Shader:
	return load("res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader") as Shader


## Constructs and configures the complete WorldEnvironment.
static func build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	_setup_sky_material(environment)
	
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.44, 0.55) 
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
	sky_material.shader = _get_custom_sky_shader()
	
	# INJECT DEDICATED CLOUD NOISE TEXTURE
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
	
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.18, 0.22)
	
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 40.0 
	environment.fog_depth_end = 80.0   
	
	# ABSOLUTE FIX: Prevent fog from muddying the sky
	environment.fog_sky_affect = 0.0 


static func _setup_high_end_profile(environment: Environment) -> void:
	environment.ssao_enabled = true
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 2.0 
	environment.ssao_power = 2.2
	environment.ssao_detail = 0.65
	
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.15 
	environment.tonemap_white = 1.05
	
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.05
	environment.glow_bloom = 0.22
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.12, 0.15, 0.22)
	
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 65.0 
	environment.fog_depth_end = 120.0  
	
	# ABSOLUTE FIX: Prevent fog from muddying the sky
	environment.fog_sky_affect = 0.0  
	
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08 
	environment.adjustment_saturation = 1.35

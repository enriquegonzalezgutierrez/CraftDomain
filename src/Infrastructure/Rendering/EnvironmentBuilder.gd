# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# Description: Builder responsible for constructing the world lighting, sky,
#              and post-processing, optimized for desktop and mobile targets.
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

const ADAPTER_TYPE_INTEGRATED := 1
const ADAPTER_TYPE_CPU := 4

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
	
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = _get_custom_sky_shader()
	
	sky.sky_material = sky_material
	environment.sky = sky
	
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


static func _setup_low_end_profile(environment: Environment) -> void:
	environment.ssao_enabled = false
	environment.glow_enabled = false
	environment.adjustment_enabled = false
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.18, 0.22)
	# Calibración: Niebla visible a partir de ~45 metros para ocultar el límite de renderizado móvil
	environment.fog_density = 0.022 
	# Mezcla un 80% de la niebla en el horizonte para una transición esférica suave
	environment.fog_sky_affect = 0.80 


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
	# Calibración: Niebla con presencia gradual a partir de ~60 metros (visible en la línea de árboles)
	environment.fog_density = 0.016 
	# Mezcla un 72% de la niebla con el domo celeste para difuminar la silueta nítida del horizonte
	environment.fog_sky_affect = 0.72 
	
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08 
	environment.adjustment_saturation = 1.35

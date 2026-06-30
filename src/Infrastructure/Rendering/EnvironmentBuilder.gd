# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the visual environment, lighting, post-processing profiles, and skies.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates atmospheric 
#                rendering setup, delegating shader calculations to external files.
#              - Open-Closed Principle (OCP): Closed for code modifications when 
#                adjusting sky visual formulas, as they reside in .gdshader resources.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

## Constructs and configures the High-Quality Directional Sun Light.
static func build_sun() -> DirectionalLight3D:
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	
	sun_light.shadow_bias = 0.04
	sun_light.shadow_normal_bias = 1.5
	sun_light.shadow_blur = 1.2
	
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_blend_splits = true
	sun_light.directional_shadow_fade_start = 0.8
	sun_light.directional_shadow_max_distance = 150.0
	
	sun_light.light_energy = 2.6
	sun_light.light_indirect_energy = 1.5
	sun_light.light_color = Color(0.99, 0.96, 0.90) 
	
	sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-42)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
	return sun_light


## Loads and returns the compiled celestial sky shader resource.
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
	environment.ambient_light_color = Color(0.40, 0.40, 0.40) 
	environment.ambient_light_sky_contribution = 0.0 
	
	environment.ssao_enabled = true
	environment.ssao_radius = 0.45
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.8
	environment.ssao_detail = 0.5
	
	environment.ssil_enabled = true
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 1.0
	
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.25
	environment.tonemap_white = 1.0
	
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.6
	environment.glow_strength = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(0.62, 0.82, 0.98)
	
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.25
	
	world_environment.environment = environment
	return world_environment

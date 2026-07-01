# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the visual environment, lighting, post-processing profiles, and skies.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates atmospheric 
#                rendering setup, delegating shader calculations to external files.
#              - Open-Closed Principle (OCP): Closed for code modifications when 
#                adjusting sky visual formulas, as they reside in .gdshader resources.
#              OPTIMIZATIONS:
#              - Reduced directional shadow max distance to 80m to save GPU vertex throughput.
#              - Replaced heavy Volumetric Fog with fast standard Depth Fog to hide loading borders.
#              - Disabled Screen-Space Reflections (SSR) to optimize fragment shader fillrate
#                and support stable 60 FPS on GTX 1060 mid-range hardware.
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
	
	# High precision shadow parameters to eliminate block-edge flickering
	sun_light.shadow_bias = 0.03
	sun_light.shadow_normal_bias = 1.2
	sun_light.shadow_blur = 1.5
	
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_blend_splits = true
	sun_light.directional_shadow_fade_start = 0.85
	sun_light.directional_shadow_max_distance = 80.0 # Optimized shadow range
	
	# Warm, natural solar illumination
	sun_light.light_energy = 2.8
	sun_light.light_indirect_energy = 1.8
	sun_light.light_color = Color(0.99, 0.96, 0.92) 
	
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
	
	# High fidelity Ambient Light setup
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.38, 0.42) 
	environment.ambient_light_sky_contribution = 0.15 
	
	# SSAO: Deep ambient occlusion in corner crevices of blocks (Highly stable and optimized)
	environment.ssao_enabled = true
	environment.ssao_radius = 0.65
	environment.ssao_intensity = 2.8
	environment.ssao_power = 2.2
	environment.ssao_detail = 0.65
	
	# Cinematic Color Grading and Exposure (AgX profile)
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.35
	environment.tonemap_white = 1.05
	
	# Cinematic Soft Glow for emissive blocks (Lava, Neon cores)
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.55
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.15
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Atmospheric Fast Depth Fog (Extremely performant and hides borders beautifully)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.68, 0.78, 0.90) # Balanced sky blue atmosphere
	environment.fog_density = 0.012
	environment.fog_sky_affect = 0.8
	
	# Volumetric Fog: Disabled to preserve GTX 1060 rendering fillrate on long distances
	environment.volumetric_fog_enabled = false
	
	# SSR: Disabled to optimize fragment shader iterations and support high views
	environment.ssr_enabled = false
	
	# Adjustment profile for vivid colors
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 1.32
	
	world_environment.environment = environment
	return world_environment

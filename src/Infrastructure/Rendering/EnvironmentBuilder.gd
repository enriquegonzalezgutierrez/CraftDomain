# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the Next-Gen High-End visual environment nodes.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by decoupling visual shader settings from the Bootstrap.
#              FIXED: Corrected tonemap constant to TONE_MAPPER_ACES.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

## Constructs and configures the High-Quality Directional Sun Light
static func build_sun() -> DirectionalLight3D:
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	sun_light.shadow_blur = 1.5 # Softer shadows
	sun_light.directional_shadow_blend_splits = true # Smooth shadow cascade transitions
	sun_light.light_energy = 1.2 # Brighter sun
	
	# Rotate the sun to a natural high-noon angle initially
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-55)).rotated(Vector3(0, 1, 0), deg_to_rad(30))
	
	return sun_light

## Constructs and configures the WorldEnvironment with RTX-style Post-Processing
static func build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	# Sky setup
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.15, 0.45, 0.9)       
	sky_material.sky_horizon_color = Color(0.65, 0.85, 1.0)   
	sky_material.ground_bottom_color = Color(0.12, 0.12, 0.12) 
	sky_material.ground_horizon_color = Color(0.65, 0.85, 1.0)
	sky_material.sun_curve = 0.05 # Larger, softer sun flare
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	
	# =======================================================
	# RTX / NEXT-GEN SHADERS UPGRADE
	# =======================================================
	# FIXED: Corrected Godot 4 constant for Tonemapping
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.15
	environment.tonemap_white = 1.2
	
	# SSAO (Screen Space Ambient Occlusion)
	environment.ssao_enabled = true
	environment.ssao_radius = 1.2
	environment.ssao_intensity = 3.0
	environment.ssao_power = 1.5
	
	# SDFGI (Global Illumination)
	environment.sdfgi_enabled = true
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_read_sky_light = true
	environment.sdfgi_cascades = 4
	environment.sdfgi_min_cell_size = 0.5
	environment.sdfgi_bounce_feedback = 0.5
	
	# Glow (Bloom)
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 1.5
	environment.glow_strength = 0.8
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Volumetric Fog (God Rays)
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.015 
	environment.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
	environment.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	
	# Screen Space Reflections (SSR)
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	
	world_environment.environment = environment
	return world_environment

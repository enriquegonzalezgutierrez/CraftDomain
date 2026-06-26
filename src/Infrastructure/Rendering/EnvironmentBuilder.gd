# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the Next-Gen High-End visual environment nodes.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by decoupling visual shader settings from the Bootstrap.
#              FIXED: Reduced SSAO radius and intensity to match voxel scales (1x1x1m),
#              eliminating giant black splotches and replacing them with elegant
#              crevice outlines.
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
	sun_light.shadow_blur = 0.5 # Sharper shadows match Minecraft RTX perfectly
	sun_light.directional_shadow_blend_splits = true 
	sun_light.light_energy = 2.2 # Bright, crisp sun
	sun_light.light_indirect_energy = 1.5 # Strong indirect lighting for shadows
	
	# Rotate the sun to a gorgeous mid-afternoon angle (perfect for shadows and reflections)
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-45)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
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
	sky_material.sky_top_color = Color(0.25, 0.60, 1.0)       # Clear clean sky blue
	sky_material.sky_horizon_color = Color(0.70, 0.88, 1.0)   
	sky_material.ground_bottom_color = Color(0.12, 0.12, 0.15) 
	sky_material.ground_horizon_color = Color(0.70, 0.88, 1.0)
	sky_material.sun_curve = 0.04
	sky.sky_material = sky_material
	environment.sky = sky
	
	# --- ENVIRONMENT LIGHTING BALANCE ---
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35 # Mix 35% sky blue in shadows
	environment.ambient_light_color = Color(0.9, 0.95, 1.0) # Warm white filling light
	
	# =======================================================
	# RTX / NEXT-GEN SHADERS UPGRADE (100% STABLE)
	# =======================================================
	# Tonemapping (Cinematic contrast and vibrant colors)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.15
	environment.tonemap_white = 1.0
	
	# SSAO (Screen Space Ambient Occlusion)
	# FIXED: Shrinked radius to 0.4 and intensity to 1.6 to perfectly match 1x1x1m voxels,
	# preventing massive black blotches and providing thin, crisp outlines in cracks.
	environment.ssao_enabled = true
	environment.ssao_radius = 0.4 
	environment.ssao_intensity = 1.6 
	environment.ssao_power = 1.5
	
	# SSIL (Screen Space Indirect Lighting) - Gorgeous, stable color bouncing
	environment.ssil_enabled = true
	environment.ssil_radius = 2.0
	environment.ssil_intensity = 1.5
	
	# Glow (Bloom)
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 1.2
	environment.glow_strength = 0.8
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# Volumetric Fog (Subtle, clear atmosphere)
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.005 
	environment.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
	
	# Screen Space Reflections (SSR) - Water reflections
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	
	# Color Adjustments (Vibrant colors like the reference image!)
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.35 # Saturated and cheerful colors
	
	world_environment.environment = environment
	return world_environment

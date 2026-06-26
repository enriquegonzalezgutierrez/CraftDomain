# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the Next-Gen High-End visual environment nodes.
#              SOLID COMPLIANCE: Adheres strictly to the Single Responsibility 
#              Principle (SRP) by decoupling visual shader settings from the Bootstrap.
#              FIXED: Balanced general lighting and exposure to prevent over-brightness.
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
	
	# OPTIMIZED: Set light energy to 1.1 to prevent over-brightness/washing out
	sun_light.light_energy = 1.1 
	sun_light.light_indirect_energy = 1.0 # Softer indirect lighting bounces
	
	# Hides the buggy, black-clipping procedural sun disk from the sky dome.
	sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	
	# Rotate the sun to a gorgeous mid-afternoon angle
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-45)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
	return sun_light

## Constructs and configures the WorldEnvironment with RTX-style Post-Processing
static func build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	# Sky setup (Vibrant daylight gradients)
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.20, 0.55, 1.0)       # Clear beautiful sky blue
	sky_material.sky_horizon_color = Color(0.65, 0.85, 1.0)   
	sky_material.ground_bottom_color = Color(0.12, 0.12, 0.15) 
	sky_material.ground_horizon_color = Color(0.65, 0.85, 1.0)
	
	sky_material.sun_curve = 0.12
	sky.sky_material = sky_material
	environment.sky = sky
	
	# --- ENVIRONMENT LIGHTING BALANCE ---
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.3 # Mix 30% sky blue in shadows
	environment.ambient_light_color = Color(0.9, 0.9, 0.95) # Balanced filling light
	
	# =======================================================
	# RTX / NEXT-GEN SHADERS UPGRADE (100% STABLE)
	# =======================================================
	# Tonemapping (Cinematic contrast and vibrant colors)
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	# OPTIMIZED: Lowered exposure to 0.9 to prevent washed-out bright areas
	environment.tonemap_exposure = 0.9
	environment.tonemap_white = 1.0
	
	# SSAO (Screen Space Ambient Occlusion)
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
	environment.glow_intensity = 1.0 # Slightly softer glow
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
	# OPTIMIZED: Slightly lowered saturation to 1.2 to prevent neon/glowing blocks
	environment.adjustment_saturation = 1.2 
	
	world_environment.environment = environment
	return world_environment

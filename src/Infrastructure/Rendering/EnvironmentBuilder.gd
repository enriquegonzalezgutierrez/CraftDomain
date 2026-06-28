# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the visual environment, lighting, and post-processing.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Strictly isolates visual 
#                and atmospheric setup from the Bootstrap core.
#              FIXED: Completely decoupled the ambient lighting from the procedural 
#              sky, using a strict neutral grey color. This prevents shadows from 
#              tinting white voxels (snow, clouds, cows, chickens) with a blue hue.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

## Constructs and configures the High-Quality Directional Sun Light with warm solar color.
static func build_sun() -> DirectionalLight3D:
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	sun_light.shadow_enabled = true
	
	# Optimize shadow map filtering and bias to prevent peter-panning and shadow acne on voxels
	sun_light.shadow_bias = 0.04
	sun_light.shadow_normal_bias = 1.5
	sun_light.shadow_blur = 1.2
	
	# Configure professional-grade shadow cascades for clear close-range details and stable far-range silhouettes
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun_light.directional_shadow_blend_splits = true
	sun_light.directional_shadow_fade_start = 0.8
	sun_light.directional_shadow_max_distance = 150.0
	
	# Boosted sun light energy and set a warm golden-white color to balance shadows
	sun_light.light_energy = 2.6
	sun_light.light_indirect_energy = 1.5
	sun_light.light_color = Color(0.99, 0.96, 0.90) # Warm, realistic sunlight color
	
	# Restrict sky rendering on the light source to avoid artifacts
	sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	
	# Set a dramatic mid-afternoon default angle
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-42)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
	return sun_light

## Constructs and configures the WorldEnvironment with balanced ambient lighting.
static func build_environment() -> WorldEnvironment:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	# Sky Setup with rich daylight gradients
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.18, 0.52, 0.92)       # Vibrant sky blue
	sky_material.sky_horizon_color = Color(0.62, 0.82, 0.98)   # Clear horizon
	sky_material.ground_bottom_color = Color(0.10, 0.10, 0.12) # Dark ground
	sky_material.ground_horizon_color = Color(0.62, 0.82, 0.98)
	sky_material.sun_curve = 0.15
	
	sky.sky_material = sky_material
	environment.sky = sky
	
	# ======================================================================
	# FIX: NEUTRALIZED AMBIENT LIGHT (Global PBR Correction)
	# Decoupled the ambient source from the sky to use a solid neutral color.
	# This ensures that shadows remain dark grey instead of tinting white voxels blue.
	# ======================================================================
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.40, 0.40, 0.40) # Neutral balanced grey
	environment.ambient_light_sky_contribution = 0.0 # Completely disable sky bleeding into shadows
	
	# ======================================================================
	# HIGH-END GRAPHICS UPGRADES (Godot 4.6+ AgX & SSAO Voxel-Optimized)
	# ======================================================================
	
	# NOTE: SDFGI is disabled to prevent dynamic chunk loading from creating dark areas.
	environment.sdfgi_enabled = false
	
	# 1. SSAO (Screen Space Ambient Occlusion) - Dark crevice shadowing
	environment.ssao_enabled = true
	environment.ssao_radius = 0.45
	environment.ssao_intensity = 2.2
	environment.ssao_power = 1.8
	environment.ssao_detail = 0.5
	
	# 2. SSIL (Screen Space Indirect Lighting) - High-frequency color bleeding
	environment.ssil_enabled = true
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 1.0
	
	# 3. AgX Tonemapping for state-of-the-art color preservation
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_exposure = 1.25
	environment.tonemap_white = 1.0
	
	# 4. Soft Bloom Glow
	environment.glow_enabled = true
	environment.glow_normalized = true
	environment.glow_intensity = 0.6
	environment.glow_strength = 0.85
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	
	# 5. Volumetric Atmosphere Fog - Seamless horizontal block clipping
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(0.62, 0.82, 0.98)
	
	# 6. Screen Space Reflections (SSR)
	environment.ssr_enabled = true
	environment.ssr_max_steps = 64
	
	# 7. Adjustments: Vivid saturation boost and deep contrast
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 1.25
	
	world_environment.environment = environment
	return world_environment

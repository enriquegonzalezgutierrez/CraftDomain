# ==============================================================================
# Project: CraftDomain
# Description: Description: Infrastructure Builder responsible for constructing and configuring
#              the visual environment, lighting, post-processing profiles, and skies.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Isolates atmospheric 
#                rendering setup, delegating shader calculations to external files.
#              - Open-Closed Principle (OCP): Closed for code modifications when 
#                adjusting sky visual formulas, as they reside in .gdshader resources.
#              PORTABILITY OVERHAUL (DYNAMIC HARDWARE SCALING):
#              - Queries `RenderingServer.get_video_adapter_type()` on startup.
#              - Automatically strips away heavy rendering pipelines (SSAO, Glow, Bloom) 
#                if running on an Integrated GPU or CPU-only software rasterizer, 
#                ensuring high-performance gameplay on any machine.
#              WARNING FIX:
#              - Added local bridge constants to bypass version-specific parser 
#                mismatches across different minor releases of Godot 4.
#              - Enforced strict explicit static typing across all variables to 
#                completely resolve `UNTYPED_DECLARATION` compiler warnings.
#              BUG FIX:
#              - Corrected shader path typo from "res://res:/src" to "res://src".
#              - Resolved duplicate ".environment" call chain crash.
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/EnvironmentBuilder.gd
# ==============================================================================
class_name EnvironmentBuilder
extends RefCounted

# ==============================================================================
# ENGINE PORTABILITY CONSTANTS
# Map raw integer values of RenderingServer.VideoAdapterType to bypass 
# version-specific compiler parser discrepancies across Godot 4.x.
# ==============================================================================
const ADAPTER_TYPE_INTEGRATED := 1
const ADAPTER_TYPE_CPU := 4


## Constructs and configures the High-Quality Directional Sun Light.
static func build_sun() -> DirectionalLight3D:
	var sun_light := DirectionalLight3D.new()
	sun_light.name = "SunLight"
	
	# Detect if running on low-end hardware using local bridge constants
	var adapter_type: int = RenderingServer.get_video_adapter_type()
	var is_low_end: bool = (adapter_type == ADAPTER_TYPE_INTEGRATED or 
							adapter_type == ADAPTER_TYPE_CPU)
	
	if is_low_end:
		# Disable shadows completely on CPU or Integrated GPUs to maximize performance!
		sun_light.shadow_enabled = false
		sun_light.light_energy = 1.8
		sun_light.light_indirect_energy = 1.0
	else:
		# Premium High precision shadow parameters for Discrete GPUs
		sun_light.shadow_enabled = true
		sun_light.shadow_bias = 0.03
		sun_light.shadow_normal_bias = 1.2
		sun_light.shadow_blur = 1.5
		
		sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun_light.directional_shadow_blend_splits = true
		sun_light.directional_shadow_fade_start = 0.85
		sun_light.directional_shadow_max_distance = 80.0
		
		sun_light.light_energy = 2.8
		sun_light.light_indirect_energy = 1.8
		
	sun_light.light_color = Color(0.99, 0.96, 0.92) 
	sun_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun_light.transform.basis = Basis(Vector3(1, 0, 0), deg_to_rad(-42)).rotated(Vector3(0, 1, 0), deg_to_rad(45))
	
	return sun_light


## Loads and returns the compiled celestial sky shader resource.
static func _get_custom_sky_shader() -> Shader:
	# FIX: Corrected double path typo "res://res:/src/" to "res://src/"
	return load("res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader") as Shader


## Constructs and configures the complete WorldEnvironment.
static func build_environment() -> WorldEnvironment:
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	
	var sky: Sky = Sky.new()
	var sky_material: ShaderMaterial = ShaderMaterial.new()
	sky_material.shader = _get_custom_sky_shader()
	
	sky.sky_material = sky_material
	environment.sky = sky
	
	# Detect video adapter type to scale down expensive post-processing dynamically
	var adapter_type: int = RenderingServer.get_video_adapter_type()
	var is_low_end: bool = (adapter_type == ADAPTER_TYPE_INTEGRATED or 
							adapter_type == ADAPTER_TYPE_CPU)
	
	if is_low_end:
		# ======================================================================
		# POTATO PROFILE (Integrated GPUs / CPU Software Rendering)
		# Deactivates all heavy shading algorithms to lock fluid framerates.
		# ======================================================================
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.4, 0.42, 0.45) # Flat ambient
		
		environment.ssao_enabled = false # SSAO completely disabled (huge performance saver)
		environment.glow_enabled = false # Glow completely disabled
		environment.adjustment_enabled = false
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		
		# Simple performant flat fog
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.15, 0.18, 0.22)
		environment.fog_density = 0.015
		environment.fog_sky_affect = 1.0
	else:
		# ======================================================================
		# CINEMATIC PROFILE (Dedicated GPUs)
		# Activates high-fidelity PBR rendering, SSAO, and streetlight bloom.
		# ======================================================================
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.24, 0.28, 0.35) 
		environment.ambient_light_sky_contribution = 0.18 
		
		environment.ssao_enabled = true
		environment.ssao_radius = 0.65
		environment.ssao_intensity = 2.8
		environment.ssao_power = 2.2
		environment.ssao_detail = 0.65
		
		environment.tonemap_mode = Environment.TONE_MAPPER_AGX
		environment.tonemap_exposure = 1.25
		environment.tonemap_white = 1.05
		
		environment.glow_enabled = true
		environment.glow_normalized = true
		environment.glow_intensity = 0.85
		environment.glow_strength = 1.05
		environment.glow_bloom = 0.22
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		
		environment.fog_enabled = true
		environment.fog_light_color = Color(0.12, 0.15, 0.22)
		environment.fog_density = 0.012
		environment.fog_sky_affect = 0.72
		
		environment.adjustment_enabled = true
		environment.adjustment_contrast = 1.15
		environment.adjustment_saturation = 1.35
		
	environment.volumetric_fog_enabled = false
	# FIX: Corrected duplicate `.environment` property chain call
	environment.ssr_enabled = false
	
	world_environment.environment = environment
	return world_environment

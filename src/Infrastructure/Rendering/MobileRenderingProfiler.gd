# ==============================================================================
# Pathfile: res://src/Infrastructure/Rendering/MobileRenderingProfiler.gd
# Description: Infrastructure Service responsible for dynamically optimizing
#              and scaling graphic rendering pipelines on mobile GPUs (LSP).
# Author: Enrique González Gutiérrez
# Email: enrique.gonzalez.gutierrez@gmail.com
# ==============================================================================
class_name MobileRenderingProfiler
extends RefCounted

# Scaled performance parameters for mobile constraints (Section 5.3)
const MOBILE_VIEW_DISTANCE: int = 5          # Restrict mobile rendering grid
const MOBILE_SHADOW_MAX_DISTANCE: float = 35.0 # Pull shadow maps closer to save fillrate
const MOBILE_SHADOW_ATLAS_SIZE: int = 512    # Drop shadow atlas size (low memory footprints)


## Evaluates active hardware and dynamically applies aggressive mobile optimizations.
## Called by the Bootstrap composition root during environment setup.
static func configure_mobile_rendering(sun_light: DirectionalLight3D, env: Environment) -> void:
	var is_mobile := OS.has_feature("mobile")
	
	if not is_mobile:
		return # Skip mobile profiles on high-end desktop hardware
		
	print("[RenderingProfiler] Mobile platform detected. Scaling pipelines down to sustain 120 FPS...")
	
	_optimize_directional_sun_shadows(sun_light)
	_optimize_environment_post_processing(env)
	_apply_viewport_downscaling()


static func _optimize_directional_sun_shadows(sun_light: DirectionalLight3D) -> void:
	if not is_instance_valid(sun_light):
		return
		
	# Disable directional shadows completely on low-end mobile devices to save massive bandwidth
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# Only keep shadow on high-tier mobile devices, otherwise strip them
		var processor_count := OS.get_processor_count()
		if processor_count < 6: # Less than 6 cores represents budget devices
			sun_light.shadow_enabled = false
			print("[RenderingProfiler] Low-tier mobile CPU detected. Disabled Sun directional shadows.")
			return
			
	sun_light.directional_shadow_max_distance = MOBILE_SHADOW_MAX_DISTANCE
	sun_light.shadow_blur = 0.5 # Sharper, low-blur shadow maps to save GPU cycles
	print("[RenderingProfiler] Calibrated Sun directional shadows for mobile: ", MOBILE_SHADOW_MAX_DISTANCE, "m")


static func _optimize_environment_post_processing(env: Environment) -> void:
	if env == null:
		return
		
	# Strip heavy post-processing passes (SSAO, Glow, SSR, Volumetric Fog)
	env.ssao_enabled = false
	env.glow_enabled = false
	env.ssr_enabled = false
	env.volumetric_fog_enabled = false
	
	# Apply fast linear tonemapping instead of expensive cinematic filmic AgX curve
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	
	# Restrict view distance grid in ChunkLoader
	ChunkLoaderService.global_view_distance = MOBILE_VIEW_DISTANCE
	print("[RenderingProfiler] Disabled cinematic post-processing on mobile. Slashed view distance to: ", MOBILE_VIEW_DISTANCE)


static func _apply_viewport_downscaling() -> void:
	# Force mobile viewport scale down to 512 for low-end shadow atlas
	RenderingServer.directional_shadow_atlas_set_size(MOBILE_SHADOW_ATLAS_SIZE, true)

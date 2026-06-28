# ==============================================================================
# Project: CraftDomain
# Description: Infrastructure Builder responsible for constructing and configuring
#              the visual environment, lighting, and post-processing.
#              SOLID COMPLIANCE: 
#              - Single Responsibility Principle (SRP): Strictly isolates visual 
#                and atmospheric setup from the Bootstrap core.
#              UPDATED: Replaced the basic sky shader with an advanced, procedural
#              weather-integrated Sky Shader. Features flat-ceiling projected 
#              clouds generated entirely via GPU fractal noise (FBM) with zero 
#              texture dependencies. Added support for dynamic `storm_weight` 
#              to darken the sky, thicken clouds, and dim celestial disks during rain/snow.
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

## Compiles and caches our custom, weather-integrated procedural Sky Shader.
static func _get_custom_sky_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
	shader_type sky;

	uniform vec3 sky_top_color : source_color = vec3(0.12, 0.45, 0.92);
	uniform vec3 sky_horizon_color : source_color = vec3(0.62, 0.82, 0.98);
	uniform vec3 sky_bottom_color : source_color = vec3(0.04, 0.04, 0.06);

	uniform vec3 night_top_color : source_color = vec3(0.01, 0.01, 0.05);
	uniform vec3 night_horizon_color : source_color = vec3(0.04, 0.04, 0.12);
	
	uniform vec3 storm_sky_top : source_color = vec3(0.15, 0.18, 0.22);
	uniform vec3 storm_sky_horizon : source_color = vec3(0.28, 0.32, 0.36);

	uniform float sun_size : hint_range(0.01, 0.2) = 0.055;
	uniform float sun_blur : hint_range(0.01, 0.5) = 0.07;
	uniform float moon_size : hint_range(0.01, 0.2) = 0.045;

	// Deterministic Uniforms injected from the Celestial clock
	uniform float day_weight : hint_range(0.0, 1.0) = 1.0;
	uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
	uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
	
	// Weather Uniform: Injected dynamically during rain or snow
	uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;

	// Procedural 2D Noise hash
	float hash22(vec2 p) {
		p = fract(p * vec2(127.1, 311.7));
		return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	}

	// 2D Value Noise for cloud generation
	float noise(vec2 uv) {
		vec2 i = floor(uv);
		vec2 f = fract(uv);
		f = f * f * (3.0 - 2.0 * f); // Smooth cubic interpolation
		
		float a = hash22(i);
		float b = hash22(i + vec2(1.0, 0.0));
		float c = hash22(i + vec2(0.0, 1.0));
		float d = hash22(i + vec2(1.0, 1.0));
		
		return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	}

	// 3-Octave Fractional Brownian Motion for fluffy cloud textures
	float fbm(vec2 uv) {
		float value = 0.0;
		float amplitude = 0.5;
		for (int j = 0; j < 3; j++) {
			value += amplitude * noise(uv);
			uv *= 2.0;
			amplitude *= 0.5;
		}
		return value;
	}

	// Pseudo-random 3D noise for rendering stars
	float hash3d(vec3 p) {
		p = fract(p * vec3(443.8975, 397.2973, 491.1871));
		p += dot(p.xyz, p.yzx + 19.19);
		return fract(p.x * p.y * p.z);
	}

	void sky() {
		vec3 dir = EYEDIR;
		float horizon = clamp(dir.y, 0.0, 1.0);
		
		// 1. Atmosphere Base color (Day vs Night)
		vec3 day_sky = mix(sky_horizon_color, sky_top_color, horizon);
		vec3 night_sky = mix(night_horizon_color, night_top_color, horizon);
		vec3 ambient_sky = mix(night_sky, day_sky, day_weight);
		
		// 2. Weather Overcast (Blend into plomizo slate-grey during rain/snow)
		vec3 storm_sky = mix(storm_sky_horizon, storm_sky_top, horizon);
		vec3 base_sky_color = mix(ambient_sky, storm_sky, storm_weight * day_weight);
		
		if (dir.y < 0.0) {
			base_sky_color = sky_bottom_color;
		}
		
		// 3. Twinkling Starfield (hidden during day and thick storms)
		float star_visibility = (1.0 - day_weight) * (1.0 - storm_weight);
		if (dir.y > 0.0 && star_visibility > 0.05) {
			float angle = TIME * 0.015;
			float c = cos(angle);
			float s = sin(angle);
			vec3 rotated_dir = vec3(dir.x * c - dir.z * s, dir.y, dir.x * s + dir.z * c);
			
			vec3 grid = floor(rotated_dir * 150.0);
			float n = hash3d(grid);
			if (n > 0.996) {
				float twinkle = sin(TIME * 3.5 + n * 80.0) * 0.4 + 0.6;
				base_sky_color += vec3(twinkle) * star_visibility * 0.9;
			}
		}
		
		// 4. Draw Glowing Sun Disk (dimmed significantly during storms)
		float sun_visibility = day_weight * (1.0 - storm_weight * 0.85);
		float dist_sun = distance(dir, sun_direction);
		if (dist_sun < sun_size + sun_blur) {
			float sun_intensity = 1.0 - smoothstep(sun_size, sun_size + sun_blur, dist_sun);
			base_sky_color = mix(base_sky_color, vec3(1.3, 1.15, 0.9) * 2.0, sun_intensity * sun_visibility);
		}
		
		// 5. Draw Moon Crescent (dimmed significantly during storms)
		float moon_visibility = (1.0 - day_weight) * (1.0 - storm_weight * 0.85);
		float dist_moon = distance(dir, moon_direction);
		if (dist_moon < moon_size && moon_visibility > 0.05) {
			float moon_mask = 1.0 - smoothstep(moon_size - 0.005, moon_size, dist_moon);
			vec3 offset_dir = moon_direction + vec3(0.015, 0.015, 0.0);
			float dist_cut = distance(dir, offset_dir);
			float cut_mask = 1.0 - smoothstep(moon_size - 0.005, moon_size, dist_cut);
			
			float crescent = clamp(moon_mask - cut_mask, 0.0, 1.0);
			base_sky_color = mix(base_sky_color, vec3(0.85, 0.92, 1.0) * 1.5, crescent * moon_visibility);
		}
		
		// 6. DRAW PROCEDURAL CLOUDS (Perspective flat-ceiling projection)
		if (dir.y > 0.0) {
			// Prevent division by zero near the horizon
			float denom = max(dir.y, 0.01);
			vec2 cloud_uv = (dir.xz / denom) * 0.4 + vec2(TIME * 0.012, TIME * 0.008);
			
			// Generate procedural FBM noise
			float cloud_noise = fbm(cloud_uv);
			
			// Dynamic cloud density: increases during storms, fades near horizon
			float target_density = mix(0.42, 0.15, storm_weight); // Thicker coverage when raining
			float fade = pow(horizon, 0.6);
			float cloud_mask = smoothstep(target_density, 1.0, cloud_noise) * fade;
			
			if (cloud_mask > 0.01) {
				// Dynamic cloud coloring:
				// - Sunset: Warm orange-pink tones
				// - Storm: Heavy dark charcoal grey
				// - Night: Deep slate-blue
				vec3 sun_sunset_color = vec3(1.0, 0.45, 0.2) * clamp(1.0 - abs(sun_direction.y * 3.0), 0.0, 1.0);
				vec3 normal_cloud_color = mix(vec3(0.08, 0.08, 0.15), vec3(1.0) + sun_sunset_color, day_weight);
				vec3 storm_cloud_color = vec3(0.25, 0.25, 0.28);
				
				vec3 final_cloud_color = mix(normal_cloud_color, storm_cloud_color, storm_weight * day_weight);
				
				// Blend clouds onto the background sky
				base_sky_color = mix(base_sky_color, final_cloud_color, cloud_mask * 0.85);
			}
		}
		
		COLOR = base_sky_color;
	}
	"""
	return shader

## Constructs and configures the WorldEnvironment.
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
	
	environment.sdfgi_enabled = false
	
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

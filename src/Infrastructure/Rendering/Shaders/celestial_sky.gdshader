// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// Description: High-performance camera-centered planar sky shader.
//              Eliminates zenith UV pinching and polar seams completely.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type sky;

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;

uniform float day_weight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float aurora_intensity : hint_range(0.0, 1.0) = 0.0;

// Global uniforms synchronized from WeatherService / Engine:
global uniform vec2 wind_offset;
global uniform float wind_strength;

void sky() {
	// --------------------------------------------------------------------------
	// 1. BASE ATMOSPHERIC GRADIENTS (Day / Sunset / Night)
	// --------------------------------------------------------------------------
	vec3 col_day_zenith = vec3(0.18, 0.52, 0.92);
	vec3 col_day_horizon = vec3(0.78, 0.88, 0.95);
	vec3 col_sunset_horizon = vec3(0.98, 0.52, 0.22);
	vec3 col_night_zenith = vec3(0.01, 0.02, 0.05);
	vec3 col_night_horizon = vec3(0.04, 0.06, 0.12);
	vec3 col_storm_horizon = vec3(0.12, 0.13, 0.16);

	float sky_height = max(EYEDIR.y, 0.0);
	
	vec3 day_sky = mix(col_day_horizon, col_day_zenith, pow(sky_height, 0.6));
	vec3 night_sky = mix(col_night_horizon, col_night_zenith, pow(sky_height, 0.6));
	
	// Sunset glow transition
	float sun_elevation = clamp(dot(sun_direction, vec3(0.0, 1.0, 0.0)), -0.2, 0.2);
	float sunset_factor = (1.0 - abs(sun_elevation) / 0.2) * day_weight;
	day_sky = mix(day_sky, col_sunset_horizon, sunset_factor * 0.75);
	
	vec3 final_sky = mix(night_sky, day_sky, day_weight);
	final_sky = mix(final_sky, col_storm_horizon, storm_weight * 0.85);

	// --------------------------------------------------------------------------
	// 2. CELESTIAL BODIES (Sun & Moon Disks)
	// --------------------------------------------------------------------------
	float sun_disk = smoothstep(0.9992, 0.9998, dot(EYEDIR, normalize(sun_direction))) * day_weight;
	vec3 sun_color = vec3(1.0, 0.95, 0.85) * 5.0;
	
	float moon_disk = smoothstep(0.9990, 0.9996, dot(EYEDIR, normalize(moon_direction))) * (1.0 - day_weight);
	vec3 moon_color = vec3(0.9, 0.95, 1.0) * 3.0;
	
	final_sky += sun_disk * sun_color;
	final_sky += moon_disk * moon_color;

	// --------------------------------------------------------------------------
	// 3. SEAMLESS PLANAR CLOUD PROJECTION (Fixes Zenith Pinch & Cuts)
	// --------------------------------------------------------------------------
	if (EYEDIR.y > 0.001) {
		// Planar projection onto a ceiling layer at Y=1.0
		float planar_scale = 1.0 / max(EYEDIR.y, 0.06);
		vec2 cloud_uv = EYEDIR.xz * planar_scale * 0.06;
		
		// Apply dynamic wind vector offset
		vec2 move_offset = wind_offset * 0.02;
		cloud_uv += move_offset;

		// Dual-layer FBM noise sampling for organic depth
		float noise_layer_a = texture(cloud_texture, cloud_uv).r;
		float noise_layer_b = texture(cloud_texture, cloud_uv * 1.7 - move_offset * 0.4).r;
		float combined_noise = mix(noise_layer_a, noise_layer_b, 0.35);

		// Coverage threshold & softness
		float cutoff = 1.0 - (cloud_coverage * 0.85);
		float cloud_alpha = smoothstep(cutoff, cutoff + 0.28, combined_noise);

		// Horizon distance fade (Prevents sharp line at EYEDIR.y -> 0)
		float horizon_fade = smoothstep(0.01, 0.22, EYEDIR.y);
		cloud_alpha *= horizon_fade;

		// Cloud Color Shading & Ambient Lighting
		vec3 cloud_light_day = vec3(0.98, 0.98, 1.0);
		vec3 cloud_shadow_day = vec3(0.60, 0.65, 0.75);
		vec3 cloud_night = vec3(0.08, 0.10, 0.18);

		vec3 lit_cloud = mix(cloud_shadow_day, cloud_light_day, day_weight);
		lit_cloud = mix(lit_cloud, cloud_night, (1.0 - day_weight) * 0.85);
		lit_cloud = mix(lit_cloud, vec3(0.20, 0.22, 0.25), storm_weight);

		final_sky = mix(final_sky, lit_cloud, cloud_alpha);
	}

	COLOR = final_sky;
}
// ==============================================================================
# Shader: Celestial Sky and Orbits
# Description: Custom sky shader managing day/night gradient blending, sun and
#              moon disk drawing, twinkling stars, and weather overcast cloud
#              density.
# SOLID COMPLIANCE: Focused solely on sky dome rendering (SRP compliant).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
# ==============================================================================
shader_type sky;

// Celestial orbits vectors passed from CelestialService.gd
uniform vec3 sun_direction;
uniform vec3 moon_direction;
uniform float day_weight : hint_range(0.0, 1.0) = 0.5;
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;

// Pseudo-random hash function to generate deterministic coordinate noise
float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

// Simple Fractional Brownian Motion (FBM) cloud noise
float cloud_noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	float a = hash(vec3(i, 0.0));
	float b = hash(vec3(i + vec2(1.0, 0.0), 0.0));
	float c = hash(vec3(i + vec2(0.0, 1.0), 0.0));
	float d = hash(vec3(i + vec2(1.0, 1.0), 0.0));
	
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void sky() {
	vec3 dir = EYEDIR;
	
	// ==========================================================================
	// 1. SKY DAY/NIGHT GRADIENT COMPOSITION
	// ==========================================================================
	// Day palette (Bright sky-blue to warm horizon teal)
	vec3 day_zenith = vec3(0.18, 0.52, 0.85);
	vec3 day_horizon = vec3(0.45, 0.72, 0.92);
	vec3 day_sky = mix(day_horizon, day_zenith, max(0.0, dir.y));
	
	// Night palette (Deep stellar navy space to black twilight)
	vec3 night_zenith = vec3(0.01, 0.01, 0.04);
	vec3 night_horizon = vec3(0.03, 0.03, 0.06);
	vec3 night_sky = mix(night_horizon, night_zenith, max(0.0, dir.y));
	
	// Blend day and night sky gradients based on celestial sun altitude weight
	vec3 base_sky = mix(night_sky, day_sky, day_weight);
	
	// Storm palette: fade sky color to slate-grey storm clouds
	vec3 storm_color = vec3(0.14, 0.15, 0.18);
	base_sky = mix(base_sky, storm_color, storm_weight * 0.85);

	// ==========================================================================
	// 2. SUN DISK INJECTION (Glow circle)
	// ==========================================================================
	float sun_dot = dot(dir, normalize(sun_direction));
	float sun_disk = smoothstep(0.992, 0.995, sun_dot);
	float sun_halo = smoothstep(0.95, 0.995, sun_dot) * 0.32;
	
	// Golden-white incandescent sun colors
	vec3 sun_color = vec3(1.0, 0.96, 0.90) * sun_disk + vec3(1.0, 0.75, 0.35) * sun_halo;
	
	// Dim sun during storm overcast
	sun_color *= (1.0 - storm_weight * 0.85);

	// ==========================================================================
	// 3. MOON DISK INJECTION (Crescent Moon)
	// ==========================================================================
	float moon_dot = dot(dir, normalize(moon_direction));
	
	// Main silver moon disk
	float moon_disk = smoothstep(0.993, 0.995, moon_dot);
	
	// Crescent ocluder shadow: offset dot calculation to subtract a crescent slice
	vec3 shadow_offset_dir = normalize(moon_direction + vec3(0.012, 0.0, 0.012));
	float moon_shadow_dot = dot(dir, shadow_offset_dir);
	float moon_shadow = smoothstep(0.993, 0.995, moon_shadow_dot);
	
	// Subtract shadow slice to form a perfect crescent Moon shape
	float crescent_moon = clamp(moon_disk - moon_shadow, 0.0, 1.0);
	float moon_halo = smoothstep(0.96, 0.995, moon_dot) * 0.15;
	
	vec3 moon_color = vec3(0.90, 0.92, 0.98) * crescent_moon + vec3(0.65, 0.75, 1.0) * moon_halo;
	
	// Dim moon during day and storm overcast
	moon_color *= (1.0 - day_weight) * (1.0 - storm_weight * 0.9);

	// ==========================================================================
	// 4. TWINKLING STARFIELD (Only visible at night)
	// ==========================================================================
	vec3 stars_color = vec3(0.0);
	if (day_weight < 0.95 && storm_weight < 0.9) {
		// Calculate rotating stellar positions to simulate planetary rotations
		float rotate_angle = TIME * 0.01;
		mat3 rot_matrix = mat3(
			vec3(cos(rotate_angle), 0.0, sin(rotate_angle)),
			vec3(0.0, 1.0, 0.0),
			vec3(-sin(rotate_angle), 0.0, cos(rotate_angle))
		);
		vec3 star_dir = rot_matrix * dir;
		
		// Generate high frequency noise based on rotated positions
		float star_noise = hash(floor(star_dir * 180.0));
		if (star_noise > 0.994 && star_dir.y > 0.05) {
			// Twinkle frequency based on sine wave time modulation
			float twinkle = sin(TIME * 6.5 + star_noise * 100.0) * 0.4 + 0.6;
			stars_color = vec3(0.92, 0.95, 1.0) * twinkle * (1.0 - day_weight) * (1.0 - storm_weight);
		}
	}

	// ==========================================================================
	// 5. PROCEDURAL CLOUD COVER
	// ==========================================================================
	vec2 cloud_uv = dir.xz / (max(0.02, dir.y) + 0.12) * 0.15 + vec2(TIME * 0.008, 0.0);
	float n = cloud_noise(cloud_uv) * 0.5 + cloud_noise(cloud_uv * 2.0) * 0.25;
	
	// Cloud thickness rises dynamically as storm weight increases
	float cloud_threshold = mix(0.48, 0.18, storm_weight);
	float cloud_alpha = smoothstep(cloud_threshold, cloud_threshold + 0.15, n) * max(0.0, dir.y);
	
	// Blend dark cloud shapes over the sky output
	vec3 cloud_color_blend = mix(vec3(0.95, 0.95, 0.98), vec3(0.28, 0.29, 0.32), storm_weight);
	
	vec3 sky_output = base_sky + sun_color + moon_color + stars_color;
	sky_output = mix(sky_output, cloud_color_blend, cloud_alpha * 0.72);

	COLOR = sky_output;
}
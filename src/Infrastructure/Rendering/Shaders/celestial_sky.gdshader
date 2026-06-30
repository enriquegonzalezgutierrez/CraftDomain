// ==============================================================================
// Project: CraftDomain
// Description: Custom procedural celestial sky shader. 
//              Interprets astronomical day/night gradients, displays crescent moons, Twinkles a rotating 3D starfield, 
//              and renders wind-blown clouds on a flat ceiling using GPU Fractal Brownian Motion.
// SOLID COMPLIANCE:
// - Single Responsibility Principle (SRP): Handles exclusively celestial 
//   render calculations, completely decoupled from active physical clocks.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// ==============================================================================
shader_type sky;

// Day Colors
uniform vec3 sky_top_color : source_color = vec3(0.12, 0.45, 0.92);
uniform vec3 sky_horizon_color : source_color = vec3(0.62, 0.82, 0.98);
uniform vec3 sky_bottom_color : source_color = vec3(0.04, 0.04, 0.06);

// Night Colors
uniform vec3 night_top_color : source_color = vec3(0.01, 0.01, 0.05);
uniform vec3 night_horizon_color : source_color = vec3(0.04, 0.04, 0.12);

// Storm Colors (Overcast)
uniform vec3 storm_sky_top : source_color = vec3(0.15, 0.18, 0.22);
uniform vec3 storm_sky_horizon : source_color = vec3(0.28, 0.32, 0.36);

// Sizing
uniform float sun_size : hint_range(0.01, 0.2) = 0.055;
uniform float sun_blur : hint_range(0.01, 0.5) = 0.07;
uniform float moon_size : hint_range(0.01, 0.2) = 0.045;

// Dynamic parameters injected from the physical CelestialService clock
uniform float day_weight : hint_range(0.0, 1.0) = 1.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);

// Weather parameters injected from WeatherService
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;


// 2D Hash pseudo-random generator
float hash22(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}


// Value Noise generator
float noise(vec2 uv) {
	vec2 i = floor(uv);
	vec2 f = fract(uv);
	f = f * f * (3.0 - 2.0 * f); // Cubic Hermite interpolation
	
	float a = hash22(i);
	float b = hash22(i + vec2(1.0, 0.0));
	float c = hash22(i + vec2(0.0, 1.0));
	float d = hash22(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


// 3-Octave Fractional Brownian Motion
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


// 3D Hash generator for star rendering
float hash3d(vec3 p) {
	p = fract(p * vec3(443.8975, 397.2973, 491.1871));
	p += dot(p.xyz, p.yzx + 19.19);
	return fract(p.x * p.y * p.z);
}


void sky() {
	vec3 dir = EYEDIR;
	float horizon = clamp(dir.y, 0.0, 1.0);
	
	// 1. Interpolate sky colors based on time (Day/Night weight)
	vec3 day_sky = mix(sky_horizon_color, sky_top_color, horizon);
	vec3 night_sky = mix(night_horizon_color, night_top_color, horizon);
	vec3 ambient_sky = mix(night_sky, day_sky, day_weight);
	
	// 2. Interpolate storm clouds overcast color
	vec3 storm_sky = mix(storm_sky_horizon, storm_sky_top, horizon);
	vec3 base_sky_color = mix(ambient_sky, storm_sky, storm_weight * day_weight);
	
	// Draw solid void below horizon
	if (dir.y < 0.0) {
		base_sky_color = sky_bottom_color;
	}
	
	// 3. Render Twinkling Starfield at night
	float star_visibility = (1.0 - day_weight) * (1.0 - storm_weight);
	if (dir.y > 0.0 && star_visibility > 0.05) {
		// Rotate stars slowly over time
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
	
	// 4. Render Sun Disk
	float sun_visibility = day_weight * (1.0 - storm_weight * 0.85);
	float dist_sun = distance(dir, sun_direction);
	if (dist_sun < sun_size + sun_blur) {
		float sun_intensity = 1.0 - smoothstep(sun_size, sun_size + sun_blur, dist_sun);
		base_sky_color = mix(base_sky_color, vec3(1.3, 1.15, 0.9) * 2.0, sun_intensity * sun_visibility);
	}
	
	// 5. Render Crescent Moon
	float moon_visibility = (1.0 - day_weight) * (1.0 - storm_weight * 0.85);
	float dist_moon = distance(dir, moon_direction);
	if (dist_moon < moon_size && moon_visibility > 0.05) {
		float moon_mask = 1.0 - smoothstep(moon_size - 0.005, moon_size, dist_moon);
		
		// Offset second circle subtraction to create crescent shadow mask
		vec3 offset_dir = moon_direction + vec3(0.015, 0.015, 0.0);
		float dist_cut = distance(dir, offset_dir);
		float cut_mask = 1.0 - smoothstep(moon_size - 0.005, moon_size, dist_cut);
		
		float crescent = clamp(moon_mask - cut_mask, 0.0, 1.0);
		base_sky_color = mix(base_sky_color, vec3(0.85, 0.92, 1.0) * 1.5, crescent * moon_visibility);
	}
	
	// 6. Render Procedural Clouds (Projection on a flat ceiling plane)
	if (dir.y > 0.0) {
		float denom = max(dir.y, 0.01);
		vec2 cloud_uv = (dir.xz / denom) * 0.4 + vec2(TIME * 0.012, TIME * 0.008);
		
		float cloud_noise = fbm(cloud_uv);
		
		// Cloud coverage density expands during storms
		float target_density = mix(0.42, 0.15, storm_weight);
		float fade = pow(horizon, 0.6); // Fade clouds smoothly near horizon
		float cloud_mask = smoothstep(target_density, 1.0, cloud_noise) * fade;
		
		if (cloud_mask > 0.01) {
			// Orange/Pink sunsets
			vec3 sun_sunset_color = vec3(1.0, 0.45, 0.2) * clamp(1.0 - abs(sun_direction.y * 3.0), 0.0, 1.0);
			vec3 normal_cloud_color = mix(vec3(0.08, 0.08, 0.15), vec3(1.0) + sun_sunset_color, day_weight);
			vec3 storm_cloud_color = vec3(0.25, 0.25, 0.28);
			
			vec3 final_cloud_color = mix(normal_cloud_color, storm_cloud_color, storm_weight * day_weight);
			
			base_sky_color = mix(base_sky_color, final_cloud_color, cloud_mask * 0.85);
		}
	}
	
	COLOR = base_sky_color;
}
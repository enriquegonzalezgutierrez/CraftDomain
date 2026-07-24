// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// Description: Photorealistic atmospheric sky shader with Rayleigh & Mie 
//              scattering gradients, dynamic sun forward-scattering glow, 
//              and horizon color synchronization for atmospheric fog.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type sky;

// --- DAYTIME ATMOSPHERIC SCATTERING PALETTE ---
uniform vec3 day_top_color : source_color = vec3(0.22, 0.52, 0.85);
uniform vec3 day_horizon_color : source_color = vec3(0.78, 0.88, 0.95);

// --- SUNSET & SUNRISE PALETTE ---
uniform vec3 sunset_top_color : source_color = vec3(0.35, 0.22, 0.48);
uniform vec3 sunset_horizon_color : source_color = vec3(0.98, 0.52, 0.22);

// --- NOCTURNAL PALETTE ---
uniform vec3 night_top_color : source_color = vec3(0.01, 0.02, 0.05);
uniform vec3 night_horizon_color : source_color = vec3(0.03, 0.04, 0.08);

// --- CELESTIAL LUMINARIES ---
uniform vec3 sun_color : source_color = vec3(1.00, 0.96, 0.88);
uniform vec3 moon_color : source_color = vec3(0.85, 0.92, 1.00);

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);

// --- METEOROLOGICAL & TEMPORAL UNIFORMS ---
uniform float day_weight : hint_range(0.0, 1.0) = 1.0;
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 dir = EYEDIR;
	
	// Normalize vertical elevation from horizon (0.0) to zenith (1.0)
	float sky_y = clamp(dir.y, 0.0, 1.0);
	float horizon_factor = pow(1.0 - sky_y, 2.2);
	
	// Calculate sun elevation angle to detect sunset/sunrise transitions
	float sun_elevation = clamp(sun_direction.y, -0.2, 0.2);
	float sunset_factor = smoothstep(0.2, -0.2, abs(sun_elevation)) * clamp(day_weight * 2.0, 0.0, 1.0);
	
	// Blend day, sunset, and night sky palettes based on solar time and elevation
	vec3 active_top = mix(night_top_color, mix(day_top_color, sunset_top_color, sunset_factor), day_weight);
	vec3 active_horizon = mix(night_horizon_color, mix(day_horizon_color, sunset_horizon_color, sunset_factor), day_weight);
	
	// Apply storm overcast darkening to sky gradient
	vec3 storm_horizon = vec3(0.12, 0.13, 0.16);
	active_horizon = mix(active_horizon, storm_horizon, storm_weight * 0.85);
	
	// Base sky gradient interpolation from horizon to zenith
	vec3 sky_color_base = mix(active_top, active_horizon, horizon_factor);
	
	// Mie forward-scattering sun glow around sun direction
	float sun_dot = max(0.0, dot(dir, normalize(sun_direction)));
	float sun_glow = pow(sun_dot, 16.0) * 0.45 * day_weight;
	vec3 sun_flare_color = mix(sun_color, vec3(1.0, 0.7, 0.3), sunset_factor);
	
	sky_color_base += sun_flare_color * sun_glow;
	
	// Sun disk rendering
	float sun_disk = smoothstep(0.9992, 0.9998, sun_dot) * day_weight;
	vec3 final_sky = mix(sky_color_base, sun_color * 2.5, sun_disk);
	
	// Moon disk rendering
	float moon_dot = max(0.0, dot(dir, normalize(moon_direction)));
	float moon_disk = smoothstep(0.9985, 0.9995, moon_dot) * (1.0 - day_weight);
	final_sky = mix(final_sky, moon_color * 1.8, moon_disk);
	
	COLOR = final_sky;
}
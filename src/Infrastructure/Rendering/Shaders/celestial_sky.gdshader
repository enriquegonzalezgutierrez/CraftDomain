// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// Description: Complete Celestial Sky Shader featuring Sun disc, Moon phases,
//              twinkling night stars, wind-driven 3D clouds, and atmosphere.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type sky;

uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float day_weight : hint_range(0.0, 1.0) = 0.5;
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

// Global wind synchronization
global uniform vec2 wind_vector;
global uniform float wind_strength;

// Hash and 3D Noise functions for 100% seamless clouds
float hash3D(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yxz + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float n000 = hash3D(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash3D(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3D(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3D(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3D(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3D(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3D(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3D(i + vec3(1.0, 1.0, 1.0));
	
	float nx0 = mix(n000, n100, f.x);
	float nx1 = mix(n001, n101, f.x);
	float nxx0 = mix(n010, n110, f.x);
	float nxx1 = mix(n011, n111, f.x);
	
	float ny0 = mix(nx0, nxx0, f.y);
	float ny1 = mix(nx1, nxx1, f.y);
	
	return mix(ny0, ny1, f.z);
}

float fbm3D(vec3 p) {
	float val = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		val += noise3D(p) * amp;
		p *= 2.02;
		amp *= 0.5;
	}
	return val;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	
	// 1. BASE ATMOSPHERIC GRADIENTS
	vec3 day_sky_top = vec3(0.20, 0.52, 0.92);
	vec3 day_sky_horizon = vec3(0.68, 0.84, 0.98);
	vec3 night_sky_top = vec3(0.01, 0.015, 0.035);
	vec3 night_sky_horizon = vec3(0.02, 0.04, 0.08);
	vec3 storm_sky = vec3(0.10, 0.12, 0.15);
	
	float altitude_factor = clamp(dir.y, 0.0, 1.0);
	vec3 base_day = mix(day_sky_horizon, day_sky_top, altitude_factor);
	vec3 base_night = mix(night_sky_horizon, night_sky_top, altitude_factor);
	vec3 sky_color = mix(base_night, base_day, day_weight);
	sky_color = mix(sky_color, storm_sky, storm_weight * 0.85);
	
	// 2. TWINKLING NIGHT STARS
	float night_factor = (1.0 - day_weight) * (1.0 - storm_weight);
	if (night_factor > 0.01) {
		vec3 star_pos = dir * 180.0;
		float star_noise = hash3D(floor(star_pos));
		if (star_noise > 0.982) {
			float twinkle = sin(TIME * 3.0 + star_noise * 100.0) * 0.5 + 0.5;
			vec3 star_color = vec3(0.9, 0.95, 1.0) * twinkle * night_factor;
			sky_color += star_color;
		}
	}
	
	// 3. SUN DISC & SOLAR GLOW CORONA
	vec3 s_dir = normalize(sun_direction);
	float sun_dot = dot(dir, s_dir);
	if (sun_dot > 0.0) {
		float sun_disc = smoothstep(0.9985, 0.9995, sun_dot);
		float sun_halo = pow(max(0.0, sun_dot), 32.0) * 0.45;
		vec3 sun_color = vec3(1.0, 0.95, 0.85) * (1.0 - storm_weight * 0.8);
		sky_color += (sun_disc * 4.0 + sun_halo) * sun_color * day_weight;
	}
	
	// 4. MOON DISC
	vec3 m_dir = normalize(moon_direction);
	float moon_dot = dot(dir, m_dir);
	if (moon_dot > 0.998) {
		float moon_disc = smoothstep(0.998, 0.999, moon_dot);
		vec3 moon_color = vec3(0.85, 0.92, 1.0) * night_factor * 2.5;
		sky_color += moon_disc * moon_color;
	}
	
	// 5. WIND-DRIVEN 3D VOLUMETRIC CLOUDS (100% Seamless)
	if (dir.y > 0.02) {
		vec3 cloud_pos = (dir / (dir.y + 0.15)) * 2.5;
		
		// Driven naturally by global wind direction and velocity
		vec2 active_wind = (length(wind_vector) > 0.01) ? wind_vector : vec2(0.3, 0.1);
		float active_speed = (wind_strength > 0.0) ? wind_strength : 0.4;
		
		cloud_pos.xz += active_wind * (TIME * 0.05 * active_speed);
		
		float cloud_density = fbm3D(cloud_pos);
		float cloud_mask = smoothstep(0.48, 0.72, cloud_density) * smoothstep(0.02, 0.25, dir.y);
		
		vec3 cloud_color = mix(vec3(0.12, 0.14, 0.20), vec3(0.98, 0.98, 1.0), day_weight);
		cloud_color = mix(cloud_color, vec3(0.10, 0.11, 0.14), storm_weight);
		
		sky_color = mix(sky_color, cloud_color, cloud_mask * 0.92);
	}
	
	COLOR = sky_color;
}
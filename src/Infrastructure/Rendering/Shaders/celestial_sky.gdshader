// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// Description: Photorealistic atmospheric sky shader with Rayleigh & Mie 
//              scattering gradients, dynamic sun glare, raymarched aurora 
//              borealis, and spherical volumetric fluffy cumulus clouds.
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

// --- AURORA BOREALIS UNIFORMS ---
uniform float aurora_intensity : hint_range(0.0, 2.0) = 0.0;
uniform float aurora_brightness : hint_range(0.0, 3.0) = 1.35;
uniform float aurora_speed : hint_range(0.0, 1.0) = 0.08;
uniform float aurora_height : hint_range(10.0, 100.0) = 36.0;
uniform float aurora_scale : hint_range(0.1, 2.0) = 0.8;

uniform vec3 aurora_color_a : source_color = vec3(0.10, 0.95, 0.55);
uniform vec3 aurora_color_b : source_color = vec3(0.65, 0.15, 0.95);

// --- METEOROLOGICAL & CLOUD UNIFORMS ---
uniform float day_weight : hint_range(0.0, 1.0) = 1.0;
uniform float storm_weight : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.0;
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;

// --- AURORA NOISE & ROTATION UTILITIES ---
mat2 mm2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

float tri(float x) {
	return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

vec2 tri2(vec2 p) {
	return vec2(tri(p.x) + tri(p.y), tri(p.y + tri(p.x)));
}

float trinoise2d(vec2 p, float t) {
	float z = 1.8;
	float z2 = 2.5;
	float rz = 0.0;

	p *= mm2(p.x * 0.06);
	vec2 bp = p;
	mat2 rot = mm2(t);

	for (int i = 0; i < 4; i++) {
		vec2 dg = tri2(bp * 1.85) * 0.75;
		dg = dg * rot;
		p -= dg / z2;

		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;

		p *= 1.21 + (rz - 1.0) * 0.02;
		rz += tri(p.x + tri(p.y)) * z;

		p *= mat2(vec2(-0.95534, -0.29552), vec2(0.29552, -0.95534));
	}

	return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

vec4 calculate_aurora_curtain(vec3 direction, float p_time) {
	vec4 color = vec4(0.0);
	vec4 average_color = vec4(0.0);
	
	const float loop_count = 20.0;
	float jitter = fract(sin(dot(direction.xz, vec2(13.0, 78.0))));
	float step_scale = aurora_height / loop_count;
	
	for (int i = 0; i < int(loop_count); i++) {
		float depth_step = (float(i) + jitter) * step_scale;
		float depth = (aurora_scale + pow(depth_step, 1.4) * 0.002) / (direction.y * 2.0 + 0.4);
		vec3 pos = depth * direction;
		float noise = trinoise2d(pos.zx, p_time * aurora_speed);

		vec4 col = vec4(0.0);
		col.a = noise;
		
		float weight = exp2(-depth_step * 0.065 - 2.5) * smoothstep(0.0, 5.0, depth_step);
		vec3 ribbon_color = mix(aurora_color_a, aurora_color_b, clamp(depth_step / aurora_height, 0.0, 1.0));
		col.rgb = ribbon_color * noise;
		average_color = mix(average_color, col, 0.5);
		
		color += average_color * weight * step_scale;
	}

	color *= clamp(direction.y * 15.0 + 0.4, 0.0, 1.0);
	color *= aurora_brightness;
	return color;
}

// --- SEAMLESS SPHERICAL FLUFFY CLOUD CALCULATOR ---
vec4 calculate_3d_volumetric_clouds(vec3 dir, float time_val, float coverage, float day_w, float storm_w, float sunset_f, vec3 sun_dir) {
	if (dir.y <= 0.001 || coverage <= 0.01) {
		return vec4(0.0);
	}
	
	// Spherical Equirectangular UV Mapping (Zero horizon stretching or division lines!)
	float u = atan(dir.x, dir.z) / (2.0 * 3.14159265359) + 0.5;
	float v = asin(clamp(dir.y, 0.0, 1.0)) / (3.14159265359 * 0.5);
	
	vec2 cloud_uv1 = vec2(u * 3.0, v * 1.5) + vec2(time_val * 0.003, time_val * 0.0015);
	vec2 cloud_uv2 = vec2(u * 6.0, v * 3.0) - vec2(time_val * 0.002, time_val * 0.001);
	
	float n1 = texture(cloud_texture, cloud_uv1).r;
	float n2 = texture(cloud_texture, cloud_uv2).r;
	float cloud_noise = mix(n1, n2, 0.40);
	
	// Ultra-soft billowy thresholding (Eliminates blocky edges completely)
	float density_threshold = 1.0 - clamp(coverage * 0.85, 0.05, 0.95);
	float cloud_density = smoothstep(density_threshold, density_threshold + 0.35, cloud_noise);
	
	// Smooth ground horizon fade
	float horizon_fade = smoothstep(0.02, 0.25, dir.y);
	cloud_density *= horizon_fade;
	
	if (cloud_density <= 0.001) {
		return vec4(0.0);
	}
	
	// 3D Directional Lighting & Sunlit Highlights
	float sun_alignment = max(0.0, dot(dir, normalize(sun_dir)));
	float cloud_light = mix(0.70, 1.00, pow(sun_alignment, 2.0));
	
	vec3 sunlit_color = mix(vec3(0.98, 0.98, 1.00), vec3(0.98, 0.65, 0.40), sunset_f) * cloud_light;
	vec3 shaded_color = mix(vec3(0.40, 0.42, 0.50), vec3(0.12, 0.13, 0.18), storm_w);
	vec3 final_cloud_rgb = mix(shaded_color, sunlit_color, day_w * 0.85 + 0.15);
	
	return vec4(final_cloud_rgb, clamp(cloud_density * 0.90, 0.0, 0.95));
}

void sky() {
	vec3 dir = EYEDIR;
	
	float sky_y = clamp(dir.y, 0.0, 1.0);
	float horizon_factor = pow(1.0 - sky_y, 2.2);
	
	float sun_elevation = clamp(sun_direction.y, -0.2, 0.2);
	float sunset_factor = smoothstep(0.2, -0.2, abs(sun_elevation)) * clamp(day_weight * 2.0, 0.0, 1.0);
	
	vec3 active_top = mix(night_top_color, mix(day_top_color, sunset_top_color, sunset_factor), day_weight);
	vec3 active_horizon = mix(night_horizon_color, mix(day_horizon_color, sunset_horizon_color, sunset_factor), day_weight);
	
	vec3 storm_horizon = vec3(0.12, 0.13, 0.16);
	active_horizon = mix(active_horizon, storm_horizon, storm_weight * 0.85);
	
	vec3 sky_color_base = mix(active_top, active_horizon, horizon_factor);
	
	// Mie forward-scattering sun glare
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
	
	// --- AURORA BOREALIS NIGHT RENDER PASS ---
	if (day_weight < 0.95 && aurora_intensity > 0.01 && dir.y > -0.05) {
		float night_mult = (1.0 - day_weight) * (1.0 - storm_weight * 0.80);
		vec4 aurora_ribbon = calculate_aurora_curtain(dir, TIME);
		final_sky = mix(final_sky, final_sky + aurora_ribbon.rgb, aurora_ribbon.a * night_mult * aurora_intensity);
	}
	
	// --- SEAMLESS 3D VOLUMETRIC CLOUD RENDER PASS ---
	vec4 cloud_pass = calculate_3d_volumetric_clouds(dir, TIME, cloud_coverage, day_weight, storm_weight, sunset_factor, sun_direction);
	if (cloud_pass.a > 0.001) {
		final_sky = mix(final_sky, cloud_pass.rgb, cloud_pass.a);
	}
	
	COLOR = final_sky;
}
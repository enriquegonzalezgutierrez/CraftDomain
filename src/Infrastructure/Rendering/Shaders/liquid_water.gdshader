// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader
// Description: Wind-driven ocean water shader with dynamic beach swash (surging 
//              over sand & receding), puddle calmness dampening, and depth-based 
//              foam edge blending.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// --- GLOBAL UNIFORMS (Synchronized with WeatherService) ---
global uniform vec2 wind_vector;
global uniform float wind_strength;
global uniform vec2 wind_offset;

// --- DEPTH BUFFER SAMPLER ---
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

// --- MATERIAL COLOR PALETTE ---
uniform vec4 shallow_water_color : source_color = vec4(0.12, 0.58, 0.78, 0.60);
uniform vec4 deep_water_color : source_color = vec4(0.01, 0.12, 0.32, 0.95);
uniform vec4 foam_color : source_color = vec4(0.96, 0.98, 1.00, 0.98);

uniform sampler2D normal_map_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map_b : hint_normal, filter_linear_mipmap, repeat_enable;

// --- BREAKING WAVE & SURF CONTROLS ---
uniform float base_wave_amplitude : hint_range(0.0, 0.5) = 0.08;
uniform float wave_frequency : hint_range(0.1, 5.0) = 0.75;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.80;
uniform float wave_steepness : hint_range(0.1, 2.5) = 1.20;

// --- PUDDLE CALMNESS & BEACH SWASH CONTROLS ---
uniform float puddle_depth_threshold : hint_range(0.1, 2.0) = 0.60;
uniform float shore_swash_reach : hint_range(0.1, 4.0) = 1.40;
uniform float edge_fade_distance : hint_range(0.01, 2.0) = 0.20;

uniform float foam_threshold : hint_range(0.0, 1.0) = 0.35;
uniform float foam_tightness : hint_range(1.0, 10.0) = 3.00;
uniform float foam_noise_scale : hint_range(0.1, 10.0) = 1.20;

uniform float roughness_val : hint_range(0.0, 1.0) = 0.03;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.08;

// Varyings passed from Vertex to Fragment stage
varying float v_wave_height;
varying vec2 v_world_pos_xz;
varying float v_peak_intensity;

// --- TROCHOIDAL BREAKING WAVE CALCULATOR ---
vec3 calculate_trochoidal_wave(vec2 pos_xz, vec2 dir, float freq, float speed, float time_val, float amp, float steep) {
	vec2 norm_dir = length(dir) > 0.01 ? normalize(dir) : vec2(1.0, 0.0);
	float phase = dot(pos_xz, norm_dir) * freq + time_val * speed;
	
	float sin_p = sin(phase);
	float cos_p = cos(phase);
	
	float vertical = pow(0.5 + 0.5 * sin_p, steep) * amp;
	vec2 horizontal = norm_dir * (cos_p * amp * steep * 0.35);
	
	return vec3(horizontal.x, vertical, horizontal.y);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_pos_xz = world_pos.xz;
	
	vec2 w_dir = length(wind_vector) > 0.01 ? normalize(wind_vector) : vec2(0.8, 0.2);
	float effective_strength = max(0.20, wind_strength);
	
	float active_amplitude = base_wave_amplitude * (0.75 + effective_strength * 1.10);
	float active_speed = wave_speed * (0.80 + effective_strength * 0.70);
	
	vec3 wave1 = calculate_trochoidal_wave(world_pos.xz, w_dir, wave_frequency, active_speed, TIME, active_amplitude, wave_steepness);
	vec2 cross_dir = vec2(-w_dir.y, w_dir.x);
	vec3 wave2 = calculate_trochoidal_wave(world_pos.xz, w_dir + cross_dir * 0.40, wave_frequency * 1.70, active_speed * 1.25, TIME * 1.10, active_amplitude * 0.40, wave_steepness * 0.85);
	
	vec3 total_displacement = wave1 + wave2;
	v_wave_height = total_displacement.y;
	v_peak_intensity = clamp(total_displacement.y / max(0.01, active_amplitude * 1.15), 0.0, 1.0);
	
	VERTEX.x += total_displacement.x;
	VERTEX.y += total_displacement.y;
	VERTEX.z += total_displacement.z;
}

void fragment() {
	// --- LINEAR VIEW-SPACE DEPTH CALCULATION ---
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float depth_diff = -view_pos.z - VERTEX.z;
	
	// HARD DISCARD: Dry land above water level never renders water highlights
	if (depth_diff <= 0.001) {
		discard;
	}
	
	// --- PUDDLE CALMNESS DAMPENING ---
	// Shallow water (< puddle_depth_threshold) reduces ocean wave intensity to stay still
	float puddle_factor = clamp(depth_diff / max(0.01, puddle_depth_threshold), 0.05, 1.0);
	
	vec2 w_dir = length(wind_vector) > 0.01 ? normalize(wind_vector) : vec2(0.8, 0.2);
	float effective_strength = max(0.20, wind_strength);
	
	// Wind-driven normal map scrolling (Dampened in puddles)
	vec2 uv_offset_a = wind_offset * 0.05 + w_dir * TIME * 0.05 * effective_strength * puddle_factor;
	vec2 uv_offset_b = -wind_offset * 0.04 + vec2(-w_dir.y, w_dir.x) * TIME * 0.035 * effective_strength * puddle_factor;
	
	vec2 uv_a = v_world_pos_xz * 0.12 + uv_offset_a;
	vec2 uv_b = v_world_pos_xz * 0.20 + uv_offset_b;
	
	vec3 norm_a = texture(normal_map_a, uv_a).rgb * 2.0 - 1.0;
	vec3 norm_b = texture(normal_map_b, uv_b).rgb * 2.0 - 1.0;
	vec3 blended_normal = normalize(mix(vec3(0.0, 0.0, 1.0), norm_a + norm_b * 0.70, puddle_factor));
	
	NORMAL_MAP = blended_normal;
	
	// Water color depth gradient
	float height_gradient = clamp((v_wave_height + base_wave_amplitude) / (base_wave_amplitude * 2.2), 0.0, 1.0);
	vec4 base_water = mix(deep_water_color, shallow_water_color, height_gradient);
	
	// --- DYNAMIC BEACH WAVE SURGE (SWASH & RECEDE) ---
	// Wave surge phase: Wave rolls forward over sand (surge > 0) and recedes back (surge < 0)
	float swash_phase = dot(v_world_pos_xz, w_dir * 0.80) * wave_frequency + TIME * wave_speed;
	float wave_surge = sin(swash_phase);
	
	// Expand reach during surge, shrink back during recede
	float active_swash_reach = shore_swash_reach * mix(0.20, 1.00, max(0.0, wave_surge)) * puddle_factor;
	float swash_mask = clamp(1.0 - (depth_diff / max(0.01, active_swash_reach)), 0.0, 1.0);
	
	vec2 foam_uv = v_world_pos_xz * foam_noise_scale + uv_offset_a * 1.5;
	float foam_pattern = texture(normal_map_a, foam_uv).r;
	float swash_foam = pow(swash_mask, 1.4) * (0.50 + foam_pattern * 0.80);
	
	// Open Ocean Crest Whitecaps (Dampened in puddles)
	float crest_raw = clamp((v_peak_intensity - foam_threshold) / (1.0 - foam_threshold), 0.0, 1.0);
	float crest_foam = pow(crest_raw, foam_tightness) * puddle_factor;
	float final_crest_foam = smoothstep(0.20, 0.75, crest_foam * (0.50 + foam_pattern * 0.90));
	
	// Combine crest whitecaps and beach swash foam
	float total_foam = clamp(final_crest_foam + swash_foam, 0.0, 1.0);
	vec3 final_albedo = mix(base_water.rgb, foam_color.rgb, total_foam * foam_color.a);
	
	// Fresnel reflection
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 specular_tint = mix(final_albedo, vec3(1.0), fresnel * 0.50 * puddle_factor);
	
	// Smooth edge blending
	float shore_blend = smoothstep(0.001, max(0.01, edge_fade_distance), depth_diff);
	
	ALBEDO = specular_tint;
	METALLIC = metallic_val;
	ROUGHNESS = mix(roughness_val, 0.65, total_foam);
	ALPHA = mix(base_water.a, 0.98, total_foam) * shore_blend;
	SPECULAR = 0.5;
}
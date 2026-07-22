// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader
// Description: High-Fidelity Voxel Water Shader featuring animated surface UV waves,
//              subtle shore foam, and crystal-clear depth transparency.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode cull_back, depth_draw_always, blend_mix;

uniform vec4 shallow_water_color : source_color = vec4(0.12, 0.52, 0.82, 0.55);
uniform vec4 deep_water_color : source_color = vec4(0.04, 0.18, 0.48, 0.85);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.90);

uniform float foam_threshold : hint_range(0.1, 2.0) = 0.35;
uniform float wave_speed : hint_range(0.1, 5.0) = 0.8;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 1. Calculate perspective linear depth difference for shore foam
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	
	float linear_depth = -view_pos.z;
	float surface_depth = -VERTEX.z;
	float water_depth = max(0.0, linear_depth - surface_depth);
	
	// 2. Animated UV wave ripples (Surface motion without mesh vertex displacement)
	vec2 uv_wave = v_world_pos.xz * 0.25;
	float wave1 = sin(TIME * wave_speed + uv_wave.x * 4.0 + uv_wave.y * 2.0) * 0.5 + 0.5;
	float wave2 = cos(TIME * wave_speed * 1.3 - uv_wave.x * 2.0 + uv_wave.y * 5.0) * 0.5 + 0.5;
	float combined_wave = (wave1 + wave2) * 0.5;
	
	// 3. Smooth depth color transition
	float depth_factor = clamp(water_depth / 3.0, 0.0, 1.0);
	vec4 water_color = mix(shallow_water_color, deep_water_color, depth_factor);
	
	// 4. Subtle shore foam calculation
	float foam_factor = clamp((foam_threshold - water_depth) / foam_threshold, 0.0, 1.0);
	float final_foam = step(0.40, foam_factor * combined_wave);
	
	ALBEDO = mix(water_color.rgb, foam_color.rgb, final_foam * foam_color.a);
	ALPHA = mix(water_color.a, 1.0, final_foam * 0.8);
	ROUGHNESS = 0.02;
	METALLIC = 0.15;
}
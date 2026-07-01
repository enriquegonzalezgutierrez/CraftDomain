// ==============================================================================
// Project: CraftDomain
// Description: Ultra-Compatible Cinematic Foliage Shader for leaf canopies.
//              SOLID COMPLIANCE: Dedicated exclusively to foliage fragment and 
//                vertex shading calculations (SRP).
//              UNIVERSAL COMPATIBILITY:
//              - Uses 'world_vertex_coords' render mode for robust hardware-agnostic 
//                world space mapping.
//              - Uses 'vec4' for block_color to prevent type mismatch failures.
//              - Uses standard multi-harmonic sine wave vertices offsets.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.88;
uniform float wind_amplitude : hint_range(0.0, 1.0) = 0.12;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.8;

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;

void vertex() {
	// Calculate triplanar blending weights
	uv1_power_normal = pow(abs(NORMAL), vec3(4.0));
	uv1_power_normal /= (uv1_power_normal.x + uv1_power_normal.y + uv1_power_normal.z);
	uv1_triplanar_pos = VERTEX;
	
	// MULTI-HARMONIC WIND SWAY (Calculated safely on world vertex positions)
	float wave_a = sin(TIME * wind_speed + VERTEX.x * 0.12 + VERTEX.y * 0.08);
	float wave_b = cos(TIME * (wind_speed * 0.6) + VERTEX.z * 0.15 - VERTEX.y * 0.05);
	float wind_displacement = wave_a * wave_b * wind_amplitude;
	
	VERTEX.xz += vec2(wind_displacement, wind_displacement);
}

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_triplanar_pos.yz) * p_weights.x;
	samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
	return samp;
}

void fragment() {
	// Fetch and blend albedo texture values triplanarly
	vec4 albedo_tex = triplanar_texture(albedo_texture, uv1_power_normal, uv1_triplanar_pos);
	ALBEDO = albedo_tex.rgb * block_color.rgb;
	
	ROUGHNESS = roughness_val;
	
	// PBR BACKLIGHT TRANSLUCENCY
	BACKLIGHT = ALBEDO * 0.35;
	SPECULAR = 0.05;
}
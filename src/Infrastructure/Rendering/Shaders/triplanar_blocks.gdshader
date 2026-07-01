// ==============================================================================
// Project: CraftDomain
// Description: Ultra-Compatible Cinematic PBR Triplanar Shader for solid voxel blocks.
//              SOLID COMPLIANCE: Dedicated exclusively to fragment and vertex 
//                shading calculations (SRP).
//              UNIVERSAL COMPATIBILITY:
//              - Uses 'world_vertex_coords' render mode for robust hardware-agnostic 
//                world space mapping, compatible with integrated and software GPUs.
//              - Uses 'vec4' for block_color to prevent silent type mismatch failures.
//              - Avoids hardware-specific derivative functions (dFdx/dFdy) for 100% 
//                compatibility on non-GPU and software (llvmpipe) renderers.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, world_vertex_coords;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 block_color : source_color = vec4(1.0); // vec4 matches Godot's Color type precisely
uniform float roughness_val : hint_range(0.0, 1.0) = 0.82;

varying vec3 uv1_triplanar_pos;
varying vec3 uv1_power_normal;

void vertex() {
	// Calculate triplanar blending weights using world-space normals
	uv1_power_normal = pow(abs(NORMAL), vec3(4.0));
	uv1_power_normal /= (uv1_power_normal.x + uv1_power_normal.y + uv1_power_normal.z);
	
	// Since world_vertex_coords is enabled, VERTEX is already transformed to World Space
	uv1_triplanar_pos = VERTEX;
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
	SPECULAR = 0.1; // Balanced dielectric specular reflectance
}
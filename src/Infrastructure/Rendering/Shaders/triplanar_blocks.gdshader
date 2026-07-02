// ==============================================================================
// Project: CraftDomain
// Description: Advanced spatial PBR shader implementing procedural triplanar mapping 
//              and real-time automatic bump-mapping based on texture luminance.
//              UX ENHANCEMENT:
//              - Calculates tangent-space displacement on-the-fly, allowing block 
//                faces to project micro-relief shading reacting to Streetlights, 
//                SunLight, and MoonLight orbits with zero CPU/RAM cost.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Uniform variables injected from the ChunkNode materials builder
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec3 block_color : source_color = vec3(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.8;

// Relief strength controller (Higher values create deeper, more prominent pixel cracks)
uniform float bump_strength : hint_range(0.0, 1.0) = 0.14;

varying vec3 v_world_pos;
varying vec3 v_world_normal;


void vertex() {
	// Unpack vertices and normals directly to world space
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


// Helper: Calculates relative pixel height based on standard RGB grayscale luminance
float get_pixel_height(vec4 color) {
	return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}


void fragment() {
	// 1. Calculate absolute triplanar blend weights
	vec3 blend_weights = abs(v_world_normal);
	blend_weights = normalize(max(blend_weights, 0.0001)); // Prevent division by zero
	float total_weight = blend_weights.x + blend_weights.y + blend_weights.z;
	blend_weights /= total_weight;

	// Scale texture repeat based on 3D coordinates (1 block = 1 complete wrap)
	vec2 uv_x = v_world_pos.zy;
	vec2 uv_y = v_world_pos.xz;
	vec2 uv_z = v_world_pos.xy;

	// Symmetrically flip UV projections to align textures cleanly across negative seams
	uv_x.x = -uv_x.x;
	uv_z.x = -uv_z.x;

	// Sample Albedo on all three projection planes
	vec4 col_x = texture(albedo_texture, uv_x);
	vec4 col_y = texture(albedo_texture, uv_y);
	vec4 col_z = texture(albedo_texture, uv_z);

	// Blend colors mathematically
	vec4 blended_albedo = (col_x * blend_weights.x) + (col_y * blend_weights.y) + (col_z * blend_weights.z);
	ALBEDO = blended_albedo.rgb * block_color;

	// ==========================================================================
	// PROCEDURAL BUMP MAPPING (STREETLIGHT SHADOW RELIEF)
	// Analyzes color luminance derivatives to project dynamic micro-reliefs.
	// ==========================================================================
	float texel_size = 0.015625; // 1.0 / 64.0 (Tailored for 64x64 retro textures)
	
	// A. Sample height offsets for X projection plane
	float h_x = get_pixel_height(col_x);
	float h_x_u = get_pixel_height(texture(albedo_texture, uv_x + vec2(0.0, texel_size)));
	float h_x_r = get_pixel_height(texture(albedo_texture, uv_x + vec2(texel_size, 0.0)));
	vec3 bump_x = vec3(0.0, h_x_u - h_x, h_x_r - h_x) * bump_strength;

	// B. Sample height offsets for Y projection plane
	float h_y = get_pixel_height(col_y);
	float h_y_u = get_pixel_height(texture(albedo_texture, uv_y + vec2(0.0, texel_size)));
	float h_y_r = get_pixel_height(texture(albedo_texture, uv_y + vec2(texel_size, 0.0)));
	vec3 bump_y = vec3(h_y_r - h_y, 0.0, h_y_u - h_y) * bump_strength;

	// C. Sample height offsets for Z projection plane
	float h_z = get_pixel_height(col_z);
	float h_z_u = get_pixel_height(texture(albedo_texture, uv_z + vec2(0.0, texel_size)));
	float h_z_r = get_pixel_height(texture(albedo_texture, uv_z + vec2(texel_size, 0.0)));
	vec3 bump_z = vec3(h_z_r - h_z, h_z_u - h_z, 0.0) * bump_strength;

	// Blend the displacement vectors based on surface projection
	vec3 blended_bump = (bump_x * blend_weights.x) + (bump_y * blend_weights.y) + (bump_z * blend_weights.z);
	
	// Add the displacement to the vertex normal and re-normalize in world space
	vec3 world_normal_displaced = normalize(v_world_normal + blended_bump);

	// Convert world-space normal to view-space normal for Godot's fragment pipeline
	NORMAL = (VIEW_MATRIX * vec4(world_normal_displaced, 0.0)).xyz;

	// High fidelity PBR settings
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
	SPECULAR = 0.08; // Soft specularity for natural voxel environments
}
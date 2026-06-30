// ==============================================================================
// Project: CraftDomain
// Description: Custom triplanar spatial shader for 3D solid blocks. 
//              Binds a 2D texture to the face projecting along the surface normal.
//              Calculates projections in LOCAL space to prevent texture sliding,
//              stretching, or warping during camera rotations.
// SOLID COMPLIANCE:
// - Single Responsibility Principle (SRP): Handles exclusively fragment blending 
//   and local-space projection, completely decoupled from GDScript node logic.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// The custom texture containing albedo or structural patterns.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;

// Fallback procedural color utilized to color-in or fill alpha gaps.
uniform vec4 block_color : source_color;

// Physical roughness of the block surface.
uniform float roughness_val : hint_range(0.0, 1.0) = 0.75;

// Local vertex position and normals sent to the fragment processor (SRP/Parity)
varying vec3 local_pos;
varying vec3 local_normal;


void vertex() {
	// Cache the raw local space coordinates to prevent view-space sliding
	local_pos = VERTEX;
	local_normal = NORMAL;
}


void fragment() {
	// Calculate absolute blend weights from local normals
	vec3 abs_n = abs(local_normal);
	
	// Normalize the blend weights so they sum to 1.0
	float total = abs_n.x + abs_n.y + abs_n.z;
	vec3 weights = abs_n / max(total, 0.001);
	
	// Sample the texture along the three local coordinate planes
	vec4 tex_x = texture(albedo_texture, local_pos.zy);
	vec4 tex_y = texture(albedo_texture, local_pos.xz);
	vec4 tex_z = texture(albedo_texture, local_pos.xy);
	
	// Blend the three samples dynamically based on normal weights
	vec4 tex_color = tex_x * weights.x + tex_y * weights.y + tex_z * weights.z;
	
	// Blend the procedural fallback color with the texture color using alpha as mask
	ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
	ROUGHNESS = roughness_val;
}
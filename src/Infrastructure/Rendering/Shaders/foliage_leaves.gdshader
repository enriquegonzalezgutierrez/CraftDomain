// ==============================================================================
// Project: CraftDomain
// Description: Custom leaves and foliage shader with procedural wind-sway 
//              deformations, high-frequency organic expansion, culling-disabled 
//              double-sided rendering, and alpha-discard clipping.
//              Calculates projections in LOCAL space to prevent texture sliding,
//              stretching, or warping during camera rotations.
// SOLID COMPLIANCE:
// - Single Responsibility Principle (SRP): Handles exclusively structural 
//   vertex displacement and pixel clipping, completely decoupled from scripting.
// Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
// File: res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// The foliage texture containing custom leaves or blossom details.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;

// Fallback procedural color utilized to color-in or fill alpha gaps.
uniform vec4 block_color : source_color;

// Physical roughness of the leaf surface.
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;

// Local vertex position and normals sent to the fragment processor (SRP/Parity)
varying vec3 local_pos;
varying vec3 local_normal;


void vertex() {
	// Cache the raw stable local space coordinates before applying wind sway
	local_pos = VERTEX;
	local_normal = NORMAL;
	
	// 1. ORGANIC VOXEL FLUFFINESS
	// Smooth high-frequency sine expansions along surface normals
	float round_wave = sin(TIME * 2.0 + VERTEX.x * 2.5 + VERTEX.y * 3.5) * 0.05;
	VERTEX.xyz += NORMAL * round_wave;
	
	// 2. WIND SWAY
	// Lateral diagonal wave translation based on vertical height
	VERTEX.x += sin(TIME * 1.5 + VERTEX.y) * 0.08;
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
	
	// Fast discard clipping: Discard rendering if pixel is mostly transparent (alpha < 0.4)
	if (tex_color.a < 0.4) {
		discard;
	}
	
	// Blend the procedural fallback color with the texture color using alpha as mask
	ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
	ROUGHNESS = roughness_val;
}
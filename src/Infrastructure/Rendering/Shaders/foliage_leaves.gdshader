// ==============================================================================
// Project: CraftDomain
// Description: Custom leaves and foliage shader with procedural wind-sway 
//              deformations, high-frequency organic expansion, culling-disabled 
//              double-sided rendering, and alpha-discard clipping.
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

// Local vertex position sent to the fragment processor for projection.
varying vec3 triplanar_pos;


void vertex() {
	triplanar_pos = VERTEX;
	
	// 1. ORGANIC VOXEL FLUFFINESS
	// Smooth high-frequency sine expansions along surface normals
	float round_wave = sin(TIME * 2.0 + VERTEX.x * 2.5 + VERTEX.y * 3.5) * 0.05;
	VERTEX.xyz += NORMAL * round_wave;
	
	// 2. WIND SWAY
	// Lateral diagonal wave translation based on vertical height
	VERTEX.x += sin(TIME * 1.5 + VERTEX.y) * 0.08;
}


void fragment() {
	vec3 abs_n = abs(NORMAL);
	vec2 uv = triplanar_pos.xy;
	
	// Fast axis evaluation to determine planar orientation
	if (abs_n.x > 0.5) {
		uv = triplanar_pos.zy;
	} else if (abs_n.y > 0.5) {
		uv = triplanar_pos.xz;
	}
	
	// Sample the texture using local coordinate projection
	vec4 tex_color = texture(albedo_texture, uv);
	
	// Fast discard clipping: Discard rendering if pixel is mostly transparent (alpha < 0.4)
	if (tex_color.a < 0.4) {
		discard;
	}
	
	// Blend the procedural fallback color with the texture color using alpha as mask
	ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
	ROUGHNESS = roughness_val;
}
// ==============================================================================
// Project: CraftDomain
// Description: Custom triplanar spatial shader for 3D solid blocks. 
//              Binds a 2D texture to the face projecting along the surface normal 
//              using a single optimized texture fetch to preserve performance.
//              If a pixel contains transparency, it blends dynamically with 
//              the fallback procedural block color.
// SOLID COMPLIANCE:
// - Single Responsibility Principle (SRP): Handles exclusively fragment blending 
//   and projection mathematics, completely decoupled from GDScript node logic.
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

// Local vertex position sent to the fragment processor for projection.
varying vec3 triplanar_pos;


void vertex() {
	// Cache the local vertex coordinates for planar projection
	triplanar_pos = VERTEX;
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
	
	// Blend the procedural fallback color with the texture color using alpha as mask
	ALBEDO = mix(block_color.rgb, tex_color.rgb, tex_color.a);
	ROUGHNESS = roughness_val;
}
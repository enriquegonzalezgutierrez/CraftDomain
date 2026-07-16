// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/foliage_leaves.gdshader
// Description: Advanced organic foliage shader for tree leaves, bushes, and grass.
//              Features dual-frequency wind-sway (low frequency branch sways
//              combined with high frequency leaf flutters) and a PBR backlight
//              translucency (Subsurface Scattering) approximation.
// SOLID COMPLIANCE: Dedicated exclusively to foliage pixel shading and vertex swaying.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

global uniform vec2 wind_vector;
global uniform float wind_strength;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
uniform float translucency_energy : hint_range(0.0, 1.0) = 0.45;


void vertex() {
	// 1. Calculate the absolute world position of the vertex
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_dir = normalize(wind_vector);
	
	// 2. Low-frequency ambient sway (representing branch movement)
	float time_low = TIME * (1.0 + wind_strength * 0.8);
	float sway_wave = sin(dot(world_pos.xz, wind_dir) * 0.5 + time_low);
	vec2 sway = wind_dir * sway_wave * (0.05 + wind_strength * 0.04);
	
	// 3. High-frequency leaf flutter (representing leaf rustling)
	float time_high = TIME * (12.0 + wind_strength * 15.0);
	float flutter_wave = sin(world_pos.y * 10.0 + time_high) * cos(world_pos.x * 10.0 - time_high);
	// Top-facing leaf faces sway more in block, vertical hanging leaves flutter more
	vec2 flutter = wind_dir * flutter_wave * (0.01 + wind_strength * 0.012) * (1.0 - NORMAL.y);
	
	VERTEX.xz += sway + flutter;
}


void fragment() {
	// Fetch albedo color from the static preloaded texture cache
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Alpha Scissor Winding: Sharp pixel-art leaf transparency cutout
	if (tex_color.a < 0.5) {
		discard;
	}
	
	ALBEDO = tex_color.rgb * block_color.rgb;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}


void light() {
	// 1. Standard lambertian diffuse shading
	float dot_nl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * dot_nl * ATTENUATION;
	
	// 2. Symmetrical Subsurface Scattering (Backlight Translucency)
	// Light penetrates the leaves, glowing emerald green when backlit by the sun
	float dot_vl = clamp(dot(VIEW, -LIGHT), 0.0, 1.0);
	float sss = pow(dot_vl, 6.0) * translucency_energy;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * sss * ATTENUATION;
}
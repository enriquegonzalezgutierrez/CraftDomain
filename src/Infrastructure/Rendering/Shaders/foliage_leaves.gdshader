/* ==============================================================================
 * Project: CraftDomain
 * Description: Infrastructure GPU Shader responsible ONLY for rendering foliage 
 *              (leaves, vines) with an organic wind-swaying vertex displacement.
 * SOLID COMPLIANCE:
 * - Single Responsibility Principle (SRP): Isolates the mathematical wind 
 *   calculations and alpha-clipping rendering away from the GDScript CPU loops.
 * GRAPHICS PIPELINE (COMPATIBILITY FIX):
 * - Uses ALPHA_SCISSOR_THRESHOLD to discard transparent pixels completely, 
 *   allowing Godot's shadow maps to accurately cast the silhouette of the leaves.
 * - Sourced programmatically from global uniforms mapped by WeatherService.
 * - Vertices now sway back and forth strictly ALONG the wind vector line, 
 *   increasing oscillation speed and displacement scale during storm cycles.
 * Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
 * ============================================================================== */

shader_type spatial;

// RENDER MODES:
// cull_disabled: Renders both sides of the leaf texture (visible from inside out).
// depth_draw_opaque: Required for proper shadow casting with alpha scissor.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Sourced programmatically from global uniforms mapped by WeatherService
global uniform vec2 wind_vector;
global uniform float wind_strength;

// INJECTED PARAMETERS FROM CHUNKNODE.GD
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;


void vertex() {
	// 1. Calculate the absolute world position of the vertex
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Project world coordinates along the normalized wind vector direction
	vec2 wind_dir = normalize(wind_vector);
	float wind_dot = dot(world_pos.xz, wind_dir);
	
	// 3. Dynamic speed scales up on heavy storm gales
	float dynamic_speed = 1.2 + wind_strength * 0.4;
	
	// 4. Calculate smooth wave oscillations along the wind direction line
	float wave = sin(wind_dot * 1.5 + TIME * dynamic_speed);
	
	// 5. Displace VERTEX xz coordinates along the wind direction vector
	vec2 displace = wind_dir * wave * (0.04 + wind_strength * 0.035);
	
	VERTEX.xz += displace;
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
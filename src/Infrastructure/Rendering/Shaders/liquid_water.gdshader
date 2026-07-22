// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader
// Description: Realistic Voxel Water Shader combining water.png texture scrolling,
//              PBR specular reflections, depth-buffer shore foam, and transparency.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode cull_back, depth_draw_always, blend_mix;

uniform vec4 shallow_water_color : source_color = vec4(0.20, 0.65, 0.90, 0.60);
uniform vec4 deep_water_color : source_color = vec4(0.08, 0.25, 0.55, 0.85);
uniform vec4 foam_color : source_color = vec4(0.95, 0.98, 1.0, 0.90);

uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

uniform float foam_threshold : hint_range(0.1, 2.0) = 0.35;
uniform float wave_speed : hint_range(0.1, 5.0) = 0.6;

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
	
	// 2. Sample realistic water.png texture with scrolling dual-layer UV motion
	vec2 uv_move1 = v_world_pos.xz * 0.25 + vec2(TIME * wave_speed * 0.05, TIME * wave_speed * 0.03);
	vec2 uv_move2 = v_world_pos.xz * 0.25 - vec2(TIME * wave_speed * 0.04, -TIME * wave_speed * 0.06);
	
	vec4 tex1 = texture(texture_albedo, uv_move1);
	vec4 tex2 = texture(texture_albedo, uv_move2);
	vec4 blended_texture = (tex1 + tex2) * 0.5;
	
	// 3. Smooth depth color transition blended with texture detail
	float depth_factor = clamp(water_depth / 3.0, 0.0, 1.0);
	vec4 depth_color = mix(shallow_water_color, deep_water_color, depth_factor);
	vec3 final_water_albedo = blended_texture.rgb * depth_color.rgb * 1.3;
	
	// 4. Subtle shore foam calculation
	float foam_factor = clamp((foam_threshold - water_depth) / foam_threshold, 0.0, 1.0);
	float wave_noise = sin(TIME * wave_speed * 2.0 + (v_world_pos.x + v_world_pos.z) * 3.0) * 0.5 + 0.5;
	float final_foam = step(0.40, foam_factor * wave_noise);
	
	ALBEDO = mix(final_water_albedo, foam_color.rgb, final_foam * foam_color.a);
	ALPHA = mix(depth_color.a, 1.0, final_foam * 0.8);
	ROUGHNESS = 0.04;
	METALLIC = 0.12;
}
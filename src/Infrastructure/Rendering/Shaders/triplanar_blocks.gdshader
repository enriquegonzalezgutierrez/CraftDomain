// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
// Description: Custom Triplanar PBR Shader for Voxel Terrain Blocks.
//              Applies world-space triplanar projection to eliminate texture
//              stretching on cliffs, integrates Vertex AO, and handles PBR.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest_mipmap_anisotropic;
uniform sampler2D texture_normal : hint_normal, filter_nearest_mipmap_anisotropic;

uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform float normal_depth : hint_range(0.0, 2.0) = 1.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Calculate triplanar blend weights based on absolute normal direction
	vec3 blend_weights = pow(abs(v_world_normal), vec3(4.0));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);
	
	// 2. Sample textures across 3 orthogonal projections (XZ, YZ, XY)
	vec2 uv_x = v_world_pos.zy * uv_scale;
	vec2 uv_y = v_world_pos.xz * uv_scale;
	vec2 uv_z = v_world_pos.xy * uv_scale;
	
	vec4 tex_x = texture(texture_albedo, uv_x);
	vec4 tex_y = texture(texture_albedo, uv_y);
	vec4 tex_z = texture(texture_albedo, uv_z);
	
	vec4 blended_albedo = tex_x * blend_weights.x + tex_y * blend_weights.y + tex_z * blend_weights.z;
	
	// 3. Apply Vertex Ambient Occlusion (COLOR.rgb) and Base Material Colors
	ALBEDO = blended_albedo.rgb * albedo_color.rgb * COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	
	// 4. Sample and blend Normal Maps for surface micro-reliefs
	vec3 norm_x = texture(texture_normal, uv_x).rgb * 2.0 - 1.0;
	vec3 norm_y = texture(texture_normal, uv_y).rgb * 2.0 - 1.0;
	vec3 norm_z = texture(texture_normal, uv_z).rgb * 2.0 - 1.0;
	
	vec3 blended_normal = norm_x * blend_weights.x + norm_y * blend_weights.y + norm_z * blend_weights.z;
	NORMAL_MAP = normalize(blended_normal);
	NORMAL_MAP_DEPTH = normal_depth;
}
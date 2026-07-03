/* ==============================================================================
   Project: CraftDomain
   Description: Custom High-Fidelity Retro-PBR Triplanar Spatial Shader.
   SOLID COMPLIANCE:
   - Single Responsibility Principle (SRP): Exclusively manages GPU rendering.
   CRITICAL FIXES & OPTIMIZATIONS:
   - Triplanar Normal Unpacking: Fixed severe Specular Aliasing (Moiré noise) 
     and inverted shadows by properly unpacking [0,1] RGB normal textures into 
     [-1,1] vectors, flipping X/Y axes based on spatial projection signs, 
     blending them mathematically, and repacking them.
   - Filter Nearest Mipmap: Enforces mipmapping to prevent pixel-skipping noise.
   Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
   File: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
   ============================================================================== */
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// ==============================================================================
// UNIFORMS
// ==============================================================================
uniform sampler2D albedo_texture   : source_color, hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_texture   : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform sampler2D ambient_texture  : hint_default_white, filter_nearest_mipmap, repeat_enable;
uniform sampler2D specular_texture : hint_default_black, filter_nearest_mipmap, repeat_enable;

// Material physical properties
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;
uniform float triplanar_sharpness : hint_range(1.0, 64.0) = 16.0;

// Dynamic performance branch toggles
uniform bool use_normal_map = false;
uniform bool use_ambient_map = false;
uniform bool use_specular_map = false;

varying vec3 uv_triplanar_pos;
varying vec3 uv_triplanar_normal;


void vertex() {
	// 1. TANGENT SPACE RECONSTRUCTION
	vec3 n = abs(NORMAL);
	if (n.x > n.y && n.x > n.z) {
		TANGENT = vec3(0.0, 0.0, sign(NORMAL.x));
		BINORMAL = vec3(0.0, 1.0, 0.0);
	} else if (n.y > n.x && n.y > n.z) {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 0.0, sign(NORMAL.y));
	} else {
		TANGENT = vec3(1.0, 0.0, 0.0);
		BINORMAL = vec3(0.0, 1.0, 0.0);
	}
	
	// 2. WORLD-SPACE TRANSLATION
	uv_triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	uv_triplanar_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}


void fragment() {
	// 1. BLEND WEIGHTS
	vec3 blend_weights = pow(abs(uv_triplanar_normal), vec3(triplanar_sharpness));
	blend_weights = blend_weights / max(blend_weights.x + blend_weights.y + blend_weights.z, 0.00001);
	
	// 2. PROJECT ALBEDO
	vec4 tex_x = texture(albedo_texture, uv_triplanar_pos.zy);
	vec4 tex_y = texture(albedo_texture, uv_triplanar_pos.xz);
	vec4 tex_z = texture(albedo_texture, uv_triplanar_pos.xy);
	ALBEDO = (tex_x * blend_weights.x + tex_y * blend_weights.y + tex_z * blend_weights.z).rgb * block_color.rgb;
	
	// 3. PROJECT AMBIENT OCCLUSION
	if (use_ambient_map) {
		vec4 ao_x = texture(ambient_texture, uv_triplanar_pos.zy);
		vec4 ao_y = texture(ambient_texture, uv_triplanar_pos.xz);
		vec4 ao_z = texture(ambient_texture, uv_triplanar_pos.xy);
		AO = (ao_x * blend_weights.x + ao_y * blend_weights.y + ao_z * blend_weights.z).r;
	} else {
		AO = 1.0;
	}
	
	// 4. PROJECT SPECULAR & ROUGHNESS
	if (use_specular_map) {
		vec4 spec_x = texture(specular_texture, uv_triplanar_pos.zy);
		vec4 spec_y = texture(specular_texture, uv_triplanar_pos.xz);
		vec4 spec_z = texture(specular_texture, uv_triplanar_pos.xy);
		float spec_val = (spec_x * blend_weights.x + spec_y * blend_weights.y + spec_z * blend_weights.z).r;
		
		SPECULAR = spec_val;
		ROUGHNESS = (1.0 - spec_val) * roughness_val;
	} else {
		SPECULAR = 0.5;
		ROUGHNESS = roughness_val;
	}
	
	// 5. PROJECT NORMAL MAP (MATHEMATICALLY CORRECTED)
	if (use_normal_map) {
		// Unpack [0,1] textures into proper [-1, 1] 3D Vectors
		vec3 norm_x = texture(normal_texture, uv_triplanar_pos.zy).rgb * 2.0 - 1.0;
		vec3 norm_y = texture(normal_texture, uv_triplanar_pos.xz).rgb * 2.0 - 1.0;
		vec3 norm_z = texture(normal_texture, uv_triplanar_pos.xy).rgb * 2.0 - 1.0;
		
		// Flip axes based on the projection face so light doesn't hit upside-down
		norm_x.x *= sign(uv_triplanar_normal.x);
		norm_y.x *= sign(uv_triplanar_normal.y);
		norm_z.x *= sign(uv_triplanar_normal.z);
		
		norm_x.y *= -1.0;
		norm_z.y *= -1.0;
		
		// Blend the true 3D vectors
		vec3 mixed_normal = normalize(norm_x * blend_weights.x + norm_y * blend_weights.y + norm_z * blend_weights.z);
		
		// Repack back to [0,1] format for the Godot NORMAL_MAP slot
		NORMAL_MAP = mixed_normal * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_scale;
	}
}
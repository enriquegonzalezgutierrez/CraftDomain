// ==============================================================================
# Shader: Triplanar Blocks PBR (Corrected Repeat Mode)
# Description: Custom world-space triplanar mapping shader optimized for voxel
#              materials. Forces repeat mode to ensure seamless texture wrapping
#              across infinite coordinates.
# SOLID COMPLIANCE: Dedicated exclusively to surface fragment projection and
#                   light-shading calculations (SRP compliant).
# Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
# File: res://src/Infrastructure/Rendering/Shaders/triplanar_blocks.gdshader
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Albedo parameters with repeat_enable to prevent flat-color clamping outside origin
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;

// Normal map parameters
uniform bool use_normal_map = false;
uniform sampler2D normal_texture : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform float normal_scale : hint_range(0.0, 2.0) = 1.0;

// Ambient Occlusion parameters
uniform bool use_ambient_map = false;
uniform sampler2D ambient_texture : hint_default_white, filter_nearest_mipmap, repeat_enable;

// Specular / Metallic parameters
uniform bool use_specular_map = false;
uniform sampler2D specular_texture : hint_default_white, filter_nearest_mipmap, repeat_enable;

// Parallax/POM parameters (Reserved for high-end PBR configurations)
uniform bool use_parallax = false;

// Emissive parameters (For glowing cybernetic pathways)
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;

// Varying vectors passed from vertex to fragment stages
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	// Calculate absolute world-space position and normals for triplanar projections
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Calculate Triplanar Blending Weights
	vec3 abs_normal = abs(world_normal);
	
	// Raise power to sharpen the transitions on 90-degree block seams
	vec3 blend_weights = pow(abs_normal, vec3(4.0));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z);

	// 2. Sample Albedo on X, Y, and Z planes
	vec4 col_x = texture(albedo_texture, world_pos.zy);
	vec4 col_y = texture(albedo_texture, world_pos.xz);
	vec4 col_z = texture(albedo_texture, world_pos.xy);
	
	// Linear blend albedo textures based on calculated weights
	vec4 albedo_tex = col_x * blend_weights.x + col_y * blend_weights.y + col_z * blend_weights.z;

	// Apply base color multipliers (allows procedural tinting on materials like grass/foliage)
	ALBEDO = albedo_tex.rgb * block_color.rgb;
	ROUGHNESS = roughness_val;

	// 3. Optional Normal Mapping projection
	if (use_normal_map) {
		vec4 norm_x = texture(normal_texture, world_pos.zy);
		vec4 norm_y = texture(normal_texture, world_pos.xz);
		vec4 norm_z = texture(normal_texture, world_pos.xy);
		
		vec3 tex_normal = (norm_x * blend_weights.x + norm_y * blend_weights.y + norm_z * blend_weights.z).rgb * 2.0 - 1.0;
		
		// Align normal tangents according to the projection normal faces
		vec3 normal_out = vec3(0.0);
		normal_out += vec3(0.0, tex_normal.g, tex_normal.r) * world_normal.x;
		normal_out += vec3(tex_normal.r, 0.0, tex_normal.g) * world_normal.y;
		normal_out += vec3(tex_normal.r, tex_normal.g, 0.0) * world_normal.z;
		
		NORMAL_MAP = normalize(normal_out) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_scale;
	}

	// 4. Optional Ambient Occlusion projection
	if (use_ambient_map) {
		vec4 ao_x = texture(ambient_texture, world_pos.zy);
		vec4 ao_y = texture(ambient_texture, world_pos.xz);
		vec4 ao_z = texture(ambient_texture, world_pos.xy);
		
		AO = (ao_x * blend_weights.x + ao_y * blend_weights.y + ao_z * blend_weights.z).r;
		AO_LIGHT_AFFECT = 1.0;
	}

	// 5. Optional Specular and Metallic projection
	if (use_specular_map) {
		vec4 spec_x = texture(specular_texture, world_pos.zy);
		vec4 spec_y = texture(specular_texture, world_pos.xz);
		vec4 spec_z = texture(specular_texture, world_pos.xy);
		
		vec4 spec_tex = spec_x * blend_weights.x + spec_y * blend_weights.y + spec_z * blend_weights.z;
		METALLIC = spec_tex.r;
		SPECULAR = spec_tex.g;
	} else {
		METALLIC = 0.0;
		SPECULAR = 0.5;
	}

	// 6. Cybernetic Emissive Lighting
	if (emission_energy > 0.01) {
		EMISSION = emission_color.rgb * emission_energy;
	}
}
// ==============================================================================
// Shader: Triplanar Blocks PBR with Procedural Edge Beveling
// Description: Custom world-space triplanar mapping shader optimized for voxel
//              materials. Programmatically bended normals near block edges to 
//              simulate smooth rounded bevels (chamfer highlights) under sunlight 
//              without extra polygon overhead.
// SOLID COMPLIANCE: Dedicated exclusively to surface fragment projection and
//                   light-shading calculations (SRP compliant).
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
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

// Procedural Bevel parameters (Smooths blocky corners under direct lighting)
uniform float bevel_width : hint_range(0.01, 0.15) = 0.06;      // Bevel width in meters (6cm)
uniform float bevel_strength : hint_range(0.0, 1.5) = 0.65;    // Rounding curvature intensity

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
	vec3 resolved_normal = world_normal;
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
		
		resolved_normal = normalize(normal_out);
		NORMAL_MAP = resolved_normal * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_scale;
	}

	// 4. Procedural Edge Beveling Calculation (Bends normal vectors near cube borders)
	vec3 local_pos = fract(world_pos);
	vec3 center_dir = local_pos - vec3(0.5);
	vec3 dist_to_edge = vec3(0.5) - abs(center_dir);
	
	// Calculate smooth-curve interpolation factor near the arris boundaries
	vec3 bevel_factor = smoothstep(bevel_width, 0.0, dist_to_edge);
	vec3 perturb = sign(center_dir) * bevel_factor * bevel_strength;
	
	// Apply bended normal offsets perpendicular to the current face normal plane
	vec3 final_normal = resolved_normal;
	if (abs(world_normal.y) > 0.5) {
		final_normal.xz += perturb.xz;
	} else if (abs(world_normal.x) > 0.5) {
		final_normal.yz += perturb.yz;
	} else {
		final_normal.xy += perturb.xy;
	}
	
	NORMAL = normalize(final_normal);

	// 5. Optional Ambient Occlusion projection
	if (use_ambient_map) {
		vec4 ao_x = texture(ambient_texture, world_pos.zy);
		vec4 ao_y = texture(ambient_texture, world_pos.xz);
		vec4 ao_z = texture(ambient_texture, world_pos.xy);
		
		AO = (ao_x * blend_weights.x + ao_y * blend_weights.y + ao_z * blend_weights.z).r;
		AO_LIGHT_AFFECT = 1.0;
	}

	// 6. Optional Specular and Metallic projection
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

	// 7. Cybernetic Emissive Lighting
	if (emission_energy > 0.01) {
		EMISSION = emission_color.rgb * emission_energy;
	}
}
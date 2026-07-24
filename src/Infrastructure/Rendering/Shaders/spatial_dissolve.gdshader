// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/spatial_dissolve.gdshader
// Description: Spatial voxel entity dissolve shader featuring noise-driven 
//              disintegration masking, glowing incandescent ember rims, 
//              and texture albedo blending upon death.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled;

// --- MATERIAL BASE UNIFORMS ---
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 base_albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// --- DISSOLVE & EMBER CONTROLS ---
uniform float dissolve_progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;

uniform vec4 burn_edge_color : source_color = vec4(1.00, 0.35, 0.00, 1.0);
uniform float burn_edge_width : hint_range(0.001, 0.25) = 0.08;
uniform float burn_emission_energy : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	// Sample noise texture value at scaled UV coordinates
	float noise_val = texture(noise_tex, UV * noise_scale).r;
	
	// Hard discard fragments that have dissolved past the progress threshold
	if (noise_val < dissolve_progress) {
		discard;
	}
	
	// Sample original entity albedo texture
	vec4 tex_color = texture(albedo_texture, UV) * base_albedo;
	
	// Detect if current fragment lies within the burning edge rim
	float edge_threshold = dissolve_progress + burn_edge_width;
	bool is_burning_edge = (noise_val < edge_threshold) && (dissolve_progress > 0.001);
	
	if (is_burning_edge) {
		// Render bright incandescent glowing ember rim
		ALBEDO = burn_edge_color.rgb;
		EMISSION = burn_edge_color.rgb * burn_emission_energy;
	} else {
		// Render standard entity visual material
		ALBEDO = tex_color.rgb;
		EMISSION = vec3(0.0);
	}
	
	ALPHA = tex_color.a;
	ROUGHNESS = 0.8;
	METALLIC = 0.0;
}
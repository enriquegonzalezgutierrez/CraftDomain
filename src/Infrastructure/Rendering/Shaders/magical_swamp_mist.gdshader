// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/magical_swamp_mist.gdshader
// Description: Low-lying ground mist fog volume shader featuring swirling 3D noise 
//              rotations, height-attenuated density gradients, and dual-tone 
//              bioluminescent color blending.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type fog;

// --- NOISE & GRADIENT SAMPLERS ---
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform float noise_scale = 1.0;
uniform sampler2D grad_tex : filter_linear_mipmap;
uniform float grad_scale = 1.0;

// --- DENSITY & ROTATION CONTROLS ---
uniform float density_scale : hint_range(0.0, 5.0) = 0.85;
uniform float rotation_speed : hint_range(0.0, 2.0) = 0.18;
uniform float rotate_with_height : hint_range(0.0, 5.0) = 1.0;
uniform vec2 rotation_pivot = vec2(0.5, 0.5);

// --- MIST COLOR PALETTE ---
uniform vec3 albedo_color_a : source_color = vec3(0.08, 0.28, 0.22); // Deep Swamp Teal
uniform vec3 albedo_color_b : source_color = vec3(0.18, 0.52, 0.35); // Bioluminescent Green
uniform vec3 emission_color : source_color = vec3(0.02, 0.12, 0.08); // Subtle Soft Glow

// --- 2D ROTATION UTILITY ---
vec2 rotate_uv(vec2 uv, vec2 pivot, float angle) {
	mat2 rotation_matrix = mat2(
		vec2(sin(angle), -cos(angle)),
		vec2(cos(angle),  sin(angle))
	);
	
	vec2 offset_uv = uv - pivot;
	offset_uv = offset_uv * rotation_matrix;
	return offset_uv + pivot;
}

void fog() {
	// Sample 2D noise with height and time rotations
	vec2 noise_uv = UVW.xz;
	float rot_with_time = TIME;
	float rot_with_height = UVW.y * TAU * rotate_with_height;
	float final_rotation = rot_with_time + rot_with_height;
	
	noise_uv = rotate_uv(noise_uv, rotation_pivot, final_rotation * rotation_speed);
	float noise_value = texture(noise_tex, noise_uv * noise_scale).r;

	// Calculate radial distance to center
	float dist = length(noise_uv - rotation_pivot);

	// Sample vertical density gradient
	vec2 grad_uv = vec2((1.0 - UVW.y) * grad_scale, 0.5);
	float height_gradient = texture(grad_tex, grad_uv).r;
	
	// Compute final mist density
	float final_density = clamp((noise_value * height_gradient) - dist, 0.0, 1.0);
	final_density *= density_scale;
	
	// Output fog attributes
	ALBEDO = mix(albedo_color_a, albedo_color_b, final_density);
	EMISSION = emission_color;
	DENSITY = final_density;
}
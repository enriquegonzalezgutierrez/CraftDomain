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
 * - Removed incompatible TRANSMISSION property to ensure 100% stability across 
 *   all Godot 4.x Forward+ and Mobile rendering backends.
 * Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
 * ============================================================================== */

shader_type spatial;

// RENDER MODES:
// cull_disabled: Renders both sides of the leaf texture (visible from inside out).
// depth_draw_opaque: Required for proper shadow casting with alpha scissor.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// INJECTED PARAMETERS FROM CHUNKNODE.GD
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 block_color : source_color = vec4(1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;

// WIND PARAMETERS
uniform float wind_speed = 1.2;
uniform float wind_strength = 0.04;

void vertex() {
	// 1. Calculate the absolute global position of the vertex
	// This ensures that adjacent blocks of leaves share the same wave phase 
	// and sway together as a single unified tree canopy.
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// 2. Generate a complex, organic wave pattern using overlapping sines/cosines
	float wave_x = sin(world_pos.x * 1.5 + TIME * wind_speed);
	float wave_z = cos(world_pos.z * 1.2 + TIME * wind_speed * 0.8);
	
	// Combine the waves into a single sway factor
	float sway = wave_x * wave_z;
	
	// 3. Displace the vertices horizontally based on the wind strength
	VERTEX.x += sway * wind_strength;
	VERTEX.z += (sway * 0.5) * wind_strength; // Slight diagonal bias
}

void fragment() {
	// 1. Sample the pixel art texture using the native 0-1 BoxMesh UVs
	vec4 tex_color = texture(albedo_texture, UV);
	
	// 2. Apply the dynamic biome color tint (e.g., Oak Green vs Sakura Magenta)
	ALBEDO = tex_color.rgb * block_color.rgb;
	
	// 3. Crisp Alpha Clipping (Discards pixels with less than 50% opacity)
	ALPHA = tex_color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	
	// 4. Physical Material Properties
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}
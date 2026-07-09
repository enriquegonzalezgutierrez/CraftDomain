/* ==============================================================================
 * Project: CraftDomain
 * Description: Infrastructure GPU Shader responsible ONLY for rendering liquid 
 *              surfaces (Water/Lava) with organic wave vertex displacement and 
 *              translucency.
 * SOLID COMPLIANCE:
 * - Single Responsibility Principle (SRP): Isolates the mathematical wave 
 *   calculations and color mixing away from the GDScript CPU loops.
 * Author: Enrique González Gutiérrez <enrique.gonzalez.gutierrez@gmail.com>
 * ============================================================================== */

shader_type spatial;
render_mode blend_mix, depth_draw_always, specular_schlick_ggx, diffuse_burley;

global uniform vec2 wind_vector;
global uniform float wind_strength;

uniform vec4 shallow_water_color : source_color = vec4(0.15, 0.45, 0.85, 0.85);
uniform vec4 deep_water_color : source_color = vec4(0.10, 0.35, 0.65, 0.85);

varying float wave_weight;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_dir = normalize(wind_vector);
	
	float time = TIME * (1.2 + wind_strength * 1.5);
	
	// Calculate a beautiful, organic wave intersecting sine and cosine
	float wave = sin(world_pos.x * 2.0 + time * wind_dir.x) * cos(world_pos.z * 2.0 + time * wind_dir.y);
	float displacement = wave * 0.06 * (1.0 + wind_strength);
	
	// Apply displacement ONLY to top-facing vertices to prevent tearing on the sides/bottom
	if (NORMAL.y > 0.5) {
		VERTEX.y += displacement;
		wave_weight = clamp((wave + 1.0) / 2.0, 0.0, 1.0);
	} else {
		wave_weight = 0.5;
	}
}

void fragment() {
	vec4 final_color = mix(deep_water_color, shallow_water_color, wave_weight);
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
	ROUGHNESS = 0.06;
	METALLIC = 0.12;
}
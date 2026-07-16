// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/liquid_water.gdshader
// Description: Advanced procedural liquid shader supporting water and lava.
//              Features dynamic depth blending, physical shore foam/lava glow lines,
//              Fresnel reflections, and high-frequency procedural normal ripples.
// SOLID COMPLIANCE: Exclusively handles fluid pixel shading and vertex wave displacement.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type spatial;
render_mode blend_mix, depth_draw_always, specular_schlick_ggx, diffuse_burley;

global uniform vec2 wind_vector;
global uniform float wind_strength;

uniform vec4 shallow_water_color : source_color;
uniform vec4 deep_water_color : source_color;

uniform sampler2D depth_texture : hint_depth_texture;

varying float wave_weight;
varying vec3 world_pos;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind_dir = normalize(wind_vector);
	float time = TIME * (1.2 + wind_strength * 1.5);
	
	// Animated multi-sine wave cluster for organic ocean displacement
	float wave = sin(world_pos.x * 2.0 + time * wind_dir.x) * cos(world_pos.z * 2.0 + time * wind_dir.y);
	float displacement = wave * 0.06 * (1.0 + wind_strength);
	
	if (NORMAL.y > 0.5) {
		VERTEX.y += displacement;
		wave_weight = clamp((wave + 1.0) / 2.0, 0.0, 1.0);
	} else {
		wave_weight = 0.5;
	}
}


void fragment() {
	// 1. Core Color Blending based on Wave Weight
	vec4 base_color = mix(deep_water_color, shallow_water_color, wave_weight);
	
	// 2. Depth Buffer Blending (Soft Shore Fading)
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 upscaled_pos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	upscaled_pos.xyz /= upscaled_pos.w;
	float depth_diff = -upscaled_pos.z + VERTEX.z;
	
	// Symmetrical Soft Depth Fade: opaque deep water, transparent at shore
	float depth_fade = clamp(depth_diff / 0.8, 0.0, 1.0);
	
	// 3. Dynamic Shore Foam / Magma Glow
	bool is_lava = deep_water_color.r > 0.8;
	vec3 foam_color = is_lava ? vec3(1.0, 0.35, 0.0) : vec3(0.95, 0.98, 1.0);
	float foam_thickness = is_lava ? 0.35 : 0.18;
	
	float foam_weight = clamp(1.0 - (depth_diff / foam_thickness), 0.0, 1.0);
	// Add animated ripple wave noise to the foam edge
	foam_weight *= smoothstep(0.3, 0.7, sin(TIME * 4.0 + (world_pos.x + world_pos.z) * 8.0) * 0.5 + 0.5);
	
	// 4. Procedural Normal Ripples (Sum of 3 scrolling waves)
	float time_sec = TIME * 1.5;
	vec2 scroll_uv = world_pos.xz * 6.0;
	
	float r1 = sin(scroll_uv.x + time_sec) * 0.08;
	float r2 = cos(scroll_uv.y - time_sec * 1.2) * 0.08;
	float r3 = sin((scroll_uv.x + scroll_uv.y) * 1.5 + time_sec * 0.8) * 0.05;
	
	vec3 ripple_normal = normalize(vec3(r1, 1.0 - (r1*r1 + r2*r2), r2));
	NORMAL = mix(NORMAL, ripple_normal, 0.35);
	
	// 5. Fresnel Reflection
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	
	// Final Color Construction
	vec3 final_albedo = mix(base_color.rgb, foam_color, foam_weight);
	
	// If water, blend with Fresnel sky reflections. If lava, add super-heated glow
	if (is_lava) {
		ALBEDO = final_albedo;
		EMISSION = final_albedo * 1.6; // Emissive magma glow
		ALPHA = 1.0;
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
	} else {
		ALBEDO = mix(final_albedo, vec3(0.9, 0.95, 1.0), fresnel * 0.45);
		ALPHA = base_color.a * depth_fade;
		ROUGHNESS = 0.04;
		METALLIC = 0.12;
	}
}
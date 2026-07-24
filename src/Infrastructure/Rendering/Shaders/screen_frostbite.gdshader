// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/screen_frostbite.gdshader
// Description: Screen-space frostbite vignette shader featuring Voronoi glass 
//              cracks, per-channel frosted blur, chromatic aberration split, 
//              and ice crystal refraction sparkles.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// --- FREEZE PROGRESS CONTROLS ---
uniform float freeze_progress : hint_range(0.0, 1.0) = 0.0;

// --- CELLULAR VORONOI CRACKS ---
uniform int pieces_x = 8;
uniform int pieces_y = 5;
uniform float point_jitter : hint_range(0.0, 0.48) = 0.38;

// --- FROSTED BLUR PARAMETERS ---
uniform float frost_blur : hint_range(0.0, 6.0) = 2.5;
uniform float frost_scatter_radius : hint_range(0.0, 0.02) = 0.006;
uniform int frost_samples = 4; // Optimized sample count for locked 120 FPS

// --- SCREEN WARP DISPLACEMENT ---
uniform float displacement_strength : hint_range(0.0, 0.05) = 0.015;
uniform float edge_displacement_bias : hint_range(0.0, 1.0) = 0.75;

// --- CHROMATIC ABERRATION ---
uniform float chroma_strength : hint_range(0.0, 0.02) = 0.008;
uniform float chroma_edge_bias : hint_range(0.0, 1.0) = 0.60;

// --- ICE VISUAL STYLE ---
uniform float edge_thickness : hint_range(0.0005, 0.04) = 0.006;
uniform float edge_brightness : hint_range(0.0, 3.0) = 1.10;
uniform vec4 ice_tint : source_color = vec4(0.72, 0.88, 1.00, 1.00);
uniform float ice_tint_strength : hint_range(0.0, 1.0) = 0.28;

// --- ICE VIGNETTE GROWTH ---
uniform float growth_edge_bias : hint_range(0.0, 2.0) = 1.20;
uniform float delay_variation : hint_range(0.0, 0.8) = 0.35;

const int SEARCH_RADIUS = 1;

// --- HASHING UTILITIES ---
float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	return vec2(
		hash12(p + vec2(1.23, 4.56)),
		hash12(p + vec2(7.89, 0.12))
	);
}

mat2 rot2(float a) {
	float s = sin(a);
	float c = cos(a);
	return mat2(vec2(c, -s), vec2(s, c));
}

// --- VORONOI CELL CALCULATOR ---
vec2 cell_point(vec2 cell_id) {
	vec2 h = hash22(cell_id);
	return cell_id + 0.5 + (h - 0.5) * (point_jitter * 2.0);
}

void voronoi_info(vec2 p, out vec2 owner_cell, out vec2 owner_point, out float edge_dist) {
	vec2 base = floor(p);
	float best_d = 1e20;
	float second_d = 1e20;
	vec2 best_cell = vec2(0.0);
	vec2 best_point = vec2(0.0);

	for (int j = -SEARCH_RADIUS; j <= SEARCH_RADIUS; j++) {
		for (int i = -SEARCH_RADIUS; i <= SEARCH_RADIUS; i++) {
			vec2 c = base + vec2(float(i), float(j));
			vec2 pt = cell_point(c);
			float d = distance(p, pt);
			if (d < best_d) {
				second_d = best_d;
				best_d = d;
				best_cell = c;
				best_point = pt;
			} else if (d < second_d) {
				second_d = d;
			}
		}
	}
	owner_cell = best_cell;
	owner_point = best_point;
	edge_dist = second_d - best_d;
}

// --- FROSTED BLUR SAMPLING ---
vec4 sample_frost_chroma(vec2 uv_r, vec2 uv_g, vec2 uv_b, float blur_amount) {
	vec3 col = vec3(0.0);
	float a = 0.0;
	float mip = blur_amount * frost_blur;

	for (int i = 0; i < frost_samples; i++) {
		vec2 jitter_seed = uv_g + vec2(float(i) * 0.371, float(i) * 0.618);
		vec2 offset = (hash22(jitter_seed * 31.7) - 0.5) * 2.0 * frost_scatter_radius * blur_amount;
		col.r += textureLod(screen_tex, clamp(uv_r + offset, vec2(0.0), vec2(1.0)), mip).r;
		col.g += textureLod(screen_tex, clamp(uv_g + offset, vec2(0.0), vec2(1.0)), mip).g;
		col.b += textureLod(screen_tex, clamp(uv_b + offset, vec2(0.0), vec2(1.0)), mip).b;
		a     += textureLod(screen_tex, clamp(uv_g + offset, vec2(0.0), vec2(1.0)), mip).a;
	}
	return vec4(col / float(frost_samples), a / float(frost_samples));
}

vec4 sample_frost(vec2 uv, float blur_amount) {
	vec4 col = vec4(0.0);
	float mip = blur_amount * frost_blur;

	for (int i = 0; i < frost_samples; i++) {
		vec2 jitter_seed = uv + vec2(float(i) * 0.371, float(i) * 0.618);
		vec2 offset = (hash22(jitter_seed * 31.7) - 0.5) * 2.0 * frost_scatter_radius * blur_amount;
		col += textureLod(screen_tex, clamp(uv + offset, vec2(0.0), vec2(1.0)), mip);
	}
	return col / float(frost_samples);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 grid = vec2(float(pieces_x), float(pieces_y));

	// Superellipse Vignette Mask
	vec2 q = abs(uv - 0.5);
	float superellipse_pow = mix(2.0, 10.0, clamp(growth_edge_bias / 2.0, 0.0, 1.0));
	float sdf = pow(pow(q.x, superellipse_pow) + pow(q.y, superellipse_pow), 1.0 / superellipse_pow);

	float vignette = clamp(sdf / 0.5, 0.0, 1.0);
	float pixel_freeze = clamp(vignette * 0.5 + freeze_progress * 1.2 - 0.2, 0.0, 1.0);

	// Voronoi crack computation
	vec2 p_now = uv * grid;
	vec2 now_cell, now_point;
	float now_edge;
	voronoi_info(p_now, now_cell, now_point, now_edge);

	float rnd_cell = hash12(now_cell);
	float cell_offset = (rnd_cell - 0.5) * delay_variation * 0.4;
	float cell_t = clamp((pixel_freeze - cell_offset) / max(0.0001, 1.0 - abs(cell_offset)), 0.0, 1.0);
	cell_t = smoothstep(0.0, 1.0, cell_t);

	float edge_core = 1.0 - smoothstep(0.0, edge_thickness * 0.35, now_edge);
	float edge_rim  = 1.0 - smoothstep(0.0, edge_thickness, now_edge);
	float edge_factor = edge_core;

	// Screen Space Displacement
	vec2 cell_center_uv = now_point / grid;
	vec2 displace_dir = normalize(uv - cell_center_uv + vec2(0.0001));
	float displace_amount = mix(
		displacement_strength * cell_t * 0.3,
		displacement_strength * cell_t,
		edge_factor * edge_displacement_bias
	);
	
	float rnd_angle = (hash12(now_cell + 3.7) - 0.5) * 0.8;
	displace_dir = rot2(rnd_angle) * displace_dir;
	vec2 warped_uv = clamp(uv + displace_dir * displace_amount, vec2(0.0), vec2(1.0));

	// Chromatic Aberration Shift
	vec2 chroma_dir = rot2(1.5708) * displace_dir;
	float chroma_drama = pow(freeze_progress, 2.5);
	float chroma_amount = chroma_strength * cell_t * (1.0 + edge_factor * chroma_edge_bias) * (1.0 + chroma_drama * 5.0);
	vec2 uv_r = clamp(warped_uv + chroma_dir * chroma_amount,  vec2(0.0), vec2(1.0));
	vec2 uv_g = warped_uv;
	vec2 uv_b = clamp(warped_uv - chroma_dir * chroma_amount,  vec2(0.0), vec2(1.0));

	float frost_blend  = smoothstep(0.2, 1.0, cell_t);
	float chroma_blend = smoothstep(0.0, 0.4, cell_t);

	vec4 col_base = texture(screen_tex, warped_uv);
	vec4 col_frost_chroma = sample_frost_chroma(uv_r, uv_g, uv_b, cell_t);
	vec4 col_frost_plain  = sample_frost(warped_uv, cell_t);
	vec4 col_frost = mix(col_frost_plain, col_frost_chroma, chroma_blend);

	vec4 col = mix(col_base, col_frost, frost_blend);

	// Apply Ice Tint
	col.rgb = mix(col.rgb, ice_tint.rgb * (col.r * 0.2 + col.g * 0.5 + col.b * 0.3 + 0.4), ice_tint_strength * cell_t);

	// Crack Edge Highlights
	vec3 edge_color = mix(vec3(1.0), ice_tint.rgb, 0.3) * edge_brightness;
	col.rgb += edge_core * edge_color * cell_t;
	col.rgb += edge_rim  * edge_color * 0.18 * cell_t;

	// Refraction Sparkles
	float sparkle_noise = hash12(uv * 387.3 + freeze_progress * 13.7);
	float sparkle = step(0.985, sparkle_noise) * cell_t * edge_core;
	col.rgb += sparkle * 1.5;

	// Final Color Mix
	vec4 original = texture(screen_tex, uv);
	col = mix(original, col, cell_t);

	COLOR = col;
}
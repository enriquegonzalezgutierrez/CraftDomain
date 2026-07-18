// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/celestial_sky.gdshader
// Description: Advanced sky shader utilizing pre-baked FBM noise textures for
//              ultra-high performance parallax clouds and astronomical bodies.
//              VISUAL UPGRADE: Implemented simulated volumetric self-shading,
//              edge glow, and horizon blending for majestic, fluffy clouds.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type sky;
render_mode use_half_res_pass;

// Sourced globally from project.godot settings
global uniform vec2 wind_vector;
global uniform float wind_strength;
global uniform float storm_weight;

// Injected dynamically by CelestialService.gd (DIP Compliant)
uniform float day_weight : hint_range(0.0, 1.0) = 0.5;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_direction = vec3(0.0, -1.0, 0.0);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;

// Pre-baked seamless cloud noise texture
uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;

// Sky Parameters
uniform float power = 0.5;
uniform float scale = 0.05;       // Decreased for massive, majestic cloud clumps
uniform float speed = 0.015;      // Slower, more natural cloud drift
uniform float density : hint_range(0.0, 1.0) = 0.42;

// Day & Night Gradients
uniform vec3 sky_color_top : source_color = vec3(0.12, 0.42, 0.85);    // Zenith Day Blue
uniform vec3 sky_color_bottom : source_color = vec3(0.42, 0.65, 0.88); // Horizon Day Blue

uniform vec3 sky_night_top : source_color = vec3(0.005, 0.005, 0.015);  // Zenith Night Navy
uniform vec3 sky_night_bottom : source_color = vec3(0.015, 0.02, 0.04); // Horizon Night Navy

uniform vec3 ground_color_top : source_color = vec3(0.2, 0.169, 0.133);
uniform vec3 ground_color_bottom : source_color = vec3(0.1, 0.08, 0.06);

// 3D hash for twinkling star positions
float hash3d(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

vec3 calculate_sky_base(vec3 eye) {
	vec3 grad_day = mix(sky_color_bottom, sky_color_top, clamp(eye.y, 0.0, 1.0));
	vec3 grad_night = mix(sky_night_bottom, sky_night_top, clamp(eye.y, 0.0, 1.0));
	return mix(grad_night, grad_day, day_weight);
}

void sky() {
	// Smoother fade formula so clouds naturally vanish near the horizon line
	float fade = pow(clamp(EYEDIR.y, 0.0, 1.0), 1.5);
	vec3 sky_back = vec3(0.0);
	
	if (EYEDIR.y > 0.0) {
		// 1. DAY/NIGHT SKY GRADIENT
		sky_back = calculate_sky_base(EYEDIR);
		
		// 2. TWINKLING STARS (ONLY AT NIGHT)
		if (day_weight < 0.95) {
			vec3 star_grid = EYEDIR * 220.0;
			float star_noise = hash3d(floor(star_grid));
			if (star_noise > 0.994) {
				float twinkle = sin(TIME * 3.5 + star_noise * 120.0) * 0.5 + 0.5;
				float star_vis = (1.0 - day_weight) * twinkle * smoothstep(0.02, 0.22, EYEDIR.y);
				sky_back += vec3(star_vis) * (1.0 - storm_weight * 0.85);
			}
		}
		
		// 3. SUN DISK
		vec3 norm_sun_dir = normalize(sun_direction);
		float sun_dot = dot(EYEDIR, norm_sun_dir);
		if (sun_dot > 0.992) {
			float sun_disk = smoothstep(0.993, 0.995, sun_dot);
			vec3 sun_color = vec3(1.0, 0.98, 0.90) * 1.5;
			sky_back = mix(sky_back, sun_color, sun_disk * day_weight);
		}
		
		// 4. MOON DISK WITH PROCEDURAL SHADED PHASES
		vec3 norm_moon_dir = normalize(moon_direction);
		float moon_dot = dot(EYEDIR, norm_moon_dir);
		
		if (moon_dot > 0.994 && day_weight < 0.95) {
			vec3 up_vec = abs(norm_moon_dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0);
			vec3 tangent_u = normalize(cross(norm_moon_dir, up_vec));
			vec3 tangent_v = cross(tangent_u, norm_moon_dir);
			
			vec2 moon_uv = vec2(dot(EYEDIR, tangent_u), dot(EYEDIR, tangent_v)) * (1.0 / 0.077);
			float dist_sq = dot(moon_uv, moon_uv);
			
			if (dist_sq <= 1.0) {
				vec3 moon_normal = vec3(moon_uv, sqrt(max(0.0, 1.0 - dist_sq)));
				float phase_angle = (moon_phase - 0.5) * 3.14159265 * 2.0;
				vec3 phase_light_dir = normalize(vec3(sin(phase_angle), 0.0, cos(phase_angle)));
				
				float phase_shade = dot(moon_normal, phase_light_dir);
				float moon_alpha = smoothstep(-0.06, 0.06, phase_shade);
				
				float craters = texture(cloud_texture, moon_uv * 0.25).r * 0.22 + 0.78;
				vec3 moon_color = vec3(0.92, 0.94, 0.98) * craters * (1.0 - day_weight);
				
				sky_back = mix(sky_back, moon_color, moon_alpha * smoothstep(1.0, 0.96, dist_sq));
			}
		}
		
		// 5. VOLUMETRIC PARALLAX CLOUDS
		vec2 sky_uv = EYEDIR.xz / EYEDIR.y;
		vec2 wind_offset = wind_vector * (TIME * speed * (1.0 + wind_strength));
		
		// Layer A: Base Structure
		vec2 coord_a = sky_uv * scale - wind_offset;
		// Layer B: Detail Fluff (Faster drift, smaller scale)
		vec2 coord_b = sky_uv * (scale * 2.2) - (wind_offset * 1.4) + vec2(TIME * 0.003, TIME * -0.002);
		
		float layer_a = texture(cloud_texture, coord_a).r;
		float layer_b = texture(cloud_texture, coord_b).r;
		
		// Base noise mask (fade applied to push clouds away from the horizon)
		float clouds_noise = (layer_a * 0.65 + layer_b * 0.35) * fade;
		
		// Hard density cutoff
		float dens = smoothstep(density, density + 0.15, clouds_noise);
		
		if (dens > 0.0) {
			// Volumetric self-shading: sample density slightly offset towards the active light source
			vec3 active_light_dir = mix(normalize(moon_direction), normalize(sun_direction), day_weight);
			vec2 light_offset = normalize(active_light_dir.xz) * 0.045; // Vector pushing into the light
			
			float layer_a_light = texture(cloud_texture, coord_a + light_offset).r;
			float layer_b_light = texture(cloud_texture, coord_b + light_offset).r;
			float clouds_noise_light = (layer_a_light * 0.65 + layer_b_light * 0.35) * fade;
			
			// If the shifted sample is less dense, it means this pixel is on the edge facing the light
			float edge_glow = smoothstep(0.0, 0.15, clouds_noise - clouds_noise_light);
			
			// Define base cloud colors based on time of day
			vec3 lit_color = mix(vec3(0.65, 0.68, 0.72), vec3(1.0, 0.98, 0.95), day_weight);
			vec3 shadow_color = mix(vec3(0.04, 0.05, 0.08), vec3(0.45, 0.50, 0.60), day_weight);
			
			// Interpolate between shadow belly and lit tops
			vec3 cloud_shading = mix(shadow_color, lit_color, smoothstep(-0.05, 0.15, clouds_noise - clouds_noise_light));
			
			// Add the burning bright edge glow rim
			cloud_shading = mix(cloud_shading, vec3(1.15, 1.10, 1.0), edge_glow * 0.65 * day_weight);
			
			// Overwrite cloud colors during storms
			cloud_shading = mix(cloud_shading, vec3(0.08, 0.09, 0.11), storm_weight * 0.85);
			
			// Blend the cloud over the sky background
			sky_back = mix(sky_back, cloud_shading, dens * (1.0 - storm_weight * 0.35));
		}
	} else {
		sky_back = mix(ground_color_top, ground_color_bottom, -EYEDIR.y);
	}
	
	COLOR = sky_back;
	
	// 6. STORM OVERCAST WASH
	vec3 overcast_color = vec3(0.12, 0.13, 0.15);
	COLOR = mix(COLOR, overcast_color, storm_weight * 0.72);
}
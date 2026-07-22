// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/underwater_post_process.gdshader
// Description: Fullscreen Post-Process Shader for underwater camera submersion.
//              Applies fluid refraction distortion, blue/cyan tinting, and edge vignette.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(0.06, 0.42, 0.75, 0.45);
uniform float wave_speed : hint_range(0.1, 10.0) = 1.8;
uniform float wave_amplitude : hint_range(0.001, 0.05) = 0.004;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;

void fragment() {
	// 1. Calculate water refraction screen-space UV distortion
	vec2 distorted_uv = SCREEN_UV;
	distorted_uv.x += sin(SCREEN_UV.y * 15.0 + TIME * wave_speed) * wave_amplitude;
	distorted_uv.y += cos(SCREEN_UV.x * 12.0 + TIME * wave_speed * 1.15) * wave_amplitude;
	
	// 2. Sample the distorted screen viewport texture
	vec4 screen_color = texture(screen_texture, distorted_uv);
	
	// 3. Compute radial vignette (darkening of screen corners)
	float dist_from_center = distance(SCREEN_UV, vec2(0.5));
	float vignette = smoothstep(0.35, 0.85, dist_from_center);
	
	// 4. Mix base screen, blue tint, and deep-water vignette
	vec3 final_color = mix(screen_color.rgb, tint_color.rgb, tint_color.a);
	final_color = mix(final_color, vec3(0.015, 0.02, 0.04), vignette * 0.72);
	
	COLOR = vec4(final_color, 1.0);
}
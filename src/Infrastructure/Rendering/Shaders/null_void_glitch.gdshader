// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/null_void_glitch.gdshader
// Description: Post-processing screen-space shader representing the Null Void.
//              Applies dynamic chromatic aberration and horizontal scanline 
//              vibrations based on glitch intensity.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;


// Pseudo-random noise generator for digital scanline jitters
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Zero-overhead bypass if the player is in safe, uncorrupted territory
	if (glitch_intensity <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
		return;
	}
	
	vec2 uv = SCREEN_UV;
	
	// 1. Horizontal Scanline Jitter (Robotic horizontal shifts)
	float jitter = (rand(vec2(TIME, floor(uv.y * 32.0))) * 2.0 - 1.0) * glitch_intensity * 0.015;
	if (rand(vec2(TIME, 0.0)) < 0.22 * glitch_intensity) {
		uv.x += jitter;
	}
	
	// 2. Chromatic Aberration (Color channel splitting: Red and Blue drift)
	float ab_offset = glitch_intensity * 0.012;
	float r_chan = texture(screen_texture, vec2(uv.x - ab_offset, uv.y)).r;
	var g_chan = texture(screen_texture, uv).g;
	float b_chan = texture(screen_texture, vec2(uv.x + ab_offset, uv.y)).b;
	
	vec3 final_color = vec3(r_chan, g_chan, b_chan);
	
	// 3. Grid Scanline Overlap (Interlaced monitor scanlines)
	float scanline = sin(uv.y * 420.0) * 0.04 * glitch_intensity;
	final_color -= vec3(scanline);
	
	COLOR = vec4(final_color, 1.0);
}
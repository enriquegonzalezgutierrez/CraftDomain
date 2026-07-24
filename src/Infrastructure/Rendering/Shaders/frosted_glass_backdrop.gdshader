// ==============================================================================
// Pathfile: res://src/Infrastructure/Rendering/Shaders/frosted_glass_backdrop.gdshader
// Description: Real-time frosted glass backdrop blur canvas item shader for 
//              glassmorphic UI panels, blurring screen textures behind dark cards.
// Author: Enrique González Gutiérrez
// Email: enrique.gonzalez.gutierrez@gmail.com
// ==============================================================================
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// --- FROSTED GLASS CONTROLS ---
uniform float blur_lod : hint_range(0.0, 5.0) = 3.2;
uniform vec4 glass_tint : source_color = vec4(0.08, 0.08, 0.12, 0.85);
uniform float vibrancy_boost : hint_range(1.0, 2.0) = 1.15;

void fragment() {
	// Sample blurred background screen texture using mipmap level LOD
	vec3 bg_color = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	
	// Apply vibrancy saturation boost
	vec3 grayscale = vec3(dot(bg_color, vec3(0.299, 0.587, 0.114)));
	bg_color = mix(grayscale, bg_color, vibrancy_boost);
	
	// Blend blurred background with glass tint overlay
	vec4 card_color = COLOR;
	vec3 final_color = mix(bg_color, card_color.rgb * glass_tint.rgb, glass_tint.a);

	COLOR = vec4(final_color, 1.0);
}
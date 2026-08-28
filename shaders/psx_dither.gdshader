shader_type canvas_item;

// PSX-style post-process: ordered (Bayer 4x4) dithering + reduced color
// levels, approximating the original PlayStation's ~15-bit color depth
// banding. Apply this shader to a full-screen ColorRect (anchored to fill
// the viewport, mouse_filter = Ignore) placed above everything else via a
// CanvasLayer.
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 64.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;

const mat4 BAYER_4X4 = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0)
) / 16.0;

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;

	ivec2 grid_pos = ivec2(mod(FRAGCOORD.xy, 4.0));
	float threshold = (BAYER_4X4[grid_pos.x][grid_pos.y] - 0.5) * dither_strength;

	vec3 dithered = color + threshold / color_levels;
	COLOR = vec4(floor(dithered * color_levels + 0.5) / color_levels, 1.0);
}

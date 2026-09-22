shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_lambert, specular_disabled;

uniform sampler2D grass_texture : source_color, filter_nearest;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Viento suave
uniform float wind_strength : hint_range(0.0, 1.0) = 0.14;
uniform float wind_speed : hint_range(0.0, 5.0) = 2.4;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.4);
uniform float plant_max_height = 0.40;
uniform vec3 backlight_tint = vec3(0.35, 0.50, 0.20);
uniform float backlight_strength = 0.40;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_ratio = clamp(VERTEX.y / plant_max_height, 0.0, 1.0);
	float bend = pow(height_ratio, 1.3);
	
	float wave = sin(TIME * wind_speed + world_pos.x * 2.2 + world_pos.z * 1.6) * wind_strength * bend;
	vec3 dir = normalize(wind_direction);
	VERTEX.x += dir.x * wave;
	VERTEX.z += dir.z * wave;
	VERTEX.y -= abs(wave) * 0.12;
}

void fragment() {
	vec4 tex = texture(grass_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
	BACKLIGHT = ALBEDO * backlight_tint * backlight_strength;
}

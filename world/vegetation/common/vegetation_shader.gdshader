shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_opaque, diffuse_lambert, specular_disabled;

// Parámetros de viento botánico
uniform float wind_strength : hint_range(0.0, 1.0) = 0.16;
uniform float wind_speed : hint_range(0.0, 5.0) = 2.2;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.35);
uniform float plant_base_y = 0.0;
uniform float plant_max_height = 0.85;

// Parámetros de material
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform vec3 backlight_tint = vec3(0.35, 0.45, 0.20);
uniform float backlight_strength : hint_range(0.0, 1.0) = 0.45;

void vertex() {
	// Cálculo de oscilación por viento natural según la altura del vértice
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_ratio = clamp((VERTEX.y - plant_base_y) / plant_max_height, 0.0, 1.0);
	float bend = pow(height_ratio, 1.4);
	
	// Dos ondas armónicas para evitar movimiento rígido
	float wave1 = sin(TIME * wind_speed + world_pos.x * 1.8 + world_pos.z * 1.2);
	float wave2 = sin(TIME * wind_speed * 1.7 + world_pos.x * 3.1 + world_pos.z * 2.3) * 0.35;
	float sway = (wave1 + wave2) * wind_strength * bend;
	
	vec3 dir = normalize(wind_direction);
	VERTEX.x += dir.x * sway;
	VERTEX.z += dir.z * sway;
	VERTEX.y -= abs(sway) * 0.15; // Ligera compresión al inclinarse
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	// Retroiluminación / dispersión subsuperficial para que las flores y el césped brillen con el sol/atardecer
	BACKLIGHT = ALBEDO * backlight_tint * backlight_strength;
}

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Uniforms de viento botánico
uniform float wind_strength : hint_range(0.0, 1.0) = 0.25;
uniform float wind_speed : hint_range(0.0, 5.0) = 2.2;
uniform float plant_max_height : hint_range(0.1, 3.0) = 1.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

// Parámetros de material
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.65;
uniform float specular : hint_range(0.0, 1.0) = 0.2;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool use_texture = false;

void vertex() {
	// Factor de altura: la raíz en y=0 no se mueve (0.0), la cima se mueve al máximo (1.0)
	float h_factor = clamp(VERTEX.y / max(plant_max_height, 0.05), 0.0, 1.0);
	float bend_curve = pow(h_factor, 1.6); // Curvatura orgánica de tallo
	
	// Fase de tiempo con variación espacial
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float time = TIME * wind_speed;
	
	// Oscilación suave principal del tallo
	vec3 norm_wind = normalize(wind_direction);
	float main_sway = sin(time + world_pos.x * 0.5 + world_pos.z * 0.5) * wind_strength * 0.12;
	
	// Micro-aleteo de hojas y pétalos (alta frecuencia en la parte alta)
	float petal_flutter = sin(time * 2.8 + (world_pos.x + world_pos.y) * 4.0) * wind_strength * 0.03 * h_factor;
	
	vec3 offset = norm_wind * (main_sway * bend_curve) + vec3(0.0, -abs(main_sway * 0.3 * bend_curve), 0.0);
	offset += vec3(-norm_wind.z, 0.0, norm_wind.x) * (petal_flutter * bend_curve);
	
	VERTEX += offset;
}

void fragment() {
	vec4 base_color = COLOR; // Color proveniente del generador procedural (vertex colors)
	
	if (use_texture) {
		vec4 tex = texture(albedo_texture, UV);
		if (tex.a < alpha_scissor_threshold) {
			discard;
		}
		base_color *= tex;
	}
	
	ALBEDO = base_color.rgb;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Retroiluminación / Translucidez botánica (Subsurface Scattering aproximado)
	// Cuando el sol está detrás de un pétalo, este se ilumina cálidamente
	BACKLIGHT = ALBEDO * 0.42;
}

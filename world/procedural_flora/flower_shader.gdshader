shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx;

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
uniform vec3 backlight_tint = vec3(0.25, 0.45, 0.15);

void vertex() {
	// Billboard en GPU para LOD 1 y LOD 2 (Cero costo de CPU en GDScript)
	// UV.y == 1.0 -> Billboard esférico (hojas y flores 2D orientadas a la cámara)
	// UV.y == 2.0 -> Billboard axial cilíndrico (tallos y ramas 2D orientados a la cámara)
	if (UV.y > 0.5 && UV.y < 1.5) {
		vec3 center = VERTEX;
		vec2 b_offset = UV2;
		vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
		vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
		VERTEX = center + cam_right * b_offset.x + cam_up * b_offset.y;
		NORMAL = normalize(-INV_VIEW_MATRIX[2].xyz * 0.75 + vec3(0.0, 0.40, 0.0) + cam_right * (b_offset.x * 0.8));
	} else if (UV.y > 1.5) {
		vec3 seg_dir = NORMAL;
		vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
		vec3 to_cam = normalize(cam_pos - VERTEX);
		vec3 side = cross(seg_dir, to_cam);
		if (dot(side, side) > 0.0001) {
			side = normalize(side);
		} else {
			side = normalize(cross(seg_dir, vec3(0.0, 1.0, 0.0)));
		}
		VERTEX += side * UV.x;
		NORMAL = normalize(cross(side, seg_dir));
	}

	// Factor de altura: la raíz en y=0 no se mueve (0.0), la cima se mueve al máximo (1.0)
	float h_factor = clamp(VERTEX.y / max(plant_max_height, 0.05), 0.0, 1.0);
	float bend_curve = pow(h_factor, 1.6); // Curvatura orgánica de tallo
	
	// Fase de tiempo con variación espacial
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float time = TIME * wind_speed;
	
	// Oscilación suave principal del tallo
	vec3 norm_wind = normalize(wind_direction);
	float main_sway = sin(time + world_pos.x * 0.5 + world_pos.z * 0.5) * wind_strength * 0.12;
	
	// Micro-aleteo de hojas y pétalos (solo para LOD 0 cercano; se omite en billboards UV.y > 0.5 para máximo ahorro de GPU)
	float petal_flutter = 0.0;
	if (UV.y < 0.5) {
		petal_flutter = sin(time * 2.8 + (world_pos.x + world_pos.y) * 4.0) * wind_strength * 0.03 * h_factor;
	}
	
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
	if (UV.y > 0.5) {
		BACKLIGHT = ALBEDO * (backlight_tint * 0.60);
	} else {
		BACKLIGHT = ALBEDO * backlight_tint;
	}
}

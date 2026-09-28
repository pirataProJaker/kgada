shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 foliage_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.25;
uniform float backlight_energy : hint_range(0.0, 2.0) = 0.45;

void vertex() {
	// Brisa sutil que anima suavemente el follaje exterior
	float sway = sin(TIME * 2.0 + VERTEX.x * 0.7 + VERTEX.y * 1.1 + VERTEX.z * 0.5) * 0.035;
	float height_factor = clamp((VERTEX.y - 2.0) * 0.08, 0.0, 1.0);
	VERTEX.x += sway * height_factor;
	VERTEX.z += sway * 0.7 * height_factor;
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	if (tex.a < alpha_scissor_threshold) {
		discard;
	}
	
	// Invertir la normal en caras traseras para evitar que el término de Fresnel
	// se dispare al 100% (Fresnel = 1.0) creando brillos plateados tipo espejo.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;

	vec3 base_col = tex.rgb * foliage_tint.rgb;
	ALBEDO = base_col;
	ROUGHNESS = 0.88;
	SPECULAR = 0.08; // Materia orgánica vegetal, no plástico reflectante ni metal
	METALLIC = 0.0;
	
	// Translúcencia botánica (sub-surface scattering) a contraluz solar:
	// La luz solar se filtra naturalmente a través de las hojas verdes
	BACKLIGHT = base_col * backlight_energy;
}

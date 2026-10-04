shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Array de texturas de calcomanías (desgaste, grafitis, humedad, grietas, etc.)
uniform sampler2DArray decal_array : source_color, filter_linear_mipmap;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.05;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.95;
uniform float specular_val : hint_range(0.0, 1.0) = 0.04;

varying flat int v_layer;
varying vec2 v_flip;
varying float v_alpha;

void vertex() {
	// Codificación de atributos por instancia en COLOR:
	// COLOR.r: Índice de capa (layer) en Texture2DArray escalado por 255.0
	// COLOR.g: Volteado horizontal (1.0 = flip_h activo, 0.0 = normal)
	// COLOR.b: Volteado vertical (1.0 = flip_v activo, 0.0 = normal)
	// COLOR.a: Multiplicador de opacidad / alfa (1.0 por defecto)
	v_layer = int(round(COLOR.r * 255.0));
	v_flip = vec2(COLOR.g, COLOR.b);
	v_alpha = COLOR.a;
}

void fragment() {
	vec2 uv = UV;
	if (v_flip.x > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	if (v_flip.y > 0.5) {
		uv.y = 1.0 - uv.y;
	}

	vec4 tex_color = texture(decal_array, vec3(uv, float(v_layer)));
	
	float final_alpha = tex_color.a * v_alpha;
	if (final_alpha < alpha_threshold) {
		discard;
	}

	ALBEDO = tex_color.rgb;
	ALPHA = final_alpha;
	ROUGHNESS = roughness_val;
	SPECULAR = specular_val;
}

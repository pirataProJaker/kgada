shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Array Universal de Texturas Inteligentes para Mobiliario y Electrodomésticos (Play Sector X)
// Capas indexadas mediante claves semánticas (maderas, refrigerador, estufa, lavadora, sillón, etc.)
uniform sampler2DArray furniture_textures : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2DArray wood_textures : source_color, filter_nearest_mipmap, repeat_enable; // Alias retrocompatible
uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform float default_roughness : hint_range(0.0, 1.0) = 0.55;
uniform float default_metallic : hint_range(0.0, 1.0) = 0.02;

varying flat int v_layer;
varying float v_roughness;
varying float v_metallic;

void vertex() {
	// Codificación de atributos por instancia en COLOR:
	// COLOR.r: Índice de capa (layer) en Texture2DArray escalado por 255.0
	// COLOR.g: Rugosidad personalizada (e.g. 0.35 para esmalte, 0.65 para cuero)
	// COLOR.b: Metálico personalizado (e.g. 0.15 para electrodomésticos, 0.02 para madera)
	// COLOR.a: Escala UV o factor de tintado
	v_layer = int(round(COLOR.r * 255.0));
	v_roughness = COLOR.g > 0.01 ? COLOR.g : default_roughness;
	v_metallic = COLOR.b > 0.005 ? COLOR.b : default_metallic;
}

void fragment() {
	vec3 tex_col = texture(furniture_textures, vec3(UV * uv_scale, float(v_layer))).rgb;
	ALBEDO = tex_col;
	ROUGHNESS = v_roughness;
	METALLIC = v_metallic;
	SPECULAR = 0.40;
}

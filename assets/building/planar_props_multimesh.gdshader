shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Shader Universal de Planos 2D con Atlas Inteligente (Play Sector X)
// Indexa dinámicamente cualquier alfombra, póster, cuadro o plano 2D desde Texture2DArray.
uniform sampler2DArray planar_textures : source_color, filter_linear_mipmap, repeat_disable;
uniform float default_roughness : hint_range(0.0, 1.0) = 0.90;
uniform float default_metallic : hint_range(0.0, 1.0) = 0.0;

varying flat int v_layer;
varying float v_roughness;
varying float v_metallic;

void vertex() {
	// COLOR.r codifica el layer_id (0 a 255) en el Texture2DArray
	v_layer = int(round(COLOR.r * 255.0));
	v_roughness = COLOR.g > 0.01 ? COLOR.g : default_roughness;
	v_metallic = COLOR.b > 0.005 ? COLOR.b : default_metallic;
}

void fragment() {
	vec3 tex_col = texture(planar_textures, vec3(clamp(UV, 0.0, 1.0), float(v_layer))).rgb;
	ALBEDO = tex_col;
	ROUGHNESS = v_roughness;
	METALLIC = v_metallic;
	SPECULAR = 0.25;
}

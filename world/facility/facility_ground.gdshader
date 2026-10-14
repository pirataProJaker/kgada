shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// =========================================================================
// SHADER DE SUELO PROCEDURAL MILITAR (PLAY SECTOR X)
// =========================================================================
// Mapea exactamente 1 textura por cada celda de cuadrícula 1x1 (4m x 4m)
// utilizando Texture2DArray indexado mediante COLOR.r en MultiMesh (+0 Draw Calls).
//
// Capas clave en Texture2DArray:
// • Capa 29: Franjas amarillas y negras de peligro / advertencia en el suelo.
// • Capa 22: Borde táctico de advertencia.
// • Capa 14 / 16: Asfalto oscuro y pistas de rodaje militar.
// • Capa 26 / 23: Losas de hormigón reforzado para cuarteles y banquetas.
// • Capa 28 / 35: Losa táctica de helipuerto y chevrons.
// • Capa 31 / 27: Rejillas metálicas y suelo de talleres / hangares.
// • Capa 17 / 25: Tierra, grava y terreno verde oliva de camuflaje.

uniform sampler2DArray tile_array : source_color, filter_nearest_mipmap, repeat_enable;
uniform float hazard_zoom : hint_range(0.1, 4.0, 0.05) = 1.0;
uniform bool continuous_hazard = false;

varying flat int v_layer;
varying float v_roughness;
varying vec2 v_world_xz;

void vertex() {
	v_layer = int(round(COLOR.r * 255.0));
	v_roughness = COLOR.g > 0.001 ? COLOR.g : 0.85;
	v_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Mapeo planar perfecto en espacio de mundo: 1 metro de mundo = 1 repetición exacta de textura
	vec2 uv_to_use = v_world_xz;
	vec3 tex_col = texture(tile_array, vec3(uv_to_use, float(v_layer))).rgb;
	ALBEDO = tex_col;
	ROUGHNESS = v_roughness;
}

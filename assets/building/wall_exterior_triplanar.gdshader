shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Shader Triplanar Anti-Tiling para Fachadas Exteriores de Casas con Texture2DArray
// Permite que TODAS las casas (amarilla, azul, blanca, etc.) compartan un solo material y Draw Call.

instance uniform int wall_layer = 0;
uniform sampler2DArray wall_textures : source_color, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 0.35;
uniform float sharpness = 3.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.90;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Muestreo suave anti-repetición de doble escala áurea sobre la capa seleccionada
vec4 sample_anti_tile(sampler2DArray tex_arr, vec2 uv, float layer) {
	vec4 col1 = texture(tex_arr, vec3(uv, layer));
	// Escala áurea 1.618033 con desfase diagonal
	vec2 uv2 = uv * 1.618033 + vec2(0.413, 0.739);
	vec4 col2 = texture(tex_arr, vec3(uv2, layer));
	
	// Modulación muy suave y natural de baja frecuencia
	float w = sin(uv.x * 0.91 + uv.y * 0.63) * 0.5 + 0.5;
	w = smoothstep(0.2, 0.8, w) * 0.35;
	
	return mix(col1, col2, w);
}

void fragment() {
	vec3 blend_weights = abs(world_normal);
	blend_weights = pow(blend_weights, vec3(sharpness));
	blend_weights /= (blend_weights.x + blend_weights.y + blend_weights.z + 0.0001);

	float layer = float(wall_layer);

	// Proyección triplanar en espacio de mundo
	vec2 uv_x = world_pos.zy * uv_scale;
	vec2 uv_y = world_pos.xz * uv_scale;
	vec2 uv_z = world_pos.xy * uv_scale;

	vec4 col_x = sample_anti_tile(wall_textures, uv_x, layer);
	vec4 col_y = sample_anti_tile(wall_textures, uv_y, layer);
	vec4 col_z = sample_anti_tile(wall_textures, uv_z, layer);

	vec4 blended_albedo = col_x * blend_weights.x + col_y * blend_weights.y + col_z * blend_weights.z;

	ALBEDO = blended_albedo.rgb * COLOR.rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.02;
	SPECULAR = 0.2;
}

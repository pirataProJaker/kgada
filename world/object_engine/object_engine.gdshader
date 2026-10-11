shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// =========================================================================
// SHADER UNIVERSAL DEL MOTOR DE OBJETOS (PLAY SECTOR X)
// =========================================================================
// Dibuja miles de objetos de cientos de tipos distintos a +0 Draw Calls combinando:
// 1. Texture2DArray: El Atlas Inteligente de capas apiladas (sin sangrado ni límite de textura gigante)
// 2. COLOR.r: Índice de capa en el Texture2DArray (0..255)
// 3. COLOR.g: Rugosidad por instancia (e.g. 0.35 esmalte, 0.70 madera)
// 4. COLOR.b: Metálico por instancia (e.g. 0.80 aluminio, 0.02 plástico/madera)
// 5. INSTANCE_CUSTOM: Sub-región UV del atlas en formato vec4(uv_min.x, uv_min.y, uv_size.x, uv_size.y)
//    Permite que una sola textura contenga logos, pantallas, rejillas y acabados lisos
//    mapeados independientemente a cada primitiva sin romper el lote de Hardware Instancing.

uniform sampler2DArray texture_array : source_color, filter_nearest_mipmap, repeat_enable;
uniform float uv_scale : hint_range(0.1, 10.0) = 1.0;
uniform float default_roughness : hint_range(0.0, 1.0) = 0.55;
uniform float default_metallic : hint_range(0.0, 1.0) = 0.02;

varying flat int v_layer;
varying float v_roughness;
varying float v_metallic;
varying vec4 v_uv_rect; // (min_x, min_y, size_x, size_y)

void vertex() {
	v_layer = int(round(COLOR.r * 255.0));
	v_roughness = COLOR.g > 0.001 ? COLOR.g : default_roughness;
	v_metallic = COLOR.b > 0.001 ? COLOR.b : default_metallic;

	// Si INSTANCE_CUSTOM define una sub-región válida (tamaño > 0), remapeamos UV
	if (INSTANCE_CUSTOM.z > 0.0001 && INSTANCE_CUSTOM.w > 0.0001) {
		v_uv_rect = INSTANCE_CUSTOM;
	} else {
		// Mapeo completo [0, 0, 1, 1]
		v_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
	}
}

void fragment() {
	vec2 mapped_uv;

	// Si es una sub-región del atlas (INSTANCE_CUSTOM < 1.0), aplicamos clamping de medio píxel
	// para prevenir sangrado por filtrado o mipmaps en los bordes del sprite
	if (v_uv_rect.z < 0.9999 || v_uv_rect.w < 0.9999) {
		vec2 local_uv = clamp(UV, vec2(0.0), vec2(1.0));
		vec2 tex_size = vec2(textureSize(texture_array, 0).xy);
		vec2 half_texel = vec2(0.5) / max(tex_size, vec2(1.0));
		vec2 uv_min = v_uv_rect.xy + half_texel;
		vec2 uv_max = v_uv_rect.xy + v_uv_rect.zw - half_texel;
		mapped_uv = clamp(v_uv_rect.xy + local_uv * v_uv_rect.zw, uv_min, uv_max);
	} else {
		vec2 local_uv = fract(UV * uv_scale);
		mapped_uv = local_uv;
	}

	vec3 tex_col = texture(texture_array, vec3(mapped_uv, float(v_layer))).rgb;

	ALBEDO = tex_col;
	ROUGHNESS = v_roughness;
	METALLIC = v_metallic;
	SPECULAR = 0.35;
}

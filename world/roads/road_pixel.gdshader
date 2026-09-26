shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting, cull_disabled;

// Shader retro PSX para carreteras, banquetas y bordillos procedurales.
// Utiliza mapeo Triplanar en Coordenadas de Mundo (World-Space) con filtrado NEAREST.
// Garantiza que los píxeles de ruido de asfalto y banqueta sean 100% cuadrados y uniformes
// a lo largo de cualquier longitud de vía sin estiramientos.

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float texture_scale = 0.5; // 0.5 = 1 repetición cada 2 metros (~64 px/m)
uniform float roughness : hint_range(0.0, 1.0) = 0.85;

// PSX Vertex Snapping opcional
uniform int grid_precision = 0; // 0 = desactivado, >0 = wobble PSX

varying vec3 world_pos;
varying vec3 world_norm;

void vertex() {
	if (grid_precision > 0) {
		vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		float grid = float(grid_precision);
		clip_position.xyz /= clip_position.w;
		clip_position.xy = floor(clip_position.xy * grid) / grid;
		clip_position.xyz *= clip_position.w;
		POSITION = clip_position;
	}

	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 abs_n = abs(world_norm);
	vec2 uv;

	// Selección de plano de proyección ortogonal en espacio de mundo
	if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) {
		// Superficie superior (rodadura de asfalto, cara superior de banqueta o bordillo)
		uv = world_pos.xz * texture_scale;
	} else if (abs_n.x >= abs_n.z) {
		// Cara lateral perpendicular al eje X (bordes de banqueta y bordillos)
		uv = world_pos.zy * texture_scale;
	} else {
		// Cara lateral perpendicular al eje Z
		uv = world_pos.xy * texture_scale;
	}

	vec4 tex_color = texture(albedo_texture, uv);
	ALBEDO = tex_color.rgb * tint_color.rgb;
	ROUGHNESS = roughness;
}

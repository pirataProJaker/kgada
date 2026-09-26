shader_type spatial;
render_mode cull_disabled;

// Shader Triplanar Universal para Redes Viales Procedurales con GPU Instancing
// Diseñado para renderizar texturas de píxel retro auténtico PSX en MultiMeshInstance3D.
// Garantiza coordenadas de mundo continuas (sin distorsión ni costuras en intersecciones).

uniform sampler2D albedo_texture : filter_nearest, source_color;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale = 0.25; // Escala en metros
uniform float roughness : hint_range(0.0, 1.0) = 0.88;
uniform float triplanar_sharpness = 16.0;
uniform bool is_directional_along_road = false; // Si es true, orienta las juntas transversales a lo largo de la vía

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_road_right;
varying vec3 v_road_fwd;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_road_right = normalize(MODEL_MATRIX[0].xyz);
	v_road_fwd = normalize(MODEL_MATRIX[2].xyz);
}

void fragment() {
	vec3 blend = abs(v_world_normal);
	blend = pow(blend, vec3(triplanar_sharpness));
	blend /= (blend.x + blend.y + blend.z + 0.00001);

	// Proyección de UVs: direccional para banquetas o triplanar isotrópico de mundo para asfalto
	vec2 uv_top;
	if (is_directional_along_road) {
		float dist_across = dot(v_world_pos, v_road_right);
		float dist_along = dot(v_world_pos, v_road_fwd);
		uv_top = vec2(dist_across * uv_scale, dist_along * uv_scale);
	} else {
		uv_top = v_world_pos.xz * uv_scale;
	}

	vec2 uv_side_x = v_world_pos.zy * uv_scale;
	vec2 uv_side_z = v_world_pos.xy * uv_scale;

	vec4 col_top = texture(albedo_texture, uv_top);
	vec4 col_x = texture(albedo_texture, uv_side_x);
	vec4 col_z = texture(albedo_texture, uv_side_z);

	vec4 blended_col = col_top * blend.y + col_x * blend.x + col_z * blend.z;

	ALBEDO = blended_col.rgb * albedo_tint.rgb;
	ROUGHNESS = roughness;
	SPECULAR = 0.05;
}


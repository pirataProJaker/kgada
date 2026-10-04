shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D doors_atlas : source_color, filter_nearest;

varying vec3 v_normal;
varying float v_style;

void vertex() {
	v_normal = abs(NORMAL);
	v_style = COLOR.r;
}

void fragment() {
	int style = int(round(v_style));
	int col = style % 4;
	int row = style / 4;
	vec2 uv_offset = vec2(float(col) * 0.25, float(row) * 0.50);
	vec2 uv_scale = vec2(0.25, 0.50);

	vec2 atlas_uv;
	if (v_normal.z > v_normal.x && v_normal.z > v_normal.y) {
		atlas_uv = uv_offset + UV * uv_scale;
	} else {
		atlas_uv = uv_offset + vec2(0.03, 0.03);
	}
	vec4 tex = texture(doors_atlas, atlas_uv);
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.85;
}

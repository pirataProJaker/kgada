shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert;

// =========================================================================
// SHADER DE VEHÍCULOS RETRO PSX CON TINTE DINÁMICO DE CARROCERÍA
// Play Sector X - Sistema Modular
// =========================================================================

uniform sampler2D main_texture : source_color, filter_nearest;
uniform vec4 default_paint_color : source_color = vec4(0.18, 0.32, 0.62, 1.0); // Azul PSX clásico
uniform float jitter_strength : hint_range(0.0, 1.0) = 0.0; // Snapping opcional PSX

varying vec4 v_color;

void vertex() {
	v_color = COLOR;
	
	// PSX vertex snapping si está habilitado
	if (jitter_strength > 0.001) {
		vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
		if (clip_pos.w > 0.0) {
			vec2 screen_res = vec2(320.0, 240.0);
			vec2 snapped = round((clip_pos.xy / clip_pos.w) * screen_res) / screen_res;
			clip_pos.xy = mix(clip_pos.xy, snapped * clip_pos.w, jitter_strength);
			POSITION = clip_pos;
		}
	}
}

void fragment() {
	vec4 tex_color = texture(main_texture, UV);
	
	// Color base de pintura: prioridad a INSTANCE_CUSTOM o vertex_color si se define, sino default
	vec4 paint_color = default_paint_color;
	if (v_color.a > 0.05 && (v_color.r != 1.0 || v_color.g != 1.0 || v_color.b != 1.0)) {
		paint_color = v_color;
	}
	
	// Detección de chapa pintable (zonas claras/blancas del atlas):
	// Los plásticos negros, parachoques oscuros (r < 0.3), ópticas ámbar/rojas y vidrios negros NO se tiñen.
	float lum = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));
	float is_neutral_white = 1.0;
	
	// Si tiene saturación (faros ámbar o rojos), no es chapa neutra
	float max_c = max(tex_color.r, max(tex_color.g, tex_color.b));
	float min_c = min(tex_color.r, min(tex_color.g, tex_color.b));
	float sat = max_c - min_c;
	
	if (sat > 0.12 || lum < 0.45) {
		is_neutral_white = 0.0; // Faros, paragolpes negro, rejillas, ruedas, vidrios
	}
	
	// Mezcla el color de pintura preservando luces y sombras del atlas
	vec3 tinted_body = tex_color.rgb * paint_color.rgb * 1.35;
	vec3 final_color = mix(tex_color.rgb, tinted_body, is_neutral_white);
	
	ALBEDO = final_color;
	ROUGHNESS = 0.65;
	METALLIC = 0.05 * is_neutral_white;
}


shader_type canvas_item;
// Fondo synthwave/vaporwave animado (recreando fondo.png con matematica pura,
// sin depender de la imagen): piso de rejilla en perspectiva que se desliza
// hacia un lado y hacia el jugador (con fundido cerca del horizonte para que
// no se vea solido de tan apretada), horizonte con resplandor rosa/morado, y
// "reflectores" en el cielo que se mecen de un lado a otro como focos
// apuntando hacia arriba.

uniform vec3 sky_top_color : source_color = vec3(0.02, 0.01, 0.05);
uniform vec3 sky_horizon_color : source_color = vec3(0.85, 0.35, 0.55);
uniform vec3 beam_color : source_color = vec3(0.55, 0.30, 0.65);
uniform vec3 floor_color : source_color = vec3(0.08, 0.04, 0.14);
uniform vec3 grid_color : source_color = vec3(0.55, 0.30, 0.65);

uniform float horizon_y : hint_range(0.2, 0.9) = 0.58;
uniform float grid_scale : hint_range(1.0, 40.0) = 4.0;
uniform float grid_line_width : hint_range(0.005, 0.1) = 0.02;
uniform float grid_fade_distance : hint_range(0.01, 0.3) = 0.06; // cuanto de "profundidad" se tarda en desvanecer la rejilla cerca del horizonte
uniform float scroll_speed_z : hint_range(-2.0, 2.0) = 0.35; // el piso "avanza" hacia la camara
uniform float scroll_speed_x : hint_range(-2.0, 2.0) = 0.08; // se desliza hacia un lado

uniform int beam_count : hint_range(2, 10) = 6;
uniform float beam_spread : hint_range(0.1, 2.0) = 0.9; // que tan abierto es el abanico de reflectores
uniform float beam_sway_speed : hint_range(0.0, 2.0) = 0.3;
uniform float beam_sway_amount : hint_range(0.0, 1.0) = 0.3;
uniform float beam_width : hint_range(0.01, 0.5) = 0.09;
uniform float beam_intensity : hint_range(0.0, 2.0) = 0.6;


void fragment() {
	vec2 uv = UV;
	vec3 color;

	if (uv.y < horizon_y) {
		// --- CIELO: degradado + reflectores meciendose como focos ---
		float dist_to_horizon = clamp(1.0 - (horizon_y - uv.y) / horizon_y, 0.0, 1.0);
		float glow = pow(dist_to_horizon, 3.0);
		vec3 sky = mix(sky_top_color, sky_horizon_color, glow);

		vec2 center = vec2(0.5, horizon_y);
		vec2 dir = uv - center;
		float angle = atan(dir.y, dir.x);
		float dist_from_center = length(dir);

		float beams = 0.0;
		for (int i = 0; i < beam_count; i++) {
			float t = float(i) / float(max(beam_count - 1, 1)) - 0.5; // -0.5 .. 0.5
			float phase = float(i) * 1.7;
			float sway = sin(TIME * beam_sway_speed + phase) * beam_sway_amount;
			float beam_angle = -1.5708 + t * beam_spread * 2.0 + sway; // -PI/2 = derecho hacia arriba
			float diff = angle - beam_angle;
			float wrapped = atan(sin(diff), cos(diff)); // diferencia angular correcta (-PI..PI)
			beams += smoothstep(beam_width, 0.0, abs(wrapped));
		}
		float beam_falloff = clamp(1.0 - dist_from_center * 0.6, 0.0, 1.0);
		beams = clamp(beams, 0.0, 1.0) * beam_intensity * beam_falloff;
		sky += beams * beam_color;

		// resplandor suave convergiendo hacia el centro del horizonte
		float rays = sin(angle * 10.0) * 0.5 + 0.5;
		rays = pow(rays, 6.0) * glow * 0.25;
		sky += rays * sky_horizon_color;

		color = sky;
	} else {
		// --- PISO: rejilla en perspectiva, se desliza hacia un lado y hacia la camara ---
		float depth = uv.y - horizon_y;
		float perspective = 1.0 / (depth + 0.015);

		vec2 floor_uv;
		floor_uv.x = (uv.x - 0.5) * perspective + TIME * scroll_speed_x;
		floor_uv.y = perspective - TIME * scroll_speed_z;

		vec2 grid = abs(fract(floor_uv * grid_scale) - 0.5);
		vec2 line_width = fwidth(floor_uv * grid_scale) * (grid_line_width * 50.0 + 0.5);
		float line_x = smoothstep(0.0, line_width.x, grid.x);
		float line_y = smoothstep(0.0, line_width.y, grid.y);
		float on_line = 1.0 - min(line_x, line_y);

		// justo pegado al horizonte las lineas quedan tan apretadas que se ven
		// como un color solido (aliasing) - se desvanece la rejilla ahi y se
		// deja solo el resplandor, en vez de mostrar ese solido feo.
		float grid_fade = smoothstep(0.0, grid_fade_distance, depth);
		on_line *= grid_fade;

		vec3 floorc = mix(floor_color, grid_color, on_line);

		// resplandor rosa/morado cerca del horizonte, y oscurece hacia la camara
		float horizon_glow = pow(1.0 - clamp(depth / (1.0 - horizon_y), 0.0, 1.0), 5.0);
		floorc = mix(floorc, sky_horizon_color, horizon_glow * 0.5);
		floorc *= mix(1.0, 0.55, clamp(depth * 1.2, 0.0, 1.0));

		color = floorc;
	}

	COLOR = vec4(color, 1.0);
}

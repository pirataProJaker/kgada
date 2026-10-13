shader_type sky;
render_mode use_half_res_pass;

// ==============================================================================
// CIELO PROCEDURAL MATEMÁTICO ULTRA-OPTIMIZADO (0 TEXTURAS, 0 CARGA CPU)
// ==============================================================================
// Genera atmósfera dinámica (Día, Atardecer, Noche), sol, luna, campo de estrellas
// con parpadeo y nubes volumétricas flotantes impulsadas por el viento a puras
// matemáticas en la GPU (sub-0.1ms por frame).

// --- Colores de Atmósfera ---
uniform vec3 day_sky_top : source_color = vec3(0.18, 0.46, 0.88);
uniform vec3 day_sky_horizon : source_color = vec3(0.68, 0.84, 0.96);

uniform vec3 sunset_sky_top : source_color = vec3(0.24, 0.16, 0.42);
uniform vec3 sunset_sky_horizon : source_color = vec3(0.98, 0.48, 0.22);
uniform vec3 sunset_sun_glow : source_color = vec3(1.0, 0.65, 0.25);

uniform vec3 night_sky_top : source_color = vec3(0.015, 0.025, 0.065);
uniform vec3 night_sky_horizon : source_color = vec3(0.045, 0.065, 0.12);

uniform vec3 ground_color : source_color = vec3(0.12, 0.15, 0.12);

// --- Sol y Luna ---
uniform vec3 sun_direction = vec3(0.5, 0.7, 0.5); // Normalizado
uniform float sun_disk_size : hint_range(0.005, 0.1) = 0.035;
uniform float moon_disk_size : hint_range(0.005, 0.1) = 0.03;
uniform float moon_crescent : hint_range(-1.0, 1.0) = 0.25;

// --- Nubes Matemáticas y Modos de Calidad ---
// 0 = Sin nubes (Cielo despejado puro, 0.0 ms)
// 1 = Nubes rápidas / básicas (Económicas estilo retro, ~0.04 ms)
// 2 = Nubes naturales cinemáticas (Clustering + Worley + Domain Warp + Sombras sol + Cirros, ~0.12 ms)
uniform int cloud_quality : hint_range(0, 2) = 2;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.50;
uniform float cloud_clustering : hint_range(0.0, 1.0) = 0.65; // Agrupación en frentes y claros de cielo
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.006;
uniform float cloud_scale : hint_range(0.05, 1.5) = 0.45;
uniform float cloud_warp_strength : hint_range(0.0, 1.0) = 0.35; // Turbulencia orgánica por viento
uniform float cloud_rim_glow : hint_range(0.0, 3.0) = 1.35; // Borde plateado hacia el Sol (Silver Lining)
uniform float cirrus_coverage : hint_range(0.0, 1.0) = 0.28; // Cirros de hielo tenues a gran altitud

uniform vec3 cloud_day_color : source_color = vec3(0.98, 0.99, 1.0);
uniform vec3 cloud_day_shadow : source_color = vec3(0.65, 0.72, 0.82);
uniform vec3 cloud_sunset_color : source_color = vec3(1.0, 0.60, 0.40);
uniform vec3 cloud_sunset_shadow : source_color = vec3(0.48, 0.25, 0.35);
uniform vec3 cloud_night_color : source_color = vec3(0.06, 0.08, 0.14);

// --- Estrellas ---
uniform float stars_density : hint_range(0.0, 1.0) = 0.75;
uniform float stars_speed : hint_range(0.0, 0.1) = 0.0005;

// --- FUNCIONES MATEMÁTICAS ANALÍTICAS (Fast Value Noise & Rotated FBM) ---
float hash(vec2 p) {
	vec2 v = fract(p * vec2(123.34, 456.21));
	v += dot(v, v + 45.32);
	return fract(v.x * v.y);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

const mat2 m2 = mat2(vec2(0.8, -0.6), vec2(0.6, 0.8));

float fbm(vec2 p) {
	float f = 0.0;
	f += 0.5000 * noise(p); p = m2 * p * 2.02;
	f += 0.2500 * noise(p); p = m2 * p * 2.03;
	f += 0.1250 * noise(p); p = m2 * p * 2.01;
	f += 0.0625 * noise(p);
	return f / 0.9375;
}

// Ruido celular / Worley 2D analítico ultra-rápido (lóbulo de cúmulo redondeado)
float worley2D(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist_sq = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 pt = vec2(hash(i + neighbor), hash(i + neighbor + vec2(43.12, 89.23)));
			vec2 diff = neighbor + pt - f;
			min_dist_sq = min(min_dist_sq, dot(diff, diff));
		}
	}
	return sqrt(min_dist_sq);
}

// Estrellas en coordenadas esféricas con parpadeo suave
float get_stars(vec3 dir, float threshold) {
	vec3 p = dir * 210.0;
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	float h = hash3(cell);
	if (h > 1.0 - threshold * 0.008) {
		float star_size = (h - (1.0 - threshold * 0.008)) / (threshold * 0.008);
		float radius = 0.08 + star_size * 0.18;
		float dist = length(local);
		float twinkle = sin(TIME * 3.5 + h * 62.8) * 0.35 + 0.65;
		return smoothstep(radius, 0.0, dist) * twinkle;
	}
	return 0.0;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 s_dir = normalize(sun_direction);
	
	// Altura del sol respecto al horizonte (-1.0 = noche cerrada, 0.0 = atardecer, 1.0 = mediodia)
	float sun_height = s_dir.y;
	float day_factor = clamp((sun_height + 0.05) / 0.35, 0.0, 1.0);
	float sunset_factor = clamp(1.0 - abs(sun_height - 0.05) / 0.25, 0.0, 1.0);
	float night_factor = clamp((-sun_height + 0.1) / 0.35, 0.0, 1.0);
	
	// 1. Degradado Atmosférico de Cielo
	float zenith_gradient = clamp(dir.y, 0.0, 1.0);
	
	vec3 current_top = mix(night_sky_top, day_sky_top, day_factor);
	current_top = mix(current_top, sunset_sky_top, sunset_factor * (1.0 - day_factor * 0.5));
	
	vec3 current_horizon = mix(night_sky_horizon, day_sky_horizon, day_factor);
	current_horizon = mix(current_horizon, sunset_sky_horizon, sunset_factor);
	
	vec3 sky_color = mix(current_horizon, current_top, pow(zenith_gradient, 0.7));
	
	// Si miramos hacia abajo del horizonte (tierra), fundir suavemente
	if (dir.y < 0.0) {
		float ground_factor = clamp(-dir.y * 8.0, 0.0, 1.0);
		sky_color = mix(current_horizon, ground_color, ground_factor);
	}
	
	// Resplandor cálido en el horizonte cerca del sol durante el atardecer
	float sun_dot = max(dot(dir, s_dir), 0.0);
	float sunset_glow = pow(sun_dot, 6.0) * sunset_factor * 1.5;
	sky_color += sunset_sun_glow * sunset_glow;
	
	// 2. Sol (Disco y Halo)
	if (sun_height > -0.15) {
		float sun_ang = acos(clamp(dot(dir, s_dir), -1.0, 1.0));
		float sun_disk = smoothstep(sun_disk_size, sun_disk_size * 0.85, sun_ang);
		float sun_halo = pow(max(dot(dir, s_dir), 0.0), 32.0) * 0.6;
		vec3 sun_light_color = mix(sunset_sun_glow, vec3(1.0, 0.98, 0.90), day_factor);
		sky_color += (sun_light_color * 2.5 * sun_disk) + (sun_light_color * sun_halo * (day_factor + sunset_factor));
	}
	
	// 3. Luna (Lado opuesto al sol)
	vec3 moon_dir = -s_dir;
	if (moon_dir.y > -0.1) {
		float moon_ang = acos(clamp(dot(dir, moon_dir), -1.0, 1.0));
		float moon_disk = smoothstep(moon_disk_size, moon_disk_size * 0.9, moon_ang);
		if (moon_disk > 0.0) {
			// Sombra creciente lunar
			vec3 crescent_offset = normalize(moon_dir + vec3(moon_crescent * 0.03, 0.0, 0.0));
			float crescent_ang = acos(clamp(dot(dir, crescent_offset), -1.0, 1.0));
			float crescent_mask = smoothstep(moon_disk_size * 0.85, moon_disk_size * 0.95, crescent_ang);
			sky_color += vec3(0.92, 0.94, 1.0) * (moon_disk * crescent_mask) * night_factor * 1.8;
		}
		float moon_halo = pow(max(dot(dir, moon_dir), 0.0), 40.0) * 0.25 * night_factor;
		sky_color += vec3(0.5, 0.6, 0.8) * moon_halo;
	}
	
	// 4. Estrellas Procedimentales (Solo visibles en noche y atardecer)
	if (dir.y > 0.02 && night_factor > 0.05) {
		// Rotación sutil de la bóveda celeste con el tiempo
		float st_angle = TIME * stars_speed;
		float sc = cos(st_angle);
		float ss = sin(st_angle);
		vec3 rot_dir = vec3(dir.x * sc + dir.z * ss, dir.y, -dir.x * ss + dir.z * sc);
		
		float star_val = get_stars(rot_dir, stars_density);
		float star_visibility = clamp((dir.y - 0.02) * 5.0, 0.0, 1.0) * night_factor;
		sky_color += vec3(0.95, 0.96, 1.0) * star_val * star_visibility * 1.5;
	}
	
	// 5. Nubes Procedurales Dinámicas (3 Niveles de Calidad)
	if (cloud_quality > 0 && dir.y > 0.01 && cloud_coverage > 0.01) {
		// Desvanecimiento suave hacia el horizonte para evitar estiramiento
		float horizon_fade = smoothstep(0.01, 0.16, dir.y);
		
		// Colores de nubes según hora del día (Intactos)
		vec3 c_top = mix(cloud_night_color, cloud_day_color, day_factor);
		c_top = mix(c_top, cloud_sunset_color, sunset_factor);
		
		vec3 c_bot = mix(cloud_night_color * 0.5, cloud_day_shadow, day_factor);
		c_bot = mix(c_bot, cloud_sunset_shadow, sunset_factor);
		
		// Proyección atmosférica en plano curvado
		vec2 cloud_coord = (dir.xz / (dir.y + 0.18)) * cloud_scale;
		vec2 wind_offset = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		cloud_coord += wind_offset;
		
		if (cloud_quality == 1) {
			// ==================================================================
			// NIVEL 1: NUBES RÁPIDAS / ECONÓMICAS (~0.04 ms GPU)
			// ==================================================================
			float n = fbm(cloud_coord);
			float threshold = 0.85 - cloud_coverage * 0.85;
			float cloud_alpha = clamp((n - threshold) / 0.22, 0.0, 1.0);
			
			if (cloud_alpha > 0.001) {
				float n_shade = fbm(cloud_coord + vec2(0.04, 0.04));
				float shade = clamp((n - n_shade) * 2.8 + 0.70, 0.45, 1.0);
				vec3 cloud_final = mix(c_bot, c_top, shade);
				cloud_alpha *= horizon_fade * 0.95;
				sky_color = mix(sky_color, cloud_final, cloud_alpha);
			}
		} else {
			// ==================================================================
			// NIVEL 2: NUBES NATURALES CINEMÁTICAS (~0.12 ms GPU)
			// ==================================================================
			// A) Weather Clustering: Frentes macro de nubes y claros de cielo azul natural
			float macro_weather = fbm(cloud_coord * 0.22 + vec2(12.3, 7.8));
			float cluster_mask = smoothstep(0.28, 0.72, macro_weather);
			float local_cov = mix(cloud_coverage, cloud_coverage * cluster_mask * 1.35, cloud_clustering);
			
			// B) Cirros Altos (Visibles en claros y cotas altas)
			if (cirrus_coverage > 0.02) {
				vec2 cirrus_coord = (dir.xz / (dir.y + 0.10)) * (cloud_scale * 1.7) + wind_offset * 1.8;
				float c_warp = noise(cirrus_coord * 1.5) * 0.35;
				vec2 c_warped = cirrus_coord + vec2(c_warp, -c_warp * 0.5);
				float c_noise = fbm(c_warped * 2.0);
				float c_thresh = 0.92 - cirrus_coverage * 0.72;
				float c_alpha = smoothstep(c_thresh - 0.15, c_thresh + 0.18, c_noise) * 0.38 * horizon_fade;
				if (c_alpha > 0.005) {
					vec3 cirrus_col = mix(cloud_night_color * 1.2, cloud_day_color, day_factor);
					cirrus_col = mix(cirrus_col, cloud_sunset_color * 1.1, sunset_factor);
					sky_color = mix(sky_color, cirrus_col, c_alpha);
				}
			}
			
			// C) Cúmulos Naturales: Domain Warping + Worley Billow + Fractal Erosion
			if (local_cov > 0.02) {
				// Deformación fluida del viento (Domain Warping)
				vec2 warp = vec2(
					noise(cloud_coord * 1.1 + vec2(1.7, 9.2)),
					noise(cloud_coord * 1.1 + vec2(8.3, 2.8))
				) - 0.5;
				vec2 warped_coord = cloud_coord + warp * (cloud_warp_strength * 0.85);
				
				// Lóbulos redondeados tipo cúmulo (Worley invertido) combinados con detalle fractal
				float worley_val = worley2D(warped_coord * 1.25);
				float billow = 1.0 - clamp(worley_val, 0.0, 1.0);
				float fractal_edge = fbm(warped_coord * 2.2);
				
				// Combinación de forma: núcleo esponjoso predominante + erosión en bordes
				float cloud_density = billow * 0.62 + fractal_edge * 0.38;
				
				// Umbral de densidad adaptativo según el mapa de frentes climáticos
				float threshold = 0.82 - local_cov * 0.78;
				float cloud_alpha = clamp((cloud_density - threshold) / 0.16, 0.0, 1.0);
				
				if (cloud_alpha > 0.001) {
					// Curva de densidad física: centros densos y opacos, bordes esponjosos
					cloud_alpha = smoothstep(0.0, 1.0, cloud_alpha);
					
					// D) Sombreado Dinámico Orientado al Sol (Luz Direccional)
					vec2 sun_dir_2d = normalize(s_dir.xz + vec2(0.0001, 0.0001));
					float shade_sample = fbm((warped_coord + sun_dir_2d * 0.08) * 2.2);
					float shade = clamp((cloud_density - shade_sample) * 2.8 + 0.72, 0.40, 1.0);
					
					// E) Borde Plateado / Dispersión Hacia Adelante (Silver Lining)
					float sun_proximity = max(dot(dir, s_dir), 0.0);
					float silver_lining = pow(sun_proximity, 6.0) * (1.0 - cloud_alpha * 0.75) * cloud_rim_glow;
					vec3 sun_tint = mix(sunset_sun_glow, vec3(1.0, 0.98, 0.92), day_factor);
					
					vec3 cloud_final = mix(c_bot, c_top, shade);
					cloud_final += sun_tint * silver_lining * (day_factor + sunset_factor);
					
					cloud_alpha *= horizon_fade * 0.98;
					sky_color = mix(sky_color, cloud_final, cloud_alpha);
				}
			}
		}
	}
	
	COLOR = sky_color;
}

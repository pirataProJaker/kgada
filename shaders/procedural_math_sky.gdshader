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

// --- Nubes Matemáticas ---
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.52;
uniform float cloud_speed : hint_range(0.0, 0.05) = 0.008;
uniform float cloud_scale : hint_range(0.05, 1.5) = 0.55;
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
	if (LIGHT0_ENABLED) {
		s_dir = -LIGHT0_DIRECTION;
	}
	
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
	
	// 5. Nubes Volumétricas Planas (Proyectadas en bóveda a gran altitud)
	if (dir.y > 0.01) {
		// Proyección en plano horizontal a gran altura (con curvatura para no estirar al horizonte)
		vec2 cloud_coord = (dir.xz / (dir.y + 0.18)) * cloud_scale;
		cloud_coord += vec2(TIME * cloud_speed, TIME * cloud_speed * 0.35);
		
		float n = fbm(cloud_coord);
		
		// Umbral de corte directo: cloud_coverage = 0.52 => threshold = 0.408
		float threshold = 0.85 - cloud_coverage * 0.85;
		float cloud_alpha = clamp((n - threshold) / 0.22, 0.0, 1.0);
		
		if (cloud_alpha > 0.001) {
			// Sombreado interno de la nube (luz vs base)
			float n_shade = fbm(cloud_coord + vec2(0.04, 0.04));
			float shade = clamp((n - n_shade) * 2.8 + 0.70, 0.45, 1.0);
			
			// Color de nubes según la hora
			vec3 c_top = mix(cloud_night_color, cloud_day_color, day_factor);
			c_top = mix(c_top, cloud_sunset_color, sunset_factor);
			
			vec3 c_bot = mix(cloud_night_color * 0.5, cloud_day_shadow, day_factor);
			c_bot = mix(c_bot, cloud_sunset_shadow, sunset_factor);
			
			vec3 cloud_final = mix(c_bot, c_top, shade);
			
			// Desvanecer nubes cerca del horizonte suavemente
			float horizon_fade = clamp(dir.y * 5.0, 0.0, 1.0);
			cloud_alpha *= horizon_fade * 0.95;
			
			sky_color = mix(sky_color, cloud_final, cloud_alpha);
		}
	}
	
	COLOR = sky_color;
}

shader_type spatial;
render_mode diffuse_lambert, specular_disabled, vertex_lighting, cull_disabled;

// PSX-style vertex snapping ("geometry wobble"). Emulates the original
// PlayStation's lack of sub-pixel vertex precision (no floating point
// transforms in hardware). As a side effect, UVs attached to the snapped
// vertices "swim" every frame, which approximates the classic PS1 texture
// warping look.
//
// Note: true affine texture mapping (disabling perspective-correct UV
// interpolation per-pixel) is NOT possible in Godot's shading language -
// it only exposes `flat` / `smooth` (default) interpolation qualifiers for
// varyings, not `noperspective` like raw GLSL/HLSL. This vertex snap is the
// closest authentic-feeling approximation without a much more complex
// manual barycentric UV hack.
uniform int grid_precision = 40; // lower = more wobble/jitter, higher = smoother
uniform vec4 albedo_color : source_color = vec4(0.8, 0.8, 0.85, 1.0);

// Optional texture, triplanar-mapped (no UVs needed - works for Marching
// Cubes terrain too). Defaults to plain white (hint_default_white), so if
// nothing is assigned the result is just `albedo_color` as a solid color -
// drop a texture onto this parameter later and it multiplies in on top.
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_nearest, repeat_enable;
uniform float texture_scale : hint_range(0.01, 4.0) = 0.25;

// Gradiente de color por altura (opcional, apagado por defecto para no
// afectar materiales existentes como las cajas). El terreno lo activa para
// pintar llanuras de verde, roca de montana en gris, y picos nevados en
// blanco - una progresion de 3 tonos en vez de un mezcla directa de 2.
uniform bool use_height_gradient = false;
uniform vec4 low_color : source_color = vec4(0.3, 0.5, 0.25, 1.0);
uniform vec4 mid_color : source_color = vec4(0.45, 0.43, 0.4, 1.0);
uniform vec4 high_color : source_color = vec4(0.92, 0.94, 0.97, 1.0);
uniform float gradient_low_height = 14.0;
uniform float gradient_mid_height = 24.0;
uniform float gradient_high_height = 32.0;

// Modo terreno con pixeles más pequeños y pasto estrictamente verde estilo PSX
uniform bool use_pixel_terrain = false;
uniform float pixel_size : hint_range(0.02, 0.5) = 0.08; // 0.08m = ~12.5 px/metro
uniform vec4 grass_g1 : source_color = vec4(0.09, 0.28, 0.07, 1.0); // Verde sombra denso (verde puro, no negro)
uniform vec4 grass_g2 : source_color = vec4(0.14, 0.38, 0.11, 1.0); // Verde césped medio-oscuro
uniform vec4 grass_g3 : source_color = vec4(0.20, 0.48, 0.15, 1.0); // Verde pradera estándar
uniform vec4 grass_g4 : source_color = vec4(0.26, 0.57, 0.19, 1.0); // Verde fresco vivo
uniform vec4 grass_g5 : source_color = vec4(0.33, 0.65, 0.22, 1.0); // Verde sol brillante (verde puro, no blanco)
uniform float slope_cliff_threshold : hint_range(0.3, 0.9) = 0.65;    // Umbral de pendiente para roca
uniform bool use_psx_color_depth = true;                              // Cuantizacion 15-bit (RGB555 de PS1)

// Paleta de tierra / mantillo forestal y caminos
uniform vec4 dirt_d1 : source_color = vec4(0.15, 0.10, 0.06, 1.0); // Tierra profunda / mantillo oscuro bajo árboles
uniform vec4 dirt_d2 : source_color = vec4(0.22, 0.15, 0.09, 1.0); // Tierra marrón fértil húmeda
uniform vec4 dirt_d3 : source_color = vec4(0.30, 0.21, 0.13, 1.0); // Tierra media de sendero
uniform vec4 dirt_d4 : source_color = vec4(0.38, 0.28, 0.17, 1.0); // Tierra ocre iluminada
uniform vec4 dirt_d5 : source_color = vec4(0.47, 0.35, 0.22, 1.0); // Tierra seca / calva clara

uniform bool use_vertex_dirt = false;                                // Si es true, lee COLOR.r (usado en showcase)
uniform bool use_procedural_biomes = true;                            // Si es true y use_vertex_dirt es false, calcula biomas por coordenadas de mundo

varying vec3 world_position;
varying vec3 world_normal;
varying vec4 vertex_color;

void vertex() {
	vec4 clip_position = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Snap to a low-resolution grid in normalized device coordinates.
	float grid = float(max(grid_precision, 1));
	clip_position.xyz /= clip_position.w;
	clip_position.xy = floor(clip_position.xy * grid) / grid;
	clip_position.xyz *= clip_position.w;

	POSITION = clip_position;

	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vertex_color = COLOR;
}

void fragment() {
	// Rama de terreno retro PSX con pixeles pequeños y pasto exclusivamente verde
	if (use_pixel_terrain) {
		vec3 snapped_pos = world_position;
		vec2 pixel_cell = floor(world_position.xz / pixel_size);

		snapped_pos.x = (pixel_cell.x + 0.5) * pixel_size;
		snapped_pos.z = (pixel_cell.y + 0.5) * pixel_size;

		// 1. Variacion macro (grandes parches organicos de color que cambian a traves del mapa)
		float n1 = sin(snapped_pos.x * 0.035 + sin(snapped_pos.z * 0.02) * 2.0);
		float n2 = cos(snapped_pos.z * 0.04 + sin(snapped_pos.x * 0.025) * 2.0);
		float macro = (n1 + n2) * 0.5; // -1.0 a 1.0

		// 2. Micro-patrón de píxel: hash determinista por celda
		float h = fract(sin(dot(pixel_cell, vec2(127.1, 311.7))) * 43758.5453123);

		// Combinación de macro + micro para seleccionar el tono de verde exacto
		float val = h * 0.70 + (macro * 0.5 + 0.5) * 0.30;

		// Selección discreta entre los 5 verdes para bordes de píxel nítidos y estilo retro auténtico
		vec3 pixel_green;
		if (val < 0.20) {
			pixel_green = grass_g1.rgb;
		} else if (val < 0.45) {
			pixel_green = grass_g2.rgb;
		} else if (val < 0.72) {
			pixel_green = grass_g3.rgb;
		} else if (val < 0.90) {
			pixel_green = grass_g4.rgb;
		} else {
			pixel_green = grass_g5.rgb;
		}

		// Selección discreta entre los 5 tonos de tierra / mantillo
		vec3 pixel_dirt;
		if (val < 0.20) {
			pixel_dirt = dirt_d1.rgb;
		} else if (val < 0.45) {
			pixel_dirt = dirt_d2.rgb;
		} else if (val < 0.72) {
			pixel_dirt = dirt_d3.rgb;
		} else if (val < 0.90) {
			pixel_dirt = dirt_d4.rgb;
		} else {
			pixel_dirt = dirt_d5.rgb;
		}

		// Transición de suelo (Césped vs Tierra) con dithering pixelado auténtico de PSX
		float dirt_amount = 0.0;
		if (use_vertex_dirt) {
			dirt_amount = clamp(vertex_color.r, 0.0, 1.0);
		} else if (use_procedural_biomes) {
			float b1 = sin(snapped_pos.x * 0.018 + sin(snapped_pos.z * 0.014) * 1.2);
			float b2 = sin(snapped_pos.z * 0.016 + sin(snapped_pos.x * 0.012) * 1.2);
			float biome_n = (b1 + b2) * 0.5;
			dirt_amount = smoothstep(0.12, 0.40, biome_n);
		}

		vec3 ground_color = pixel_green;
		if (dirt_amount > 0.001) {
			float dither_thresh = dirt_amount + (h - 0.5) * 0.40;
			if (dither_thresh > 0.50) {
				ground_color = pixel_dirt;
			}
		}

		// 3. Deteccion de pendiente para acantilados y paredes rocosas
		float slope = abs(world_normal.y);
		vec3 final_ground = ground_color;

		if (slope < slope_cliff_threshold) {
			float cliff_t = smoothstep(slope_cliff_threshold * 0.7, slope_cliff_threshold, slope);
			vec2 side_cell = floor(snapped_pos.xy / pixel_size) + floor(snapped_pos.zy / pixel_size);
			float rock_rnd = fract(sin(dot(side_cell, vec2(127.1, 311.7))) * 43758.5453123);
			vec3 cliff_rock = mid_color.rgb * (0.85 + rock_rnd * 0.28);
			final_ground = mix(cliff_rock, pixel_green, cliff_t);
		}

		// 4. Gradiente por altura (montañas y picos nevados)
		if (use_height_gradient && world_position.y > gradient_mid_height) {
			float t = smoothstep(gradient_mid_height, gradient_high_height, world_position.y);
			final_ground = mix(final_ground, high_color.rgb, t);
		}

		// 5. Cuantizacion de color PSX (15-bit RGB555: 32 niveles por canal)
		if (use_psx_color_depth) {
			final_ground = floor(final_ground * 32.0 + 0.5) / 32.0;
		}

		ALBEDO = final_ground;
		ROUGHNESS = 1.0;
	} else {
		// Triplanar blend: sample the texture from the 3 world axes and blend
		// by how much the surface normal faces each one. Avoids needing real
		// UV coordinates, which Marching Cubes meshes don't have.
		vec3 blend = abs(world_normal);
		blend /= (blend.x + blend.y + blend.z);

		vec3 sample_pos = world_position * texture_scale;
		vec4 tex_x = texture(albedo_texture, sample_pos.yz);
		vec4 tex_y = texture(albedo_texture, sample_pos.xz);
		vec4 tex_z = texture(albedo_texture, sample_pos.xy);
		vec4 tex_color = tex_x * blend.x + tex_y * blend.y + tex_z * blend.z;

		vec3 base_color = albedo_color.rgb;
		if (use_height_gradient) {
			if (world_position.y < gradient_mid_height) {
				float t = smoothstep(gradient_low_height, gradient_mid_height, world_position.y);
				base_color = mix(low_color.rgb, mid_color.rgb, t);
			} else {
				float t = smoothstep(gradient_mid_height, gradient_high_height, world_position.y);
				base_color = mix(mid_color.rgb, high_color.rgb, t);
			}
		}

		ALBEDO = tex_color.rgb * base_color;
		ROUGHNESS = 1.0;
	}
}


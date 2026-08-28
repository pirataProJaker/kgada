shader_type sky;

// Cielo panoramico que ROTA EN YAW (izquierda-derecha, como la rotacion real
// de un cielo estrellado visto desde la Tierra) y mezcla suavemente entre el
// panorama de dia y el de noche segun un factor de dia/noche. Godot 4.7 no
// expone una propiedad `rotation` en Sky/PanoramaSkyMaterial, asi que la
// rotacion se hace en el shader rotando la direccion de vista alrededor del
// eje Y segun el tiempo. Se usa como sky_material del Sky del WorldEnvironment.
//
// IMPORTANTE: antes rotaba en PITCH (eje X, de arriba a abajo). Eso hacia
// que la franja del horizonte (donde esta todo el detalle: montanas,
// estrellas bajas, etc.) pasara periodicamente por el cenit/nadir, que es
// justo donde el mapeo equirectangular (atan/acos) tiene su distorsion mas
// fuerte (los polos de la textura se comprimen a un solo punto) - se veia
// "esferico"/deforme porque literalmente estabas viendo la costura/pellizco
// de los polos de la textura barrer la pantalla. Rotar en YAW mantiene los
// polos fijos arriba/abajo (donde suelen ser lisos u oscuros en un HDRI de
// cielo) y solo gira el horizonte lateralmente, como el giro real de la
// boveda celeste - mucho mas natural y sin exponer la distorsion polar.

// Panorama de dia (HDR). filter_linear_mipmap_anisotropic (+ mipmaps
// generados en el .import, ver PSX_Daysky_HDRI/PSX_Nightsky_HDRI) es
// necesario aqui: el mapeo equirectangular manual de abajo (atan/acos) tiene
// una derivada de UV que varia muchisimo segun la direccion de vista (casi
// nula cerca del horizonte, enorme cerca de los polos/cenit), y sin mipmaps
// el GPU siempre usa el nivel base -> resultado: zonas donde el texel cae
// justo en un pixel se ven "de aguja" muy nitidas y zonas vecinas con alta
// frecuencia (estrellas) se ven como manchas grandes borrosas (aliasing
// clasico de minificacion, no un problema de la textura en si). Anisotropic
// ademas compensa el estiramiento direccional que ocurre cerca de los polos.
uniform sampler2D panorama_day : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Panorama de noche (HDR). Mismo motivo que panorama_day - aqui es aun mas
// notorio porque el campo de estrellas es puro detalle de alta frecuencia
// (puntos brillantes sobre fondo oscuro), el caso peor para aliasing sin
// mipmaps.
uniform sampler2D panorama_night : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// Factor de dia/noche: 0 = noche pura, 1 = dia puro. Se interpola suavemente
// para que la transicion entre dia y noche sea natural (no un corte brusco).
uniform float day_night_factor : hint_range(0.0, 1.0) = 1.0;
// Velocidad de rotacion horizontal (yaw) en radianes por segundo (positivo =
// el cielo gira hacia un lado, negativo = hacia el otro).
uniform float rotation_speed : hint_range(-1.0, 1.0) = 0.02;
// Brillo del cielo (multiplica el color final).
uniform float energy : hint_range(0.0, 4.0) = 1.0;

void sky() {
	// EYEDIR es la direccion de vista (vector unitario 3D).
	vec3 dir = EYEDIR;

	// Rotar la direccion alrededor del eje Y (giro horizontal, yaw).
	float angle = TIME * rotation_speed;
	float c = cos(angle);
	float s = sin(angle);
	vec3 rotated = vec3(
		dir.x * c + dir.z * s,
		dir.y,
		-dir.x * s + dir.z * c
	);

	// Convertir la direccion rotada a coordenadas UV equirectangulares.
	vec2 uv = vec2(
		atan(rotated.z, rotated.x) / (2.0 * PI) + 0.5,
		acos(clamp(rotated.y, -1.0, 1.0)) / PI
	);

	// Muestrear ambos panoramas y mezclarlos suavemente segun el factor de
	// dia/noche. Esto da una transicion natural (el cielo se oscurece y las
	// estrellas aparecen gradualmente) en vez de un corte brusco.
	vec3 day_color = texture(panorama_day, uv).rgb;
	vec3 night_color = texture(panorama_night, uv).rgb;
	vec3 color = mix(night_color, day_color, day_night_factor) * energy;
	COLOR = color;
}

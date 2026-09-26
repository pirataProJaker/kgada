class_name AlnusRadialCrownBaker
extends RefCounted

## Generador y Proyector Dinámico de Follaje para el Modo Radial Star (20 Triángulos).
##
## Proyecta los racimos botánicos recortados por el usuario sobre los 10 planos radiales
## en las posiciones exactas (r, y) donde se detecta madera de las ramas.
## El resto del plano permanece con transparencia alfa absoluta (alpha = 0).

const NUM_PLANES := 10
const ATLAS_COLS := 5
const ATLAS_ROWS := 2
const SLOT_SIZE := 512 # 512x512 por slot -> Atlas total: 2560 x 1024

# Caché estática de imágenes base de hojas provistas por el usuario
static var _raw_leaf_images: Array[Image] = []
static var _raw_anchors: Array[Vector2] = []
static var _leaf_variants_ready := false

static func _init_leaf_variants() -> void:
	if _leaf_variants_ready:
		return
	
	var files := [
		"res://assets/vegetation/alnus/hoja_alnus_1.png",
		"res://assets/vegetation/alnus/hoja_alnus_2.png",
		"res://assets/vegetation/alnus/hoja_alnus_3.png",
		"res://assets/vegetation/alnus/hoja_alnus_4.png"
	]
	
	# Coordenadas exactas en píxeles provistas por el usuario en 1024x1024
	var raw_anchors := [
		Vector2(610.0 / 1024.0, 1023.0 / 1024.0),
		Vector2(511.0 / 1024.0, 755.0 / 1024.0),
		Vector2(544.0 / 1024.0, 730.0 / 1024.0),
		Vector2(498.0 / 1024.0, 509.0 / 1024.0)
	]
	
	_raw_leaf_images.clear()
	_raw_anchors.clear()
	
	for i in range(4):
		var img: Image = null
		if ResourceLoader.exists(files[i]):
			var tex: Texture2D = load(files[i])
			if tex:
				img = tex.get_image()
		if not img:
			var global_path := ProjectSettings.globalize_path(files[i])
			if FileAccess.file_exists(global_path):
				img = Image.load_from_file(global_path)
		
		if img:
			_raw_leaf_images.append(img)
			_raw_anchors.append(raw_anchors[i])
		else:
			push_warning("No se pudo cargar textura de hoja: " + files[i])
	
	_leaf_variants_ready = _raw_leaf_images.size() == 4

## Hornea el atlas de 10 ranuras (2560x1024) estampando hojas únicamente donde pasan las ramas.
static func bake_atlas(canopy_bounds: Vector3, branch_segments: Array, tree_seed: int = 12345) -> ImageTexture:
	_init_leaf_variants()
	if not _leaf_variants_ready or _raw_leaf_images.size() < 4:
		push_error("AlnusRadialCrownBaker: No hay texturas de hojas disponibles.")
		return null
	
	var y_base: float = canopy_bounds.x
	var y_top: float = canopy_bounds.y
	var r_max: float = canopy_bounds.z
	var delta_y: float = maxf(y_top - y_base, 1.0)
	var r_extent: float = maxf(r_max, 0.5)
	
	var atlas_w: int = ATLAS_COLS * SLOT_SIZE
	var atlas_h: int = ATLAS_ROWS * SLOT_SIZE
	var atlas_img := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas_img.fill(Color(0, 0, 0, 0)) # Fondo 100% transparente
	
	# Pre-escalar los 4 tipos de hojas a 3 escalas botánicas (grande, mediana, densa)
	# Las dimensiones en píxeles del slot corrigen la relación de aspecto del quad 3D:
	# En 3D el quad mide r_extent de ancho y delta_y de alto.
	# Para que la hoja en 3D sea un círculo o racimo proporcionado de W metros:
	var scales := [1.45, 1.15, 0.90] # Tamaños en metros en el mundo 3D
	var scaled_variants: Array[Array] = [] # [scale_idx][variant_idx] = {"img": Image, "anchor": Vector2i}
	
	for s_val in scales:
		var scale_group: Array = []
		var sw: int = maxi(16, int(round(s_val * (float(SLOT_SIZE) / r_extent))))
		var sh: int = maxi(16, int(round(s_val * (float(SLOT_SIZE) / delta_y))))
		
		for v in range(4):
			var src_img := _raw_leaf_images[v]
			var resized := Image.new()
			resized.copy_from(src_img)
			resized.resize(sw, sh, Image.INTERPOLATE_LANCZOS)
			var anc := _raw_anchors[v]
			var anc_px := Vector2i(int(round(anc.x * sw)), int(round(anc.y * sh)))
			scale_group.append({"img": resized, "anchor": anc_px})
		scaled_variants.append(scale_group)
	
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed
	
	# Angular threshold: ramas dentro de +-25 grados son proyectadas sobre el plano
	var angle_threshold: float = deg_to_rad(25.5)
	
	# Margen de seguridad estricto (en píxeles) para evitar sangrado entre slots o hacia el cielo
	var PAD := 6
	
	# Iterar por cada uno de los 10 planos radiales (k = 0..9)
	for k in range(NUM_PLANES):
		var plane_angle: float = float(k) * (TAU / float(NUM_PLANES))
		var col: int = k % ATLAS_COLS
		var row: int = k / ATLAS_COLS
		var slot_x: int = col * SLOT_SIZE
		var slot_y: int = row * SLOT_SIZE
		var min_x: int = slot_x + PAD
		var max_x: int = slot_x + SLOT_SIZE - PAD
		var min_y: int = slot_y + PAD
		var max_y: int = slot_y + SLOT_SIZE - PAD
		
		for seg_idx in range(branch_segments.size()):
			var seg = branch_segments[seg_idx]
			var p0: Vector3 = seg["start"]
			var p1: Vector3 = seg["end"]
			var depth: int = int(seg.get("depth", 1))
			
			var seg_len := p0.distance_to(p1)
			var num_samples: int = maxi(2, int(ceil(seg_len / 0.28)))
			
			for s in range(num_samples + 1):
				var t: float = float(s) / float(num_samples)
				var pos := p0.lerp(p1, t)
				var r := Vector2(pos.x, pos.z).length()
				
				# Regla botánica: El tronco central y la base de las ramas principales son madera limpia
				# Las hojas brotan en las ramas medias y exteriores (r >= 0.75m)
				if r < 0.75:
					continue
				
				var phi := atan2(pos.z, pos.x)
				var angle_diff := absf(wrapf(phi - plane_angle, -PI, PI))
				
				if angle_diff <= angle_threshold:
					# Generar racimo central y ramillas secundarias
					var offsets := [
						Vector2(0.0, 0.0), # Central sobre la rama
						Vector2(0.20, 0.14), # Brote hacia el sol
					]
					if t > 0.45 or depth > 1:
						offsets.append(Vector2(-0.12, -0.08)) # Follaje lateral
					
					for off_idx in range(offsets.size()):
						var off: Vector2 = offsets[off_idx]
						var sample_r := clampf(r + off.x, 0.75, r_extent * 0.97)
						var sample_y := clampf(pos.y + off.y, y_base + 0.1, y_top - 0.1)
						
						var u_norm := clampf(sample_r / r_extent, 0.0, 0.99)
						var v_norm := clampf(1.0 - (sample_y - y_base) / delta_y, 0.0, 0.99)
						
						var branch_px: int = slot_x + int(round(u_norm * float(SLOT_SIZE - 1)))
						var branch_py: int = slot_y + int(round(v_norm * float(SLOT_SIZE - 1)))
						
						var var_idx: int = (k * 7 + seg_idx * 5 + s * 13 + off_idx * 3) % 4
						var scale_tier: int = 1 # Mediana por defecto
						if (t > 0.65 or depth > 1) and off_idx == 0:
							scale_tier = 0 # Grande en las puntas exteriores
						elif off_idx > 0 or (t < 0.35 and depth == 1):
							scale_tier = 2 # Escala menor en ramillas
						
						var leaf_data = scaled_variants[scale_tier][var_idx]
						var leaf_img: Image = leaf_data["img"]
						var leaf_anchor: Vector2i = leaf_data["anchor"]
						
						var dst_x: int = branch_px - leaf_anchor.x
						var dst_y: int = branch_py - leaf_anchor.y
						
						var src_rect := Rect2i(0, 0, leaf_img.get_width(), leaf_img.get_height())
						var blit_pos := Vector2i(dst_x, dst_y)
						
						# Despeje estricto del tronco: ninguna hoja puede acercarse a menos de 0.55m del eje central
						var trunk_clearance_px: int = slot_x + int(round((0.55 / r_extent) * float(SLOT_SIZE)))
						var safe_min_x: int = maxi(min_x, trunk_clearance_px)
						
						# Recorte estricto dentro de [safe_min_x..max_x, min_y..max_y]
						if blit_pos.x < safe_min_x:
							var diff: int = safe_min_x - blit_pos.x
							src_rect.position.x += diff
							src_rect.size.x -= diff
							blit_pos.x = safe_min_x
						if blit_pos.y < min_y:
							var diff: int = min_y - blit_pos.y
							src_rect.position.y += diff
							src_rect.size.y -= diff
							blit_pos.y = min_y
						if blit_pos.x + src_rect.size.x > max_x:
							src_rect.size.x = max_x - blit_pos.x
						if blit_pos.y + src_rect.size.y > max_y:
							src_rect.size.y = max_y - blit_pos.y
						
						if src_rect.size.x > 0 and src_rect.size.y > 0:
							atlas_img.blend_rect(leaf_img, src_rect, blit_pos)
	
	# Guardar copia para inspección de depuración
	atlas_img.save_png("res://assets/vegetation/alnus/alnus_radial_atlas.png")
	
	return ImageTexture.create_from_image(atlas_img)

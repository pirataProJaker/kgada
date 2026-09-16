extends RefCounted
class_name ProceduralTreeTextures
## Generador y cache de texturas procedurales para follaje (ramilletes de hojas con canal alfa).
## Permite que un solo triangulo represente una fronda/ramillete con 8 a 12 hojas reales,
## eliminando el efecto de "hoja gigante" y logrando una silueta organica con Alpha Scissor.

static var _cached_textures: Dictionary = {}


## Retorna la textura de ramillete de follaje adecuada para la especie.
## Si existe un archivo PNG en res://assets/textures/foliage/, lo carga directamente;
## de lo contrario, genera una textura procedural en memoria.
static func get_foliage_texture(profile_id: String) -> Texture2D:
	if _cached_textures.has(profile_id):
		return _cached_textures[profile_id]
	
	# Rutas de archivos en disco (el usuario puede editarlos o reemplazarlos)
	var file_path := "res://assets/textures/foliage/leaf_broadleaf_cluster.png"
	match profile_id.to_lower():
		"pine_boreal", "pine", "canada":
			file_path = "res://assets/textures/foliage/leaf_pine_cluster.png"
		"weeping_willow", "willow":
			file_path = "res://assets/textures/foliage/leaf_willow_cluster.png"
		_:
			file_path = "res://assets/textures/foliage/leaf_broadleaf_cluster.png"
	
	var global_path := ProjectSettings.globalize_path(file_path)
	var img_disk: Image = null
	if FileAccess.file_exists(global_path):
		img_disk = Image.load_from_file(global_path)
	elif FileAccess.file_exists(file_path):
		img_disk = Image.load_from_file(file_path)
	
	if img_disk != null:
		img_disk.generate_mipmaps()
		var tex := ImageTexture.create_from_image(img_disk)
		_cached_textures[profile_id] = tex
		return tex
	
	if ResourceLoader.exists(file_path):
		var disk_tex := load(file_path) as Texture2D
		if disk_tex != null:
			_cached_textures[profile_id] = disk_tex
			return disk_tex
	
	# Generacion procedural de respaldo si el archivo no existe
	var img: Image
	match profile_id.to_lower():
		"pine_boreal", "pine", "canada":
			img = _generate_pine_needles_image(128, 128)
		"weeping_willow", "willow":
			img = _generate_willow_frond_image(128, 128)
		_:
			img = _generate_broadleaf_branch_image(128, 128)
	
	var tex := ImageTexture.create_from_image(img)
	_cached_textures[profile_id] = tex
	return tex


## Retorna la textura de corteza adecuada para la especie.
static func get_bark_texture(profile_id: String) -> Texture2D:
	var cache_key := "bark_" + profile_id
	if _cached_textures.has(cache_key):
		return _cached_textures[cache_key]
	
	var file_path := "res://assets/textures/foliage/bark_oak.png"
	match profile_id.to_lower():
		"pine_boreal", "pine", "canada":
			file_path = "res://assets/textures/foliage/bark_pine.png"
		"autumn_birch", "birch":
			file_path = "res://assets/textures/foliage/bark_birch.png"
		_:
			file_path = "res://assets/textures/foliage/bark_oak.png"
	
	var global_path := ProjectSettings.globalize_path(file_path)
	var img_disk: Image = null
	if FileAccess.file_exists(global_path):
		img_disk = Image.load_from_file(global_path)
	elif FileAccess.file_exists(file_path):
		img_disk = Image.load_from_file(file_path)
	
	if img_disk != null:
		img_disk.generate_mipmaps()
		var tex := ImageTexture.create_from_image(img_disk)
		_cached_textures[cache_key] = tex
		return tex
	
	if ResourceLoader.exists(file_path):
		var disk_tex := load(file_path) as Texture2D
		if disk_tex != null:
			_cached_textures[cache_key] = disk_tex
			return disk_tex
	
	return null


## Genera una textura de ramillete caducifolio (tallo central con 8-10 hojitas a los lados).
## Dibujada en tonos blancos/grises para que el Vertex Color del MultiMesh la tinte naturalmente.
static func _generate_broadleaf_branch_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0)) # Fondo transparente
	
	var center_x := float(w) * 0.5
	
	# 1. Tallo central desde la base inferior hacia la punta superior
	for y in range(int(h * 0.15), int(h * 0.95)):
		var t := float(y - int(h * 0.15)) / float(h * 0.80)
		var stem_y := h - y
		var stem_w := 2 if t < 0.4 else 1
		for dx in range(-stem_w, stem_w + 1):
			var px := int(center_x + dx)
			if px >= 0 and px < w and stem_y >= 0 and stem_y < h:
				img.set_pixel(px, stem_y, Color(0.85, 0.85, 0.80, 1.0))
	
	# 2. Hojitas alternas a izquierda y derecha a lo largo del tallo
	var leaf_nodes := 5 # Pares de hojas
	for i in range(leaf_nodes):
		var t := float(i + 1) / float(leaf_nodes + 1)
		var cy := int(lerpf(float(h) * 0.80, float(h) * 0.20, t))
		
		# Hoja izquierda
		_draw_leaf_ellipse(img, center_x - 4, cy, -22.0, -10.0, 14.0, 7.0, -0.45)
		# Hoja derecha
		_draw_leaf_ellipse(img, center_x + 4, cy - 4, 22.0, -10.0, 14.0, 7.0, 0.45)
	
	# Hoja apical en la punta
	_draw_leaf_ellipse(img, center_x, int(h * 0.12), 0.0, -14.0, 7.0, 16.0, 0.0)
	
	return img


## Genera una textura de penacho de agujas de conifera (pino).
static func _generate_pine_needles_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center_x := float(w) * 0.5
	
	# Agujas que se abren hacia afuera en abanico denso
	var needle_count := 38
	for i in range(needle_count):
		var t := float(i) / float(needle_count)
		var angle := lerpf(-PI * 0.42, PI * 0.42, t)
		var base_y := float(h) * lerpf(0.90, 0.35, absf(sin(angle * 0.8)))
		var length := float(h) * randf_range(0.40, 0.55)
		
		var end_x := center_x + sin(angle) * length
		var end_y := base_y - cos(angle) * length
		
		_draw_line(img, center_x, base_y, end_x, end_y, Color(0.90, 0.95, 0.88, 1.0))
	
	# Tallo central fino
	for y in range(int(h * 0.25), int(h * 0.95)):
		var py := h - y
		img.set_pixel(int(center_x), py, Color(0.70, 0.70, 0.65, 1.0))
	
	return img


## Genera una fronda alargada tipo sauce lloron.
static func _generate_willow_frond_image(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	var center_x := float(w) * 0.5
	
	# Tallo flexible
	for y in range(int(h * 0.10), int(h * 0.95)):
		var t := float(y) / float(h)
		var curve := sin(t * PI) * 6.0
		var py := h - y
		var px := int(center_x + curve)
		if px >= 0 and px < w and py >= 0 and py < h:
			img.set_pixel(px, py, Color(0.85, 0.85, 0.80, 1.0))
	
	# Hojas lanceoladas estrechas y largas
	for i in range(7):
		var t := float(i + 1) / 9.0
		var cy := int(lerpf(float(h) * 0.85, float(h) * 0.18, t))
		var cx := center_x + sin(t * PI) * 6.0
		_draw_leaf_ellipse(img, cx - 2, cy, -18.0, 12.0, 6.0, 18.0, -0.6)
		_draw_leaf_ellipse(img, cx + 2, cy - 6, 18.0, 12.0, 6.0, 18.0, 0.6)
	
	return img


## Dibuja una hoja eliptica rotada en la imagen.
static func _draw_leaf_ellipse(img: Image, ox: float, oy: float, dx: float, dy: float, rx: float, ry: float, rot: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := ox + dx
	var cy := oy + dy
	
	var cos_r := cos(-rot)
	var sin_r := sin(-rot)
	
	var margin := int(maxf(rx, ry) * 1.5)
	var min_x := clampi(int(cx - margin), 0, w - 1)
	var max_x := clampi(int(cx + margin), 0, w - 1)
	var min_y := clampi(int(cy - margin), 0, h - 1)
	var max_y := clampi(int(cy + margin), 0, h - 1)
	
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var lx := float(x) - cx
			var ly := float(y) - cy
			
			# Rotar al espacio local de la elipse
			var local_x := lx * cos_r - ly * sin_r
			var local_y := lx * sin_r + ly * cos_r
			
			var dist_sq := (local_x * local_x) / (rx * rx) + (local_y * local_y) / (ry * ry)
			if dist_sq <= 1.0:
				# Tono suave con nervadura central
				var vein := 1.0 - clampf(absf(local_x) / 1.5, 0.0, 0.3)
				var c := Color(0.92 * vein, 0.95 * vein, 0.90 * vein, 1.0)
				img.set_pixel(x, y, c)


## Dibuja una linea simple estilo Bresenham en la imagen.
static func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	
	var dx := absf(x1 - x0)
	var dy := absf(y1 - y0)
	var sx := 1.0 if x0 < x1 else -1.0
	var sy := 1.0 if y0 < y1 else -1.0
	var err := dx - dy
	
	var cur_x := x0
	var cur_y := y0
	
	for _step in range(int(maxf(dx, dy) * 1.5)):
		var ix := int(cur_x)
		var iy := int(cur_y)
		if ix >= 0 and ix < w and iy >= 0 and iy < h:
			img.set_pixel(ix, iy, color)
		if absf(cur_x - x1) < 1.0 and absf(cur_y - y1) < 1.0:
			break
		var e2 := 2.0 * err
		if e2 > -dy:
			err -= dy
			cur_x += sx
		if e2 < dx:
			err += dx
			cur_y += sy

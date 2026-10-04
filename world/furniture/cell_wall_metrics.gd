class_name CellWallMetrics
extends RefCounted

## Medición y Diagnóstico de Ocupación de Muros por Cuadro (1m x 1m Grid)
## Permite que cualquier celda/cuadro sepa exactamente qué porción de sus 4 bordes
## está ocupada por muros exteriores (20cm) o interiores (12cm), garantizando
## que el mobiliario NUNCA penetre ni roce ningún muro.

const EXT_WALL_THICKNESS := 0.20 # 20cm muro exterior
const INT_WALL_THICKNESS := 0.12 # 12cm muro interior
const WALL_AIR_GAP := 0.04       # 4cm holgura de aire para que cornisas y molduras no toquen el muro

var gx: int = 0
var gz: int = 0
var room_id: int = 0
var map: PackedByteArray
var map_w: int = 0
var map_d: int = 0

# Espesor de muro que penetra hacia el interior del cuadro desde cada borde (en metros):
var wall_west: float = 0.0   # 0.20 (ext), 0.06 (int), 0.0 (abierto/mismo cuarto)
var wall_east: float = 0.0
var wall_north: float = 0.0
var wall_south: float = 0.0

# Coordenadas locales exactas de los límites físicos interiores libres (con holgura de aire):
var inner_min_x: float = 0.0
var inner_max_x: float = 0.0
var inner_min_z: float = 0.0
var inner_max_z: float = 0.0

# Límites brutos del cuadro sin muros:
var cell_min_x: float = 0.0
var cell_max_x: float = 0.0
var cell_min_z: float = 0.0
var cell_max_z: float = 0.0
var center_x: float = 0.0
var center_z: float = 0.0


## Mide de manera ultra-optimizada O(1) la ocupación de muros de una celda específica
static func measure_cell(p_map: PackedByteArray, w: int, d: int, cell_gx: int, cell_gz: int, r_id: int) -> CellWallMetrics:
	var m = (load("res://world/furniture/cell_wall_metrics.gd") as GDScript).new()
	m.gx = cell_gx
	m.gz = cell_gz
	m.room_id = r_id
	m.map = p_map
	m.map_w = w
	m.map_d = d

	var half_w := float(w) * 0.5
	var half_d := float(d) * 0.5

	m.cell_min_x = float(cell_gx) - half_w
	m.cell_max_x = float(cell_gx + 1) - half_w
	m.cell_min_z = float(cell_gz) - half_d
	m.cell_max_z = float(cell_gz + 1) - half_d

	m.center_x = (m.cell_min_x + m.cell_max_x) * 0.5
	m.center_z = (m.cell_min_z + m.cell_max_z) * 0.5

	# 1. Borde Oeste (gx - 1)
	m.wall_west = _get_wall_intrusion(p_map, w, d, cell_gx - 1, cell_gz, r_id)

	# 2. Borde Este (gx + 1)
	m.wall_east = _get_wall_intrusion(p_map, w, d, cell_gx + 1, cell_gz, r_id)

	# 3. Borde Norte (gz - 1)
	m.wall_north = _get_wall_intrusion(p_map, w, d, cell_gx, cell_gz - 1, r_id)

	# 4. Borde Sur (gz + 1)
	m.wall_south = _get_wall_intrusion(p_map, w, d, cell_gx, cell_gz + 1, r_id)

	# Paramentos interiores libres reales
	m.inner_min_x = m.cell_min_x + m.wall_west + (WALL_AIR_GAP if m.wall_west > 0.0 else 0.0)
	m.inner_max_x = m.cell_max_x - m.wall_east - (WALL_AIR_GAP if m.wall_east > 0.0 else 0.0)
	m.inner_min_z = m.cell_min_z + m.wall_north + (WALL_AIR_GAP if m.wall_north > 0.0 else 0.0)
	m.inner_max_z = m.cell_max_z - m.wall_south - (WALL_AIR_GAP if m.wall_south > 0.0 else 0.0)

	return m


static func _get_wall_intrusion(map_bytes: PackedByteArray, w: int, d: int, nx: int, nz: int, r_id: int) -> float:
	if nx < 0 or nx >= w or nz < 0 or nz >= d or map_bytes[nz * w + nx] == 0:
		return EXT_WALL_THICKNESS # Muro exterior: ocupa los 20cm completos hacia adentro de la celda perimetral
	elif map_bytes[nz * w + nx] != r_id:
		return INT_WALL_THICKNESS * 0.5 # Muro divisorio interior: 6cm hacia adentro (centrado en el límite)
	return 0.0 # Espacio abierto dentro del mismo cuarto


## Calcula la posición 3D exacta para un mueble adosado a muro garantizando
## que NUNCA penetre ni el muro posterior ni los muros laterales perpendiculares.
func calculate_safe_placement(dir: Vector2i, depth: float, width: float, y_val: float) -> Dictionary:
	var pos_x := center_x
	var pos_z := center_z
	var fits := true

	var half_w := width * 0.5
	var half_d := depth * 0.5

	if dir.y == 1:
		# Mira hacia +Z (adosado a muro Norte en -Z)
		pos_z = inner_min_z + half_d
		if wall_west > 0.0:
			pos_x = maxf(pos_x, inner_min_x + half_w)
		if wall_east > 0.0:
			pos_x = minf(pos_x, inner_max_x - half_w)
		if wall_west > 0.0 and wall_east > 0.0:
			fits = (inner_max_x - inner_min_x) >= width

	elif dir.y == -1:
		# Mira hacia -Z (adosado a muro Sur en +Z)
		pos_z = inner_max_z - half_d
		if wall_west > 0.0:
			pos_x = maxf(pos_x, inner_min_x + half_w)
		if wall_east > 0.0:
			pos_x = minf(pos_x, inner_max_x - half_w)
		if wall_west > 0.0 and wall_east > 0.0:
			fits = (inner_max_x - inner_min_x) >= width

	elif dir.x == 1:
		# Mira hacia +X (adosado a muro Oeste en -X)
		pos_x = inner_min_x + half_d
		if wall_north > 0.0:
			pos_z = maxf(pos_z, inner_min_z + half_w)
		if wall_south > 0.0:
			pos_z = minf(pos_z, inner_max_z - half_w)
		if wall_north > 0.0 and wall_south > 0.0:
			fits = (inner_max_z - inner_min_z) >= width

	elif dir.x == -1:
		# Mira hacia -X (adosado a muro Este en +X)
		pos_x = inner_max_x - half_d
		if wall_north > 0.0:
			pos_z = maxf(pos_z, inner_min_z + half_w)
		if wall_south > 0.0:
			pos_z = minf(pos_z, inner_max_z - half_w)
		if wall_north > 0.0 and wall_south > 0.0:
			fits = (inner_max_z - inner_min_z) >= width

	# Verificación exhaustiva de caja envolvente contra todas las celdas y muros tocados:
	if fits and not map.is_empty():
		var hw := (width if dir.y != 0 else depth) * 0.5
		var hd := (depth if dir.y != 0 else width) * 0.5
		var min_x := pos_x - hw
		var max_x := pos_x + hw
		var min_z := pos_z - hd
		var max_z := pos_z + hd

		var m_half_w := float(map_w) * 0.5
		var m_half_d := float(map_d) * 0.5

		var gx_min := int(floor(min_x + m_half_w + 0.001))
		var gx_max := int(floor(max_x + m_half_w - 0.001))
		var gz_min := int(floor(min_z + m_half_d + 0.001))
		var gz_max := int(floor(max_z + m_half_d - 0.001))

		for cz in range(gz_min, gz_max + 1):
			for cx in range(gx_min, gx_max + 1):
				if cx < 0 or cx >= map_w or cz < 0 or cz >= map_d:
					fits = false
					break
				if map[cz * map_w + cx] != room_id:
					fits = false
					break

				# Validar que ningún muro de las celdas tocadas invada la caja libre con aire:
				var w_w := _get_wall_intrusion(map, map_w, map_d, cx - 1, cz, room_id)
				if w_w > 0.0:
					var face_x := float(cx) - m_half_w + w_w + WALL_AIR_GAP
					if min_x < face_x - 0.001:
						fits = false
						break
				var w_e := _get_wall_intrusion(map, map_w, map_d, cx + 1, cz, room_id)
				if w_e > 0.0:
					var face_x := float(cx + 1) - m_half_w - w_e - WALL_AIR_GAP
					if max_x > face_x + 0.001:
						fits = false
						break
				var w_n := _get_wall_intrusion(map, map_w, map_d, cx, cz - 1, room_id)
				if w_n > 0.0:
					var face_z := float(cz) - m_half_d + w_n + WALL_AIR_GAP
					if min_z < face_z - 0.001:
						fits = false
						break
				var w_s := _get_wall_intrusion(map, map_w, map_d, cx, cz + 1, room_id)
				if w_s > 0.0:
					var face_z := float(cz + 1) - m_half_d - w_s - WALL_AIR_GAP
					if max_z > face_z + 0.001:
						fits = false
						break
			if not fits:
				break

	return {
		"position": Vector3(pos_x, y_val, pos_z),
		"fits": fits
	}

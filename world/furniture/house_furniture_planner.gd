class_name HouseFurniturePlanner
extends RefCounted

## Planificador Arquitectónico Coherente de Mobiliario e Infraestructura Eléctrica
## Resuelve de manera estricta y algorítmica las 3 directivas críticas:
## 1. Mufas y Medidores CFE: NUNCA en ventanas ni puertas; estrictamente en tramos macizos de fachada con margen de seguridad.
## 2. Pasos y Puertas Libres: Ningún mueble invade el cono de apertura ni el corredor de tránsito de puertas (interiores o exteriores).
## 3. Cero Penetración en Paredes: La estufa, refrigerador y gabinetes calculan el paramento interior real del muro y respetan su profundidad exacta.

const ApplianceRefrigeratorScript = preload("res://world/furniture/appliance_refrigerator.gd")
const ApplianceStoveScript = preload("res://world/furniture/appliance_stove.gd")
const ApplianceMicrowaveScript = preload("res://world/furniture/appliance_microwave.gd")
const KitchenCabinetScript = preload("res://world/furniture/kitchen_cabinet.gd")
const ApplianceToasterScript = preload("res://world/furniture/appliance_toaster.gd")
const CoffeeTableScript = preload("res://world/furniture/coffee_table.gd")
const ApplianceWasherScript = preload("res://world/furniture/appliance_washer.gd")
const ApplianceDryerScript = preload("res://world/furniture/appliance_dryer.gd")
const ArmchairLeatherScript = preload("res://world/furniture/armchair_leather.gd")
const BedSingleOakScript = preload("res://world/furniture/bed_single_oak.gd")
const NightstandOakScript = preload("res://world/furniture/nightstand_oak.gd")
const WardrobeOakScript = preload("res://world/furniture/wardrobe_oak.gd")
const BookcaseTallScript = preload("res://world/furniture/bookcase_tall.gd")
const SinkUnitWhiteScript = preload("res://world/furniture/sink_unit_white.gd")
const CellWallMetricsScript = preload("res://world/furniture/cell_wall_metrics.gd")
const PlanarPropsManagerScript = preload("res://world/furniture/planar_props_manager.gd")

const EXT_WALL_THICKNESS := 0.20 # Muro exterior de 20cm
const INT_WALL_THICKNESS := 0.12 # Muro interior de 12cm
const WALL_AIR_GAP := 0.02       # 2cm de separación de dilatación con el yeso

const DOOR_TRANSIT_WIDTH := 0.95 # Ancho mínimo de paso libre
const DOOR_TRANSIT_DEPTH := 0.90 # Profundidad de paso libre hacia ambos lados


# =========================================================================
# 1. PLANIFICADOR DE MEDIDOR CFE EN FACHADA EXTERIOR
# =========================================================================

## Encuentra una ubicación sólida garantizada en la fachada frontal para el medidor CFE
## evitando ventanas, puertas y esquinas con al menos 40cm de buffer.
static func find_safe_facade_meter_position(res: Dictionary, house_xform: Transform3D, house_w: float, house_d: float) -> Dictionary:
	var facade_z_local := -house_d * 0.5
	var half_w := house_w * 0.5

	# Recopilar todos los vanos en planta baja sobre la fachada frontal (Z = -house_d * 0.5)
	var openings: Array[Dictionary] = []

	for win in res.get("windows", []):
		if win.get("floor", 1) == 1 and absf(win.position.z - facade_z_local) < 0.35:
			var sz = win.size
			var win_w: float = sz.x if sz is Vector2 or sz is Vector3 else 1.2
			openings.append({
				"x_min": win.position.x - win_w * 0.5 - 0.40, # 40cm buffer
				"x_max": win.position.x + win_w * 0.5 + 0.40,
				"center": win.position.x
			})

	var main_door_x := 0.0
	var has_main_door := false
	for dr in res.get("doors", []):
		if absf(dr.position.z - facade_z_local) < 0.35:
			var sz: Vector3 = dr.size
			var dr_w: float = sz.x
			openings.append({
				"x_min": dr.position.x - dr_w * 0.5 - 0.45, # 45cm buffer
				"x_max": dr.position.x + dr_w * 0.5 + 0.45,
				"center": dr.position.x
			})
			if dr.get("is_main", false):
				main_door_x = dr.position.x
				has_main_door = true

	# Borde del muro con margen de esquina de 30cm
	var wall_x0 := -half_w + 0.30
	var wall_x1 := half_w - 0.30

	# Ordenar vanos de izquierda a derecha
	openings.sort_custom(func(a, b): return a.x_min < b.x_min)

	# Extraer tramos de muro ciego / sólido de al menos 65cm de ancho
	var solid_piers: Array[Dictionary] = []
	var cur_x := wall_x0

	for op in openings:
		if op.x_min > cur_x + 0.65:
			solid_piers.append({
				"x_min": cur_x,
				"x_max": op.x_min,
				"width": op.x_min - cur_x,
				"center": (cur_x + op.x_min) * 0.5
			})
		cur_x = maxf(cur_x, op.x_max)

	if wall_x1 > cur_x + 0.65:
		solid_piers.append({
			"x_min": cur_x,
			"x_max": wall_x1,
			"width": wall_x1 - cur_x,
			"center": (cur_x + wall_x1) * 0.5
		})

	# Calcular la orientación mundial hacia donde debe mirar el medidor (hacia la calle)
	var world_facade_normal: Vector3 = house_xform.basis * Vector3(0, 0, -1)
	var meter_rot_y := _get_wall_facing_rotation(world_facade_normal)

	if solid_piers.is_empty():
		# Fallback de emergencia al extremo de la esquina
		return {
			"valid": false,
			"meter_world_pos": house_xform * Vector3(wall_x0 + 0.35, 1.55, facade_z_local - 0.06),
			"switch_world_pos": house_xform * Vector3(wall_x0 + 0.70, 1.55, facade_z_local - 0.06),
			"rotation_y": meter_rot_y
		}

	# Elegir el mejor tramo sólido: Preferir la mocheta adyacente a la puerta principal
	var best_pier: Dictionary = solid_piers[0]
	if has_main_door:
		var min_dist := 9999.0
		for pier in solid_piers:
			var d := absf(pier.center - main_door_x)
			if d < min_dist:
				min_dist = d
				best_pier = pier
	else:
		# Tomar el tramo más ancho
		for pier in solid_piers:
			if pier.width > best_pier.width:
				best_pier = pier

	# Medidor centrado en el tramo sólido
	var meter_local_x: float = best_pier.center
	# Si el tramo es muy ancho (>1.5m), situarlo hacia el lado de la puerta o esquina
	if best_pier.width > 1.5 and has_main_door:
		if main_door_x > best_pier.center:
			meter_local_x = best_pier.x_max - 0.40
		else:
			meter_local_x = best_pier.x_min + 0.40

	# Switch a 40cm a un lado, garantizado dentro del mismo tramo sólido
	var switch_local_x := meter_local_x + 0.40
	if switch_local_x > best_pier.x_max - 0.15:
		switch_local_x = meter_local_x - 0.40

	var meter_local_z := facade_z_local - (EXT_WALL_THICKNESS * 0.5 + 0.02)
	var meter_world_pos: Vector3 = house_xform * Vector3(meter_local_x, 1.55, meter_local_z)
	var switch_world_pos: Vector3 = house_xform * Vector3(switch_local_x, 1.55, meter_local_z)

	return {
		"valid": true,
		"meter_world_pos": meter_world_pos,
		"switch_world_pos": switch_world_pos,
		"rotation_y": meter_rot_y
	}


# =========================================================================
# FUNCIONES AUXILIARES DE MATRIZ DE CELDAS DISCRETAS (1m x 1m)
# =========================================================================

static func _get_floor_map(res: Dictionary, floor_num: int, w: int, d: int) -> PackedByteArray:
	var key := "room_map_floor1" if floor_num == 1 else "room_map_floor2"
	var map: PackedByteArray = res.get(key, PackedByteArray())
	if map.size() == w * d:
		return map

	var fallback := PackedByteArray()
	fallback.resize(w * d)
	fallback.fill(0)
	for r in res.get("rooms", []):
		if int(r.get("floor", 1)) == floor_num:
			var rid: int = int(r.get("id", 1))
			var x0: int = clampi(int(r.get("x_min", 0)), 0, w)
			var x1: int = clampi(int(r.get("x_max", 0)), 0, w)
			var z0: int = clampi(int(r.get("z_min", 0)), 0, d)
			var z1: int = clampi(int(r.get("z_max", 0)), 0, d)
			for z in range(z0, z1):
				for x in range(x0, x1):
					fallback[z * w + x] = rid
	return fallback


static func _is_valid_room_cell(map: PackedByteArray, w: int, d: int, gx: int, gz: int, room_id: int) -> bool:
	if gx < 0 or gx >= w or gz < 0 or gz >= d:
		return false
	return map[gz * w + gx] == room_id


static func _get_door_reserved_cells(res: Dictionary, floor_num: int, w: int, d: int) -> Dictionary:
	var reserved := {}
	var half_w := float(w) * 0.5
	var half_d := float(d) * 0.5

	for dr in res.get("doors", []):
		var dp: Vector3 = dr.get("position", Vector3.ZERO)
		var d_floor := 1 if dp.y < 2.0 else 2
		if d_floor != floor_num:
			continue

		var dgx := int(floor(dp.x + half_w))
		var dgz := int(floor(dp.z + half_d))

		for oz in range(-1, 2):
			for ox in range(-1, 2):
				var cgx := dgx + ox
				var cgz := dgz + oz
				if cgx >= 0 and cgx < w and cgz >= 0 and cgz < d:
					var cell_center_x := float(cgx) - half_w + 0.5
					var cell_center_z := float(cgz) - half_d + 0.5
					var dist := Vector2(cell_center_x - dp.x, cell_center_z - dp.z).length()
					if dist < 1.15:
						reserved[Vector2i(cgx, cgz)] = true
	return reserved


static func _get_cell_wall_inner_face(gx: int, gz: int, dir: Vector2i, map: PackedByteArray, w: int, d: int) -> float:
	var half_w := float(w) * 0.5
	var half_d := float(d) * 0.5
	var bgx := gx - dir.x
	var bgz := gz - dir.y
	var is_exterior := (bgx < 0 or bgx >= w or bgz < 0 or bgz >= d or map[bgz * w + bgx] == 0)
	var wall_th := EXT_WALL_THICKNESS if is_exterior else INT_WALL_THICKNESS

	if dir.x == 1:
		# Pared Oeste, cara interior mira hacia +X
		var wall_coord := float(gx) - half_w
		return wall_coord + wall_th * 0.5
	elif dir.x == -1:
		# Pared Este, cara interior mira hacia -X
		var wall_coord := float(gx + 1) - half_w
		return wall_coord - wall_th * 0.5
	elif dir.y == 1:
		# Pared Norte, cara interior mira hacia +Z
		var wall_coord := float(gz) - half_d
		return wall_coord + wall_th * 0.5
	else:
		# Pared Sur, cara interior mira hacia -Z
		var wall_coord := float(gz + 1) - half_d
		return wall_coord - wall_th * 0.5


static func _get_wall_furniture_pos(gx: int, gz: int, dir: Vector2i, depth: float, width: float, y_val: float, map: PackedByteArray, w: int, d: int, room_id: int = -1) -> Vector3:
	var r_id := room_id
	if r_id <= 0:
		if gx >= 0 and gx < w and gz >= 0 and gz < d:
			r_id = map[gz * w + gx]
		else:
			r_id = 1
	var m := CellWallMetricsScript.measure_cell(map, w, d, gx, gz, r_id)
	var placement: Dictionary = m.calculate_safe_placement(dir, depth, width, y_val)
	return placement["position"]


static func _cell_to_local_center(gx: int, gz: int, w: int, d: int) -> Vector3:
	return Vector3(
		float(gx) - float(w) * 0.5 + 0.5,
		0.16,
		float(gz) - float(d) * 0.5 + 0.5
	)


static func _get_dir_rotation(dir: Vector2i) -> float:
	if dir.y == 1:
		return 0.0 # Mira hacia +Z
	elif dir.y == -1:
		return PI # Mira hacia -Z
	elif dir.x == 1:
		return PI * 0.5 # Mira hacia +X
	else:
		return -PI * 0.5 # Mira hacia -X


static func _get_wall_facing_rotation(norm: Vector3) -> float:
	if norm.z > 0.5:
		return 0.0
	elif norm.z < -0.5:
		return PI
	elif norm.x > 0.5:
		return PI * 0.5
	else:
		return -PI * 0.5


# =========================================================================
# 2. PLANIFICADOR DE COCINA INTEGRAL (Estufa, Refri, Gabinetes y Microondas)
# =========================================================================

## Planifica la cocina colocando los electrodomésticos y gabinetes en un muro ciego,
## con paramentos exactos (sin penetrar paredes) y sin obstruir puertas ni vanos.
static func plan_kitchen_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	# Identificar qué celdas colindan con el Comedor (vano social abierto)
	var comedor_cells := {}
	for other_r in res.get("rooms", []):
		if other_r.get("name", "") == "Comedor" and int(other_r.get("floor", 1)) == 1:
			var ox0: int = int(other_r.get("x_min", 0))
			var ox1: int = int(other_r.get("x_max", 0))
			var oz0: int = int(other_r.get("z_min", 0))
			var oz1: int = int(other_r.get("z_max", 0))
			for oz in range(oz0, oz1):
				for ox in range(ox0, ox1):
					comedor_cells[Vector2i(ox, oz)] = true

	# Buscar tramos continuos de pared en la cocina
	var dirs: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	var best_wall_cells: Array[Vector2i] = []
	var best_dir := Vector2i(0, 0)
	var best_count := 0

	for dir in dirs:
		var perp := Vector2i(-dir.y, dir.x)
		var scan_cells: Array[Vector2i] = []
		for z in range(r_zmin, r_zmax):
			for x in range(r_xmin, r_xmax):
				var cell := Vector2i(x, z)
				if not _is_valid_room_cell(map, iw, id, x, z, room_id):
					continue
				var bg: Vector2i = cell - dir
				if _is_valid_room_cell(map, iw, id, bg.x, bg.y, room_id):
					continue
				if comedor_cells.has(bg):
					continue
				scan_cells.append(cell)

		scan_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var val_a: int = a.x * perp.x + a.y * perp.y
			var val_b: int = b.x * perp.x + b.y * perp.y
			return val_a < val_b
		)

		var cur_seq: Array[Vector2i] = []
		var longest_seq: Array[Vector2i] = []

		for cell in scan_cells:
			if door_reserved.has(cell):
				if cur_seq.size() > longest_seq.size():
					longest_seq = cur_seq.duplicate()
				cur_seq.clear()
				continue

			if cur_seq.is_empty():
				cur_seq.append(cell)
			else:
				var prev: Vector2i = cur_seq[-1]
				if (cell - prev) == perp:
					cur_seq.append(cell)
				else:
					if cur_seq.size() > longest_seq.size():
						longest_seq = cur_seq.duplicate()
					cur_seq = [cell]

		if cur_seq.size() > longest_seq.size():
			longest_seq = cur_seq.duplicate()

		if longest_seq.size() > best_count:
			best_count = longest_seq.size()
			best_wall_cells = longest_seq
			best_dir = dir

	if best_wall_cells.is_empty():
		return []

	var cab_rot_y := _get_dir_rotation(best_dir)
	var results: Array[Dictionary] = []
	var occupied_cells := {}

	# 1. Gabinete Base + Microondas + Tostadora + Gabinete Aéreo en celda 0
	var cab_cell: Vector2i = best_wall_cells[0]
	occupied_cells[cab_cell] = true
	var cab_d := 0.60
	var cab_w := 0.85
	var cab_pos := _get_wall_furniture_pos(cab_cell.x, cab_cell.y, best_dir, cab_d, cab_w, 0.16, map, iw, id, room_id)

	results.append({
		"name": "KitchenBaseCabinet",
		"script": KitchenCabinetScript,
		"position": cab_pos,
		"rotation_y": cab_rot_y,
		"cabinet_type": KitchenCabinetScript.CabinetType.BASE_COUNTER
	})

	var wall_tan := Vector3(0, 0, 1) if best_dir.x != 0 else Vector3(1, 0, 0)
	var wall_norm_3d := Vector3(float(best_dir.x), 0, float(best_dir.y))

	# Microondas compacto sobre la encimera
	results.append({
		"name": "KitchenMicrowave",
		"script": ApplianceMicrowaveScript,
		"position": cab_pos + Vector3(0.0, 0.86, 0.0) + wall_norm_3d * 0.04 - wall_tan * 0.20,
		"rotation_y": cab_rot_y
	})

	# Tostadora
	results.append({
		"name": "KitchenToaster",
		"script": ApplianceToasterScript,
		"position": cab_pos + Vector3(0.0, 0.86, 0.0) + wall_norm_3d * 0.04 + wall_tan * 0.24,
		"rotation_y": cab_rot_y
	})

	# Gabinete Aéreo
	results.append({
		"name": "KitchenWallCabinet",
		"script": KitchenCabinetScript,
		"position": cab_pos + Vector3(0.0, 1.45, 0.0) - wall_norm_3d * (cab_d * 0.5 - 0.38 * 0.5),
		"rotation_y": cab_rot_y,
		"cabinet_type": KitchenCabinetScript.CabinetType.WALL_HANGING
	})

	# 2. Estufa en celda 1 (si existe)
	if best_wall_cells.size() >= 2:
		var stove_cell: Vector2i = best_wall_cells[1]
		occupied_cells[stove_cell] = true
		var stove_d := 0.68
		var stove_w := 0.76
		var stove_pos := _get_wall_furniture_pos(stove_cell.x, stove_cell.y, best_dir, stove_d, stove_w, 0.16, map, iw, id, room_id)
		results.append({
			"name": "KitchenStove",
			"script": ApplianceStoveScript,
			"position": stove_pos,
			"rotation_y": cab_rot_y
		})

	# 3. Refrigerador en celda 2 (o en otra pared libre)
	var refri_d := 0.78
	var refri_w := 0.80
	if best_wall_cells.size() >= 3:
		var refri_cell: Vector2i = best_wall_cells[2]
		occupied_cells[refri_cell] = true
		var refri_pos := _get_wall_furniture_pos(refri_cell.x, refri_cell.y, best_dir, refri_d, refri_w, 0.16, map, iw, id, room_id)
		results.append({
			"name": "KitchenRefrigerator",
			"script": ApplianceRefrigeratorScript,
			"position": refri_pos,
			"rotation_y": cab_rot_y
		})
	else:
		# Buscar otra celda de pared libre en la cocina
		for z in range(r_zmin, r_zmax):
			var placed_refri := false
			for x in range(r_xmin, r_xmax):
				var cell := Vector2i(x, z)
				if occupied_cells.has(cell) or door_reserved.has(cell) or not _is_valid_room_cell(map, iw, id, x, z, room_id):
					continue
				for rdir in dirs:
					var rbg: Vector2i = cell - rdir
					if not _is_valid_room_cell(map, iw, id, rbg.x, rbg.y, room_id) and not comedor_cells.has(rbg):
						var refri_pos := _get_wall_furniture_pos(cell.x, cell.y, rdir, refri_d, refri_w, 0.16, map, iw, id, room_id)
						results.append({
							"name": "KitchenRefrigerator",
							"script": ApplianceRefrigeratorScript,
							"position": refri_pos,
							"rotation_y": _get_dir_rotation(rdir)
						})
						placed_refri = true
						break
				if placed_refri:
					break
			if placed_refri:
				break

	return results


# =========================================================================
# 3. PLANIFICADOR DE COMEDOR (Mesa y Sillas con Corredor Libre)
# =========================================================================

## Planifica la ubicación del Comedor garantizando que las sillas y la mesa
## nunca bloqueen el camino entre la puerta de entrada, la cocina y los pasillos.
static func plan_dining_set(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float) -> Dictionary:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	var center_fx := float(r_xmin + r_xmax) * 0.5
	var center_fz := float(r_zmin + r_zmax) * 0.5

	# Buscar un bloque 2x2 centrado donde todas las 4 celdas pertenezcan al comedor y no tengan puertas
	var best_pos := Vector3.ZERO
	var best_dist := 9999.0

	for z in range(r_zmin, r_zmax - 1):
		for x in range(r_xmin, r_xmax - 1):
			var c00 := Vector2i(x, z)
			var c10 := Vector2i(x + 1, z)
			var c01 := Vector2i(x, z + 1)
			var c11 := Vector2i(x + 1, z + 1)
			if _is_valid_room_cell(map, iw, id, c00.x, c00.y, room_id) and \
			   _is_valid_room_cell(map, iw, id, c10.x, c10.y, room_id) and \
			   _is_valid_room_cell(map, iw, id, c01.x, c01.y, room_id) and \
			   _is_valid_room_cell(map, iw, id, c11.x, c11.y, room_id):
				if not door_reserved.has(c00) and not door_reserved.has(c10) and not door_reserved.has(c01) and not door_reserved.has(c11):
					var bx := float(x + 1) - float(iw) * 0.5
					var bz := float(z + 1) - float(id) * 0.5
					var d := Vector2(float(x + 1) - center_fx, float(z + 1) - center_fz).length()
					if d < best_dist:
						best_dist = d
						best_pos = Vector3(bx, 0.16, bz)

	if best_dist > 9000.0:
		# Fallback: Celda individual más central libre de puertas
		var best_cell := Vector2i(-999, -999)
		var min_d := 9999.0
		for z in range(r_zmin, r_zmax):
			for x in range(r_xmin, r_xmax):
				var c := Vector2i(x, z)
				if _is_valid_room_cell(map, iw, id, x, z, room_id) and not door_reserved.has(c):
					var d := Vector2(float(x) + 0.5 - center_fx, float(z) + 0.5 - center_fz).length()
					if d < min_d:
						min_d = d
						best_cell = c
		if best_cell.x != -999:
			best_pos = _cell_to_local_center(best_cell.x, best_cell.y, iw, id)
		else:
			best_pos = Vector3(center_fx - float(iw) * 0.5, 0.16, center_fz - float(id) * 0.5)

	var rot := 0.0 if (r_xmax - r_xmin) >= (r_zmax - r_zmin) else PI * 0.5
	return {
		"position": best_pos,
		"rotation_y": rot
	}


# =========================================================================
# 4. PLANIFICADOR DE SALA (Mesa de Centro / Coffee Table con Tránsito Libre)
# =========================================================================

## Planifica la mesa de centro en la sala respetando corredores de paso y puertas
static func plan_living_room_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float, house_seed: int = 0) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	var center_fx := float(r_xmin + r_xmax) * 0.5
	var center_fz := float(r_zmin + r_zmax) * 0.5

	# Buscar la celda válida más cercana al centro que no esté en corredor de puerta
	var best_table_cell := Vector2i(-999, -999)
	var min_dist := 9999.0

	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			if _is_valid_room_cell(map, iw, id, x, z, room_id) and not door_reserved.has(Vector2i(x, z)):
				var d := Vector2(float(x) + 0.5 - center_fx, float(z) + 0.5 - center_fz).length()
				if d < min_dist:
					min_dist = d
					best_table_cell = Vector2i(x, z)

	if best_table_cell.x == -999:
		return []

	var table_pos := _cell_to_local_center(best_table_cell.x, best_table_cell.y, iw, id)
	var table_rot := 0.0 if (r_xmax - r_xmin) >= (r_zmax - r_zmin) else PI * 0.5

	var results: Array[Dictionary] = []
	results.append({
		"name": "LivingCoffeeTable",
		"script": CoffeeTableScript,
		"position": table_pos,
		"rotation_y": table_rot
	})

	# Alfombra Rectangular de Sala (debajo de la mesa de centro con su misma orientación)
	var rug_pos := table_pos
	rug_pos.y = 0.17
	var living_rug_id: String = PlanarPropsManagerScript.get_random_prop_id("floor", ["living_room"], house_seed ^ (room_id * 97) ^ (r_xmin * 31) ^ 0x9D8E7F)
	results.append({
		"name": "LivingRug",
		"script": "planar_floor",
		"prop_type": "planar_floor",
		"prop_id": living_rug_id,
		"position": rug_pos,
		"rotation_y": table_rot
	})

	# Buscar una celda vecina ortogonal para el sillón (LivingArmchair)
	# Priorizar Norte o Sur (frente al lado largo de la mesa), luego Oeste o Este
	var sofa_dirs: Array[Vector2i] = [
		Vector2i(0, -1), # Al norte mirando al sur hacia la mesa
		Vector2i(0, 1),  # Al sur mirando al norte hacia la mesa
		Vector2i(-1, 0), # Al oeste mirando al este
		Vector2i(1, 0)   # Al este mirando al oeste
	]

	var best_sofa_cell := Vector2i(-999, -999)
	var best_sofa_dir := Vector2i(0, 0)

	for sdir in sofa_dirs:
		var scell := best_table_cell + sdir
		if _is_valid_room_cell(map, iw, id, scell.x, scell.y, room_id) and not door_reserved.has(scell):
			best_sofa_cell = scell
			best_sofa_dir = sdir
			break

	if best_sofa_cell.x != -999:
		var sofa_pos := _cell_to_local_center(best_sofa_cell.x, best_sofa_cell.y, iw, id)
		var sofa_rot := _get_dir_rotation(-best_sofa_dir)
		results.append({
			"name": "LivingArmchair",
			"script": ArmchairLeatherScript,
			"position": sofa_pos,
			"rotation_y": sofa_rot
		})

	return results


# =========================================================================
# 5. PLANIFICADOR DE LAVANDERÍA (Lavadora y Secadora Pareja)
# =========================================================================

## Planifica la pareja de lavadora y secadora en un muro libre sin invadir puertas
static func plan_laundry_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var best_c1 := Vector2i(-999, -999)
	var best_c2 := Vector2i(-999, -999)
	var best_dir := Vector2i(0, 0)
	var found := false

	# Buscar 2 celdas contiguas a lo largo de una pared
	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			var c1 := Vector2i(x, z)
			if not _is_valid_room_cell(map, iw, id, c1.x, c1.y, room_id) or door_reserved.has(c1):
				continue
			for dir in dirs:
				if _is_valid_room_cell(map, iw, id, c1.x - dir.x, c1.y - dir.y, room_id):
					continue
				var perp := Vector2i(-dir.y, dir.x)
				var c2 := c1 + perp
				if _is_valid_room_cell(map, iw, id, c2.x, c2.y, room_id) and not door_reserved.has(c2):
					if not _is_valid_room_cell(map, iw, id, c2.x - dir.x, c2.y - dir.y, room_id):
						best_c1 = c1
						best_c2 = c2
						best_dir = dir
						found = true
						break
			if found:
				break
		if found:
			break

	if not found:
		return []

	var app_d := 0.68
	var app_w := 0.74
	var rot_y := _get_dir_rotation(best_dir)
	var washer_pos := _get_wall_furniture_pos(best_c1.x, best_c1.y, best_dir, app_d, app_w, 0.16, map, iw, id, room_id)
	var dryer_pos := _get_wall_furniture_pos(best_c2.x, best_c2.y, best_dir, app_d, app_w, 0.16, map, iw, id, room_id)

	var results: Array[Dictionary] = []
	results.append({
		"name": "LaundryWasher",
		"script": ApplianceWasherScript,
		"position": washer_pos,
		"rotation_y": rot_y
	})
	results.append({
		"name": "LaundryDryer",
		"script": ApplianceDryerScript,
		"position": dryer_pos,
		"rotation_y": rot_y
	})
	return results


# =========================================================================
# 6. PLANIFICADOR DE RECÁMARA (Cama con ropa de cama, buró, ropero y tapete)
# =========================================================================

## Planifica el mobiliario de una recámara colocando la cama con cabecera en un muro sólido,
## buró adyacente con prop (taza o libro), ropero en pared secundaria y tapete decorativo.
static func plan_bedroom_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float, rng_seed: int = 0) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var half_w := house_w * 0.5
	var half_d := house_d * 0.5

	# 1. Encontrar todas las celdas válidas de esta recámara
	var room_cells: Array[Vector2i] = []
	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			if _is_valid_room_cell(map, iw, id, x, z, room_id):
				room_cells.append(Vector2i(x, z))

	if room_cells.is_empty():
		return []

	# Recopilar ventanas de este cuarto para evitar cabecera bajo ventanas si es posible
	var room_windows: Array[Vector3] = []
	for wn in res.get("windows", []):
		if int(wn.get("floor", 1)) == room_floor:
			var wp: Vector3 = wn.position
			var wgx := int(floor(wp.x + half_w))
			var wgz := int(floor(wp.z + half_d))
			if wgx >= r_xmin - 1 and wgx <= r_xmax and wgz >= r_zmin - 1 and wgz <= r_zmax:
				room_windows.append(wp)

	# 2. Evaluar posibles ubicaciones para la cama (cabecera en celda H contra una pared, apuntando en dir)
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var best_bed_candidate: Dictionary = {}
	var best_score := -9999.0

	for cell in room_cells:
		for dir in dirs:
			var bgx: int = cell.x - dir.x
			var bgz: int = cell.y - dir.y
			if _is_valid_room_cell(map, iw, id, bgx, bgz, room_id):
				continue # No hay pared detrás

			if door_reserved.has(cell):
				continue

			var f1 := Vector2i(cell.x + dir.x, cell.y + dir.y)
			if not _is_valid_room_cell(map, iw, id, f1.x, f1.y, room_id) or door_reserved.has(f1):
				continue

			var f2 := Vector2i(cell.x + dir.x * 2, cell.y + dir.y * 2)
			var has_f2 := _is_valid_room_cell(map, iw, id, f2.x, f2.y, room_id) and not door_reserved.has(f2)
			if not has_f2:
				continue

			# Validar con CellWallMetrics que toda la caja envolvente de la cama (2.14m x 1.05m)
			# quepa perfectamente dentro del cuarto sin tocar ningún muro perimetral ni perpendicular
			var m := CellWallMetricsScript.measure_cell(map, iw, id, cell.x, cell.y, room_id)
			var safe := m.calculate_safe_placement(dir, 2.14, 1.05, 0.16)
			if not safe["fits"]:
				continue

			var score := 50.0

			var perp := Vector2i(-dir.y, dir.x)
			var n1 := cell + perp
			var n2 := cell - perp
			var n1_valid := _is_valid_room_cell(map, iw, id, n1.x, n1.y, room_id) and not door_reserved.has(n1)
			var n2_valid := _is_valid_room_cell(map, iw, id, n2.x, n2.y, room_id) and not door_reserved.has(n2)

			if n1_valid or n2_valid:
				score += 20.0
			if n1_valid and n2_valid:
				score += 10.0

			var is_exterior: bool = (bgx < 0 or bgx >= iw or bgz < 0 or bgz >= id or map[bgz * iw + bgx] == 0)
			if not is_exterior:
				score += 15.0

			var cell_center_x := float(cell.x) - half_w + 0.5
			var cell_center_z := float(cell.y) - half_d + 0.5
			for win_p in room_windows:
				if Vector2(cell_center_x - win_p.x, cell_center_z - win_p.z).length() < 1.0:
					score -= 25.0

			if score > best_score:
				best_score = score
				best_bed_candidate = {
					"head_cell": cell,
					"foot_cell": f1,
					"dir": dir,
					"perp": perp,
					"n1_valid": n1_valid,
					"n2_valid": n2_valid,
					"n1_cell": n1,
					"n2_cell": n2,
					"has_f2": has_f2,
					"position": safe["position"]
				}

	if best_bed_candidate.is_empty():
		return []

	var head_c: Vector2i = best_bed_candidate["head_cell"]
	var b_dir: Vector2i = best_bed_candidate["dir"]
	var b_perp: Vector2i = best_bed_candidate["perp"]
	var bed_rot_y := _get_dir_rotation(b_dir)

	var results: Array[Dictionary] = []

	var seed_u: int = absi(rng_seed ^ (room_id * 31337) ^ (room_floor * 7919))
	var sheet_id: int = seed_u % 16
	var blanket_id: int = (seed_u >> 4) % 24
	var state_roll: int = (seed_u >> 8) % 100
	var b_state: int = BedSingleOakScript.BedState.MADE
	if state_roll >= 94:
		b_state = BedSingleOakScript.BedState.BARE_MATTRESS
	elif state_roll >= 85:
		b_state = BedSingleOakScript.BedState.STRIPPED
	elif state_roll >= 60:
		b_state = BedSingleOakScript.BedState.UNMADE

	var has_pillow: bool = (b_state != BedSingleOakScript.BedState.BARE_MATTRESS)
	if has_pillow and ((seed_u >> 11) % 20 == 0):
		has_pillow = false

	var dirt: float = float((seed_u >> 13) % 28) * 0.01

	# Posición de la Cama calculada y validada por CellWallMetrics:
	var bed_pos: Vector3 = best_bed_candidate["position"]

	results.append({
		"name": "BedroomBed",
		"script": BedSingleOakScript,
		"position": bed_pos,
		"rotation_y": bed_rot_y,
		"bed_state": b_state,
		"sheet_pattern_id": sheet_id,
		"blanket_pattern_id": blanket_id,
		"has_pillow": has_pillow,
		"dirt_pct": dirt
	})

	var occupied_cells := {
		head_c: true,
		best_bed_candidate["foot_cell"]: true
	}
	if best_bed_candidate["has_f2"]:
		occupied_cells[Vector2i(head_c.x + b_dir.x * 2, head_c.y + b_dir.y * 2)] = true

	# Posición del Buró:
	var ns_cell: Vector2i
	if best_bed_candidate["n1_valid"]:
		ns_cell = best_bed_candidate["n1_cell"]
	elif best_bed_candidate["n2_valid"]:
		ns_cell = best_bed_candidate["n2_cell"]
	else:
		ns_cell = Vector2i(-999, -999)

	if ns_cell.x != -999:
		occupied_cells[ns_cell] = true
		var ns_d := 0.43
		var ns_w := 0.48
		var ns_pos := _get_wall_furniture_pos(ns_cell.x, ns_cell.y, b_dir, ns_d, ns_w, 0.16, map, iw, id, room_id)

		results.append({
			"name": "BedroomNightstand",
			"script": NightstandOakScript,
			"position": ns_pos,
			"rotation_y": bed_rot_y
		})

		var prop_roll := (seed_u >> 16) % 10
		if prop_roll < 4:
			results.append({
				"name": "NightstandMug",
				"script": "mug",
				"position": ns_pos + Vector3(0.0, 0.705, 0.0),
				"rotation_y": bed_rot_y + float((seed_u >> 18) % 314) * 0.01
			})
		elif prop_roll < 7:
			results.append({
				"name": "NightstandBook",
				"script": "book",
				"book_type": "bible" if ((seed_u >> 19) % 2 == 0) else "novel_red",
				"position": ns_pos + Vector3(0.0, 0.705, 0.0),
				"rotation_y": bed_rot_y + 0.35
			})

	# Tapete (BedroomRug): Buscar celda interior que no toque muros perimetrales
	var rug_candidates: Array[Vector2i] = [
		best_bed_candidate["foot_cell"] + b_perp,
		best_bed_candidate["foot_cell"] - b_perp,
		head_c + b_perp * 2,
		head_c - b_perp * 2
	]
	for rc in rug_candidates:
		if _is_valid_room_cell(map, iw, id, rc.x, rc.y, room_id) and not occupied_cells.has(rc) and not door_reserved.has(rc):
			var n_ok: bool = _is_valid_room_cell(map, iw, id, rc.x, rc.y - 1, room_id)
			var s_ok: bool = _is_valid_room_cell(map, iw, id, rc.x, rc.y + 1, room_id)
			var w_ok: bool = _is_valid_room_cell(map, iw, id, rc.x - 1, rc.y, room_id)
			var e_ok: bool = _is_valid_room_cell(map, iw, id, rc.x + 1, rc.y, room_id)
			if n_ok and s_ok and w_ok and e_ok:
				var r_center := _cell_to_local_center(rc.x, rc.y, iw, id)
				r_center.y = 0.17
				var rug_id: String = PlanarPropsManagerScript.get_random_prop_id("floor", ["bedroom"], (seed_u >> 16) ^ 0x3A5B7C)
				results.append({
					"name": "BedroomRug",
					"script": "planar_floor",
					"prop_type": "planar_floor",
					"prop_id": rug_id,
					"position": r_center,
					"rotation_y": bed_rot_y
				})
				occupied_cells[rc] = true
				break

	# Ropero (BedroomWardrobe)
	var wardrobe_d := 0.62
	var wardrobe_w := 1.06
	var best_w_cell := Vector2i(-999, -999)
	var best_w_dir := Vector2i(0, 0)
	var best_w_score := -999.0

	for cell in room_cells:
		if occupied_cells.has(cell) or door_reserved.has(cell):
			continue
		for dir in dirs:
			if dir == b_dir:
				continue
			var bgx: int = cell.x - dir.x
			var bgz: int = cell.y - dir.y
			if _is_valid_room_cell(map, iw, id, bgx, bgz, room_id):
				continue

			var front_c: Vector2i = cell + dir
			if not _is_valid_room_cell(map, iw, id, front_c.x, front_c.y, room_id) or door_reserved.has(front_c) or occupied_cells.has(front_c):
				continue

			var m := CellWallMetricsScript.measure_cell(map, iw, id, cell.x, cell.y, room_id)
			var safe := m.calculate_safe_placement(dir, wardrobe_d, wardrobe_w, 0.16)
			if not safe["fits"]:
				continue

			var dist_to_bed := (Vector2(cell) - Vector2(head_c)).length()
			if dist_to_bed > best_w_score:
				best_w_score = dist_to_bed
				best_w_cell = cell
				best_w_dir = dir

	if best_w_cell.x != -999:
		var w_pos := _get_wall_furniture_pos(best_w_cell.x, best_w_cell.y, best_w_dir, wardrobe_d, wardrobe_w, 0.16, map, iw, id, room_id)
		var w_rot := _get_dir_rotation(best_w_dir)
		results.append({
			"name": "BedroomWardrobe",
			"script": WardrobeOakScript,
			"position": w_pos,
			"rotation_y": w_rot
		})
		occupied_cells[best_w_cell] = true

	return results


# =========================================================================
# 7. PLANIFICADOR DE BAÑO (Fregadero / Lavamanos blanco con grifería)
# =========================================================================

## Planifica el lavamanos en el baño asegurando pared libre de puerta
static func plan_bathroom_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float, _rng_seed: int = 0) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var best_cell := Vector2i(-999, -999)
	var best_dir := Vector2i(0, 0)
	var best_score := -999.0

	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			var cell := Vector2i(x, z)
			if not _is_valid_room_cell(map, iw, id, x, z, room_id) or door_reserved.has(cell):
				continue
			for dir in dirs:
				var bgx: int = x - dir.x
				var bgz: int = z - dir.y
				if _is_valid_room_cell(map, iw, id, bgx, bgz, room_id):
					continue
				var front_c: Vector2i = cell + dir
				if not _is_valid_room_cell(map, iw, id, front_c.x, front_c.y, room_id) or door_reserved.has(front_c):
					continue

				var m := CellWallMetricsScript.measure_cell(map, iw, id, cell.x, cell.y, room_id)
				var safe := m.calculate_safe_placement(dir, 0.62, 1.01, 0.16)
				if not safe["fits"]:
					continue

				var score := 10.0
				var is_ext: bool = (bgx < 0 or bgx >= iw or bgz < 0 or bgz >= id or map[bgz * iw + bgx] == 0)
				if not is_ext:
					score += 5.0
				if score > best_score:
					best_score = score
					best_cell = cell
					best_dir = dir

	if best_cell.x == -999:
		return []

	var sink_d := 0.62
	var sink_w := 1.01
	var sink_pos := _get_wall_furniture_pos(best_cell.x, best_cell.y, best_dir, sink_d, sink_w, 0.16, map, iw, id, room_id)
	var sink_rot := _get_dir_rotation(best_dir)

	var results: Array[Dictionary] = []
	results.append({
		"name": "BathroomSinkUnit",
		"script": SinkUnitWhiteScript,
		"position": sink_pos,
		"rotation_y": sink_rot
	})
	return results


# =========================================================================
# 8. PLANIFICADOR DE ESTUDIO / BIBLIOTECA (Libreros altos, libros y sillón)
# =========================================================================

## Planifica libreros altos, libros y sillón de lectura en el estudio
static func plan_studio_furniture(res: Dictionary, room_dict: Dictionary, house_w: float, house_d: float, _rng_seed: int = 0) -> Array[Dictionary]:
	var iw := int(house_w)
	var id := int(house_d)
	var room_floor := int(room_dict.get("floor", 1))
	var room_id := int(room_dict.get("id", 1))
	var map := _get_floor_map(res, room_floor, iw, id)
	var door_reserved := _get_door_reserved_cells(res, room_floor, iw, id)

	var r_xmin := int(room_dict.get("x_min", 0))
	var r_xmax := int(room_dict.get("x_max", iw))
	var r_zmin := int(room_dict.get("z_min", 0))
	var r_zmax := int(room_dict.get("z_max", id))

	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	var results: Array[Dictionary] = []
	var occupied_cells := {}

	# 1. Libreros en pared
	var bc_cell1 := Vector2i(-999, -999)
	var bc_cell2 := Vector2i(-999, -999)
	var bc_dir := Vector2i(0, 0)
	var found := false

	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			var c1 := Vector2i(x, z)
			if not _is_valid_room_cell(map, iw, id, c1.x, c1.y, room_id) or door_reserved.has(c1):
				continue
			for dir in dirs:
				if _is_valid_room_cell(map, iw, id, c1.x - dir.x, c1.y - dir.y, room_id):
					continue
				var perp := Vector2i(-dir.y, dir.x)
				var c2 := c1 + perp
				if _is_valid_room_cell(map, iw, id, c2.x, c2.y, room_id) and not door_reserved.has(c2):
					if not _is_valid_room_cell(map, iw, id, c2.x - dir.x, c2.y - dir.y, room_id):
						bc_cell1 = c1
						bc_cell2 = c2
						bc_dir = dir
						found = true
						break
			if found:
				break
		if found:
			break

	var bookcase_d := 0.30
	var bookcase_w := 0.84
	if found:
		occupied_cells[bc_cell1] = true
		occupied_cells[bc_cell2] = true
		var rot_y := _get_dir_rotation(bc_dir)
		results.append({
			"name": "StudioBookcase1",
			"script": BookcaseTallScript,
			"position": _get_wall_furniture_pos(bc_cell1.x, bc_cell1.y, bc_dir, bookcase_d, bookcase_w, 0.16, map, iw, id, room_id),
			"rotation_y": rot_y
		})
		results.append({
			"name": "StudioBookcase2",
			"script": BookcaseTallScript,
			"position": _get_wall_furniture_pos(bc_cell2.x, bc_cell2.y, bc_dir, bookcase_d, bookcase_w, 0.16, map, iw, id, room_id),
			"rotation_y": rot_y
		})

	# 2. Sillón de lectura confortable (ArmchairLeather)
	var center_fx := float(r_xmin + r_xmax) * 0.5
	var center_fz := float(r_zmin + r_zmax) * 0.5
	var best_chair_cell := Vector2i(-999, -999)
	var min_cdist := 9999.0

	for z in range(r_zmin, r_zmax):
		for x in range(r_xmin, r_xmax):
			var c := Vector2i(x, z)
			if _is_valid_room_cell(map, iw, id, x, z, room_id) and not occupied_cells.has(c) and not door_reserved.has(c):
				var d := Vector2(float(x) + 0.5 - center_fx, float(z) + 0.5 - center_fz).length()
				if d < min_cdist:
					min_cdist = d
					best_chair_cell = c

	if best_chair_cell.x != -999:
		occupied_cells[best_chair_cell] = true
		var chair_pos := _cell_to_local_center(best_chair_cell.x, best_chair_cell.y, iw, id)
		var chair_rot := 0.0
		if found:
			chair_rot = _get_dir_rotation(-bc_dir)
		results.append({
			"name": "StudioReadingArmchair",
			"script": ArmchairLeatherScript,
			"position": chair_pos,
			"rotation_y": chair_rot
		})

		var side_cell := Vector2i(-999, -999)
		var side_dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		for sdir in side_dirs:
			var sc: Vector2i = best_chair_cell + sdir
			if _is_valid_room_cell(map, iw, id, sc.x, sc.y, room_id) and not occupied_cells.has(sc) and not door_reserved.has(sc):
				side_cell = sc
				break

		if side_cell.x != -999:
			occupied_cells[side_cell] = true
			var side_pos := _cell_to_local_center(side_cell.x, side_cell.y, iw, id)
			results.append({
				"name": "StudioCoffeeTable",
				"script": CoffeeTableScript,
				"position": side_pos,
				"rotation_y": chair_rot
			})
			results.append({
				"name": "StudioMug",
				"script": "mug",
				"position": side_pos + Vector3(0.0, 0.45, 0.0),
				"rotation_y": chair_rot
			})

	return results


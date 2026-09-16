class_name RoadTrajectorySystem
extends Node3D
## Sistema de Carreteras Continuas por Trayectorias y Banquetas Paralelas Independientes.
## Las carreteras se generan a lo largo de vectores directores (endpoints) y las banquetas
## son cintas paralelas elevadas que se aplican a las orillas que el usuario decida.

const ProceduralRoadMaterials = preload("res://world/city/procedural_road_materials.gd")

enum RoadType {
	TWO_WAY_YELLOW,   # Calle de 2 sentidos con doble línea amarilla central
	AVENUE_WHITE,     # Avenida con líneas blancas de carril
	RURAL_PLAIN,      # Carretera simple de asfalto sin pintar
}

class RoadEndpoint:
	var id: int
	var position: Vector3
	var direction: Vector3 # Vector horizontal normalizado hacia donde apunta la salida
	var width: float
	var road_type: RoadType
	var connected_segments: Array[int] = []

	func _init(p_id: int, p_pos: Vector3, p_dir: Vector3, p_width: float, p_type: RoadType) -> void:
		id = p_id
		position = p_pos
		direction = Vector3(p_dir.x, 0.0, p_dir.z).normalized()
		width = p_width
		road_type = p_type


class RoadSegment:
	var id: int
	var start_endpoint_id: int
	var end_endpoint_id: int
	var start_pos: Vector3
	var end_pos: Vector3
	var width: float
	var road_type: RoadType
	var has_left_sidewalk: bool = false
	var has_right_sidewalk: bool = false
	var left_sidewalk_width: float = 2.5
	var right_sidewalk_width: float = 2.5

	func _init(p_id: int, p_s_id: int, p_e_id: int, p_start: Vector3, p_end: Vector3, p_width: float, p_type: RoadType) -> void:
		id = p_id
		start_endpoint_id = p_s_id
		end_endpoint_id = p_e_id
		start_pos = p_start
		end_pos = p_end
		width = p_width
		road_type = p_type


const ROAD_HEIGHT := 0.04
const PAINT_HEIGHT := 0.003
const SIDEWALK_HEIGHT := 0.20
const CURB_WIDTH := 0.20

var _endpoints: Dictionary = {} # int (id) -> RoadEndpoint
var _segments: Dictionary = {}  # int (id) -> RoadSegment
var _next_endpoint_id: int = 1
var _next_segment_id: int = 1
var _last_sw_offsets: Dictionary = {}

var _mesh_instance: MeshInstance3D
var _static_body: StaticBody3D


func _ready() -> void:
	_setup_nodes()


func _setup_nodes() -> void:
	if _static_body == null:
		_static_body = StaticBody3D.new()
		_static_body.name = "StaticBody"
		add_child(_static_body)

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "MeshInstance"
		_static_body.add_child(_mesh_instance)


var is_batch_updating: bool = false


func begin_batch() -> void:
	is_batch_updating = true


func end_batch() -> void:
	is_batch_updating = false
	rebuild_geometry()


func clear() -> void:
	_endpoints.clear()
	_segments.clear()
	_next_endpoint_id = 1
	_next_segment_id = 1
	if not is_batch_updating:
		rebuild_geometry()


# ==============================================================================
# GESTIÓN DE ENDPOINTS Y TRAYECTORIAS
# ==============================================================================

## Crea o reutiliza un extremo de carretera en el mundo
func add_endpoint(pos: Vector3, dir: Vector3, width: float = 8.0, road_type: RoadType = RoadType.TWO_WAY_YELLOW) -> RoadEndpoint:
	# Si ya existe un endpoint en esta misma posición (a menos de 0.25m), reutilizarlo
	for ep_item in _endpoints.values():
		var ep_ex: RoadEndpoint = ep_item
		if ep_ex.position.distance_to(pos) < 0.25:
			if dir != Vector3.ZERO:
				ep_ex.direction = Vector3(dir.x, 0.0, dir.z).normalized()
			return ep_ex

	var ep := RoadEndpoint.new(_next_endpoint_id, pos, dir, width, road_type)
	_endpoints[ep.id] = ep
	_next_endpoint_id += 1
	return ep


func get_endpoint(id: int) -> RoadEndpoint:
	return _endpoints.get(id, null)


func get_segment(id: int) -> RoadSegment:
	return _segments.get(id, null)


func get_sidewalk_offsets(seg_id: int) -> Dictionary:
	return _last_sw_offsets.get(seg_id, {
		"start_left": 0.0,
		"start_right": 0.0,
		"end_left": 0.0,
		"end_right": 0.0
	})


func get_all_endpoints() -> Array:
	return _endpoints.values()


## Modifica la dirección hacia donde se extenderá un extremo (Plano de Carretera)
func set_endpoint_direction(endpoint_id: int, new_dir: Vector3) -> void:
	var ep: RoadEndpoint = get_endpoint(endpoint_id)
	if ep != null:
		ep.direction = Vector3(new_dir.x, 0.0, new_dir.z).normalized()


## Construye un nuevo tramo de carretera extendiendo desde un endpoint a lo largo de una distancia
func extend_road(endpoint_id: int, length: float, custom_dir: Vector3 = Vector3.ZERO) -> RoadSegment:
	var start_ep: RoadEndpoint = get_endpoint(endpoint_id)
	if start_ep == null or length <= 0.5:
		return null

	var dir := start_ep.direction
	if custom_dir != Vector3.ZERO:
		dir = Vector3(custom_dir.x, 0.0, custom_dir.z).normalized()
		start_ep.direction = dir

	var end_pos := start_ep.position + dir * length
	var end_ep := add_endpoint(end_pos, dir, start_ep.width, start_ep.road_type)

	var seg := RoadSegment.new(_next_segment_id, start_ep.id, end_ep.id, start_ep.position, end_pos, start_ep.width, start_ep.road_type)
	_segments[seg.id] = seg
	_next_segment_id += 1

	if not start_ep.connected_segments.has(seg.id):
		start_ep.connected_segments.append(seg.id)
	if not end_ep.connected_segments.has(seg.id):
		end_ep.connected_segments.append(seg.id)

	rebuild_geometry()
	return seg


## Conecta dos endpoints existentes con un nuevo tramo de carretera
func connect_endpoints(start_ep_id: int, end_ep_id: int, custom_width: float = -1.0, custom_type: RoadType = RoadType.TWO_WAY_YELLOW, auto_rebuild: bool = true) -> RoadSegment:
	var start_ep: RoadEndpoint = get_endpoint(start_ep_id)
	var end_ep: RoadEndpoint = get_endpoint(end_ep_id)
	if start_ep == null or end_ep == null or start_ep_id == end_ep_id:
		return null

	var w: float = custom_width if custom_width > 0.0 else start_ep.width
	var t: RoadType = custom_type

	var seg := RoadSegment.new(_next_segment_id, start_ep.id, end_ep.id, start_ep.position, end_ep.position, w, t)
	_segments[seg.id] = seg
	_next_segment_id += 1

	if not start_ep.connected_segments.has(seg.id):
		start_ep.connected_segments.append(seg.id)
	if not end_ep.connected_segments.has(seg.id):
		end_ep.connected_segments.append(seg.id)

	if auto_rebuild:
		rebuild_geometry()
	return seg


## Agrega o quita banqueta en el lado izquierdo o derecho de un tramo
func toggle_sidewalk(segment_id: int, is_left_side: bool, sidewalk_width: float = 2.5) -> bool:
	var seg: RoadSegment = _segments.get(segment_id, null)
	if seg == null:
		return false

	if is_left_side:
		seg.has_left_sidewalk = not seg.has_left_sidewalk
		seg.left_sidewalk_width = sidewalk_width
	else:
		seg.has_right_sidewalk = not seg.has_right_sidewalk
		seg.right_sidewalk_width = sidewalk_width

	rebuild_geometry()
	return seg.has_left_sidewalk if is_left_side else seg.has_right_sidewalk


## Asigna explícitamente el estado de la banqueta sin conmutar a ciegas
func set_sidewalk(segment_id: int, is_left_side: bool, enabled: bool, sidewalk_width: float = 2.5, auto_rebuild: bool = true) -> void:
	var seg: RoadSegment = _segments.get(segment_id, null)
	if seg == null:
		return

	if is_left_side:
		seg.has_left_sidewalk = enabled
		seg.left_sidewalk_width = sidewalk_width
	else:
		seg.has_right_sidewalk = enabled
		seg.right_sidewalk_width = sidewalk_width

	if auto_rebuild:
		rebuild_geometry()


func get_all_segments() -> Array:
	return _segments.values()


# ==============================================================================
# GENERACIÓN GEOMÉTRICA CONTINUA (INSTANT BOX & RIBBON MESH)
# ==============================================================================

func rebuild_geometry() -> void:
	if is_batch_updating:
		return
	_setup_nodes()

	# Limpiar colisiones previas
	for child in _static_body.get_children():
		if child is CollisionShape3D:
			child.queue_free()

	if _segments.is_empty():
		_mesh_instance.mesh = null
		return

	# Almacenes de geometría agrupados por material
	var geom_data: Dictionary = {} # material_key -> { "vertices": PackedVector3Array, "normals": PackedVector3Array, "uvs": PackedVector2Array, "indices": PackedInt32Array }
	for mat_key in ProceduralRoadMaterials.get_all_material_keys():
		geom_data[mat_key] = {
			"vertices": PackedVector3Array(),
			"normals": PackedVector3Array(),
			"uvs": PackedVector2Array(),
			"indices": PackedInt32Array(),
			"index_offset": 0
		}

	# 1. Precalcular recortes de banqueta en cruces para evitar que invadan calzadas
	# Estructura: seg_id -> { "start_left": float, "start_right": float, "end_left": float, "end_right": float }
	var sw_offsets: Dictionary = {}
	for seg_id in _segments:
		sw_offsets[seg_id] = {
			"start_left": 0.0,
			"start_right": 0.0,
			"end_left": 0.0,
			"end_right": 0.0
		}

	var corner_joins: Array = []

	for ep_item in _endpoints.values():
		var ep: RoadEndpoint = ep_item
		var connected_list: Array[RoadSegment] = []
		for seg_item in _segments.values():
			var s: RoadSegment = seg_item
			if s.start_pos.distance_to(ep.position) < 0.25 or s.end_pos.distance_to(ep.position) < 0.25:
				if not connected_list.has(s):
					connected_list.append(s)

		if connected_list.size() < 2:
			continue

		# Ramas ordenadas cíclicamente alrededor del endpoint
		var branches := []
		for s in connected_list:
			var is_start := s.start_pos.distance_to(ep.position) < 0.25
			var u: Vector3 = (s.end_pos - s.start_pos).normalized() if is_start else (s.start_pos - s.end_pos).normalized()
			var angle := atan2(u.x, -u.z)
			branches.append({
				"seg": s,
				"u": u,
				"angle": angle,
				"is_start": is_start
			})

		branches.sort_custom(func(a, b): return a["angle"] < b["angle"])
		var branch_count := branches.size()

		for i in range(branch_count):
			var bA = branches[i]
			var bB = branches[(i + 1) % branch_count]
			var segA: RoadSegment = bA["seg"]
			var segB: RoadSegment = bB["seg"]
			var uA: Vector3 = bA["u"]
			var uB: Vector3 = bB["u"]

			# Continuación colineal recta (~180°)
			if uA.dot(uB) < -0.995:
				continue

			var rA := Vector3(-uA.z, 0.0, uA.x).normalized()
			var lB := Vector3(uB.z, 0.0, -uB.x).normalized()

			var has_sw_A: bool = segA.has_right_sidewalk if bA["is_start"] else segA.has_left_sidewalk
			var sw_w_A: float = segA.right_sidewalk_width if bA["is_start"] else segA.left_sidewalk_width

			var has_sw_B: bool = segB.has_left_sidewalk if bB["is_start"] else segB.has_right_sidewalk
			var sw_w_B: float = segB.left_sidewalk_width if bB["is_start"] else segB.right_sidewalk_width

			var half_w_A := segA.width * 0.5
			var half_w_B := segB.width * 0.5
			var K_A0 := ep.position + rA * half_w_A
			var K_B0 := ep.position + lB * half_w_B

			var res_road := _intersect_2d_lines(K_A0, uA, K_B0, uB)
			var M_road: Vector3 = res_road["point"] if res_road["valid"] else (K_A0 + K_B0) * 0.5

			var segA_len: float = (segA.end_pos - segA.start_pos).length()
			var segB_len: float = (segB.end_pos - segB.start_pos).length()
			var max_ext := maxf(half_w_A, half_w_B) * 3.0
			var t_road_A: float = clampf((M_road - ep.position).dot(uA), -max_ext, segA_len)
			var t_road_B: float = clampf((M_road - ep.position).dot(uB), -max_ext, segB_len)

			var is_acute_fork: bool = uA.dot(uB) > 0.35
			var is_reflex: bool = t_road_A < -0.01
			var t_sw_A := t_road_A
			var t_sw_B := t_road_B
			var M_curb := M_road
			var M_outer := M_road

			if has_sw_A or has_sw_B:
				var eff_sw_A := sw_w_A if has_sw_A else sw_w_B
				var eff_sw_B := sw_w_B if has_sw_B else sw_w_A
				var C_A0 := ep.position + rA * (half_w_A + CURB_WIDTH)
				var C_B0 := ep.position + lB * (half_w_B + CURB_WIDTH)
				var res_curb := _intersect_2d_lines(C_A0, uA, C_B0, uB)
				M_curb = res_curb["point"] if res_curb["valid"] else (C_A0 + C_B0) * 0.5

				var O_A0 := ep.position + rA * (half_w_A + eff_sw_A)
				var O_B0 := ep.position + lB * (half_w_B + eff_sw_B)
				var res_outer := _intersect_2d_lines(O_A0, uA, O_B0, uB)
				M_outer = res_outer["point"] if res_outer["valid"] else (O_A0 + O_B0) * 0.5

				if not is_reflex:
					# Limitar distancia de inglete si el ángulo es sumamente agudo
					var max_dist := (maxf(half_w_A, half_w_B) + maxf(eff_sw_A, eff_sw_B)) * 3.0
					if M_outer.distance_to(ep.position) > max_dist:
						var bis := (rA + lB).normalized()
						M_outer = ep.position + bis * max_dist
						M_curb = ep.position + bis * (max_dist * 0.85)

					if has_sw_A and has_sw_B:
						t_sw_A = clampf((M_outer - ep.position).dot(uA), t_road_A, segA_len)
						t_sw_B = clampf((M_outer - ep.position).dot(uB), t_road_B, segB_len)
					elif has_sw_A and not has_sw_B:
						var res_AB := _intersect_2d_lines(O_A0, uA, K_B0, uB)
						var t_clear: float = (res_AB["point"] - ep.position).dot(uA) if res_AB["valid"] else t_road_A
						t_sw_A = clampf(maxf(t_clear, t_road_A), 0.0, segA_len)
					elif not has_sw_A and has_sw_B:
						var res_BA := _intersect_2d_lines(K_A0, uA, O_B0, uB)
						var t_clear: float = (res_BA["point"] - ep.position).dot(uB) if res_BA["valid"] else t_road_B
						t_sw_B = clampf(maxf(t_clear, t_road_B), 0.0, segB_len)
				else:
					# Esquina refleja (exterior): la banqueta recta termina exactamente en t_road
					t_sw_A = t_road_A
					t_sw_B = t_road_B

			# Asignar recortes precisos a los tramos de banqueta para que jamás invadan calzadas
			# En esquinas reflejas (t_sw < 0), la losa se extiende hacia afuera para sellar perfectamente con M_road
			if bA["is_start"]:
				sw_offsets[segA.id]["start_right"] = t_sw_A if sw_offsets[segA.id]["start_right"] == 0.0 else maxf(sw_offsets[segA.id]["start_right"], t_sw_A)
			else:
				sw_offsets[segA.id]["end_left"] = t_sw_A if sw_offsets[segA.id]["end_left"] == 0.0 else maxf(sw_offsets[segA.id]["end_left"], t_sw_A)

			if bB["is_start"]:
				sw_offsets[segB.id]["start_left"] = t_sw_B if sw_offsets[segB.id]["start_left"] == 0.0 else maxf(sw_offsets[segB.id]["start_left"], t_sw_B)
			else:
				sw_offsets[segB.id]["end_right"] = t_sw_B if sw_offsets[segB.id]["end_right"] == 0.0 else maxf(sw_offsets[segB.id]["end_right"], t_sw_B)

			corner_joins.append({
				"E": ep.position,
				"uA": uA, "uB": uB,
				"rA": rA, "lB": lB,
				"K_A0": K_A0, "K_B0": K_B0,
				"segA": segA, "segB": segB,
				"bA": bA, "bB": bB,
				"has_sw_A": has_sw_A, "has_sw_B": has_sw_B,
				"sw_w_A": sw_w_A, "sw_w_B": sw_w_B,
				"half_w_A": half_w_A, "half_w_B": half_w_B,
				"t_road_A": t_road_A, "t_road_B": t_road_B,
				"t_sw_A": t_sw_A, "t_sw_B": t_sw_B,
				"is_acute_fork": is_acute_fork,
				"is_reflex": is_reflex,
				"M_road": M_road,
				"M_curb": M_curb,
				"M_outer": M_outer
			})

		# Colisión física del cruce (cilindro en el centro de la intersección)
		var col_junc := CollisionShape3D.new()
		col_junc.name = "Col_Junction_%d" % ep.id
		var cyl := CylinderShape3D.new()
		cyl.radius = maxf(ep.width * 0.6, 5.0)
		cyl.height = 0.30
		col_junc.shape = cyl
		col_junc.position = ep.position + Vector3(0.0, 0.10, 0.0)
		_static_body.add_child(col_junc)

	_last_sw_offsets = sw_offsets

	var col_index := 0

	# 2. Construcción geométrica de los tramos rectos
	for seg_id in _segments:
		var seg: RoadSegment = _segments[seg_id]
		var p0 := seg.start_pos
		var p1 := seg.end_pos
		var delta := p1 - p0
		var length := delta.length()
		if length <= 0.01:
			continue

		var fwd := delta / length
		var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
		var half_w := seg.width * 0.5

		# A. Cinta de Asfalto
		var c0 := p0 - right * half_w # Inicio Izquierda
		var c1 := p0 + right * half_w # Inicio Derecha
		var c2 := p1 + right * half_w # Fin Derecha
		var c3 := p1 - right * half_w # Fin Izquierda

		_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_ASPHALT], c0, c1, c2, c3, 0.0, ROAD_HEIGHT)

		# B. Señalización vial central
		if seg.road_type == RoadType.TWO_WAY_YELLOW:
			var stripe_w := 0.14
			var y_paint := ROAD_HEIGHT + PAINT_HEIGHT
			var s0_l := p0 - right * (stripe_w * 1.5)
			var s1_l := p0 - right * (stripe_w * 0.5)
			var s2_l := p1 - right * (stripe_w * 0.5)
			var s3_l := p1 - right * (stripe_w * 1.5)
			_append_quad(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_l, s1_l, s2_l, s3_l, y_paint, Vector3.UP)

			var s0_r := p0 + right * (stripe_w * 0.5)
			var s1_r := p0 + right * (stripe_w * 1.5)
			var s2_r := p1 + right * (stripe_w * 1.5)
			var s3_r := p1 + right * (stripe_w * 0.5)
			_append_quad(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_r, s1_r, s2_r, s3_r, y_paint, Vector3.UP)
		elif seg.road_type == RoadType.AVENUE_WHITE:
			var lane_w := seg.width / 3.0
			var y_paint := ROAD_HEIGHT + PAINT_HEIGHT
			var stripe_w := 0.12
			for lane_idx in [-1, 1]:
				var center_offset := float(lane_idx) * (lane_w * 0.5)
				_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p0 + right * center_offset, p1 + right * center_offset, right, stripe_w, y_paint)

		# C. Banqueta Paralela Izquierda (recortada antes del cruce)
		if seg.has_left_sidewalk:
			var sw := seg.left_sidewalk_width
			var curb := CURB_WIDTH
			var t_start: float = sw_offsets[seg.id]["start_left"]
			var t_end: float = sw_offsets[seg.id]["end_left"]
			var sw_len := length - t_start - t_end
			if sw_len > 0.1:
				var sp0 := p0 + fwd * t_start
				var sp1 := p1 - fwd * t_end
				var skb0 := sp0 - right * half_w
				var skb1 := sp0 - right * (half_w + curb)
				var skb2 := sp1 - right * (half_w + curb)
				var skb3 := sp1 - right * half_w
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_CURB], skb1, skb0, skb3, skb2, 0.0, SIDEWALK_HEIGHT)

				var ssw0 := skb1
				var ssw1 := sp0 - right * (half_w + sw)
				var ssw2 := sp1 - right * (half_w + sw)
				var ssw3 := skb2
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], ssw1, ssw0, ssw3, ssw2, 0.0, SIDEWALK_HEIGHT)

		# D. Banqueta Paralela Derecha (recortada antes del cruce)
		if seg.has_right_sidewalk:
			var sw := seg.right_sidewalk_width
			var curb := CURB_WIDTH
			var t_start: float = sw_offsets[seg.id]["start_right"]
			var t_end: float = sw_offsets[seg.id]["end_right"]
			var sw_len := length - t_start - t_end
			if sw_len > 0.1:
				var sp0 := p0 + fwd * t_start
				var sp1 := p1 - fwd * t_end
				var skb0 := sp0 + right * half_w
				var skb1 := sp0 + right * (half_w + curb)
				var skb2 := sp1 + right * (half_w + curb)
				var skb3 := sp1 + right * half_w
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_CURB], skb0, skb1, skb2, skb3, 0.0, SIDEWALK_HEIGHT)

				var ssw0 := skb1
				var ssw1 := sp0 + right * (half_w + sw)
				var ssw2 := sp1 + right * (half_w + sw)
				var ssw3 := skb2
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], ssw0, ssw1, ssw2, ssw3, 0.0, SIDEWALK_HEIGHT)

		# E. Colisión física del tramo recto
		var col := CollisionShape3D.new()
		col.name = "Col_Road_%d" % col_index
		var box_shape := BoxShape3D.new()
		var total_width := seg.width + (seg.left_sidewalk_width if seg.has_left_sidewalk else 0.0) + (seg.right_sidewalk_width if seg.has_right_sidewalk else 0.0)
		var center_shift := ((seg.right_sidewalk_width if seg.has_right_sidewalk else 0.0) - (seg.left_sidewalk_width if seg.has_left_sidewalk else 0.0)) * 0.5
		box_shape.size = Vector3(total_width, 0.30, length)
		col.shape = box_shape

		var mid_pos := (p0 + p1) * 0.5 + right * center_shift + Vector3(0.0, 0.10, 0.0)
		var seg_basis := Basis.looking_at(fwd, Vector3.UP)
		col.transform = Transform3D(seg_basis, mid_pos)
		_static_body.add_child(col)
		col_index += 1

	# 3. Construcción de uniones de esquina inteligentes
	for cj in corner_joins:
		var E: Vector3 = cj["E"]
		var uA: Vector3 = cj["uA"]
		var uB: Vector3 = cj["uB"]
		var rA: Vector3 = cj["rA"]
		var lB: Vector3 = cj["lB"]
		var K_A0: Vector3 = cj["K_A0"]
		var K_B0: Vector3 = cj["K_B0"]
		var M_road: Vector3 = cj["M_road"]
		var is_acute_fork: bool = cj["is_acute_fork"]

		# Relleno de asfalto en la cuña de la intersección entre las calzadas rectas
		_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_ASPHALT], E, K_A0, M_road, ROAD_HEIGHT)
		_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_ASPHALT], E, M_road, K_B0, ROAD_HEIGHT)

		if cj["has_sw_A"] and cj["has_sw_B"]:
			var M_curb: Vector3 = cj["M_curb"]
			var M_outer: Vector3 = cj["M_outer"]

			if not cj.get("is_reflex", false):
				var P_road_A: Vector3 = E + uA * cj["t_sw_A"] + rA * cj["half_w_A"]
				var P_curb_A: Vector3 = E + uA * cj["t_sw_A"] + rA * (cj["half_w_A"] + CURB_WIDTH)
				var P_outer_A: Vector3 = E + uA * cj["t_sw_A"] + rA * (cj["half_w_A"] + cj["sw_w_A"])

				var P_road_B: Vector3 = E + uB * cj["t_sw_B"] + lB * cj["half_w_B"]
				var P_curb_B: Vector3 = E + uB * cj["t_sw_B"] + lB * (cj["half_w_B"] + CURB_WIDTH)
				var P_outer_B: Vector3 = E + uB * cj["t_sw_B"] + lB * (cj["half_w_B"] + cj["sw_w_B"])

				# Bordillos verticales mirando a la calle desde el vértice común M_road
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], P_road_A, M_road, 0.0, SIDEWALK_HEIGHT)
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_road_B, 0.0, SIDEWALK_HEIGHT)

				# Tapa horizontal superior del bordillo
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_road_A, P_curb_A, M_curb, SIDEWALK_HEIGHT)
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, M_curb, P_curb_B, P_road_B, SIDEWALK_HEIGHT)

				# Losa de concreto superior de la isleta divisoria
				if P_outer_A.distance_squared_to(P_outer_B) < 0.01:
					_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, P_curb_A, M_outer, SIDEWALK_HEIGHT)
					_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, M_outer, P_curb_B, SIDEWALK_HEIGHT)
				else:
					_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, P_curb_A, P_outer_A, SIDEWALK_HEIGHT)
					_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, P_outer_A, P_outer_B, P_curb_B, SIDEWALK_HEIGHT)
					_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_outer_A, P_outer_B, 0.0, SIDEWALK_HEIGHT)
			else:
				# ESQUINA OBTUSA / GIRO DE CALLE:
				# Las banquetas rectas terminan en t_road_A y t_road_B.
				# En ese punto, el borde de asfalto de ambas vías converge en M_road.
				var P_curb_A: Vector3 = E + uA * cj["t_road_A"] + rA * (cj["half_w_A"] + CURB_WIDTH)
				var P_outer_A: Vector3 = E + uA * cj["t_road_A"] + rA * (cj["half_w_A"] + cj["sw_w_A"])

				var P_curb_B: Vector3 = E + uB * cj["t_road_B"] + lB * (cj["half_w_B"] + CURB_WIDTH)
				var P_outer_B: Vector3 = E + uB * cj["t_road_B"] + lB * (cj["half_w_B"] + cj["sw_w_B"])

				# Tapa de bordillo en la esquina
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_curb_A, M_curb, SIDEWALK_HEIGHT)
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, M_curb, P_curb_B, SIDEWALK_HEIGHT)

				# Losa de concreto superior de la banqueta envolviendo la esquina
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, P_curb_A, P_outer_A, M_outer, SIDEWALK_HEIGHT)
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_curb, M_outer, P_outer_B, P_curb_B, SIDEWALK_HEIGHT)

				# Caras exteriores verticales de la banqueta hacia el terreno
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_outer_A, M_outer, 0.0, SIDEWALK_HEIGHT)
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], M_outer, P_outer_B, 0.0, SIDEWALK_HEIGHT)

		elif cj["has_sw_A"] and not cj["has_sw_B"]:
			if not is_acute_fork:
				var P_curb_A: Vector3 = E + uA * cj["t_road_A"] + rA * (cj["half_w_A"] + CURB_WIDTH)
				var P_outer_A: Vector3 = E + uA * cj["t_road_A"] + rA * (cj["half_w_A"] + cj["sw_w_A"])

				var res_outer := _intersect_2d_lines(E + rA * (cj["half_w_A"] + cj["sw_w_A"]), uA, K_B0, uB)
				var P_B_outer: Vector3 = res_outer["point"] if res_outer["valid"] else P_outer_A
				var res_curb := _intersect_2d_lines(E + rA * (cj["half_w_A"] + CURB_WIDTH), uA, K_B0, uB)
				var P_B_curb: Vector3 = res_curb["point"] if res_curb["valid"] else (M_road + P_B_outer) * 0.5

				# 1. Bordillo vertical hacia el asfalto de la Vía B desde el vértice de la esquina
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_B_outer, 0.0, SIDEWALK_HEIGHT)

				# 2. Tapa de bordillo en la esquina
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_curb_A, P_B_curb, SIDEWALK_HEIGHT)

				# 3. Losa de concreto sellando hasta el borde de la Vía B
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_B_curb, P_curb_A, P_outer_A, P_B_outer, SIDEWALK_HEIGHT)

				# 4. Cara exterior hacia el terreno
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_outer_A, P_B_outer, 0.0, SIDEWALK_HEIGHT)
			else:
				var P_road_A: Vector3 = E + uA * cj["t_sw_A"] + rA * cj["half_w_A"]
				var P_curb_A: Vector3 = E + uA * cj["t_sw_A"] + rA * (cj["half_w_A"] + CURB_WIDTH)
				var P_outer_A: Vector3 = E + uA * cj["t_sw_A"] + rA * (cj["half_w_A"] + cj["sw_w_A"])

				# Punto donde la línea de bordillo de la Vía A interseca el borde de asfalto de la Vía B
				var res_curb := _intersect_2d_lines(K_A0 + rA * CURB_WIDTH, uA, K_B0, uB)
				var P_B_curb: Vector3 = res_curb["point"] if res_curb["valid"] else (M_road + P_outer_A) * 0.5

				# 1. Bordillo vertical hacia el asfalto de la Vía A
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], P_road_A, M_road, 0.0, SIDEWALK_HEIGHT)
				# 2. Bordillo vertical hacia el asfalto de la Vía B
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_outer_A, 0.0, SIDEWALK_HEIGHT)
				# 3. Tapa superior del bordillo
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_road_A, P_curb_A, P_B_curb, SIDEWALK_HEIGHT)
				# 4. Losa de concreto de la banqueta
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_B_curb, P_curb_A, P_outer_A, SIDEWALK_HEIGHT)
		elif not cj["has_sw_A"] and cj["has_sw_B"]:
			if not is_acute_fork:
				var P_curb_B: Vector3 = E + uB * cj["t_road_B"] + lB * (cj["half_w_B"] + CURB_WIDTH)
				var P_outer_B: Vector3 = E + uB * cj["t_road_B"] + lB * (cj["half_w_B"] + cj["sw_w_B"])

				var res_outer := _intersect_2d_lines(K_A0, uA, E + lB * (cj["half_w_B"] + cj["sw_w_B"]), uB)
				var P_A_outer: Vector3 = res_outer["point"] if res_outer["valid"] else P_outer_B
				var res_curb := _intersect_2d_lines(K_A0, uA, E + lB * (cj["half_w_B"] + CURB_WIDTH), uB)
				var P_A_curb: Vector3 = res_curb["point"] if res_curb["valid"] else (M_road + P_A_outer) * 0.5

				# 1. Bordillo vertical hacia el asfalto de la Vía A desde el vértice de la esquina
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], P_A_outer, M_road, 0.0, SIDEWALK_HEIGHT)

				# 2. Tapa de bordillo en la esquina
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_A_curb, P_curb_B, SIDEWALK_HEIGHT)

				# 3. Losa de concreto sellando hasta el borde de la Vía A
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_A_curb, P_A_outer, P_outer_B, P_curb_B, SIDEWALK_HEIGHT)

				# 4. Cara exterior hacia el terreno
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_outer_B, P_A_outer, 0.0, SIDEWALK_HEIGHT)
			else:
				var P_road_B: Vector3 = E + uB * cj["t_sw_B"] + lB * cj["half_w_B"]
				var P_curb_B: Vector3 = E + uB * cj["t_sw_B"] + lB * (cj["half_w_B"] + CURB_WIDTH)
				var P_outer_B: Vector3 = E + uB * cj["t_sw_B"] + lB * (cj["half_w_B"] + cj["sw_w_B"])

				# Punto donde la línea de bordillo de la Vía B interseca el borde de asfalto de la Vía A
				var res_curb := _intersect_2d_lines(K_A0, uA, K_B0 + lB * CURB_WIDTH, uB)
				var P_A_curb: Vector3 = res_curb["point"] if res_curb["valid"] else (M_road + P_outer_B) * 0.5

				# 1. Bordillo vertical hacia el asfalto de la Vía B
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_road_B, 0.0, SIDEWALK_HEIGHT)
				# 2. Bordillo vertical hacia el asfalto de la Vía A
				_append_vertical_strip(geom_data[ProceduralRoadMaterials.KEY_CURB], P_outer_B, M_road, 0.0, SIDEWALK_HEIGHT)
				# 3. Tapa superior del bordillo
				_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_CURB], M_road, P_A_curb, P_curb_B, P_road_B, SIDEWALK_HEIGHT)
				# 4. Losa de concreto de la banqueta
				_append_triangle_top(geom_data[ProceduralRoadMaterials.KEY_SIDEWALK], P_A_curb, P_outer_B, P_curb_B, SIDEWALK_HEIGHT)

	# Construir ArrayMesh unificado
	var mesh := ArrayMesh.new()
	for mat_key in geom_data:
		var data: Dictionary = geom_data[mat_key]
		var verts: PackedVector3Array = data["vertices"]
		if verts.is_empty():
			continue

		var surface_arrays := []
		surface_arrays.resize(Mesh.ARRAY_MAX)
		surface_arrays[Mesh.ARRAY_VERTEX] = verts
		surface_arrays[Mesh.ARRAY_NORMAL] = data["normals"]
		surface_arrays[Mesh.ARRAY_TEX_UV] = data["uvs"]
		surface_arrays[Mesh.ARRAY_INDEX] = data["indices"]

		var surf_idx := mesh.get_surface_count()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)
		mesh.surface_set_material(surf_idx, ProceduralRoadMaterials.get_material(mat_key))

	_mesh_instance.mesh = mesh


# ==============================================================================
# AUXILIARES MATEMÁTICOS DE GEOMETRÍA ORIENTADA
# ==============================================================================

static func _intersect_2d_lines(p1: Vector3, d1: Vector3, p2: Vector3, d2: Vector3) -> Dictionary:
	var det := d1.z * d2.x - d1.x * d2.z
	if absf(det) < 0.001:
		return {"valid": false, "point": (p1 + p2) * 0.5}
	var diff := p2 - p1
	var t1 := (-diff.x * d2.z + diff.z * d2.x) / det
	return {"valid": true, "point": p1 + d1 * t1}


static func _append_vertical_strip(
	data: Dictionary,
	p0: Vector3, p1: Vector3,
	y_min: float, y_max: float
) -> void:
	var delta := p1 - p0
	if delta.length_squared() < 0.0001:
		return
	var dir := delta.normalized()
	var normal := Vector3(-dir.z, 0.0, dir.x)
	var v0 := Vector3(p0.x, y_min, p0.z)
	var v1 := Vector3(p1.x, y_min, p1.z)
	var v2 := Vector3(p1.x, y_max, p1.z)
	var v3 := Vector3(p0.x, y_max, p0.z)
	_append_quad_3d(data, v0, v1, v2, v3, normal)


static func _append_triangle(
	data: Dictionary,
	v0: Vector3, v1: Vector3, v2: Vector3,
	y_pos: float, normal: Vector3
) -> void:
	var base: int = data["index_offset"]
	var verts: PackedVector3Array = data["vertices"]
	var norms: PackedVector3Array = data["normals"]
	var uvs: PackedVector2Array = data["uvs"]
	var indices: PackedInt32Array = data["indices"]

	verts.append(Vector3(v0.x, y_pos, v0.z))
	verts.append(Vector3(v1.x, y_pos, v1.z))
	verts.append(Vector3(v2.x, y_pos, v2.z))

	norms.append(normal)
	norms.append(normal)
	norms.append(normal)

	uvs.append(Vector2(v0.x, v0.z))
	uvs.append(Vector2(v1.x, v1.z))
	uvs.append(Vector2(v2.x, v2.z))

	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)

	data["index_offset"] = base + 3


static func _append_quad_top(
	data: Dictionary,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	y_pos: float
) -> void:
	var cp := (v1 - v0).cross(v2 - v0)
	if cp.length_squared() < 0.0001:
		cp = (v2 - v0).cross(v3 - v0)
		if cp.length_squared() < 0.0001:
			return
	if cp.y < 0.0:
		_append_quad(data, v0, v3, v2, v1, y_pos, Vector3.UP)
	else:
		_append_quad(data, v0, v1, v2, v3, y_pos, Vector3.UP)


static func _append_triangle_top(
	data: Dictionary,
	v0: Vector3, v1: Vector3, v2: Vector3,
	y_pos: float
) -> void:
	var cp := (v1 - v0).cross(v2 - v0)
	if cp.length_squared() < 0.0001:
		return
	if cp.y < 0.0:
		_append_triangle(data, v0, v2, v1, y_pos, Vector3.UP)
	else:
		_append_triangle(data, v0, v1, v2, y_pos, Vector3.UP)


static func _append_oriented_slab(
	data: Dictionary,
	c0: Vector3, c1: Vector3, c2: Vector3, c3: Vector3,
	y_min: float, y_max: float
) -> void:
	# 6 Caras orientadas: Top, Bottom, Inicio (c0-c1), Fin (c2-c3), Lado 1 (c0-c3), Lado 2 (c1-c2)
	# Top
	_append_quad_top(data, Vector3(c0.x, y_max, c0.z), Vector3(c1.x, y_max, c1.z), Vector3(c2.x, y_max, c2.z), Vector3(c3.x, y_max, c3.z), y_max)
	# Bottom
	_append_quad(data, Vector3(c3.x, y_min, c3.z), Vector3(c2.x, y_min, c2.z), Vector3(c1.x, y_min, c1.z), Vector3(c0.x, y_min, c0.z), y_min, Vector3.DOWN)

	# Cara frontal (Inicio c0 -> c1)
	var fwd_n := ((c1 - c0).cross(Vector3.UP)).normalized()
	_append_quad_3d(data,
		Vector3(c1.x, y_min, c1.z), Vector3(c0.x, y_min, c0.z),
		Vector3(c0.x, y_max, c0.z), Vector3(c1.x, y_max, c1.z),
		fwd_n
	)
	# Cara trasera (Fin c2 -> c3)
	_append_quad_3d(data,
		Vector3(c3.x, y_min, c3.z), Vector3(c2.x, y_min, c2.z),
		Vector3(c2.x, y_max, c2.z), Vector3(c3.x, y_max, c3.z),
		-fwd_n
	)
	# Cara lateral Izquierda (c0 -> c3)
	var left_n := ((c3 - c0).cross(Vector3.UP)).normalized()
	_append_quad_3d(data,
		Vector3(c0.x, y_min, c0.z), Vector3(c3.x, y_min, c3.z),
		Vector3(c3.x, y_max, c3.z), Vector3(c0.x, y_max, c0.z),
		left_n
	)
	# Cara lateral Derecha (c1 -> c2)
	_append_quad_3d(data,
		Vector3(c2.x, y_min, c2.z), Vector3(c1.x, y_min, c1.z),
		Vector3(c1.x, y_max, c1.z), Vector3(c2.x, y_max, c2.z),
		-left_n
	)


static func _append_quad(
	data: Dictionary,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	y_pos: float, normal: Vector3
) -> void:
	var base: int = data["index_offset"]
	var verts: PackedVector3Array = data["vertices"]
	var norms: PackedVector3Array = data["normals"]
	var uvs: PackedVector2Array = data["uvs"]
	var indices: PackedInt32Array = data["indices"]

	var p0 := Vector3(v0.x, y_pos, v0.z)
	var p1 := Vector3(v1.x, y_pos, v1.z)
	var p2 := Vector3(v2.x, y_pos, v2.z)
	var p3 := Vector3(v3.x, y_pos, v3.z)

	verts.append(p0)
	verts.append(p1)
	verts.append(p2)
	verts.append(p3)

	norms.append(normal)
	norms.append(normal)
	norms.append(normal)
	norms.append(normal)

	uvs.append(Vector2(v0.x, v0.z))
	uvs.append(Vector2(v1.x, v1.z))
	uvs.append(Vector2(v2.x, v2.z))
	uvs.append(Vector2(v3.x, v3.z))

	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base + 0)
	indices.append(base + 2)
	indices.append(base + 3)

	data["index_offset"] = base + 4


static func _append_quad_3d(
	data: Dictionary,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	normal: Vector3
) -> void:
	var base: int = data["index_offset"]
	var verts: PackedVector3Array = data["vertices"]
	var norms: PackedVector3Array = data["normals"]
	var uvs: PackedVector2Array = data["uvs"]
	var indices: PackedInt32Array = data["indices"]

	verts.append(v0)
	verts.append(v1)
	verts.append(v2)
	verts.append(v3)

	norms.append(normal)
	norms.append(normal)
	norms.append(normal)
	norms.append(normal)

	uvs.append(Vector2(v0.x + v0.z, v0.y))
	uvs.append(Vector2(v1.x + v1.z, v1.y))
	uvs.append(Vector2(v2.x + v2.z, v2.y))
	uvs.append(Vector2(v3.x + v3.z, v3.y))

	indices.append(base + 0)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base + 0)
	indices.append(base + 2)
	indices.append(base + 3)

	data["index_offset"] = base + 4


static func _append_dashed_line(
	data: Dictionary,
	start: Vector3, end: Vector3,
	right: Vector3, width: float, y_pos: float
) -> void:
	var delta := end - start
	var total_len := delta.length()
	if total_len <= 0.5:
		return
	var dir := delta / total_len
	var half_w := width * 0.5

	var dash_len := 1.5
	var gap_len := 1.5
	var period := dash_len + gap_len

	var cur := 0.0
	while cur + dash_len <= total_len:
		var p0 := start + dir * cur
		var p1 := start + dir * (cur + dash_len)
		var v0 := p0 - right * half_w
		var v1 := p0 + right * half_w
		var v2 := p1 + right * half_w
		var v3 := p1 - right * half_w
		_append_quad(data, Vector3(v0.x, y_pos, v0.z), Vector3(v1.x, y_pos, v1.z), Vector3(v2.x, y_pos, v2.z), Vector3(v3.x, y_pos, v3.z), y_pos, Vector3.UP)
		cur += period

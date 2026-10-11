class_name RoadTrajectorySystem
extends Node3D
## Sistema de Carreteras Continuas por Trayectorias y Banquetas Paralelas Independientes.
## Las carreteras se generan a lo largo de vectores directores (endpoints) y las banquetas
## son cintas paralelas elevadas que se aplican a las orillas que el usuario decida.

const ProceduralRoadMaterials = preload("res://world/city/procedural_road_materials.gd")
const PROCEDURAL_TREE_SCRIPT = preload("res://world/procedural_trees/procedural_tree.gd")

## Anchos métricos estándar de carril según jerarquía y contexto vial
const LANE_WIDTH_RESIDENTIAL: float = 3.25   # Calles de colonia, residenciales y privadas
const LANE_WIDTH_AVENUE: float = 4.00        # Avenidas primarias, bulevares y vías comerciales
const LANE_WIDTH_HIGHWAY: float = 4.00       # Carreteras interurbanas e internacionales
const STANDARD_LANE_WIDTH: float = LANE_WIDTH_RESIDENTIAL

enum RoadType {
	TWO_WAY_2LANE,        # Calle estándar de 2 sentidos (1 por sentido, doble amarilla central)
	AVENUE_ONEWAY_2LANE,  # Calzada de avenida unidireccional de 2 carriles (1 línea blanca discontinua)
	AVENUE_ONEWAY_3LANE,  # Calzada de avenida unidireccional de 3 carriles (2 líneas blancas discontinuas)
	COMMERCIAL_4LANE,     # Avenida comercial de 4 carriles (2 por sentido, doble amarilla central + líneas blancas)
	RURAL_PLAIN_2LANE,    # Carretera rural de 2 carriles sin pintar
	ALLEY_1LANE,          # Callejón / Privada de 1 solo carril (sin línea central)
	DIVIDED_MEDIAN_3LANE, # Calle de 3 carriles por sentido (6 carriles total) con camellón central de 2.0m
	# Aliases retrocompatibles
	TWO_WAY_YELLOW = TWO_WAY_2LANE,
	AVENUE_WHITE = AVENUE_ONEWAY_3LANE,
	RURAL_PLAIN = RURAL_PLAIN_2LANE,
}

## Constantes métricas para calle dividida de 3 carriles por sentido con camellón central de 2.0m
const LANE_WIDTH_DIVIDED_3LANE: float = 3.50         # Ancho de cada carril (3.50m)
const LANES_PER_WAY_DIVIDED_3LANE: int = 3           # 3 carriles en cada calzada / sentido
const ROADWAY_WIDTH_DIVIDED_3LANE: float = 10.50     # 3 * 3.50m = 10.50m por calzada
const MEDIAN_WIDTH_DIVIDED_3LANE: float = 2.00       # Separador central elevado de 2.00m
const STANDARD_WIDTH_DIVIDED_3LANE: float = 23.00    # 10.50m + 2.00m + 10.50m = 23.00m total

static func get_lane_count_for_type(type: RoadType) -> int:
	match type:
		RoadType.ALLEY_1LANE:
			return 1
		RoadType.AVENUE_ONEWAY_2LANE:
			return 2
		RoadType.AVENUE_ONEWAY_3LANE:
			return 3
		RoadType.DIVIDED_MEDIAN_3LANE:
			return 6
		RoadType.COMMERCIAL_4LANE:
			return 4
		RoadType.RURAL_PLAIN_2LANE:
			return 2
		_:
			return 2


static func get_standard_width_for_type(type: RoadType) -> float:
	if type == RoadType.DIVIDED_MEDIAN_3LANE:
		return STANDARD_WIDTH_DIVIDED_3LANE
	return float(get_lane_count_for_type(type)) * STANDARD_LANE_WIDTH


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
const PAINT_HEIGHT := 0.007
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


## Asigna explícitamente ambas banquetas (izquierda y derecha) en una sola llamada
func set_both_sidewalks(segment_id: int, enabled_left: bool, enabled_right: bool, sidewalk_width: float = 2.5, auto_rebuild: bool = true) -> void:
	var seg: RoadSegment = _segments.get(segment_id, null)
	if seg == null:
		return

	seg.has_left_sidewalk = enabled_left
	seg.left_sidewalk_width = sidewalk_width
	seg.has_right_sidewalk = enabled_right
	seg.right_sidewalk_width = sidewalk_width

	if auto_rebuild:
		rebuild_geometry()


func get_all_segments() -> Array:
	return _segments.values()


# ==============================================================================
# GENERACIÓN GEOMÉTRICA CONTINUA (INSTANT BOX & RIBBON MESH)
func _resolve_network_intersections() -> void:
	# 1. Detectar cruces 2D entre segmentos rectos y asegurar que exista un endpoint compartido
	var initial_segs := _segments.values().duplicate()
	for i in range(initial_segs.size()):
		var sA: RoadSegment = initial_segs[i]
		var p0 := Vector2(sA.start_pos.x, sA.start_pos.z)
		var p1 := Vector2(sA.end_pos.x, sA.end_pos.z)
		var dA := p1 - p0
		for j in range(i + 1, initial_segs.size()):
			var sB: RoadSegment = initial_segs[j]
			var q0 := Vector2(sB.start_pos.x, sB.start_pos.z)
			var q1 := Vector2(sB.end_pos.x, sB.end_pos.z)
			var dB := q1 - q0

			var det := -dA.x * dB.y + dB.x * dA.y
			if absf(det) < 0.001:
				continue

			var diff := q0 - p0
			var t1 := (-diff.x * dB.y + diff.y * dB.x) / det
			var t2 := (dA.x * diff.y - diff.x * dA.y) / det

			if t1 > 0.02 and t1 < 0.98 and t2 > 0.02 and t2 < 0.98:
				var inter_2d := p0 + dA * t1
				var inter_pos := Vector3(inter_2d.x, (sA.start_pos.y + sB.start_pos.y) * 0.5, inter_2d.y)
				add_endpoint(inter_pos, Vector3.ZERO, minf(sA.width, sB.width), sA.road_type)

	# 2. Particionar segmentos continuos en todos los endpoints que intersectan su trayectoria
	var pass_count := 0
	var has_splits := true
	while has_splits and pass_count < 10:
		has_splits = false
		pass_count += 1
		var current_segs := _segments.values().duplicate()
		for s_item in current_segs:
			var seg: RoadSegment = s_item
			if not _segments.has(seg.id):
				continue
			var p0 := seg.start_pos
			var p1 := seg.end_pos
			var d := p1 - p0
			var len_sq := d.x * d.x + d.z * d.z
			if len_sq < 1.0:
				continue

			var split_eps: Array[Dictionary] = []
			for ep_item in _endpoints.values():
				var ep: RoadEndpoint = ep_item
				if ep.id == seg.start_endpoint_id or ep.id == seg.end_endpoint_id:
					continue
				var w := Vector2(ep.position.x - p0.x, ep.position.z - p0.z)
				var v := Vector2(d.x, d.z)
				var t := w.dot(v) / len_sq
				if t > 0.01 and t < 0.99:
					var proj := Vector2(p0.x, p0.z) + v * t
					var dist := (Vector2(ep.position.x, ep.position.z) - proj).length()
					if dist < 0.35: # Dentro del eje del tramo
						split_eps.append({"t": t, "ep": ep})

			if split_eps.is_empty():
				continue

			split_eps.sort_custom(func(a, b): return a["t"] < b["t"])

			var prev_ep_id := seg.start_endpoint_id
			var prev_pos := p0

			var start_ep := get_endpoint(seg.start_endpoint_id)
			if start_ep != null:
				start_ep.connected_segments.erase(seg.id)
			var end_ep := get_endpoint(seg.end_endpoint_id)
			if end_ep != null:
				end_ep.connected_segments.erase(seg.id)

			for split_info in split_eps:
				var curr_ep: RoadEndpoint = split_info["ep"]
				if prev_pos.distance_to(curr_ep.position) < 0.2:
					continue
				var sub_seg := RoadSegment.new(
					_next_segment_id,
					prev_ep_id,
					curr_ep.id,
					prev_pos,
					curr_ep.position,
					seg.width,
					seg.road_type
				)
				sub_seg.has_left_sidewalk = seg.has_left_sidewalk
				sub_seg.has_right_sidewalk = seg.has_right_sidewalk
				sub_seg.left_sidewalk_width = seg.left_sidewalk_width
				sub_seg.right_sidewalk_width = seg.right_sidewalk_width

				_segments[sub_seg.id] = sub_seg
				_next_segment_id += 1

				var ep_a := get_endpoint(prev_ep_id)
				if ep_a != null and not ep_a.connected_segments.has(sub_seg.id):
					ep_a.connected_segments.append(sub_seg.id)
				if not curr_ep.connected_segments.has(sub_seg.id):
					curr_ep.connected_segments.append(sub_seg.id)

				prev_ep_id = curr_ep.id
				prev_pos = curr_ep.position

			if prev_pos.distance_to(p1) >= 0.2:
				var last_sub_seg := RoadSegment.new(
					_next_segment_id,
					prev_ep_id,
					seg.end_endpoint_id,
					prev_pos,
					p1,
					seg.width,
					seg.road_type
				)
				last_sub_seg.has_left_sidewalk = seg.has_left_sidewalk
				last_sub_seg.has_right_sidewalk = seg.has_right_sidewalk
				last_sub_seg.left_sidewalk_width = seg.left_sidewalk_width
				last_sub_seg.right_sidewalk_width = seg.right_sidewalk_width

				_segments[last_sub_seg.id] = last_sub_seg
				_next_segment_id += 1

				var ep_last_a := get_endpoint(prev_ep_id)
				if ep_last_a != null and not ep_last_a.connected_segments.has(last_sub_seg.id):
					ep_last_a.connected_segments.append(last_sub_seg.id)
				if end_ep != null and not end_ep.connected_segments.has(last_sub_seg.id):
					end_ep.connected_segments.append(last_sub_seg.id)

			_segments.erase(seg.id)
			has_splits = true


## Calcula recortes métricos de señalización vial (líneas de carril y líneas de orilla)
## para normalizar cruces, intersecciones en T, esquinas y retornos.
func _compute_marking_cuts() -> Dictionary:
	var cuts: Dictionary = {}
	for seg_id in _segments:
		cuts[seg_id] = {
			"cut_start_lanes": 0.0,
			"cut_end_lanes": 0.0,
			"cut_start_left": 0.0,
			"cut_end_left": 0.0,
			"cut_start_right": 0.0,
			"cut_end_right": 0.0
		}

	for ep_item in _endpoints.values():
		var ep: RoadEndpoint = ep_item
		var connected_list: Array[RoadSegment] = []
		for seg_item in _segments.values():
			var s: RoadSegment = seg_item
			if s.start_pos.distance_to(ep.position) < 0.30 or s.end_pos.distance_to(ep.position) < 0.30:
				if not connected_list.has(s):
					connected_list.append(s)

		if connected_list.size() < 2:
			continue

		var branches: Array[Dictionary] = []
		for s in connected_list:
			var is_start := s.start_pos.distance_to(ep.position) < 0.30
			var u: Vector3 = (s.end_pos - s.start_pos).normalized() if is_start else (s.start_pos - s.end_pos).normalized()
			var s_len := (s.end_pos - s.start_pos).length()
			branches.append({
				"seg": s,
				"is_start": is_start,
				"u": u,
				"half_w": s.width * 0.5,
				"length": s_len
			})

		var num_branches := branches.size()

		for i in range(num_branches):
			var b := branches[i]
			var seg: RoadSegment = b["seg"]
			var is_start: bool = b["is_start"]
			var u: Vector3 = b["u"]
			var seg_len: float = b["length"]
			var seg_fwd: Vector3 = (seg.end_pos - seg.start_pos).normalized()
			var seg_right: Vector3 = Vector3(-seg_fwd.z, 0.0, seg_fwd.x).normalized()

			# 1. Buscar si esta rama tiene continuación colineal opuesta (~180°)
			var colinear_idx := -1
			for j in range(num_branches):
				if i == j:
					continue
				if u.dot(branches[j]["u"]) < -0.98:
					colinear_idx = j
					break

			var has_colinear: bool = (colinear_idx != -1)

			# 2. Ramas transversales (las que cruzan en ángulo)
			var transverse_branches: Array[Dictionary] = []
			for j in range(num_branches):
				if j != i and j != colinear_idx:
					transverse_branches.append(branches[j])

			var has_transverse: bool = not transverse_branches.is_empty()

			if has_colinear and has_transverse:
				# VÍA CONTINUA ATRAVESANDO UN CRUCE (Ej: Bulevar o Avenida en T o Cruz)
				var is_major := (seg.road_type == RoadType.AVENUE_ONEWAY_3LANE or seg.road_type == RoadType.AVENUE_ONEWAY_2LANE or seg.road_type == RoadType.DIVIDED_MEDIAN_3LANE)
				if num_branches >= 4 and not is_major:
					var max_cross := 0.0
					for tb in transverse_branches:
						max_cross = maxf(max_cross, tb["half_w"])
					var stop_dist := clampf(max_cross + 0.15, 0.0, seg_len * 0.45)
					if is_start:
						cuts[seg.id]["cut_start_lanes"] = maxf(cuts[seg.id]["cut_start_lanes"], stop_dist)
					else:
						cuts[seg.id]["cut_end_lanes"] = maxf(cuts[seg.id]["cut_end_lanes"], stop_dist)

				# Líneas de orilla: se abren en la boca de cada rama transversal
				for tb in transverse_branches:
					var cross_half_w: float = tb["half_w"]
					var cross_u: Vector3 = tb["u"]
					var side := seg_right.dot(cross_u)
					var open_dist := clampf(cross_half_w + 0.15, 0.0, seg_len * 0.45)

					if side > 0.20:
						# Rama transversal sale hacia la DERECHA del segmento
						if is_start:
							cuts[seg.id]["cut_start_right"] = maxf(cuts[seg.id]["cut_start_right"], open_dist)
						else:
							cuts[seg.id]["cut_end_right"] = maxf(cuts[seg.id]["cut_end_right"], open_dist)
					elif side < -0.20:
						# Rama transversal sale hacia la IZQUIERDA del segmento
						if is_start:
							cuts[seg.id]["cut_start_left"] = maxf(cuts[seg.id]["cut_start_left"], open_dist)
						else:
							cuts[seg.id]["cut_end_left"] = maxf(cuts[seg.id]["cut_end_left"], open_dist)

			elif not has_colinear:
				# RAMA QUE DESEMBOCA EN EL CRUCE (Calle secundaria de una T, o rama en esquina/estrella)
				var max_cross_depth := 0.0
				for j in range(num_branches):
					if i == j:
						continue
					var other_b := branches[j]
					var other_half_w: float = other_b["half_w"]
					var sin_a := absf(u.cross(other_b["u"]).y)
					var depth := other_half_w
					if sin_a > 0.20:
						depth = other_half_w / sin_a
					max_cross_depth = maxf(max_cross_depth, depth)

				var stop_lanes := clampf(max_cross_depth + 0.15, 0.0, seg_len * 0.48)
				var stop_edges := clampf(max_cross_depth, 0.0, seg_len * 0.48)

				if is_start:
					cuts[seg.id]["cut_start_lanes"] = maxf(cuts[seg.id]["cut_start_lanes"], stop_lanes)
					cuts[seg.id]["cut_start_left"] = maxf(cuts[seg.id]["cut_start_left"], stop_edges)
					cuts[seg.id]["cut_start_right"] = maxf(cuts[seg.id]["cut_start_right"], stop_edges)
				else:
					cuts[seg.id]["cut_end_lanes"] = maxf(cuts[seg.id]["cut_end_lanes"], stop_lanes)
					cuts[seg.id]["cut_end_left"] = maxf(cuts[seg.id]["cut_end_left"], stop_edges)
					cuts[seg.id]["cut_end_right"] = maxf(cuts[seg.id]["cut_end_right"], stop_edges)

	return cuts


func rebuild_geometry() -> void:
	if is_batch_updating:
		return
	_setup_nodes()

	# Limpiar colisiones previas
	for child in _static_body.get_children():
		if child is CollisionShape3D:
			child.queue_free()

	_resolve_network_intersections()

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
			if s.start_pos.distance_to(ep.position) < 0.30 or s.end_pos.distance_to(ep.position) < 0.30:
				if not connected_list.has(s):
					connected_list.append(s)

		if connected_list.size() < 2:
			continue

		# Ramas ordenadas cíclicamente alrededor del endpoint
		var branches := []
		for s in connected_list:
			var is_start := s.start_pos.distance_to(ep.position) < 0.30
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

	# 2. Precalcular recortes de señalización vial en cruces e intersecciones
	var marking_cuts := _compute_marking_cuts()

	# 3. Construcción geométrica de los tramos rectos
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

		# A2. Camellón / Separador Central Integrado (Para calles de 3 carriles divididas)
		if seg.road_type == RoadType.DIVIDED_MEDIAN_3LANE:
			var seg_cuts_m: Dictionary = marking_cuts[seg.id]
			var t_med_0: float = maxf(seg_cuts_m["cut_start_lanes"], 1.8)
			var t_med_1: float = length - maxf(seg_cuts_m["cut_end_lanes"], 1.8)
			var med_rad: float = MEDIAN_WIDTH_DIVIDED_3LANE * 0.5
			var curb_w: float = CURB_WIDTH
			var y_med: float = ROAD_HEIGHT + SIDEWALK_HEIGHT

			# Coordenadas transversales del camellón:
			# Ambas vías tienen 3 carriles de 3.50m = 10.50m cada una (21m total de asfalto).
			# El camellón mide 2.00m de ancho y queda exactamente centrado en el eje (x = 0.0).
			var xm_left: float = -MEDIAN_WIDTH_DIVIDED_3LANE * 0.5 # -1.00m
			var xm_right: float = MEDIAN_WIDTH_DIVIDED_3LANE * 0.5  # +1.00m
			var xm_center: float = 0.0

			if (t_med_1 - t_med_0) > (med_rad * 2.0 + 0.5):
				var tb_0: float = t_med_0 + med_rad
				var tb_1: float = t_med_1 - med_rad

				# 1. Bordillo izquierdo del camellón
				var mkb0 := p0 + fwd * tb_0 + right * xm_left
				var mkb1 := p0 + fwd * tb_0 + right * (xm_left + curb_w)
				var mkb2 := p0 + fwd * tb_1 + right * (xm_left + curb_w)
				var mkb3 := p0 + fwd * tb_1 + right * xm_left
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_CURB], mkb0, mkb1, mkb2, mkb3, ROAD_HEIGHT, y_med)

				# 2. Relleno central (tierra / vegetación / losa de camellón)
				var msw0 := mkb1
				var msw1 := p0 + fwd * tb_0 + right * (xm_right - curb_w)
				var msw2 := p0 + fwd * tb_1 + right * (xm_right - curb_w)
				var msw3 := mkb2
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_MEDIAN], msw0, msw1, msw2, msw3, ROAD_HEIGHT, y_med)

				# 3. Bordillo derecho del camellón
				var mkbr0 := msw1
				var mkbr1 := p0 + fwd * tb_0 + right * xm_right
				var mkbr2 := p0 + fwd * tb_1 + right * xm_right
				var mkbr3 := msw2
				_append_oriented_slab(geom_data[ProceduralRoadMaterials.KEY_CURB], mkbr0, mkbr1, mkbr2, mkbr3, ROAD_HEIGHT, y_med)

				# 4. Narices / Cabeceras redondeadas en ambos extremos
				var cap_center_0 := p0 + fwd * tb_0 + right * xm_center
				_append_median_cap(geom_data, cap_center_0, -fwd, right, med_rad, curb_w, ROAD_HEIGHT, y_med)

				var cap_center_1 := p0 + fwd * tb_1 + right * xm_center
				_append_median_cap(geom_data, cap_center_1, fwd, right, med_rad, curb_w, ROAD_HEIGHT, y_med)

				# 5. Colisión física del camellón
				var col_med := CollisionShape3D.new()
				col_med.name = "Col_Median_%d" % col_index
				var med_box := BoxShape3D.new()
				med_box.size = Vector3(MEDIAN_WIDTH_DIVIDED_3LANE, SIDEWALK_HEIGHT + 0.10, t_med_1 - t_med_0)
				col_med.shape = med_box
				var med_mid := p0 + fwd * ((t_med_0 + t_med_1) * 0.5) + right * xm_center + Vector3(0.0, ROAD_HEIGHT + SIDEWALK_HEIGHT * 0.5, 0.0)
				col_med.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), med_mid)
				_static_body.add_child(col_med)
				col_index += 1

		# B. Señalización vial (con recortes normalizados en cruces)
		var stripe_w := 0.14
		var white_stripe_w := 0.14
		var y_paint := ROAD_HEIGHT + PAINT_HEIGHT
		var edge_inset := 0.28 # Distancia desde la orilla de la calzada

		var seg_cuts: Dictionary = marking_cuts[seg.id]
		var t_lanes_0: float = seg_cuts["cut_start_lanes"]
		var t_lanes_1: float = length - seg_cuts["cut_end_lanes"]
		var has_lane_markings: bool = (t_lanes_1 - t_lanes_0) > 0.40

		var p_lane_0: Vector3 = p0 + fwd * t_lanes_0
		var p_lane_1: Vector3 = p0 + fwd * t_lanes_1

		var t_left_0: float = seg_cuts["cut_start_left"]
		var t_left_1: float = length - seg_cuts["cut_end_left"]
		var has_left_edge: bool = (t_left_1 - t_left_0) > 0.40

		var t_right_0: float = seg_cuts["cut_start_right"]
		var t_right_1: float = length - seg_cuts["cut_end_right"]
		var has_right_edge: bool = (t_right_1 - t_right_0) > 0.40

		match seg.road_type:
			RoadType.TWO_WAY_2LANE:
				# 1. Doble línea amarilla continua al centro exacto (detenida en cruces)
				if has_lane_markings:
					var s0_l := p_lane_0 - right * (stripe_w * 1.3)
					var s1_l := p_lane_0 - right * (stripe_w * 0.3)
					var s2_l := p_lane_1 - right * (stripe_w * 0.3)
					var s3_l := p_lane_1 - right * (stripe_w * 1.3)
					_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_l, s1_l, s2_l, s3_l, y_paint)

					var s0_r := p_lane_0 + right * (stripe_w * 0.3)
					var s1_r := p_lane_0 + right * (stripe_w * 1.3)
					var s2_r := p_lane_1 + right * (stripe_w * 1.3)
					var s3_r := p_lane_1 + right * (stripe_w * 0.3)
					_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_r, s1_r, s2_r, s3_r, y_paint)

				# 2. Líneas blancas continuas en las orillas (abiertas en bocacalles)
				if has_left_edge and half_w > edge_inset + 0.5:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)

				if has_right_edge and half_w > edge_inset + 0.5:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pr0, pr1, right, white_stripe_w, y_paint)

			RoadType.AVENUE_ONEWAY_2LANE:
				# 2 carriles unidireccionales: 1 línea blanca discontinua al centro
				if has_lane_markings:
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0, p_lane_1, right, white_stripe_w, y_paint)
				# Líneas blancas continuas en las orillas
				if has_left_edge and half_w > edge_inset + 0.5:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)
				if has_right_edge and half_w > edge_inset + 0.5:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pr0, pr1, right, white_stripe_w, y_paint)

			RoadType.AVENUE_ONEWAY_3LANE:
				# 3 carriles unidireccionales: 2 líneas blancas discontinuas dividiendo los 3 carriles
				if has_lane_markings:
					var lane_w := seg.width / 3.0
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 - right * (lane_w * 0.5), p_lane_1 - right * (lane_w * 0.5), right, white_stripe_w, y_paint)
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * (lane_w * 0.5), p_lane_1 + right * (lane_w * 0.5), right, white_stripe_w, y_paint)

				# Líneas blancas continuas en las orillas (abiertas en bocacalles)
				if has_left_edge and half_w > edge_inset + 0.5:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)
				if has_right_edge and half_w > edge_inset + 0.5:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pr0, pr1, right, white_stripe_w, y_paint)

			RoadType.COMMERCIAL_4LANE:
				# 4 carriles: 2 por sentido
				# 1. Doble línea amarilla continua al centro exacto
				if has_lane_markings:
					var s0_l := p_lane_0 - right * (stripe_w * 1.3)
					var s1_l := p_lane_0 - right * (stripe_w * 0.3)
					var s2_l := p_lane_1 - right * (stripe_w * 0.3)
					var s3_l := p_lane_1 - right * (stripe_w * 1.3)
					_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_l, s1_l, s2_l, s3_l, y_paint)

					var s0_r := p_lane_0 + right * (stripe_w * 0.3)
					var s1_r := p_lane_0 + right * (stripe_w * 1.3)
					var s2_r := p_lane_1 + right * (stripe_w * 1.3)
					var s3_r := p_lane_1 + right * (stripe_w * 0.3)
					_append_quad_top(geom_data[ProceduralRoadMaterials.KEY_YELLOW_LINE], s0_r, s1_r, s2_r, s3_r, y_paint)

					# 2. Líneas blancas discontinuas dividiendo los dos carriles de cada sentido
					var lane_w := seg.width / 4.0
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 - right * lane_w, p_lane_1 - right * lane_w, right, white_stripe_w, y_paint)
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * lane_w, p_lane_1 + right * lane_w, right, white_stripe_w, y_paint)

				# 3. Líneas blancas continuas en las orillas comerciales
				if has_left_edge and half_w > edge_inset + 0.5:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)
				if has_right_edge and half_w > edge_inset + 0.5:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pr0, pr1, right, white_stripe_w, y_paint)

			RoadType.ALLEY_1LANE:
				# Callejón / Privada de 1 solo carril: ¡CERO línea divisoria central!
				# Únicamente línea blanca continua en la orilla junto a la banqueta si existe
				if seg.has_left_sidewalk and has_left_edge and half_w > edge_inset + 0.3:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)
				if seg.has_right_sidewalk and has_right_edge and half_w > edge_inset + 0.3:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
			RoadType.DIVIDED_MEDIAN_3LANE:
				var x_m_left := -MEDIAN_WIDTH_DIVIDED_3LANE * 0.5  # -1.00m
				var x_m_right := MEDIAN_WIDTH_DIVIDED_3LANE * 0.5  # +1.00m

				# 1. Calzada izquierda (3 carriles de 3.50m netos, total 10.50m: de -11.50m a -1.00m):
				# Dos líneas blancas discontinuas divisorias:
				# Carril 1 exterior: [-11.50, -8.00] -> Línea 1 en x = -8.00m
				# Carril 2 medio:    [-8.00, -4.50]  -> Línea 2 en x = -4.50m
				# Carril 3 interior: [-4.50, -1.00]
				if has_lane_markings:
					var lane_div_l1 := -half_w + 3.50 # -8.00m
					var lane_div_l2 := -half_w + 7.00 # -4.50m
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * lane_div_l1, p_lane_1 + right * lane_div_l1, right, white_stripe_w, y_paint)
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * lane_div_l2, p_lane_1 + right * lane_div_l2, right, white_stripe_w, y_paint)

				# Línea blanca continua de orilla exterior izquierda (junto a la banqueta)
				if has_left_edge and half_w > edge_inset + 0.5:
					var pl0 := p0 + fwd * t_left_0 - right * (half_w - edge_inset)
					var pl1 := p0 + fwd * t_left_1 - right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pl0, pl1, right, white_stripe_w, y_paint)

				# Línea blanca continua interior izquierda (junto al bordillo del camellón)
				if has_lane_markings:
					var p_med_l0 := p0 + fwd * t_lanes_0 + right * (x_m_left - edge_inset)
					var p_med_l1 := p0 + fwd * t_lanes_1 + right * (x_m_left - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_med_l0, p_med_l1, right, white_stripe_w, y_paint)

				# 2. Calzada derecha (3 carriles de 3.50m netos, total 10.50m: de +1.00m a +11.50m):
				# Línea blanca continua interior derecha (junto al bordillo del camellón)
				if has_lane_markings:
					var p_med_r0 := p0 + fwd * t_lanes_0 + right * (x_m_right + edge_inset)
					var p_med_r1 := p0 + fwd * t_lanes_1 + right * (x_m_right + edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_med_r0, p_med_r1, right, white_stripe_w, y_paint)

				# Dos líneas blancas discontinuas divisorias:
				# Carril 1 interior: [+1.00, +4.50]  -> Línea 1 en x = +4.50m
				# Carril 2 medio:    [+4.50, +8.00]  -> Línea 2 en x = +8.00m
				# Carril 3 exterior: [+8.00, +11.50]
				if has_lane_markings:
					var lane_div_r1 := half_w - 7.00 # +4.50m
					var lane_div_r2 := half_w - 3.50 # +8.00m
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * lane_div_r1, p_lane_1 + right * lane_div_r1, right, white_stripe_w, y_paint)
					_append_dashed_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], p_lane_0 + right * lane_div_r2, p_lane_1 + right * lane_div_r2, right, white_stripe_w, y_paint)

				# Línea blanca continua de orilla exterior derecha (junto a la banqueta)
				if has_right_edge and half_w > edge_inset + 0.5:
					var pr0 := p0 + fwd * t_right_0 + right * (half_w - edge_inset)
					var pr1 := p0 + fwd * t_right_1 + right * (half_w - edge_inset)
					_append_continuous_line(geom_data[ProceduralRoadMaterials.KEY_WHITE_LINE], pr0, pr1, right, white_stripe_w, y_paint)

			RoadType.RURAL_PLAIN_2LANE:
				pass

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


static func _append_median_cap(
	geom_data: Dictionary,
	center: Vector3,
	outward_dir: Vector3,
	lateral_dir: Vector3,
	radius: float,
	curb_w: float,
	y_min: float,
	y_max: float,
	num_segments: int = 8
) -> void:
	var curb_data: Dictionary = geom_data[ProceduralRoadMaterials.KEY_CURB]
	var median_data: Dictionary = geom_data[ProceduralRoadMaterials.KEY_MEDIAN]
	var inner_radius := radius - curb_w

	for i in range(num_segments):
		var a0 := -PI * 0.5 + float(i) * PI / float(num_segments)
		var a1 := -PI * 0.5 + float(i + 1) * PI / float(num_segments)

		var dir0 := outward_dir * cos(a0) + lateral_dir * sin(a0)
		var dir1 := outward_dir * cos(a1) + lateral_dir * sin(a1)

		var p_out0 := center + dir0 * radius
		var p_out1 := center + dir1 * radius
		var p_in0 := center + dir0 * inner_radius
		var p_in1 := center + dir1 * inner_radius

		# 1. Cara vertical del bordillo exterior hacia el asfalto
		_append_vertical_strip(curb_data, p_out0, p_out1, y_min, y_max)

		# 2. Tapa horizontal superior del bordillo
		_append_quad_top(curb_data, p_out0, p_out1, p_in1, p_in0, y_max)

		# 3. Relleno interior superior (tierra / vegetación / losa de camellón)
		_append_triangle_top(median_data, center, p_in0, p_in1, y_max)


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


static func _append_continuous_line(
	data: Dictionary,
	start: Vector3, end: Vector3,
	right: Vector3, width: float, y_pos: float
) -> void:
	var delta := end - start
	var total_len := delta.length()
	if total_len <= 0.1:
		return
	var half_w := width * 0.5
	var v0 := start - right * half_w
	var v1 := start + right * half_w
	var v2 := end + right * half_w
	var v3 := end - right * half_w
	_append_quad_top(data, Vector3(v0.x, y_pos, v0.z), Vector3(v1.x, y_pos, v1.z), Vector3(v2.x, y_pos, v2.z), Vector3(v3.x, y_pos, v3.z), y_pos)


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

	var dash_len := 2.5
	var gap_len := 2.5
	var period := dash_len + gap_len

	var cur := 0.2
	while cur + dash_len <= total_len - 0.2:
		var p0 := start + dir * cur
		var p1 := start + dir * (cur + dash_len)
		var v0 := p0 - right * half_w
		var v1 := p0 + right * half_w
		var v2 := p1 + right * half_w
		var v3 := p1 - right * half_w
		_append_quad_top(data, Vector3(v0.x, y_pos, v0.z), Vector3(v1.x, y_pos, v1.z), Vector3(v2.x, y_pos, v2.z), Vector3(v3.x, y_pos, v3.z), y_pos)
		cur += period


# ==============================================================================
# SISTEMA PROCEDURAL DE POSTES DE LUZ (STREETLIGHT INTELLIGENCE)
# ==============================================================================

const STREETLIGHT_TARGET_SPACING: float = 28.0       ## Espaciado nominal ideal entre postes (25m - 30m)
const STREETLIGHT_SAFETY_MARGIN: float = 7.0        ## Despeje mínimo respecto al extremo del camellón o cruces
const STREETLIGHT_MIN_SEGMENT_LENGTH: float = 14.0   ## Largo mínimo para alojar al menos 1 poste


## Retorna los transforms 3D óptimos para postes de luz en un segmento específico.
## Distribuye las posiciones paramétricamente a lo largo de la calle o camellón
## adaptándose de forma elástica a la longitud sin medidas hardcodeadas.
func get_streetlight_transforms_for_segment(seg_id: int) -> Array[Transform3D]:
	var seg: RoadSegment = _segments.get(seg_id, null)
	if seg == null:
		return []

	var p0 := seg.start_pos
	var p1 := seg.end_pos
	var delta := p1 - p0
	var length := delta.length()
	if length < STREETLIGHT_MIN_SEGMENT_LENGTH:
		return []

	var fwd := delta / length
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	var seg_basis := Basis.looking_at(fwd, Vector3.UP)

	var marking_cuts := _compute_marking_cuts()
	var seg_cuts: Dictionary = marking_cuts.get(seg.id, {
		"cut_start_lanes": 0.0,
		"cut_end_lanes": 0.0,
	})

	var transforms: Array[Transform3D] = []

	match seg.road_type:
		RoadType.DIVIDED_MEDIAN_3LANE:
			# Los postes van DIRECTAMENTE sobre el camellón central elevado (centrados en x = 0.0)
			var x_m_center := 0.0
			var y_pos := ROAD_HEIGHT + SIDEWALK_HEIGHT

			var t_med_0: float = maxf(seg_cuts["cut_start_lanes"], 1.8) + (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)
			var t_med_1: float = length - maxf(seg_cuts["cut_end_lanes"], 1.8) - (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)

			var t_first: float = t_med_0 + STREETLIGHT_SAFETY_MARGIN
			var t_last: float = t_med_1 - STREETLIGHT_SAFETY_MARGIN
			var usable_dist: float = t_last - t_first

			if usable_dist < 6.0:
				# Cuadra corta/mediana (15m a ~35m): 1 poste único en el centro exacto del camellón
				var mid_t: float = (t_med_0 + t_med_1) * 0.5
				var pos := p0 + fwd * mid_t + right * x_m_center + Vector3(0.0, y_pos, 0.0)
				transforms.append(Transform3D(seg_basis, pos))
			else:
				# Cuadra estándar o larga (> 35m): distribución adaptativa perfectamente equidistante
				var spans: int = maxi(1, int(round(usable_dist / STREETLIGHT_TARGET_SPACING)))
				var count: int = spans + 1
				var step: float = usable_dist / float(spans)
				for i in range(count):
					var t: float = t_first + float(i) * step
					var pos := p0 + fwd * t + right * x_m_center + Vector3(0.0, y_pos, 0.0)
					transforms.append(Transform3D(seg_basis, pos))

		_:
			# En calles sin camellón central (residenciales, comerciales, etc.), van en las banquetas
			var half_w := seg.width * 0.5
			var t_first: float = float(seg_cuts.get("cut_start_lanes", 0.0)) + STREETLIGHT_SAFETY_MARGIN
			var t_last: float = length - float(seg_cuts.get("cut_end_lanes", 0.0)) - STREETLIGHT_SAFETY_MARGIN
			var usable_dist: float = t_last - t_first
			var y_pos := ROAD_HEIGHT + SIDEWALK_HEIGHT

			if usable_dist >= 6.0:
				var spans: int = maxi(1, int(round(usable_dist / STREETLIGHT_TARGET_SPACING)))
				var count: int = spans + 1
				var step: float = usable_dist / float(spans)
				for i in range(count):
					var t: float = t_first + float(i) * step
					# Alternar lado izquierdo y derecho si ambas banquetas existen
					var side_offset: float = (half_w + 0.60)
					if seg.has_right_sidewalk and (i % 2 == 0 or not seg.has_left_sidewalk):
						var pos := p0 + fwd * t + right * side_offset + Vector3(0.0, y_pos, 0.0)
						transforms.append(Transform3D(seg_basis, pos))
					elif seg.has_left_sidewalk:
						var pos := p0 + fwd * t - right * side_offset + Vector3(0.0, y_pos, 0.0)
						transforms.append(Transform3D(seg_basis, pos))

	return transforms


## Retorna la lista de todos los transforms de postes de luz en toda la red vial
func get_all_streetlight_transforms() -> Array[Transform3D]:
	var all_xf: Array[Transform3D] = []
	for seg_id in _segments:
		all_xf.append_array(get_streetlight_transforms_for_segment(seg_id))
	return all_xf


## Crea la malla cilíndrica low-poly idéntica a la del medidor CFE (12 lados)
static func create_cfe_lowpoly_cylinder_mesh(height: float = 7.2, top_rad: float = 0.09, bot_rad: float = 0.13) -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_rad
	cyl.bottom_radius = bot_rad
	cyl.height = height
	cyl.radial_segments = 12 # 12 segmentos: estándar medidor CFE / estética PSX
	cyl.rings = 1
	return cyl


## Determina si una calle califica como vía grande/primaria (bulevares y avenidas multilínea con o sin camellón)
static func is_major_street(road_type: RoadType, _width: float = 0.0) -> bool:
	return road_type == RoadType.DIVIDED_MEDIAN_3LANE \
		or road_type == RoadType.AVENUE_ONEWAY_3LANE \
		or road_type == RoadType.AVENUE_ONEWAY_2LANE


## Determina deterministamente si un poste en una posición dada presenta óxido / desgaste
static func _is_streetlight_rusty(pos: Vector3) -> bool:
	var ix := int(floor(pos.x * 19.0 + pos.z * 7.0))
	var iz := int(floor(pos.z * 23.0 - pos.x * 11.0))
	var n: int = (ix * 374761393 + iz * 668265263) & 0x7FFFFFFF
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7FFFFFFF
	n = (n ^ (n >> 16)) & 0x7FFFFFFF
	var val: float = float(n) / 2147483647.0
	return val < 0.22 # ~22% de probabilidad: óxido aparece de vez en cuando, no siempre


## Instancia por GPU Hardware (MultiMeshInstance3D) todos los postes de luz usando el cilindro low-poly de 12 lados del medidor CFE.
## Aplica las reglas de texturizado:
## - Calles grandes (Bulevares, Avenidas divididas) -> Tono Metal (Galvanizado).
## - Calles medianas o chicas (Comerciales, Residenciales, Callejones) -> Tono Amarillo.
## - Textura con óxido: Aparece de vez en cuando (~22%) de manera determinista.
## Agrupa en MultiMesh por variante de textura (máximo 4 draw calls para toda la ciudad).
func spawn_streetlights_gpu(parent_node: Node3D, target_seg_id: int = -1, force_tone: String = "") -> Dictionary:
	var seg_list: Array = [target_seg_id] if target_seg_id != -1 else _segments.keys()
	if seg_list.is_empty():
		return {}

	# Clasificar transforms por clave de material
	var groups: Dictionary = {
		ProceduralRoadMaterials.KEY_POLE_METAL_CLEAN: [],
		ProceduralRoadMaterials.KEY_POLE_METAL_RUSTY: [],
		ProceduralRoadMaterials.KEY_POLE_YELLOW_CLEAN: [],
		ProceduralRoadMaterials.KEY_POLE_YELLOW_RUSTY: [],
	}

	var all_lamp_xfs: Array[Transform3D] = []
	var total_poles := 0

	for s_id in seg_list:
		var seg: RoadSegment = _segments.get(s_id, null)
		if seg == null:
			continue

		var is_major: bool = is_major_street(seg.road_type, seg.width)
		if force_tone == "metal":
			is_major = true
		elif force_tone == "yellow":
			is_major = false

		var seg_xfs := get_streetlight_transforms_for_segment(s_id)
		for xf in seg_xfs:
			total_poles += 1
			var is_rusty := _is_streetlight_rusty(xf.origin)
			var key: String
			if is_major:
				key = ProceduralRoadMaterials.KEY_POLE_METAL_RUSTY if is_rusty else ProceduralRoadMaterials.KEY_POLE_METAL_CLEAN
			else:
				key = ProceduralRoadMaterials.KEY_POLE_YELLOW_RUSTY if is_rusty else ProceduralRoadMaterials.KEY_POLE_YELLOW_CLEAN

			groups[key].append(xf)

			# Dos luminarias LED por poste
			all_lamp_xfs.append(xf.translated_local(Vector3(-1.05, 7.10, 0.0)))
			all_lamp_xfs.append(xf.translated_local(Vector3(1.05, 7.10, 0.0)))

	if total_poles == 0:
		return {}

	# Contenedor del grupo
	var group_root := Node3D.new()
	group_root.name = "Streetlights_GPU_Instanced"
	parent_node.add_child(group_root)

	var pole_nodes: Array[MultiMeshInstance3D] = []
	var arm_nodes: Array[MultiMeshInstance3D] = []

	# Instanciar cada grupo de mástiles y brazos por GPU Hardware Instancing
	for mat_key in groups:
		var xfs: Array = groups[mat_key]
		if xfs.is_empty():
			continue

		var count: int = xfs.size()
		var mat: Material = ProceduralRoadMaterials.get_material(mat_key)

		# 1. MultiMesh Mástiles CFE 12 lados
		var mm_poles := MultiMesh.new()
		mm_poles.transform_format = MultiMesh.TRANSFORM_3D
		mm_poles.instance_count = count
		var pole_mesh := create_cfe_lowpoly_cylinder_mesh(7.2, 0.09, 0.13)
		pole_mesh.material = mat
		mm_poles.mesh = pole_mesh

		# 2. MultiMesh Brazos transversales dobles
		var mm_arms := MultiMesh.new()
		mm_arms.transform_format = MultiMesh.TRANSFORM_3D
		mm_arms.instance_count = count
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(2.2, 0.10, 0.10)
		arm_mesh.material = mat
		mm_arms.mesh = arm_mesh

		for i in range(count):
			var xf: Transform3D = xfs[i]
			var pole_xf := xf.translated_local(Vector3(0.0, 3.6, 0.0))
			mm_poles.set_instance_transform(i, pole_xf)

			var arm_xf := xf.translated_local(Vector3(0.0, 7.15, 0.0))
			mm_arms.set_instance_transform(i, arm_xf)

		var inst_p := MultiMeshInstance3D.new()
		inst_p.name = "Poles_%s" % mat_key
		inst_p.multimesh = mm_poles
		group_root.add_child(inst_p)
		pole_nodes.append(inst_p)

		var inst_a := MultiMeshInstance3D.new()
		inst_a.name = "Arms_%s" % mat_key
		inst_a.multimesh = mm_arms
		group_root.add_child(inst_a)
		arm_nodes.append(inst_a)

	# 3. MultiMesh para los cabezales LED (1 solo draw call para todos los focos)
	var inst_lamps: MultiMeshInstance3D = null
	if not all_lamp_xfs.is_empty():
		var mm_lamps := MultiMesh.new()
		mm_lamps.transform_format = MultiMesh.TRANSFORM_3D
		mm_lamps.instance_count = all_lamp_xfs.size()
		var lamp_mesh := BoxMesh.new()
		lamp_mesh.size = Vector3(0.35, 0.12, 0.22)
		lamp_mesh.material = ProceduralRoadMaterials.get_material(ProceduralRoadMaterials.KEY_LAMP_LED)
		mm_lamps.mesh = lamp_mesh

		for i in range(all_lamp_xfs.size()):
			mm_lamps.set_instance_transform(i, all_lamp_xfs[i])

		inst_lamps = MultiMeshInstance3D.new()
		inst_lamps.name = "Lamps_LED_Warm"
		inst_lamps.multimesh = mm_lamps
		group_root.add_child(inst_lamps)

	return {
		"root": group_root,
		"pole_instances": pole_nodes,
		"arm_instances": arm_nodes,
		"lamps": inst_lamps
	}


## Instancia postes de luz procedurales en el árbol de escena.
## Por defecto utiliza GPU Hardware Instancing (MultiMeshInstance3D) con el cilindro del medidor CFE (12 lados).
func spawn_streetlights(parent_node: Node3D, custom_scene_or_factory = null, target_seg_id: int = -1, force_tone: String = "") -> Array[Node3D]:
	if custom_scene_or_factory == null:
		# GPU Hardware Instancing hiperoptimizado con las texturas auténticas CFE
		var gpu_res := spawn_streetlights_gpu(parent_node, target_seg_id, force_tone)
		if gpu_res.has("root"):
			return [gpu_res["root"]]
		return []

	var spawned: Array[Node3D] = []
	var xforms: Array[Transform3D] = get_streetlight_transforms_for_segment(target_seg_id) if target_seg_id != -1 else get_all_streetlight_transforms()

	for xf in xforms:
		var node: Node3D = null
		if custom_scene_or_factory is PackedScene:
			node = (custom_scene_or_factory as PackedScene).instantiate()
		elif custom_scene_or_factory is Callable:
			node = (custom_scene_or_factory as Callable).call()

		if node != null:
			parent_node.add_child(node)
			node.transform = xf
			spawned.append(node)

	return spawned


# ==============================================================================
# VEGETACIÓN PROCEDURAL EN CAMELLÓN CENTRAL (REGLA STRICT AGENTS.MD: ProceduralTree)
# ==============================================================================

const MEDIAN_TREE_TARGET_SPACING: float = 16.0       ## Espaciado nominal entre árboles en camellón
const MEDIAN_TREE_SAFETY_MARGIN: float = 6.0         ## Margen respecto al extremo del camellón


## Retorna los transforms 3D para árboles en el camellón central de 2m.
## Se colocan a lo largo del camellón en x = 0.0 a altura y_pos,
## intercalándose armónicamente y respetando la distancia con los postes de luz.
func get_median_tree_transforms_for_segment(seg_id: int) -> Array[Transform3D]:
	var seg: RoadSegment = _segments.get(seg_id, null)
	if seg == null or seg.road_type != RoadType.DIVIDED_MEDIAN_3LANE:
		return []

	var p0 := seg.start_pos
	var p1 := seg.end_pos
	var delta := p1 - p0
	var length := delta.length()
	if length < 16.0:
		return []

	var fwd := delta / length
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	var seg_basis := Basis.looking_at(fwd, Vector3.UP)

	var marking_cuts := _compute_marking_cuts()
	var seg_cuts: Dictionary = marking_cuts.get(seg.id, {
		"cut_start_lanes": 0.0,
		"cut_end_lanes": 0.0,
	})

	var t_med_0: float = maxf(seg_cuts["cut_start_lanes"], 1.8) + (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)
	var t_med_1: float = length - maxf(seg_cuts["cut_end_lanes"], 1.8) - (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)
	var y_pos := ROAD_HEIGHT + SIDEWALK_HEIGHT

	# Obtener posiciones de postes para no plantar un árbol encima de una luminaria
	var light_xfs := get_streetlight_transforms_for_segment(seg_id)
	var light_ts: Array[float] = []
	for l_xf in light_xfs:
		var t_proj := (l_xf.origin - p0).dot(fwd)
		light_ts.append(t_proj)

	var t_first := t_med_0 + MEDIAN_TREE_SAFETY_MARGIN
	var t_last := t_med_1 - MEDIAN_TREE_SAFETY_MARGIN
	var usable_dist := t_last - t_first

	var tree_xfs: Array[Transform3D] = []
	if usable_dist <= 2.0:
		return []

	var spans: int = maxi(1, int(round(usable_dist / MEDIAN_TREE_TARGET_SPACING)))
	var count: int = spans + 1
	var step: float = usable_dist / float(spans)

	for i in range(count):
		var t := t_first + float(i) * step
		# Verificar que no colisione con un poste de luz (mantener despeje mínimo de 3.5m)
		var near_light := false
		for lt in light_ts:
			if absf(lt - t) < 3.5:
				near_light = true
				break
		if near_light:
			continue

		# Rotación variada en Y para aspecto natural
		var rot_y := fmod(float(i * 137.5), 360.0) * (PI / 180.0)
		var t_basis := seg_basis.rotated(Vector3.UP, rot_y)
		var pos := p0 + fwd * t + Vector3(0.0, y_pos, 0.0)
		tree_xfs.append(Transform3D(t_basis, pos))

	return tree_xfs


## Instancia árboles en los camellones usando ÚNICA Y EXCLUSIVAMENTE ProceduralTree (Regla AGENTS.md)
func spawn_median_trees(parent_node: Node3D, profile_id: String = "classic_oak", target_seg_id: int = -1) -> Array[Node3D]:
	var spawned: Array[Node3D] = []
	var seg_list: Array = [target_seg_id] if target_seg_id != -1 else _segments.keys()
	for seg_id in seg_list:
		var xforms := get_median_tree_transforms_for_segment(seg_id)
		for xf in xforms:
			var tree: Node3D = PROCEDURAL_TREE_SCRIPT.new()
			tree.set("profile_id", profile_id)
			tree.set("tree_seed", randi())
			parent_node.add_child(tree)
			tree.global_transform = xf
			spawned.append(tree)
	return spawned


# ==============================================================================
# MACETAS CUADRADAS PROCEDURALES EN CAMELLÓN CENTRAL (DISTRIBUCIÓN INTELIGENTE)
# ==============================================================================

const PLANTER_SQUARE_SIZE: float = 1.20              ## Ancho y largo exterior de la maceta (1.20m en camellón de 2.0m)
const PLANTER_SQUARE_HEIGHT: float = 0.55            ## Altura de la jardinera de concreto (0.55m)
const PLANTER_TARGET_SPACING: float = 8.5            ## Espaciado nominal ideal entre jardineras
const PLANTER_LIGHT_SAFETY_MARGIN: float = 2.4       ## Despeje mínimo respecto al poste de luz


## Retorna los transforms 3D para macetas cuadradas en el camellón central de 2.0m.
## La colocación es 100% paramétrica, inteligente y elástica:
## - No utiliza medidas estáticas ni espaciados fijos que se rompan con largos arbitrarios.
## - Detecta las posiciones de los postes de luz GPU y subdivide armónicamente los vanos entre ellos.
## - Mantiene simetría perfecta tanto en cuadras cortas de 20m como en avenidas de 300m.
func get_median_planter_transforms_for_segment(seg_id: int) -> Array[Transform3D]:
	var seg: RoadSegment = _segments.get(seg_id, null)
	if seg == null or seg.road_type != RoadType.DIVIDED_MEDIAN_3LANE:
		return []

	var p0 := seg.start_pos
	var p1 := seg.end_pos
	var delta := p1 - p0
	var length := delta.length()
	if length < 10.0:
		return []

	var fwd := delta / length
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	var seg_basis := Basis.looking_at(fwd, Vector3.UP)

	var marking_cuts := _compute_marking_cuts()
	var seg_cuts: Dictionary = marking_cuts.get(seg.id, {
		"cut_start_lanes": 0.0,
		"cut_end_lanes": 0.0,
	})

	var t_med_0: float = maxf(seg_cuts["cut_start_lanes"], 1.8) + (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)
	var t_med_1: float = length - maxf(seg_cuts["cut_end_lanes"], 1.8) - (MEDIAN_WIDTH_DIVIDED_3LANE * 0.5)
	var y_pos := ROAD_HEIGHT + SIDEWALK_HEIGHT

	# Puntos de referencia de luminarias GPU en el camellón
	var light_xfs := get_streetlight_transforms_for_segment(seg_id)
	var light_ts: Array[float] = []
	for l_xf in light_xfs:
		var t_proj := (l_xf.origin - p0).dot(fwd)
		if t_proj >= t_med_0 and t_proj <= t_med_1:
			light_ts.append(t_proj)
	light_ts.sort()

	var planter_ts: Array[float] = []

	if light_ts.is_empty():
		# Cuadra corta sin luminarias: subdivisión simétrica del tramo útil
		var usable := t_med_1 - t_med_0 - 4.0
		if usable > 2.0:
			var count: int = maxi(1, int(round(usable / PLANTER_TARGET_SPACING)))
			var step := usable / float(count + 1)
			for i in range(1, count + 1):
				planter_ts.append(t_med_0 + 2.0 + float(i) * step)
	else:
		# Cuadra estándar con luminarias: subdivisión rítmica inteligente por tramos intermedios
		# 1. Tramo inicial: Nariz del camellón -> Primer poste
		var dist_start: float = float(light_ts[0]) - t_med_0 - 2.0
		if dist_start >= PLANTER_LIGHT_SAFETY_MARGIN * 2.0:
			var k_start: int = maxi(1, int(round((dist_start - PLANTER_LIGHT_SAFETY_MARGIN) / PLANTER_TARGET_SPACING)))
			var step_start: float = (dist_start - PLANTER_LIGHT_SAFETY_MARGIN) / float(k_start + 1)
			for j in range(1, k_start + 1):
				planter_ts.append(t_med_0 + 2.0 + float(j) * step_start)

		# 2. Tramos intermedios: Entre postes consecutivos (equidistancia simétrica)
		for i in range(light_ts.size() - 1):
			var span_len: float = float(light_ts[i + 1]) - float(light_ts[i])
			var usable_span: float = span_len - 2.0 * PLANTER_LIGHT_SAFETY_MARGIN
			if usable_span >= 3.0:
				var k_mid: int = maxi(1, int(round(usable_span / PLANTER_TARGET_SPACING)))
				var step_mid: float = usable_span / float(k_mid + 1)
				for j in range(1, k_mid + 1):
					planter_ts.append(float(light_ts[i]) + PLANTER_LIGHT_SAFETY_MARGIN + float(j) * step_mid)

		# 3. Tramo final: Último poste -> Nariz final
		var dist_end: float = t_med_1 - 2.0 - float(light_ts.back())
		if dist_end >= PLANTER_LIGHT_SAFETY_MARGIN * 2.0:
			var k_end: int = maxi(1, int(round((dist_end - PLANTER_LIGHT_SAFETY_MARGIN) / PLANTER_TARGET_SPACING)))
			var step_end: float = (dist_end - PLANTER_LIGHT_SAFETY_MARGIN) / float(k_end + 1)
			for j in range(1, k_end + 1):
				planter_ts.append(float(light_ts.back()) + PLANTER_LIGHT_SAFETY_MARGIN + float(j) * step_end)

	var transforms: Array[Transform3D] = []
	for t in planter_ts:
		var pos := p0 + fwd * t + Vector3(0.0, y_pos, 0.0)
		transforms.append(Transform3D(seg_basis, pos))

	return transforms


## Retorna todos los transforms de macetas cuadradas en la red vial
func get_all_median_planter_transforms() -> Array[Transform3D]:
	var all_xf: Array[Transform3D] = []
	for seg_id in _segments:
		all_xf.append_array(get_median_planter_transforms_for_segment(seg_id))
	return all_xf


## Instancia macetas cuadradas mediante GPU Hardware Instancing (MultiMeshInstance3D)
## con cajón de cantera/concreto, tierra vegetal y vegetación ProceduralTree (shrub_sapling).
func spawn_median_planters(parent_node: Node3D, with_vegetation: bool = true, target_seg_id: int = -1) -> Dictionary:
	var xforms: Array[Transform3D] = get_median_planter_transforms_for_segment(target_seg_id) if target_seg_id != -1 else get_all_median_planter_transforms()
	if xforms.is_empty():
		return {}

	var count := xforms.size()

	var group_root := Node3D.new()
	group_root.name = "MedianPlanters_GPU_Instanced"
	parent_node.add_child(group_root)

	# Material de concreto/cantera urbana para las jardineras cuadradas
	var concrete_mat := StandardMaterial3D.new()
	concrete_mat.albedo_color = Color(0.56, 0.56, 0.55) # Cantera / concreto urbano mate
	concrete_mat.roughness = 0.88

	# Material de tierra vegetal húmeda
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.18, 0.14, 0.10)
	soil_mat.roughness = 0.95

	# 1. MultiMesh para cajones de concreto de 1.20m x 0.55m x 1.20m
	var mm_planters := MultiMesh.new()
	mm_planters.transform_format = MultiMesh.TRANSFORM_3D
	mm_planters.instance_count = count
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(PLANTER_SQUARE_SIZE, PLANTER_SQUARE_HEIGHT, PLANTER_SQUARE_SIZE)
	box_mesh.material = concrete_mat
	mm_planters.mesh = box_mesh

	# 2. MultiMesh para tierra fértil interior
	var mm_soil := MultiMesh.new()
	mm_soil.transform_format = MultiMesh.TRANSFORM_3D
	mm_soil.instance_count = count
	var soil_mesh := BoxMesh.new()
	soil_mesh.size = Vector3(PLANTER_SQUARE_SIZE - 0.16, 0.05, PLANTER_SQUARE_SIZE - 0.16)
	soil_mesh.material = soil_mat
	mm_soil.mesh = soil_mesh

	var spawned_plants: Array[Node3D] = []

	for i in range(count):
		var xf := xforms[i]

		# Transform del cajón de la maceta (elevado la mitad de su altura sobre el camellón)
		var planter_xf := xf.translated_local(Vector3(0.0, PLANTER_SQUARE_HEIGHT * 0.5, 0.0))
		mm_planters.set_instance_transform(i, planter_xf)

		# Transform de la tierra (en la parte superior de la maceta)
		var soil_xf := xf.translated_local(Vector3(0.0, PLANTER_SQUARE_HEIGHT - 0.02, 0.0))
		mm_soil.set_instance_transform(i, soil_xf)

		# 3. Vegetación procedural dentro de la maceta (ProceduralTree perfil shrub_sapling)
		if with_vegetation:
			var shrub: Node3D = PROCEDURAL_TREE_SCRIPT.new()
			shrub.set("profile_id", "shrub_sapling")
			shrub.set("tree_seed", randi())
			# Escala proporcional de arbusto para encajar orgánicamente en la maceta urbana
			shrub.scale = Vector3(0.40, 0.40, 0.40)
			group_root.add_child(shrub)
			var plant_pos := xf.origin + Vector3(0.0, PLANTER_SQUARE_HEIGHT - 0.08, 0.0)
			shrub.global_position = plant_pos
			shrub.rotation.y = fmod(float(i * 123.7), 360.0) * (PI / 180.0)
			spawned_plants.append(shrub)

	var inst_planters := MultiMeshInstance3D.new()
	inst_planters.name = "PlanterBoxes_120cm_GPU"
	inst_planters.multimesh = mm_planters
	group_root.add_child(inst_planters)

	var inst_soil := MultiMeshInstance3D.new()
	inst_soil.name = "PlanterSoil_GPU"
	inst_soil.multimesh = mm_soil
	group_root.add_child(inst_soil)

	return {
		"root": group_root,
		"planters": inst_planters,
		"soil": inst_soil,
		"plants": spawned_plants
	}


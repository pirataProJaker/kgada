class_name RoadBlueprintTool
extends Node3D
## Herramienta interactiva del jugador: Plano de Carretera, Constructor y Banqueta.
## - Modo 1 (PLANO): Apunta a un extremo, orienta la dirección (flecha 3D) y fija el ángulo.
## - Modo 2 (CONSTRUCTOR): Muestra previsualización holográfica y construye el tramo continuo.
## - Modo 3 (BANQUETA): Apunta a la orilla de una carretera y aplica la banqueta paralela independiente.

const RoadTrajectorySystem = preload("res://world/city/road_trajectory_system.gd")

enum ToolMode {
	BLUEPRINT_DIRECTION, # Plano: definir ángulo y dirección en un endpoint
	ROAD_BUILDER,        # Constructor: previsualizar y generar tramo
	SIDEWALK_PLACER,     # Banqueta: colocar/quitar acera en orillas
}

@export var road_system: RoadTrajectorySystem
@export var default_segment_length: float = 16.0
@export var angle_snap_degrees: float = 15.0

var current_mode: ToolMode = ToolMode.BLUEPRINT_DIRECTION
var selected_endpoint_id: int = -1
var proposed_angle_degrees: float = 0.0

# Nodos visuales del Gizmo/Indicador
var _indicator_root: Node3D
var _arrow_mesh: MeshInstance3D
var _ring_mesh: MeshInstance3D
var _ghost_preview: MeshInstance3D


func _ready() -> void:
	_setup_visual_gizmos()


func _setup_visual_gizmos() -> void:
	_indicator_root = Node3D.new()
	_indicator_root.name = "DirectionGizmo"
	_indicator_root.visible = false
	add_child(_indicator_root)

	# Anillo base sobre el suelo
	_ring_mesh = MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 2.0
	torus.bottom_radius = 2.0
	torus.height = 0.08
	_ring_mesh.mesh = torus

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.8, 1.0, 0.65)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mesh.material_override = ring_mat
	_indicator_root.add_child(_ring_mesh)

	# Flecha de dirección
	_arrow_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 2.5, 0.12)
	_arrow_mesh.mesh = prism
	_arrow_mesh.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_arrow_mesh.position = Vector3(0.0, 0.15, -2.5)

	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color(1.0, 0.85, 0.1, 0.9)
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_mesh.material_override = arrow_mat
	_indicator_root.add_child(_arrow_mesh)

	# Malla holográfica de previsualización del tramo
	_ghost_preview = MeshInstance3D.new()
	_ghost_preview.name = "GhostPreview"
	_ghost_preview.visible = false
	var ghost_box := BoxMesh.new()
	_ghost_preview.mesh = ghost_box

	var ghost_mat := StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.2, 0.9, 0.4, 0.45)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_preview.material_override = ghost_mat
	add_child(_ghost_preview)


## Convierte un ángulo en grados a un vector director unitario horizontal
## 0° = Norte (-Z), 90° = Este (+X), 180° = Sur (+Z), -90° = Oeste (-X)
static func angle_to_direction(degrees: float) -> Vector3:
	var rad := deg_to_rad(degrees)
	return Vector3(sin(rad), 0.0, -cos(rad)).normalized()


## Convierte un vector director horizontal a un ángulo en grados [-180, 180]
static func direction_to_angle(dir: Vector3) -> float:
	return rad_to_deg(atan2(dir.x, -dir.z))


## Apunta hacia un punto en el mundo (ej. desde el raycast de la cámara)
func handle_cursor_hover(world_hit: Vector3) -> void:
	if road_system == null:
		return

	match current_mode:
		ToolMode.BLUEPRINT_DIRECTION:
			_update_blueprint_hover(world_hit)
		ToolMode.ROAD_BUILDER:
			_update_builder_hover(world_hit)
		ToolMode.SIDEWALK_PLACER:
			_update_sidewalk_hover(world_hit)


## Acción principal (clic izquierdo)
func handle_action_click(world_hit: Vector3) -> bool:
	if road_system == null:
		return false

	match current_mode:
		ToolMode.BLUEPRINT_DIRECTION:
			# Confirmar dirección en el endpoint seleccionado
			if selected_endpoint_id > 0:
				var dir := angle_to_direction(proposed_angle_degrees)
				road_system.set_endpoint_direction(selected_endpoint_id, dir)
				print("[PlanoCarretera] Dirección fijada en endpoint %d: %.1f grados" % [selected_endpoint_id, proposed_angle_degrees])
				return true
		ToolMode.ROAD_BUILDER:
			# Construir tramo a partir del endpoint hacia adelante
			if selected_endpoint_id > 0:
				var dir := angle_to_direction(proposed_angle_degrees)
				var new_seg := road_system.extend_road(selected_endpoint_id, default_segment_length, dir)
				if new_seg != null:
					print("[ConstructorCarretera] Tramo construido! Nuevo endpoint al final: %d" % new_seg.end_endpoint_id)
					selected_endpoint_id = new_seg.end_endpoint_id
					var new_ep := road_system.get_endpoint(selected_endpoint_id)
					if new_ep != null:
						proposed_angle_degrees = direction_to_angle(new_ep.direction)
					return true
		ToolMode.SIDEWALK_PLACER:
			# Aplicar/quitar banqueta en la orilla apuntada
			var nearest_side := _find_nearest_segment_side(world_hit)
			if nearest_side["segment_id"] > 0:
				var active := road_system.toggle_sidewalk(nearest_side["segment_id"], nearest_side["is_left"])
				print("[HerramientaBanqueta] Banqueta %s en tramo %d: %s" % [
					"Izquierda" if nearest_side["is_left"] else "Derecha",
					nearest_side["segment_id"],
					"ACTIVADA" if active else "QUITADA"
				])
				return true
	return false


## Gira la dirección del plano en grados (con rueda del ratón o teclas)
func rotate_direction(delta_degrees: float) -> void:
	proposed_angle_degrees = wrapf(proposed_angle_degrees + delta_degrees, -180.0, 180.0)
	if angle_snap_degrees > 0.0:
		proposed_angle_degrees = roundf(proposed_angle_degrees / angle_snap_degrees) * angle_snap_degrees
	_update_gizmo_display()


# ==============================================================================
# LÓGICA INTERNA DE MODOS
# ==============================================================================

func _update_blueprint_hover(hit_pos: Vector3) -> void:
	var nearest_ep := _find_nearest_endpoint(hit_pos, 10.0)
	if nearest_ep != null:
		selected_endpoint_id = nearest_ep.id
		var offset := hit_pos - nearest_ep.position
		if offset.length() > 1.2:
			var target_angle := direction_to_angle(offset)
			if angle_snap_degrees > 0.0:
				target_angle = roundf(target_angle / angle_snap_degrees) * angle_snap_degrees
			proposed_angle_degrees = target_angle

	_update_gizmo_display()
	_ghost_preview.visible = false


func _update_gizmo_display() -> void:
	var ep: RoadTrajectorySystem.RoadEndpoint = road_system.get_endpoint(selected_endpoint_id) if (road_system != null and selected_endpoint_id > 0) else null
	if ep != null and current_mode == ToolMode.BLUEPRINT_DIRECTION:
		_indicator_root.visible = true
		_indicator_root.position = ep.position + Vector3(0.0, 0.08, 0.0)
		var dir := angle_to_direction(proposed_angle_degrees)
		_indicator_root.transform.basis = Basis.looking_at(dir, Vector3.UP)
	else:
		_indicator_root.visible = false


func _update_builder_hover(_hit_pos: Vector3) -> void:
	_indicator_root.visible = false
	var ep: RoadTrajectorySystem.RoadEndpoint = road_system.get_endpoint(selected_endpoint_id) if selected_endpoint_id > 0 else null
	if ep == null:
		_ghost_preview.visible = false
		return

	_ghost_preview.visible = true
	var dir := angle_to_direction(proposed_angle_degrees)
	var half_len := default_segment_length * 0.5
	var center := ep.position + dir * half_len + Vector3(0.0, 0.06, 0.0)

	var box_mesh: BoxMesh = _ghost_preview.mesh
	box_mesh.size = Vector3(ep.width, 0.06, default_segment_length)
	_ghost_preview.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), center)

	var ghost_mat: StandardMaterial3D = _ghost_preview.material_override
	ghost_mat.albedo_color = Color(0.2, 0.9, 0.4, 0.45)


func _update_sidewalk_hover(hit_pos: Vector3) -> void:
	_indicator_root.visible = false
	var nearest := _find_nearest_segment_side(hit_pos)
	if nearest["segment_id"] <= 0:
		_ghost_preview.visible = false
		return

	var seg: RoadTrajectorySystem.RoadSegment = road_system.get_segment(nearest["segment_id"])
	if seg == null:
		_ghost_preview.visible = false
		return

	_ghost_preview.visible = true
	var fwd := (seg.end_pos - seg.start_pos).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	var length := (seg.end_pos - seg.start_pos).length()

	var offsets := road_system.get_sidewalk_offsets(seg.id)
	var t_start: float = offsets.get("start_left" if nearest["is_left"] else "start_right", 0.0)
	var t_end: float = offsets.get("end_left" if nearest["is_left"] else "end_right", 0.0)
	var sw_len := maxf(length - t_start - t_end, 0.5)

	var p_start := seg.start_pos + fwd * t_start
	var p_end := seg.end_pos - fwd * t_end
	var side_sign := -1.0 if nearest["is_left"] else 1.0
	var sw_width := 2.5
	var sw_center := (p_start + p_end) * 0.5 + right * (side_sign * (seg.width * 0.5 + sw_width * 0.5)) + Vector3(0.0, 0.15, 0.0)

	var box_mesh: BoxMesh = _ghost_preview.mesh
	box_mesh.size = Vector3(sw_width, 0.22, sw_len)
	_ghost_preview.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), sw_center)

	var already_has := seg.has_left_sidewalk if nearest["is_left"] else seg.has_right_sidewalk
	var ghost_mat: StandardMaterial3D = _ghost_preview.material_override
	if already_has:
		# Naranja / Rojo: Indica quitar banqueta existente
		ghost_mat.albedo_color = Color(1.0, 0.35, 0.2, 0.60)
	else:
		# Verde esmeralda: Indica colocar banqueta nueva
		ghost_mat.albedo_color = Color(0.1, 0.9, 0.45, 0.60)


func _update_gizmo_rotation() -> void:
	var dir := angle_to_direction(proposed_angle_degrees)
	_indicator_root.transform.basis = Basis.looking_at(dir, Vector3.UP)


func _find_nearest_endpoint(hit_pos: Vector3, max_dist: float) -> RoadTrajectorySystem.RoadEndpoint:
	var best_ep: RoadTrajectorySystem.RoadEndpoint = null
	var best_dist := max_dist

	for item in road_system.get_all_endpoints():
		var ep: RoadTrajectorySystem.RoadEndpoint = item
		var d := hit_pos.distance_to(ep.position)
		if d < best_dist:
			best_dist = d
			best_ep = ep

	return best_ep


func _find_nearest_segment_side(hit_pos: Vector3) -> Dictionary:
	var best_seg_id := -1
	var is_left := false
	var best_dist := 4.5 # Umbral de tolerancia estricto cerca de la arista real

	for item in road_system.get_all_segments():
		var seg: RoadTrajectorySystem.RoadSegment = item
		var p0: Vector3 = seg.start_pos
		var p1: Vector3 = seg.end_pos
		var delta: Vector3 = p1 - p0
		var seg_len := delta.length()
		if seg_len <= 0.001:
			continue

		var fwd := delta / seg_len
		var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
		var half_w := seg.width * 0.5
		var sw_offset := half_w + 1.25 # Centro de la franja de banqueta (ancho 2.5m)

		var t := clampf((hit_pos - p0).dot(fwd) / seg_len, 0.0, 1.0)
		var proj_center := p0 + fwd * (t * seg_len)

		var left_sw_pos := proj_center - right * sw_offset
		var right_sw_pos := proj_center + right * sw_offset

		var dist_left := hit_pos.distance_to(left_sw_pos)
		var dist_right := hit_pos.distance_to(right_sw_pos)

		if dist_left < best_dist and dist_left <= dist_right:
			best_dist = dist_left
			best_seg_id = seg.id
			is_left = true
		elif dist_right < best_dist and dist_right < dist_left:
			best_dist = dist_right
			best_seg_id = seg.id
			is_left = false

	return {"segment_id": best_seg_id, "is_left": is_left, "distance": best_dist}

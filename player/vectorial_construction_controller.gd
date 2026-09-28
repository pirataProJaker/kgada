extends Node
class_name VectorialConstructionController
## Controlador de Construcción Vectorial 3D.
## Gestiona:
## 1. Detección de herramientas en mano (Palo, Cuaderno/Estacas, Plano/Cal).
## 2. Apertura contextual de la rueda radial con clic derecho.
## 3. Pisos: Trazado libre sin restricciones (P0 donde sea), mínimo 1x1m, 3D rascado y LOD.
## 4. Paredes:
##    - Exclusivamente sobre un piso existente.
##    - Anclaje magnético automático a las orillas del piso cuando el cursor se aproxima.
##    - Flujo guiado de 3 pasos: Clic 1 (P0 en piso) -> Paso 2 (Altura) -> Paso 3 (Largo en piso) -> Clic 3 (Construir).
## 5. Fantasma holográfico 3D y etiqueta flotante con medidas en tiempo real.
## 6. Asignación y bloqueo de material al hacer clic con madera o piedra en la mano.

signal mode_changed(new_mode_name: String)

@export var max_reach_distance: float = 25.0
@export var ray_collision_mask: int = 1

var player: CharacterBody3D
var camera: Camera3D
var inventory: Inventory
var construction_engine: Node3D # ConstructionEngine (Rust)

const ConstructionVisualMarkerScript = preload("res://world/building/construction_visual_marker.gd")

var active_tool_info: Dictionary = {}
var active_element_type: int = 0 # 0: Floor, 1: Wall, 2: Ceiling, 3: DoorFrame, 4: WindowFrame, -1: Demolish
var active_material_type: int = 5 # 5: Frame (sin material asignado inicialmente)
var active_mode_name: String = "Piso"

# Estado de colocación para Pisos / Techos (2 clics directos)
var first_point: Variant = null # Vector3 o null
var current_preview_point: Vector3 = Vector3.ZERO
var visual_marker: Node3D

# Estado de colocación para Paredes (Flujo de 3 Pasos: P0 en piso -> Altura -> Largo en piso)
enum WallStep {
	IDLE = 0,           # Sin punto fijado
	SETTING_HEIGHT = 1, # P0 fijado en piso. Ajustando Altura H
	SETTING_LENGTH = 2  # Altura H confirmada. Ajustando Largo P1 dentro del rango del piso
}

var wall_step: int = WallStep.IDLE
var wall_p0: Vector3 = Vector3.ZERO
var wall_current_height: float = 2.5
var wall_locked_height: float = 2.5
var wall_active_floor: Dictionary = {}

# Visualización Fantasma (Holograma de medidas futuras)
var ghost_mesh: MeshInstance3D
var dimension_label: Label3D
var _ghost_mat: StandardMaterial3D
var _delete_mat: StandardMaterial3D
var _aiming_marker: MeshInstance3D
var _aiming_mat: StandardMaterial3D

# Estado de colocación para Ventanas (Flujo de 2 Pasos: Esquina inicial -> Tamaño flexible)
enum WindowStep {
	IDLE = 0,
	SETTING_SIZE = 1
}
var window_step: int = WindowStep.IDLE
var window_target_site: PlannedSite = null
var window_start_t: float = 0.0
var window_start_y: float = 0.0
var window_hovered_opening_id: int = -1
var door_hovered_opening_id: int = -1

# Menú Radial
var radial_menu: BuildingRadialMenu

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		inventory = player.get_node_or_null("Inventory") as Inventory
		camera = player.get_node_or_null("Head/Camera3D") as Camera3D

	# Instanciar marcador visual
	visual_marker = ConstructionVisualMarkerScript.new()
	add_child(visual_marker)

	# Crear componentes del Fantasma Holográfico 3D y Apuntado
	_setup_ghost_preview()

	# Buscar o crear nodo ConstructionEngine
	_ensure_construction_engine()

	# Configurar menús UI
	_setup_ui_menus()

func _setup_ghost_preview() -> void:
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.2, 0.75, 1.0, 0.40) # Cian etéreo
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ghost_mat.emission_enabled = true
	_ghost_mat.emission = Color(0.1, 0.55, 0.95)
	_ghost_mat.emission_energy_multiplier = 0.65

	_delete_mat = StandardMaterial3D.new()
	_delete_mat.albedo_color = Color(1.0, 0.20, 0.20, 0.55) # Rojo advertencia de eliminación
	_delete_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_delete_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_delete_mat.emission_enabled = true
	_delete_mat.emission = Color(0.95, 0.15, 0.15)
	_delete_mat.emission_energy_multiplier = 0.85

	ghost_mesh = MeshInstance3D.new()
	ghost_mesh.visible = false
	add_child(ghost_mesh)

	dimension_label = Label3D.new()
	dimension_label.visible = false
	dimension_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dimension_label.no_depth_test = true
	dimension_label.font_size = 28
	dimension_label.outline_size = 8
	dimension_label.outline_modulate = Color(0.05, 0.05, 0.05, 0.95)
	dimension_label.modulate = Color(1.0, 0.92, 0.35)
	add_child(dimension_label)

	# Marcador de apuntado en suelo antes del primer clic (P0)
	_aiming_marker = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.25
	_aiming_marker.mesh = torus

	_aiming_mat = StandardMaterial3D.new()
	_aiming_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
	_aiming_mat.emission_enabled = true
	_aiming_mat.emission = Color(1.0, 0.75, 0.15)
	_aiming_mat.emission_energy_multiplier = 0.8
	_aiming_marker.material_override = _aiming_mat
	_aiming_marker.visible = false
	add_child(_aiming_marker)

func _get_world_node() -> Node:
	if is_inside_tree():
		var tree := get_tree()
		if tree:
			if tree.current_scene != null:
				return tree.current_scene
			elif tree.root != null:
				return tree.root
	var main_tree := Engine.get_main_loop() as SceneTree
	if main_tree:
		if main_tree.current_scene != null:
			return main_tree.current_scene
		elif main_tree.root != null:
			return main_tree.root
	return null

func _ensure_construction_engine() -> void:
	var world_node := _get_world_node()
	if world_node:
		construction_engine = world_node.get_node_or_null("ConstructionEngine")
		if construction_engine == null:
			if ClassDB.class_exists("ConstructionEngine"):
				construction_engine = ClassDB.instantiate("ConstructionEngine")
				world_node.add_child.call_deferred(construction_engine)
				print("[VectorialConstruction] Nodo ConstructionEngine (Rust) instanciado en el mundo.")

func _setup_ui_menus() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var radial_scene = load("res://ui/building/building_radial_menu.tscn")
	if radial_scene:
		radial_menu = radial_scene.instantiate()
		canvas.add_child(radial_menu)
		radial_menu.element_selected.connect(_on_radial_element_selected)

func _get_building_manager() -> Node:
	if is_inside_tree():
		var node = get_node_or_null("/root/BuildingManager")
		if node != null:
			return node
	var main_tree := Engine.get_main_loop() as SceneTree
	if main_tree and main_tree.root:
		return main_tree.root.get_node_or_null("BuildingManager")
	return null

func _get_inventory() -> Inventory:
	if inventory != null:
		return inventory
	if player != null:
		inventory = player.get_node_or_null("Inventory") as Inventory
		return inventory
	var p = get_parent() as CharacterBody3D
	if p:
		player = p
		inventory = p.get_node_or_null("Inventory") as Inventory
		return inventory
	return null

func _process(_delta: float) -> void:
	# Actualizar herramienta y material en mano
	var bm = _get_building_manager()
	if bm and bm.has_method("get_equipped_construction_tool"):
		active_tool_info = bm.get_equipped_construction_tool(player)
	else:
		active_tool_info = {}
	var has_tool: bool = not active_tool_info.is_empty()
	var held_mat: int = _detect_held_material_type()

	# 1. Si el jugador tiene Madera o Piedra en la mano (modo Edificación)
	if held_mat >= 0:
		if first_point != null or wall_step != WallStep.IDLE or window_step != WindowStep.IDLE:
			_cancel_placement()
		if visual_marker:
			visual_marker.call("clear")
		_process_material_building_hover(held_mat)
		return

	# 2. Si el jugador NO tiene herramienta de construcción en la mano (manos vacías, comida, etc.)
	# NO se muestra ningún cursor de trazado ni se permite interactuar con vanos
	if not has_tool:
		if first_point != null or wall_step != WallStep.IDLE or window_step != WindowStep.IDLE:
			_cancel_placement()
		if visual_marker:
			visual_marker.call("clear")
		if _aiming_marker:
			_aiming_marker.visible = false
		if ghost_mesh:
			ghost_mesh.visible = false
		if dimension_label:
			dimension_label.visible = false
		return

	# 3. El jugador TIENE el Palo / Cuaderno / Plano en la mano:
	# ==============================================================================
	# CASO 1: MODO PARED (active_element_type == 1) - Flujo de 3 Pasos sobre Piso
	# ==============================================================================
	if active_element_type == 1:
		_process_wall_mode()
		return

	# ==============================================================================
	# CASO 2: MODO VANO (Puerta o Ventana) (active_element_type == 3 ó 4)
	# ==============================================================================
	if active_element_type == 3 or active_element_type == 4:
		_process_opening_planning_mode()
		return

	# ==============================================================================
	# CASO 3: MODO PISO / TECHO (active_element_type == 0 ó 2) - Flujo Libre de 2 Clics
	# ==============================================================================
	_process_floor_mode()

## Muestra feedback visual cuando el jugador sostiene Madera o Piedra en la mano
func _process_material_building_hover(held_mat: int) -> void:
	var hit: Variant = _raycast_from_camera()
	if hit == null:
		if _aiming_marker: _aiming_marker.visible = false
		if dimension_label: dimension_label.visible = false
		if ghost_mesh: ghost_mesh.visible = false
		return

	var raw_pos: Vector3 = hit["position"]
	var collider = hit.get("collider")
	var site := _get_planned_site_from_collider(collider)
	if site == null:
		site = _find_planned_site_near(raw_pos, 1.2)

	var mat_name := _get_material_name(held_mat)

	if site != null:
		# Apuntando a un trazado planificado con Madera o Piedra en mano
		_aiming_mat.albedo_color = Color(0.20, 0.95, 0.35, 0.90) # Verde edificar
		_aiming_mat.emission = Color(0.15, 0.90, 0.25)
		_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
		_aiming_marker.visible = true

		var site_type := "Pared" if site.element_type == 1 else ("Piso" if site.element_type == 0 else "Techo")
		dimension_label.text = "🔨 [Clic Izq]: Edificar %s con %s" % [site_type, mat_name]
		dimension_label.modulate = Color(0.4, 1.0, 0.4)
		dimension_label.global_position = raw_pos + Vector3(0, 0.65, 0)
		dimension_label.visible = true
		if ghost_mesh: ghost_mesh.visible = false
		return

	# Si apunta a una estructura ya construida en ConstructionEngine
	if construction_engine and construction_engine.has_method("get_element_material_at"):
		var cur_mat: int = construction_engine.call("get_element_material_at", raw_pos)
		if cur_mat >= 0:
			if cur_mat == 5: # Frame
				_aiming_mat.albedo_color = Color(0.20, 0.95, 0.35, 0.90)
				_aiming_mat.emission = Color(0.15, 0.90, 0.25)
				dimension_label.text = "🔨 [Clic Izq]: Convertir a %s" % mat_name
				dimension_label.modulate = Color(0.4, 1.0, 0.4)
			elif cur_mat == held_mat:
				_aiming_mat.albedo_color = Color(0.30, 0.80, 1.0, 0.85)
				_aiming_mat.emission = Color(0.20, 0.70, 0.95)
				dimension_label.text = "🔨 [Clic Izq]: Aportar %s (Mantenimiento)" % mat_name
				dimension_label.modulate = Color(0.7, 0.9, 1.0)
			else:
				var cur_name := _get_material_name(cur_mat)
				_aiming_mat.albedo_color = Color(1.0, 0.25, 0.25, 0.85)
				_aiming_mat.emission = Color(0.95, 0.15, 0.15)
				dimension_label.text = "❌ Estructura de %s (No acepta %s)" % [cur_name, mat_name]
				dimension_label.modulate = Color(1.0, 0.35, 0.35)

			_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
			_aiming_marker.visible = true
			dimension_label.global_position = raw_pos + Vector3(0, 0.65, 0)
			dimension_label.visible = true
			if ghost_mesh: ghost_mesh.visible = false
			return

	if _aiming_marker: _aiming_marker.visible = false
	if dimension_label: dimension_label.visible = false
	if ghost_mesh: ghost_mesh.visible = false

## Procesa la interacción en tiempo real para planificar o eliminar vanos (Puertas y Ventanas)
func _process_opening_planning_mode() -> void:
	# 1. Si estamos en modo Ventana y en el paso de definir tamaño flexible
	if active_element_type == 4 and window_step == WindowStep.SETTING_SIZE:
		if not is_instance_valid(window_target_site):
			window_step = WindowStep.IDLE
			window_target_site = null
			_cancel_placement()
			return

		var p0: Vector3 = window_target_site.p0
		var p1: Vector3 = window_target_site.p1
		var wall_h: float = window_target_site.height
		var wall_dir := p1 - p0
		var wall_len := wall_dir.length()
		if wall_len < 0.01:
			_cancel_placement()
			return

		var u := wall_dir / wall_len
		var wall_normal := Vector3(-u.z, 0.0, u.x)
		var wall_plane := Plane(wall_normal, p0.dot(wall_normal))

		var cam_from: Vector3
		var cam_dir: Vector3
		if camera:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				cam_from = camera.global_position
				cam_dir = -camera.global_transform.basis.z
			else:
				var m_pos := camera.get_viewport().get_mouse_position()
				cam_from = camera.project_ray_origin(m_pos)
				cam_dir = camera.project_ray_normal(m_pos)

		var inter: Variant = wall_plane.intersects_ray(cam_from, cam_dir)
		var cur_pos: Vector3 = inter as Vector3 if inter != null else (p0 + u * window_start_t + Vector3(0, window_start_y, 0))
		var cur_t := clampf((cur_pos - p0).dot(u), 0.0, wall_len)
		var cur_y := clampf(cur_pos.y - p0.y, 0.0, wall_h)

		var t_min := minf(window_start_t, cur_t)
		var t_max := maxf(window_start_t, cur_t)
		if (t_max - t_min) < 0.3:
			if cur_t >= window_start_t:
				t_max = minf(t_min + 0.3, wall_len)
				t_min = maxf(0.0, t_max - 0.3)
			else:
				t_min = maxf(0.0, t_max - 0.3)
				t_max = minf(t_min + 0.3, wall_len)

		var y_min := clampf(minf(window_start_y, cur_y), 0.05, wall_h - 0.15)
		var y_max := clampf(maxf(window_start_y, cur_y), y_min + 0.2, wall_h)

		# Auto-snapping inteligente a marco de puerta o vano inferior si se coloca arriba
		for op in window_target_site.openings:
			var op_t_min: float = op.get("t_min", 0.0)
			var op_t_max: float = op.get("t_max", 1.0)
			var op_y_top: float = op.get("y_top", 2.1)
			if minf(t_max, op_t_max) - maxf(t_min, op_t_min) > 0.10:
				if absf(y_min - op_y_top) < 0.25:
					y_min = op_y_top
					if y_max < y_min + 0.2:
						y_max = minf(wall_h, y_min + 0.25)

		var win_w := t_max - t_min
		var win_h := y_max - y_min

		# Holograma 3D del vano de ventana flexible
		var angle_rad := atan2(u.z, u.x)
		var box := BoxMesh.new()
		box.size = Vector3(win_w, win_h, 0.22)
		var can_place_win: bool = window_target_site.can_add_opening(t_min, t_max, y_min, y_max)
		box.material = _ghost_mat if can_place_win else _delete_mat
		ghost_mesh.mesh = box
		ghost_mesh.rotation = Vector3(0, -angle_rad, 0)
		var center_t := (t_min + t_max) * 0.5
		var center_y := (y_min + y_max) * 0.5
		ghost_mesh.global_position = p0 + u * center_t + Vector3(0, center_y, 0)
		ghost_mesh.visible = true

		if can_place_win:
			dimension_label.text = "🪟 Paso 2/2: Ventana = %.1fm ancho × %.1fm alto (Antepecho: %.1fm)\n[Clic Izq: Confirmar • Clic Der / Esc: Cancelar]" % [win_w, win_h, y_min]
			dimension_label.modulate = Color(0.4, 0.9, 1.0)
		else:
			dimension_label.text = "❌ La ventana se superpone con otro vano existente\n[Ajusta el tamaño o posición]"
			dimension_label.modulate = Color(1.0, 0.35, 0.35)

		dimension_label.global_position = ghost_mesh.global_position + Vector3(0, win_h * 0.5 + 0.45, 0)
		dimension_label.visible = true

		if _aiming_marker: _aiming_marker.visible = false
		return

	# 2. Estado IDLE (apuntando con selector de Puerta o Ventana)
	var hit: Variant = _raycast_from_camera()
	if hit == null:
		if _aiming_marker: _aiming_marker.visible = false
		if dimension_label: dimension_label.visible = false
		if ghost_mesh: ghost_mesh.visible = false
		return

	var raw_pos: Vector3 = hit["position"]
	var collider = hit.get("collider")

	var site: PlannedSite = null
	if collider is CollisionObject3D:
		var meta_site = collider.get_meta("planned_site", null)
		if meta_site is PlannedSite:
			site = meta_site
		elif collider.get_parent() is PlannedSite:
			site = collider.get_parent()

	# Caso A: Golpea una estructura construida permanente en ConstructionEngine
	if site == null:
		var is_built_wall: bool = false
		if construction_engine and construction_engine.has_method("get_element_material_at"):
			var cur_mat: int = construction_engine.call("get_element_material_at", raw_pos)
			if cur_mat >= 0:
				is_built_wall = true

		if is_built_wall:
			# REGLA 5: "una vez construida, no se podra editar esa construccion"
			_aiming_mat.albedo_color = Color(1.0, 0.20, 0.20, 0.85)
			_aiming_mat.emission = Color(0.95, 0.15, 0.15)
			_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
			_aiming_marker.visible = true

			dimension_label.text = "❌ La pared ya está construida.\nLos vanos solo se pueden planificar antes de poner madera o piedra."
			dimension_label.modulate = Color(1.0, 0.35, 0.35)
			dimension_label.global_position = raw_pos + Vector3(0, 0.65, 0)
			dimension_label.visible = true
			if ghost_mesh: ghost_mesh.visible = false
			return
		else:
			# Apuntando al suelo/terreno o vacío
			_aiming_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
			_aiming_mat.emission = Color(1.0, 0.75, 0.15)
			_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
			_aiming_marker.visible = true

			var elem_name := "puerta" if active_element_type == 3 else "ventana"
			dimension_label.text = "ℹ️ Apunta a un trazado de pared para planificar la %s" % elem_name
			dimension_label.modulate = Color(1.0, 0.92, 0.35)
			dimension_label.global_position = raw_pos + Vector3(0, 0.55, 0)
			dimension_label.visible = true
			if ghost_mesh: ghost_mesh.visible = false
			return

	# Caso B: Golpea un trazado, pero es Piso o Techo (no es Pared)
	if site.element_type != 1:
		_aiming_mat.albedo_color = Color(1.0, 0.25, 0.25, 0.85)
		_aiming_mat.emission = Color(0.95, 0.15, 0.15)
		_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
		_aiming_marker.visible = true

		var elem_plural := "puertas" if active_element_type == 3 else "ventanas"
		dimension_label.text = "❌ Las %s solo se pueden planificar en trazados de pared." % elem_plural
		dimension_label.modulate = Color(1.0, 0.35, 0.35)
		dimension_label.global_position = raw_pos + Vector3(0, 0.55, 0)
		dimension_label.visible = true
		if ghost_mesh: ghost_mesh.visible = false
		return

	# Caso C: Golpea un trazado de pared (PlannedSite element_type == 1)
	var p0: Vector3 = site.p0
	var p1: Vector3 = site.p1
	var wall_h: float = site.height
	var wall_dir := p1 - p0
	var wall_len := wall_dir.length()
	if wall_len < 0.01:
		return

	var u := wall_dir / wall_len
	var angle_rad := atan2(u.z, u.x)

	# REGLA 4: Comprobar si el cursor está sobre un vano existente del mismo tipo
	var hovered_op: Dictionary = site.find_opening_at(raw_pos, active_element_type)
	if not hovered_op.is_empty():
		var op_id: int = hovered_op.get("id", -1)
		var t_min: float = hovered_op.get("t_min", 0.0)
		var t_max: float = hovered_op.get("t_max", 1.0)
		var y_min: float = hovered_op.get("y_bottom", 0.0)
		var y_max: float = hovered_op.get("y_top", 2.1)
		var op_w := t_max - t_min
		var op_h := y_max - y_min

		# Holograma en rojo de eliminación ("si le damos click... se quitara esa planeacion")
		var box := BoxMesh.new()
		box.size = Vector3(op_w + 0.05, op_h + 0.05, 0.28)
		box.material = _delete_mat
		ghost_mesh.mesh = box
		ghost_mesh.rotation = Vector3(0, -angle_rad, 0)
		var center_pos := p0 + u * ((t_min + t_max) * 0.5) + Vector3(0, (y_min + y_max) * 0.5, 0)
		ghost_mesh.global_position = center_pos
		ghost_mesh.visible = true

		var op_name := "puerta" if active_element_type == 3 else "ventana"
		dimension_label.text = "🗑️ Quitar %s planificada (%.1fm)\n[Clic Izq: Eliminar esta planeación]" % [op_name, op_w]
		dimension_label.modulate = Color(1.0, 0.35, 0.35)
		dimension_label.global_position = center_pos + Vector3(0, op_h * 0.5 + 0.45, 0)
		dimension_label.visible = true

		if _aiming_marker: _aiming_marker.visible = false
		if active_element_type == 3:
			door_hovered_opening_id = op_id
		else:
			window_hovered_opening_id = op_id
		return

	# Si no está sobre un vano existente, preparar colocación nueva
	door_hovered_opening_id = -1
	window_hovered_opening_id = -1

	var t_raw := (raw_pos - p0).dot(u)

	if active_element_type == 3:
		# REGLA 2: "las puertas siempre deben ponerse ancladas al piso, porque actualmente permite ponerlas volando"
		var door_w := 1.30 # Puerta más ancha y cómoda para cruzar
		var door_h := minf(2.1, wall_h)
		var t_center := clampf(t_raw, door_w * 0.5, maxf(door_w * 0.5, wall_len - door_w * 0.5))
		var t_min := t_center - door_w * 0.5
		var t_max := t_center + door_w * 0.5
		var can_place_door: bool = site.can_add_opening(t_min, t_max, 0.0, door_h)

		# Base de la puerta estrictamente en Y = p0.y (anclada sobre el piso)
		var door_center_pos := p0 + u * t_center + Vector3(0.0, door_h * 0.5, 0.0)

		var box := BoxMesh.new()
		box.size = Vector3(door_w, door_h, 0.22)
		box.material = _ghost_mat if can_place_door else _delete_mat
		ghost_mesh.mesh = box
		ghost_mesh.rotation = Vector3(0, -angle_rad, 0)
		ghost_mesh.global_position = door_center_pos
		ghost_mesh.visible = true

		if can_place_door:
			dimension_label.text = "🚪 Puerta planificada: %.1fm × %.1fm (Anclada al piso)\n[Clic Izq: Colocar en trazado]" % [door_w, door_h]
			dimension_label.modulate = Color(0.35, 1.0, 0.90)
		else:
			dimension_label.text = "❌ Ya existe un vano en esta posición\n[Elige otra sección de la pared]"
			dimension_label.modulate = Color(1.0, 0.35, 0.35)

		dimension_label.global_position = door_center_pos + Vector3(0, door_h * 0.5 + 0.45, 0)
		dimension_label.visible = true
		if _aiming_marker: _aiming_marker.visible = false

	elif active_element_type == 4:
		# REGLA 3: "las ventanas deben ser de tamaño flexible" (Paso 1: Punto inicial)
		var t_clamped := clampf(t_raw, 0.1, wall_len - 0.1)
		var y_rel := clampf(raw_pos.y - p0.y, 0.05, wall_h - 0.1)
		var win_point_pos := p0 + u * t_clamped + Vector3(0.0, y_rel, 0.0)

		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.6, 0.22)
		box.material = _ghost_mat
		ghost_mesh.mesh = box
		ghost_mesh.rotation = Vector3(0, -angle_rad, 0)
		ghost_mesh.global_position = win_point_pos
		ghost_mesh.visible = true

		dimension_label.text = "🪟 Ventana (Tamaño flexible)\n[Clic 1: Fijar esquina inicial de la ventana]"
		dimension_label.modulate = Color(0.55, 0.88, 1.0)
		dimension_label.global_position = win_point_pos + Vector3(0, 0.55, 0)
		dimension_label.visible = true
		if _aiming_marker: _aiming_marker.visible = false

## Procesa la interacción específica del Modo Pared
func _process_wall_mode() -> void:
	var hit: Variant = _raycast_from_camera()

	match wall_step:
		WallStep.IDLE:
			# Paso 1: Apuntando al piso antes de fijar P0
			if hit == null:
				if _aiming_marker: _aiming_marker.visible = false
				if dimension_label: dimension_label.visible = false
				return

			var raw_pos: Vector3 = hit["position"]
			var snap_info := _snap_point_to_floors(raw_pos, 0.45)

			if not snap_info.get("valid", false):
				# Cursor fuera de cualquier piso: Advertencia en rojo
				_aiming_mat.albedo_color = Color(1.0, 0.20, 0.20, 0.85)
				_aiming_mat.emission = Color(0.95, 0.15, 0.15)
				_aiming_marker.global_position = raw_pos + Vector3(0, 0.04, 0)
				_aiming_marker.visible = true

				dimension_label.text = "❌ Las paredes solo se pueden colocar dentro de un piso"
				dimension_label.modulate = Color(1.0, 0.35, 0.35)
				dimension_label.global_position = raw_pos + Vector3(0, 0.55, 0)
				dimension_label.visible = true
				if ghost_mesh: ghost_mesh.visible = false
			else:
				# Cursor sobre un piso válido: Anclaje y magnetismo a la orilla
				var is_edge: bool = snap_info.get("is_on_edge", false)
				var snapped_pos: Vector3 = snap_info.get("position", raw_pos)

				if is_edge:
					# Anclado a la orilla del piso (Magnético)
					_aiming_mat.albedo_color = Color(0.15, 0.95, 0.85, 0.90) # Turquesa magnético
					_aiming_mat.emission = Color(0.10, 0.90, 0.80)
					dimension_label.text = "🧲 Orilla de piso [Clic: Fijar inicio de pared]"
					dimension_label.modulate = Color(0.35, 1.0, 0.90)
				else:
					# Interior del piso
					_aiming_mat.albedo_color = Color(0.30, 0.80, 1.0, 0.85) # Azul piso
					_aiming_mat.emission = Color(0.20, 0.70, 0.95)
					dimension_label.text = "🧱 Sobre piso [Clic: Fijar inicio de pared]"
					dimension_label.modulate = Color(0.90, 0.95, 1.0)

				_aiming_marker.global_position = snapped_pos + Vector3(0, 0.04, 0)
				_aiming_marker.visible = true
				dimension_label.global_position = snapped_pos + Vector3(0, 0.55, 0)
				dimension_label.visible = true
				if ghost_mesh: ghost_mesh.visible = false

		WallStep.SETTING_HEIGHT:
			# Paso 2: P0 fijado. El usuario mueve el ratón para definir la ALTURA
			if _aiming_marker: _aiming_marker.visible = false

			wall_current_height = _calculate_wall_height_from_camera(wall_p0)

			# Previsualizar poste vertical / columna holográfica de altura H en P0
			var post_box := BoxMesh.new()
			post_box.size = Vector3(0.28, wall_current_height, 0.28)
			post_box.material = _ghost_mat
			ghost_mesh.mesh = post_box
			ghost_mesh.rotation = Vector3.ZERO
			ghost_mesh.global_position = Vector3(wall_p0.x, wall_p0.y + wall_current_height * 0.5, wall_p0.z)
			ghost_mesh.visible = true

			dimension_label.text = "📏 Paso 2/3: Altura de pared = %.1f m\n[Mueve el ratón arriba/abajo • Clic Izq: Confirmar Altura]" % wall_current_height
			dimension_label.modulate = Color(1.0, 0.92, 0.35)
			dimension_label.global_position = Vector3(wall_p0.x, wall_p0.y + wall_current_height + 0.55, wall_p0.z)
			dimension_label.visible = true

			# Marcador de tierra/estacas en P0
			var marker_type: String = active_tool_info.get("marker_type", "dirt_scrape")
			visual_marker.setup(marker_type, [wall_p0, wall_p0 + Vector3(0.01, 0, 0.01)])

		WallStep.SETTING_LENGTH:
			# Paso 3: Altura fijada. El usuario mueve el ratón para definir el LARGO dentro del rango del piso
			if _aiming_marker: _aiming_marker.visible = false

			var raw_pos: Vector3
			if hit != null:
				raw_pos = hit["position"]
			else:
				# Si no hay colisión física (apuntando al horizonte, cielo o vacío),
				# proyectar rayo de cámara contra el plano horizontal del piso
				var floor_y: float = wall_p0.y
				var floor_plane := Plane(Vector3.UP, floor_y)
				var cam_from: Vector3
				var cam_dir: Vector3
				if camera != null:
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
						cam_from = camera.global_position
						cam_dir = -camera.global_transform.basis.z
					else:
						var m_pos := camera.get_viewport().get_mouse_position()
						cam_from = camera.project_ray_origin(m_pos)
						cam_dir = camera.project_ray_normal(m_pos)

					var inter: Variant = floor_plane.intersects_ray(cam_from, cam_dir)
					if inter != null and (inter as Vector3).distance_to(cam_from) <= 35.0:
						raw_pos = inter
					else:
						# Mirando horizontal o arriba: proyectar en el plano XZ hacia adelante
						var horiz_dir := Vector3(cam_dir.x, 0.0, cam_dir.z).normalized()
						if horiz_dir.length_squared() < 0.01:
							horiz_dir = Vector3(1, 0, 0)
						raw_pos = Vector3(cam_from.x + horiz_dir.x * 6.0, floor_y, cam_from.z + horiz_dir.z * 6.0)
				else:
					raw_pos = wall_p0 + Vector3(1, 0, 0)

			var snapped_p1: Vector3 = _constrain_wall_p1_to_floor(raw_pos, wall_p0, wall_active_floor)
			current_preview_point = snapped_p1

			var dx: float = current_preview_point.x - wall_p0.x
			var dz: float = current_preview_point.z - wall_p0.z
			var dist_2d: float = maxf(Vector2(dx, dz).length(), 1.0)

			# Holograma 3D de la pared completa (Largo × Altura bloqueada)
			var angle_rad: float = atan2(current_preview_point.z - wall_p0.z, current_preview_point.x - wall_p0.x)
			var wall_box := BoxMesh.new()
			wall_box.size = Vector3(dist_2d, wall_locked_height, 0.20)

			var is_wall_overlap: bool = _check_wall_overlap(wall_p0, current_preview_point)
			wall_box.material = _delete_mat if is_wall_overlap else _ghost_mat
			ghost_mesh.mesh = wall_box
			ghost_mesh.rotation = Vector3(0, -angle_rad, 0)
			ghost_mesh.global_position = Vector3(
				(wall_p0.x + current_preview_point.x) * 0.5,
				wall_p0.y + wall_locked_height * 0.5,
				(wall_p0.z + current_preview_point.z) * 0.5
			)
			ghost_mesh.visible = true

			var min_x: float = wall_active_floor.get("min_x", wall_p0.x - 5.0)
			var max_x: float = wall_active_floor.get("max_x", wall_p0.x + 5.0)
			var min_z: float = wall_active_floor.get("min_z", wall_p0.z - 5.0)
			var max_z: float = wall_active_floor.get("max_z", wall_p0.z + 5.0)
			var is_edge: bool = (absf(current_preview_point.x - min_x) <= 0.05 \
				or absf(current_preview_point.x - max_x) <= 0.05 \
				or absf(current_preview_point.z - min_z) <= 0.05 \
				or absf(current_preview_point.z - max_z) <= 0.05)
			var edge_str := " (🧲 Anclado a orilla)" if is_edge else ""

			if is_wall_overlap:
				dimension_label.text = "❌ Ya existe una pared en esta posición\n[Elige otra posición o dirección]"
				dimension_label.modulate = Color(1.0, 0.35, 0.35)
			else:
				dimension_label.text = "📐 Paso 3/3: Pared = %.1fm largo × %.1fm alto%s\n[Clic Izq: Construir • Clic Der: Reajustar Altura]" % [dist_2d, wall_locked_height, edge_str]
				dimension_label.modulate = Color(1.0, 0.92, 0.35)

			dimension_label.global_position = Vector3(
				(wall_p0.x + current_preview_point.x) * 0.5,
				wall_p0.y + wall_locked_height + 0.65,
				(wall_p0.z + current_preview_point.z) * 0.5
			)
			dimension_label.visible = true

			# Marcador de marco perimetral 3D en la pared ("debe verse con una linea toda su orilla y ya")
			var marker_type: String = active_tool_info.get("marker_type", "dirt_scrape")
			var b0 := wall_p0 + Vector3(0.0, 0.02, 0.0)
			var b1 := current_preview_point + Vector3(0.0, 0.02, 0.0)
			var t1 := b1 + Vector3(0.0, wall_locked_height, 0.0)
			var t0 := b0 + Vector3(0.0, wall_locked_height, 0.0)
			visual_marker.setup(marker_type, [b0, b1, t1, t0, b0])

## Procesa el flujo estándar de Pisos / Techos (P0 libre -> P1 libre continuo)
func _process_floor_mode() -> void:
	# Si NO hay punto fijado todavía (antes de P0), mostrar cursor de apuntado libre en tiempo real
	# REGLA: "el fantasmas del punto nunca se debe meter a donde ya haya suelo construido, el punto del fantasmas del suele debe rodear las construcciones de suelo ya existente"
	if first_point == null:
		var hit: Variant = _raycast_from_camera()
		if hit != null and _aiming_marker:
			var raw_hit: Vector3 = hit["position"]
			var collider = hit.get("collider")

			# Si el raycast golpea directamente un piso (PlannedSite o ConstructionEngine),
			# nivelar raw_hit.y a la base del piso para que el punto de construcción
			# NUNCA escale sobre la losa (grosor pequeño de 0.20m), a menos que sea una pared.
			var hit_floor_y: Variant = null
			var site := _get_planned_site_from_collider(collider)
			if site != null and (site.element_type == 0 or site.element_type == 2):
				hit_floor_y = site.p0.y
			else:
				for fl in _get_all_floors():
					if raw_hit.x >= fl["min_x"] - 0.10 and raw_hit.x <= fl["max_x"] + 0.10 and \
					   raw_hit.z >= fl["min_z"] - 0.10 and raw_hit.z <= fl["max_z"] + 0.10 and \
					   absf(raw_hit.y - fl.get("y", raw_hit.y)) <= 0.8:
						hit_floor_y = fl["y"]
						break

			if hit_floor_y != null:
				raw_hit.y = hit_floor_y

			var proj_info := _project_point_outside_floors(raw_hit, 0.40)
			var snapped_pos: Vector3 = proj_info.get("position", raw_hit)
			var is_edge: bool = proj_info.get("is_on_edge", false)
			var was_inside: bool = proj_info.get("was_inside", false)

			if is_edge or was_inside:
				# Rodeando / contorneando la orilla exterior de un piso existente
				_aiming_mat.albedo_color = Color(0.15, 0.95, 0.85, 0.90) # Turquesa contorno
				_aiming_mat.emission = Color(0.10, 0.90, 0.80)
				_aiming_marker.global_position = snapped_pos + Vector3(0, 0.04, 0)
				_aiming_marker.visible = true

				dimension_label.text = "🧲 Orilla de piso existente [Clic: Iniciar nuevo piso contiguo]"
				dimension_label.modulate = Color(0.35, 1.0, 0.90)
				dimension_label.global_position = snapped_pos + Vector3(0, 0.55, 0)
				dimension_label.visible = true
			else:
				# Suelo libre / terreno
				_aiming_mat.albedo_color = Color(1.0, 0.85, 0.25, 0.85)
				_aiming_mat.emission = Color(1.0, 0.75, 0.15)
				_aiming_marker.global_position = snapped_pos + Vector3(0, 0.04, 0)
				_aiming_marker.visible = true

				dimension_label.text = "⛏️ Suelo libre [Clic: Iniciar trazado de piso]"
				dimension_label.modulate = Color(1.0, 0.92, 0.35)
				dimension_label.global_position = snapped_pos + Vector3(0, 0.55, 0)
				dimension_label.visible = true
		elif _aiming_marker:
			_aiming_marker.visible = false
			if dimension_label: dimension_label.visible = false
		return

	# Si ya tenemos P0, ocultar indicador simple de P0 y calcular P1 continuamente
	if _aiming_marker:
		_aiming_marker.visible = false

	if camera:
		var hit: Variant = _raycast_from_camera()
		if hit != null:
			var raw_hit: Vector3 = hit["position"]
			# 1. Proyectar y constreñir P1 para no penetrar pisos existentes al arrastrar
			var constrained_p1: Vector3 = _constrain_floor_p1_against_floors(first_point, raw_hit)
			var snapped_hit: Vector3 = constrained_p1

			if construction_engine and construction_engine.has_method("calc_snap_point"):
				snapped_hit = construction_engine.calc_snap_point(first_point, constrained_p1, 0)
			else:
				var dx: float = constrained_p1.x - first_point.x
				var dz: float = constrained_p1.z - first_point.z
				var clamped_dx: float = (1.0 if dx >= 0.0 else -1.0) if absf(dx) < 1.0 else dx
				var clamped_dz: float = (1.0 if dz >= 0.0 else -1.0) if absf(dz) < 1.0 else dz
				snapped_hit = Vector3(first_point.x + clamped_dx, first_point.y, first_point.z + clamped_dz)

			current_preview_point = snapped_hit

			# Actualizar trazador visual (toda la orilla perimetral rascada en tierra con LOD)
			var marker_type: String = active_tool_info.get("marker_type", "dirt_scrape")
			var min_x: float = minf(first_point.x, current_preview_point.x)
			var max_x: float = maxf(first_point.x, current_preview_point.x)
			var min_z: float = minf(first_point.z, current_preview_point.z)
			var max_z: float = maxf(first_point.z, current_preview_point.z)
			var y_coord: float = first_point.y

			var c0 := Vector3(min_x, y_coord, min_z)
			var c1 := Vector3(max_x, y_coord, min_z)
			var c2 := Vector3(max_x, y_coord, max_z)
			var c3 := Vector3(min_x, y_coord, max_z)
			var pts: Array[Vector3] = [c0, c1, c2, c3, c0]

			visual_marker.setup(marker_type, pts)

			# Actualizar fantasma y mediciones en tiempo real
			var p0: Vector3 = first_point
			var p1: Vector3 = current_preview_point
			var w: float = maxf(absf(p1.x - p0.x), 1.0)
			var d: float = maxf(absf(p1.z - p0.z), 1.0)
			var area_est: float = w * d

			var is_floor_overlap: bool = _check_floor_rect_overlap(p0, p1)

			var box := BoxMesh.new()
			box.size = Vector3(w, 0.20, d)
			box.material = _delete_mat if is_floor_overlap else _ghost_mat
			ghost_mesh.mesh = box
			ghost_mesh.rotation = Vector3.ZERO
			ghost_mesh.global_position = Vector3((p0.x + p1.x) * 0.5, p0.y + 0.10, (p0.z + p1.z) * 0.5)
			ghost_mesh.visible = true

			if is_floor_overlap:
				dimension_label.text = "❌ No se puede construir suelo donde ya hay suelo\n[Reduce o cambia el trazado]"
				dimension_label.modulate = Color(1.0, 0.35, 0.35)
			else:
				dimension_label.text = "📐 %.1fm × %.1fm  (%.1f m²)" % [w, d, area_est]
				dimension_label.modulate = Color(1.0, 0.92, 0.35)

			dimension_label.global_position = Vector3((p0.x + p1.x) * 0.5, p0.y + 0.70, (p0.z + p1.z) * 0.5)
			dimension_label.visible = true

## Calcula dinámicamente la altura de la pared según hacia dónde mire la cámara del jugador
func _calculate_wall_height_from_camera(origin: Vector3) -> float:
	if camera == null:
		return 2.5

	var cam_pos := camera.global_position
	var mouse_pos := camera.get_viewport().get_mouse_position() if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED else Vector2.ZERO
	var ray_dir: Vector3 = -camera.global_transform.basis.z if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else camera.project_ray_normal(mouse_pos)

	# Proyección geométrica sobre el eje vertical que pasa por origin (P0)
	var horiz_dist := Vector2(origin.x - cam_pos.x, origin.z - cam_pos.z).length()
	var ray_horiz_len := Vector2(ray_dir.x, ray_dir.z).length()

	var t: float = horiz_dist / maxf(ray_horiz_len, 0.05)
	var y_at_wall: float = cam_pos.y + ray_dir.y * t
	var raw_h: float = y_at_wall - origin.y

	# Si el raycast físico golpea una superficie elevada, comprobar altura
	var hit: Variant = _raycast_from_camera()
	if hit != null:
		var hit_pos: Vector3 = hit["position"]
		var hit_h: float = hit_pos.y - origin.y
		if hit_h > 0.8 and absf(hit_pos.x - origin.x) < 2.0 and absf(hit_pos.z - origin.z) < 2.0:
			raw_h = hit_h

	# Mínimo 1 metro estricto, máximo 8 metros
	var clamped_h: float = clampf(raw_h, 1.0, 8.0)

	# Magnetismo suave a alturas estándar (2.0m, 2.5m, 3.0m, 3.5m)
	for standard_h in [2.0, 2.5, 3.0, 3.5, 4.0]:
		if absf(clamped_h - standard_h) < 0.12:
			return standard_h

	return snappedf(clamped_h, 0.05)

## Recopila todos los pisos existentes (en ConstructionEngine y en PlannedSite)
func _get_all_floors() -> Array[Dictionary]:
	var floors: Array[Dictionary] = []

	# 1. Pisos construidos en ConstructionEngine
	if construction_engine and construction_engine.has_method("get_floor_spans"):
		var engine_spans: Array = construction_engine.call("get_floor_spans")
		for s in engine_spans:
			floors.append(s)

	# 2. Sitios de piso delimitados en PlannedSite en el mundo
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var candidate_sites: Array = []
	if tree:
		candidate_sites = tree.get_nodes_in_group("planned_sites")

	var world_node := _get_world_node()
	if candidate_sites.is_empty() and world_node:
		candidate_sites = world_node.find_children("*", "", true, false)

	for child in candidate_sites:
		if child is PlannedSite and not child.is_queued_for_deletion():
			if child.element_type == 0 or child.element_type == 2:
				var p0: Vector3 = child.p0
				var p1: Vector3 = child.p1
				floors.append({
					"min_x": minf(p0.x, p1.x),
					"max_x": maxf(p0.x, p1.x),
					"min_z": minf(p0.z, p1.z),
					"max_z": maxf(p0.z, p1.z),
					"y": p0.y,
					"site": child
				})

	return floors

## Comprueba si un punto XZ se encuentra estrictamente dentro de algún piso
func _is_point_inside_any_floor(pos: Vector3, margin: float = 0.02) -> bool:
	for fl in _get_all_floors():
		if absf(pos.y - fl.get("y", pos.y)) > 1.2:
			continue
		var min_x: float = fl["min_x"]
		var max_x: float = fl["max_x"]
		var min_z: float = fl["min_z"]
		var max_z: float = fl["max_z"]
		if pos.x > (min_x + margin) and pos.x < (max_x - margin) and \
		   pos.z > (min_z + margin) and pos.z < (max_z - margin):
			return true
	return false

## REGLA: El fantasma del punto nunca debe meterse dentro de un piso construido;
## debe rodear las construcciones de piso existentes adaptándose a su orilla exterior.
func _project_point_outside_floors(raw_pos: Vector3, edge_snap_dist: float = 0.40) -> Dictionary:
	var pos := raw_pos
	var all_floors := _get_all_floors()
	if all_floors.is_empty():
		return {"position": pos, "is_on_edge": false, "was_inside": false, "floor": {}}

	var was_inside := false
	var is_on_edge := false
	var matched_floor: Dictionary = {}

	# Realizar hasta 3 pasadas para empujar el punto al perímetro exterior si cae dentro de pisos
	for _iter in range(3):
		var adjusted := false
		for fl in all_floors:
			if absf(pos.y - fl.get("y", pos.y)) > 1.2:
				continue
			var min_x: float = fl["min_x"]
			var max_x: float = fl["max_x"]
			var min_z: float = fl["min_z"]
			var max_z: float = fl["max_z"]

			# Si el cursor cae dentro del piso (con margen de seguridad de 0.01m)
			if pos.x > (min_x + 0.01) and pos.x < (max_x - 0.01) and \
			   pos.z > (min_z + 0.01) and pos.z < (max_z - 0.01):
				was_inside = true
				is_on_edge = true
				matched_floor = fl

				# Distancias a los 4 bordes exteriores
				var d_w := pos.x - min_x
				var d_e := max_x - pos.x
				var d_n := pos.z - min_z
				var d_s := max_z - pos.z
				var min_d := minf(minf(d_w, d_e), minf(d_n, d_s))

				if min_d == d_w: pos.x = min_x
				elif min_d == d_e: pos.x = max_x
				elif min_d == d_n: pos.z = min_z
				else: pos.z = max_z
				adjusted = true
				break
		if not adjusted:
			break

	# Si está fuera pero cerca de una orilla exterior, anclaje magnético al contorno
	if not was_inside and edge_snap_dist > 0.0:
		for fl in all_floors:
			if absf(pos.y - fl.get("y", pos.y)) > 1.2:
				continue
			var min_x: float = fl["min_x"]
			var max_x: float = fl["max_x"]
			var min_z: float = fl["min_z"]
			var max_z: float = fl["max_z"]

			var clamped_x := clampf(pos.x, min_x, max_x)
			var clamped_z := clampf(pos.z, min_z, max_z)
			var dist_sq := (pos.x - clamped_x) * (pos.x - clamped_x) + (pos.z - clamped_z) * (pos.z - clamped_z)

			if dist_sq <= edge_snap_dist * edge_snap_dist:
				var d_w := absf(pos.x - min_x)
				var d_e := absf(pos.x - max_x)
				var d_n := absf(pos.z - min_z)
				var d_s := absf(pos.z - max_z)

				var near_x := pos.x >= (min_x - edge_snap_dist) and pos.x <= (max_x + edge_snap_dist)
				var near_z := pos.z >= (min_z - edge_snap_dist) and pos.z <= (max_z + edge_snap_dist)

				if near_z and d_w <= edge_snap_dist and (d_w <= d_n and d_w <= d_s):
					pos.x = min_x
					is_on_edge = true
					matched_floor = fl
				elif near_z and d_e <= edge_snap_dist and (d_e <= d_n and d_e <= d_s):
					pos.x = max_x
					is_on_edge = true
					matched_floor = fl
				elif near_x and d_n <= edge_snap_dist:
					pos.z = min_z
					is_on_edge = true
					matched_floor = fl
				elif near_x and d_s <= edge_snap_dist:
					pos.z = max_z
					is_on_edge = true
					matched_floor = fl
	# REGLA: El piso tiene una altura/espesor de losa (0.20m).
	# A diferencia de las paredes (que legítimamente descansan SOBRE el piso a y + 0.20m),
	# el trazado de pisos y contornos NUNCA debe escalar en altura sobre la losa del piso.
	# Su altura Y debe fijarse rígidamente al plano base del piso (fl["y"]).
	if not matched_floor.is_empty():
		pos.y = matched_floor.get("y", pos.y)

	return {
		"position": pos,
		"is_on_edge": is_on_edge,
		"was_inside": was_inside,
		"floor": matched_floor
	}

## Comprueba si un rectángulo de piso propuesto [p0, p1] se superpone con algún piso existente
func _check_floor_rect_overlap(p0: Vector3, p1: Vector3, exclude_site: PlannedSite = null) -> bool:
	var min_x := minf(p0.x, p1.x)
	var max_x := maxf(p0.x, p1.x)
	var min_z := minf(p0.z, p1.z)
	var max_z := maxf(p0.z, p1.z)

	var all_floors := _get_all_floors()
	for fl in all_floors:
		if exclude_site != null and fl.get("site") == exclude_site:
			continue
		if absf(p0.y - fl.get("y", p0.y)) > 1.0:
			continue

		var fl_min_x: float = fl["min_x"]
		var fl_max_x: float = fl["max_x"]
		var fl_min_z: float = fl["min_z"]
		var fl_max_z: float = fl["max_z"]

		# Medida de solapamiento en ambos ejes (con margen de 0.05m para permitir compartir arista contigua)
		var overlap_w := minf(max_x, fl_max_x) - maxf(min_x, fl_min_x)
		var overlap_d := minf(max_z, fl_max_z) - maxf(min_z, fl_min_z)

		if overlap_w > 0.05 and overlap_d > 0.05:
			return true

	return false

## Restringe P1 durante el arrastre para detenerse al borde de un piso existente si se expande hacia él
func _constrain_floor_p1_against_floors(p0: Vector3, raw_p1: Vector3) -> Vector3:
	var result_p1 := raw_p1
	var all_floors := _get_all_floors()
	if all_floors.is_empty():
		return result_p1

	for fl in all_floors:
		if absf(p0.y - fl.get("y", p0.y)) > 1.0:
			continue
		var fl_min_x: float = fl["min_x"]
		var fl_max_x: float = fl["max_x"]
		var fl_min_z: float = fl["min_z"]
		var fl_max_z: float = fl["max_z"]

		var proposed_min_z := minf(p0.z, result_p1.z)
		var proposed_max_z := maxf(p0.z, result_p1.z)
		var z_overlaps := maxf(proposed_min_z, fl_min_z) < minf(proposed_max_z, fl_max_z) - 0.05

		var proposed_min_x := minf(p0.x, result_p1.x)
		var proposed_max_x := maxf(p0.x, result_p1.x)
		var x_overlaps := maxf(proposed_min_x, fl_min_x) < minf(proposed_max_x, fl_max_x) - 0.05

		# Si P0 está al oeste y arrastra al este hacia el piso
		if z_overlaps and p0.x <= fl_min_x and result_p1.x > fl_min_x:
			if absf(result_p1.x - fl_min_x) < 2.0 or result_p1.x < fl_max_x:
				result_p1.x = fl_min_x

		# Si P0 está al este y arrastra al oeste hacia el piso
		if z_overlaps and p0.x >= fl_max_x and result_p1.x < fl_max_x:
			if absf(result_p1.x - fl_max_x) < 2.0 or result_p1.x > fl_min_x:
				result_p1.x = fl_max_x

		# Si P0 está al norte y arrastra al sur hacia el piso
		if x_overlaps and p0.z <= fl_min_z and result_p1.z > fl_min_z:
			if absf(result_p1.z - fl_min_z) < 2.0 or result_p1.z < fl_max_z:
				result_p1.z = fl_min_z

		# Si P0 está al sur y arrastra al norte hacia el piso
		if x_overlaps and p0.z >= fl_max_z and result_p1.z < fl_max_z:
			if absf(result_p1.z - fl_max_z) < 2.0 or result_p1.z > fl_min_z:
				result_p1.z = fl_max_z

	return result_p1

## Recopila todas las paredes existentes (en ConstructionEngine y en PlannedSite)
func _get_all_walls() -> Array[Dictionary]:
	var walls: Array[Dictionary] = []

	# 1. Paredes construidas en ConstructionEngine
	if construction_engine and construction_engine.has_method("get_wall_spans"):
		var engine_spans: Array = construction_engine.call("get_wall_spans")
		for s in engine_spans:
			walls.append(s)

	# 2. Sitios de pared delimitados en PlannedSite en el mundo
	var tree: SceneTree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	var candidate_sites: Array = []
	if tree:
		candidate_sites = tree.get_nodes_in_group("planned_sites")

	var world_node := _get_world_node()
	if candidate_sites.is_empty() and world_node:
		candidate_sites = world_node.find_children("*", "", true, false)

	for child in candidate_sites:
		if child is PlannedSite and child.element_type == 1 and not child.is_queued_for_deletion():
			walls.append({
				"p0": child.p0,
				"p1": child.p1,
				"height": child.height,
				"site": child
			})

	return walls

## Comprueba si un tramo propuesto de pared se superpone con una pared colineal ya existente
func _check_wall_overlap(p0: Vector3, p1: Vector3, exclude_site: PlannedSite = null) -> bool:
	var delta_a := Vector2(p1.x - p0.x, p1.z - p0.z)
	var len_a := delta_a.length()
	if len_a < 0.20:
		return false
	var u_a := delta_a / len_a

	var all_walls := _get_all_walls()
	for w in all_walls:
		if exclude_site != null and w.get("site") == exclude_site:
			continue

		var wp0: Vector3 = w["p0"]
		var wp1: Vector3 = w["p1"]
		var w_height: float = float(w.get("height", 2.5))

		# Comprobar solapamiento en altura Y (mismo nivel de piso)
		var min_ya := p0.y
		var max_ya := p0.y + wall_locked_height
		var min_yb := wp0.y
		var max_yb := wp0.y + w_height
		var y_overlap := minf(max_ya, max_yb) - maxf(min_ya, min_yb)
		if y_overlap < 0.30:
			continue

		var delta_b := Vector2(wp1.x - wp0.x, wp1.z - wp0.z)
		var len_b := delta_b.length()
		if len_b < 0.20:
			continue
		var u_b := delta_b / len_b

		# Comprobar paralelismo / colinealidad (producto escalar cercano a 1 o -1)
		var dot := u_a.dot(u_b)
		if absf(dot) < 0.85:
			# Paredes perpendiculares o en ángulo (esquinas, cruces en T): PERMITIDO
			continue

		# Comprobar distancia perpendicular entre ambas líneas
		var v0 := Vector2(wp0.x - p0.x, wp0.z - p0.z)
		var perp_dist := absf(v0.x * u_a.y - v0.y * u_a.x)
		if perp_dist > 0.25:
			# Líneas paralelas separadas (ej. paredes opuestas de una habitación): PERMITIDO
			continue

		# Proyectar extremos de pared B sobre la línea de pared A
		var t_b0 := v0.dot(u_a)
		var v1 := Vector2(wp1.x - p0.x, wp1.z - p0.z)
		var t_b1 := v1.dot(u_a)

		var min_tb := minf(t_b0, t_b1)
		var max_tb := maxf(t_b0, t_b1)

		# Intervalo de solapamiento longitudinal
		var overlap_start := maxf(0.0, min_tb)
		var overlap_end := minf(len_a, max_tb)
		var overlap_len := overlap_end - overlap_start

		if overlap_len > 0.15:
			# Superposición longitudinal colineal: PROHIBIDO (ya existe una pared en este tramo)
			return true

	return false


## Ancla un punto al piso más cercano, con magnetismo a la orilla
func _snap_point_to_floors(raw_pos: Vector3, edge_threshold: float = 0.40) -> Dictionary:
	var all_floors := _get_all_floors()
	if all_floors.is_empty():
		return {
			"valid": false,
			"position": raw_pos,
			"is_on_edge": false,
			"is_corner": false,
			"edge_index": -1,
			"floor": null
		}

	var best_result: Dictionary = {}
	var min_dist_sq := 999999.0

	for fl in all_floors:
		var res: Dictionary
		if construction_engine and construction_engine.has_method("snap_point_to_rect"):
			res = construction_engine.call("snap_point_to_rect",
				raw_pos, fl["min_x"], fl["max_x"], fl["min_z"], fl["max_z"], fl["y"], edge_threshold)
		else:
			res = _snap_rect_fallback(raw_pos, fl, edge_threshold)

		if res.get("valid", false):
			var pos_res: Vector3 = res.get("position", raw_pos)
			var d_sq := Vector2(pos_res.x - raw_pos.x, pos_res.z - raw_pos.z).length_squared()
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_result = res
				best_result["floor"] = fl

	if best_result.is_empty():
		return {
			"valid": false,
			"position": raw_pos,
			"is_on_edge": false,
			"is_corner": false,
			"edge_index": -1,
			"floor": null
		}

	return best_result

## Ancla un punto específicamente al piso activo seleccionado en el Paso 1
func _snap_point_to_active_floor(raw_pos: Vector3, edge_threshold: float = 0.40) -> Dictionary:
	if wall_active_floor.is_empty():
		return _snap_point_to_floors(raw_pos, edge_threshold)

	var fl := wall_active_floor
	if construction_engine and construction_engine.has_method("snap_point_to_rect"):
		var res: Dictionary = construction_engine.call("snap_point_to_rect",
			raw_pos, fl["min_x"], fl["max_x"], fl["min_z"], fl["max_z"], fl["y"], edge_threshold)
		res["floor"] = fl
		return res
	else:
		var res := _snap_rect_fallback(raw_pos, fl, edge_threshold)
		res["floor"] = fl
		return res

## Respaldo de anclaje magnético rectangular en GDScript
func _snap_rect_fallback(pos: Vector3, fl: Dictionary, edge_threshold: float) -> Dictionary:
	var min_x: float = fl["min_x"]
	var max_x: float = fl["max_x"]
	var min_z: float = fl["min_z"]
	var max_z: float = fl["max_z"]
	var floor_surface_y: float = fl.get("y", 0.0) + 0.20 # Superficie superior de la losa de piso (0.20m de espesor)

	var inset := 0.10 # Inset de medio espesor de pared para que el muro descanse 100% sobre el piso
	var in_min_x := minf(min_x + inset, max_x - inset)
	var in_max_x := maxf(max_x - inset, min_x + inset)
	var in_min_z := minf(min_z + inset, max_z - inset)
	var in_max_z := maxf(max_z - inset, min_z + inset)

	var clamped_x := clampf(pos.x, min_x, max_x)
	var clamped_z := clampf(pos.z, min_z, max_z)
	var dist_to_rect_sq := (pos.x - clamped_x) * (pos.x - clamped_x) + (pos.z - clamped_z) * (pos.z - clamped_z)

	if dist_to_rect_sq > 1.5 * 1.5:
		return {"valid": false, "position": pos, "is_on_edge": false, "is_corner": false, "edge_index": -1}

	var d_west := absf(pos.x - min_x)
	var d_east := absf(pos.x - max_x)
	var d_north := absf(pos.z - min_z)
	var d_south := absf(pos.z - max_z)

	var near_w := d_west <= edge_threshold
	var near_e := d_east <= edge_threshold
	var near_n := d_north <= edge_threshold
	var near_s := d_south <= edge_threshold

	var in_clamped_x := clampf(pos.x, in_min_x, in_max_x)
	var in_clamped_z := clampf(pos.z, in_min_z, in_max_z)

	if near_n and near_w:
		return {"valid": true, "position": Vector3(in_min_x, floor_surface_y, in_min_z), "is_on_edge": true, "is_corner": true, "edge_index": 0}
	if near_n and near_e:
		return {"valid": true, "position": Vector3(in_max_x, floor_surface_y, in_min_z), "is_on_edge": true, "is_corner": true, "edge_index": 0}
	if near_s and near_w:
		return {"valid": true, "position": Vector3(in_min_x, floor_surface_y, in_max_z), "is_on_edge": true, "is_corner": true, "edge_index": 2}
	if near_s and near_e:
		return {"valid": true, "position": Vector3(in_max_x, floor_surface_y, in_max_z), "is_on_edge": true, "is_corner": true, "edge_index": 2}

	var min_d := minf(minf(d_west, d_east), minf(d_north, d_south))
	if min_d <= edge_threshold:
		if min_d == d_west:
			return {"valid": true, "position": Vector3(in_min_x, floor_surface_y, in_clamped_z), "is_on_edge": true, "is_corner": false, "edge_index": 3}
		elif min_d == d_east:
			return {"valid": true, "position": Vector3(in_max_x, floor_surface_y, in_clamped_z), "is_on_edge": true, "is_corner": false, "edge_index": 1}
		elif min_d == d_north:
			return {"valid": true, "position": Vector3(in_clamped_x, floor_surface_y, in_min_z), "is_on_edge": true, "is_corner": false, "edge_index": 0}
		else:
			return {"valid": true, "position": Vector3(in_clamped_x, floor_surface_y, in_max_z), "is_on_edge": true, "is_corner": false, "edge_index": 2}

	return {"valid": true, "position": Vector3(in_clamped_x, floor_surface_y, in_clamped_z), "is_on_edge": false, "is_corner": false, "edge_index": -1}

## Restringe P1 estrictamente dentro del piso activo, con anclaje a orillas y longitud mínima de 1.0m
func _constrain_wall_p1_to_floor(raw_target: Vector3, p0: Vector3, fl: Dictionary) -> Vector3:
	var min_x: float = fl.get("min_x", p0.x - 5.0)
	var max_x: float = fl.get("max_x", p0.x + 5.0)
	var min_z: float = fl.get("min_z", p0.z - 5.0)
	var max_z: float = fl.get("max_z", p0.z + 5.0)
	var floor_surface_y: float = p0.y # Ya se encuentra a la altura de la superficie del piso

	var inset := 0.10
	var in_min_x := minf(min_x + inset, max_x - inset)
	var in_max_x := maxf(max_x - inset, min_x + inset)
	var in_min_z := minf(min_z + inset, max_z - inset)
	var in_max_z := maxf(max_z - inset, min_z + inset)

	# 1. Clampear raw_target a los límites interiores del piso
	var tx := clampf(raw_target.x, in_min_x, in_max_x)
	var tz := clampf(raw_target.z, in_min_z, in_max_z)

	# 2. Magnetismo a las 4 orillas del piso (umbral 0.45m)
	if absf(tx - in_min_x) <= 0.45: tx = in_min_x
	elif absf(in_max_x - tx) <= 0.45: tx = in_max_x

	if absf(tz - in_min_z) <= 0.45: tz = in_min_z
	elif absf(in_max_z - tz) <= 0.45: tz = in_max_z

	# 3. Comprobar si P0 está sobre una orilla específica
	var p0_on_west := absf(p0.x - in_min_x) <= 0.05
	var p0_on_east := absf(p0.x - in_max_x) <= 0.05
	var p0_on_north := absf(p0.z - in_min_z) <= 0.05
	var p0_on_south := absf(p0.z - in_max_z) <= 0.05

	# Si P0 está en orilla oeste/este y el usuario se mueve principalmente en Z, anclar X a esa orilla
	if (p0_on_west or p0_on_east) and absf(tz - p0.z) > absf(tx - p0.x):
		tx = p0.x
	# Si P0 está en orilla norte/sur y el usuario se mueve principalmente en X, anclar Z a esa orilla
	elif (p0_on_north or p0_on_south) and absf(tx - p0.x) > absf(tz - p0.z):
		tz = p0.z

	# 4. Asegurar longitud mínima de 1.0m respecto a P0
	var delta := Vector2(tx - p0.x, tz - p0.z)
	var len_2d := delta.length()

	if len_2d < 1.0:
		var dir_2d: Vector2
		if len_2d > 0.05:
			dir_2d = delta.normalized()
		else:
			# Si el cursor está casi encima de P0, usar dirección horizontal de la cámara
			if camera != null:
				var cam_fwd := -camera.global_transform.basis.z
				dir_2d = Vector2(cam_fwd.x, cam_fwd.z).normalized()
			else:
				dir_2d = Vector2(1, 0)

		# Si P0 está pegado a un borde y dir_2d apunta hacia afuera del piso, proyectar a lo largo del borde
		if p0_on_west and dir_2d.x < 0.0: dir_2d.x = 0.0; dir_2d = dir_2d.normalized()
		if p0_on_east and dir_2d.x > 0.0: dir_2d.x = 0.0; dir_2d = dir_2d.normalized()
		if p0_on_north and dir_2d.y < 0.0: dir_2d.y = 0.0; dir_2d = dir_2d.normalized()
		if p0_on_south and dir_2d.y > 0.0: dir_2d.y = 0.0; dir_2d = dir_2d.normalized()

		if dir_2d.length_squared() < 0.01:
			var center_dir := Vector2((in_min_x + in_max_x) * 0.5 - p0.x, (in_min_z + in_max_z) * 0.5 - p0.z).normalized()
			dir_2d = center_dir if center_dir.length_squared() > 0.01 else Vector2(1, 0)

		tx = clampf(p0.x + dir_2d.x * 1.0, in_min_x, in_max_x)
		tz = clampf(p0.z + dir_2d.y * 1.0, in_min_z, in_max_z)

	return Vector3(tx, floor_surface_y, tz)

func _unhandled_input(event: InputEvent) -> void:
	# Clic Derecho: Retroceder un paso o abrir rueda radial
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var has_tool: bool = not active_tool_info.is_empty()

		# Si estamos en modo ventana y ajustando tamaño flexible, clic derecho cancela
		if active_element_type == 4 and window_step == WindowStep.SETTING_SIZE:
			window_step = WindowStep.IDLE
			window_target_site = null
			print("[VectorialConstruction] ↩️ Ajuste de ventana flexible cancelado.")
			get_viewport().set_input_as_handled()
			return

		# Si estamos en modo pared y en pasos intermedios, el clic derecho retrocede
		if active_element_type == 1:
			if wall_step == WallStep.SETTING_LENGTH:
				wall_step = WallStep.SETTING_HEIGHT
				print("[VectorialConstruction] ↩️ Regresando al Paso 2: Ajuste de Altura.")
				get_viewport().set_input_as_handled()
				return
			elif wall_step == WallStep.SETTING_HEIGHT:
				_cancel_placement()
				print("[VectorialConstruction] ↩️ Cancelando punto inicial de pared.")
				get_viewport().set_input_as_handled()
				return
		elif first_point != null:
			_cancel_placement()
			get_viewport().set_input_as_handled()
			return

		if has_tool:
			if radial_menu and not radial_menu.visible:
				radial_menu.open_menu(active_tool_info)
				get_viewport().set_input_as_handled()

	# Clic Izquierdo: Acción principal de construcción
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if radial_menu and radial_menu.visible:
			return
		_handle_left_click()

	# Tecla ESC: Cancelar trazado
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if window_step != WindowStep.IDLE:
			window_step = WindowStep.IDLE
			window_target_site = null
			_cancel_placement()
			get_viewport().set_input_as_handled()
			return
		if first_point != null or wall_step != WallStep.IDLE:
			_cancel_placement()
			get_viewport().set_input_as_handled()

func _get_planned_site_from_collider(collider: Variant) -> PlannedSite:
	if collider is CollisionObject3D:
		var meta_site = collider.get_meta("planned_site", null)
		if meta_site is PlannedSite:
			return meta_site
		if collider.get_parent() is PlannedSite:
			return collider.get_parent() as PlannedSite
	return null

func _find_planned_site_near(pos: Vector3, max_dist: float = 1.2) -> PlannedSite:
	var world_node := _get_world_node()
	if world_node == null:
		return null
	var best_site: PlannedSite = null
	var best_d := max_dist * max_dist
	var all_nodes := world_node.find_children("*", "Node3D", true, false)
	for child in all_nodes:
		if child is PlannedSite and not child.is_queued_for_deletion():
			var p0: Vector3 = child.p0
			var p1: Vector3 = child.p1
			if child.element_type == 1:
				var wall_dir := p1 - p0
				var len_sq := wall_dir.length_squared()
				if len_sq > 0.001:
					var t := clampf((pos - p0).dot(wall_dir) / len_sq, 0.0, 1.0)
					var proj := p0 + wall_dir * t
					var dy := clampf(pos.y - p0.y, 0.0, child.height)
					var closest_point := Vector3(proj.x, p0.y + dy, proj.z)
					var d := pos.distance_squared_to(closest_point)
					if d < best_d:
						best_d = d
						best_site = child
			else:
				var min_x := minf(p0.x, p1.x)
				var max_x := maxf(p0.x, p1.x)
				var min_z := minf(p0.z, p1.z)
				var max_z := maxf(p0.z, p1.z)
				var clamped_x := clampf(pos.x, min_x, max_x)
				var clamped_z := clampf(pos.z, min_z, max_z)
				var closest_pt := Vector3(clamped_x, p0.y, clamped_z)
				var d := pos.distance_squared_to(closest_pt)
				if d < best_d:
					best_d = d
					best_site = child
	return best_site

func _handle_left_click() -> void:
	if construction_engine == null:
		_ensure_construction_engine()

	# 0. Actualizar herramienta y material en mano
	var bm = _get_building_manager()
	if bm and bm.has_method("get_equipped_construction_tool"):
		active_tool_info = bm.get_equipped_construction_tool(player)
	else:
		active_tool_info = {}
	var has_tool: bool = not active_tool_info.is_empty()
	var held_mat: int = _detect_held_material_type()

	# ==============================================================================
	# CASO PRIORITARIO 1: EL JUGADOR SOSTIENE UN MATERIAL (Madera, Piedra, etc.)
	# Si tiene madera o piedra, su intención es EDIFICAR el trazado o aplicar material.
	# Esto tiene prioridad absoluta sobre cualquier modo anterior del palo.
	# ==============================================================================
	if held_mat >= 0:
		var hit: Variant = _raycast_from_camera()
		if hit != null:
			var raw_pos: Vector3 = hit["position"]
			var collider = hit.get("collider")
			var site := _get_planned_site_from_collider(collider)
			if site == null:
				site = _find_planned_site_near(raw_pos, 1.2)

			if site != null:
				var mat_name := _get_material_name(held_mat)
				site.build_with_material(held_mat, inventory, construction_engine)
				print("[VectorialConstruction] ✅ ¡Estructura de %s construida sobre el trazado!" % mat_name)
				get_viewport().set_input_as_handled()
				return

			# Si golpea una estructura construida en ConstructionEngine, aplicar/aportar material
			if construction_engine and construction_engine.has_method("apply_material_at"):
				var mat_result: int = construction_engine.call("apply_material_at", raw_pos, held_mat)
				if mat_result == 1:
					var mat_name := _get_material_name(held_mat)
					print("[VectorialConstruction] ✅ ¡Estructura convertida a %s!" % mat_name)
					if inventory: inventory.consume_selected(1)
					get_viewport().set_input_as_handled()
					return
				elif mat_result == 2:
					print("[VectorialConstruction] ✅ Aportado material a la estructura.")
					if inventory: inventory.consume_selected(1)
					get_viewport().set_input_as_handled()
					return
				elif mat_result == -1:
					var cur_mat: int = construction_engine.call("get_element_material_at", raw_pos)
					var cur_name := _get_material_name(cur_mat)
					var attempt_name := _get_material_name(held_mat)
					print("[VectorialConstruction] ❌ Esta estructura ya es de %s. No acepta %s." % [cur_name, attempt_name])
					get_viewport().set_input_as_handled()
					return
		return

	# ==============================================================================
	# CASO 2: EL JUGADOR NO SOSTIENE MATERIAL NI HERRAMIENTA DE CONSTRUCCIÓN
	# Si no tiene el palo en la mano, NO se le permite ni trazar, ni modificar,
	# NI BORRAR PUERTAS O VENTANAS.
	# ==============================================================================
	if not has_tool:
		var hit: Variant = _raycast_from_camera()
		if hit != null:
			var site := _get_planned_site_from_collider(hit.get("collider"))
			if site != null:
				print("[VectorialConstruction] ℹ️ Para edificar este trazado toma Madera o Piedra. Para planificar o modificar vanos, equipa el Palo de Trazado.")
		return

	# ==============================================================================
	# CASO 3: EL JUGADOR TIENE EL PALO/HERRAMIENTA EN LA MANO
	# Ahora sí se ejecutan los flujos de planificación (Pisos, Paredes, Puertas, Ventanas, Demoler).
	# ==============================================================================

	# A) Manejo inmediato de paso 2 de Ventana flexible
	if active_element_type == 4 and window_step == WindowStep.SETTING_SIZE:
		_handle_opening_click(Vector3.ZERO, null)
		return

	# B) Manejo inmediato de pasos 2 y 3 de Pared (no dependen de colisión física previa)
	if active_element_type == 1:
		if wall_step == WallStep.SETTING_HEIGHT:
			_handle_wall_click(wall_p0)
			return
		elif wall_step == WallStep.SETTING_LENGTH:
			_handle_wall_click(current_preview_point)
			return

	var hit: Variant = _raycast_from_camera()
	if hit == null:
		return

	var raw_pos: Vector3 = hit["position"]
	var collider = hit.get("collider")

	# C) Modo Demoler
	if active_element_type == -1:
		var site := _get_planned_site_from_collider(collider)
		if site != null:
			site.cancel_site()
			print("[VectorialConstruction] 🧹 Trazado cancelado y tierra limpiada.")
			get_viewport().set_input_as_handled()
			return
		if construction_engine and construction_engine.has_method("remove_element_at"):
			var removed: bool = construction_engine.call("remove_element_at", raw_pos)
			print("[VectorialConstruction] Demoler en ", raw_pos, " -> ", removed)
			get_viewport().set_input_as_handled()
			return
		return

	# D) Modo Vano (Puerta o Ventana con el Palo en mano)
	if active_element_type == 3 or active_element_type == 4:
		_handle_opening_click(raw_pos, collider)
		return

	# E) Modo Pared (Paso 1)
	if active_element_type == 1:
		_handle_wall_click(raw_pos)
		return

	# F) Modo Piso / Techo (Paso 1 ó 2)
	_handle_floor_click(raw_pos)

## Gestiona el clic en modo Puerta o Ventana (Planificación, Tamaño Flexible o Eliminación)
func _handle_opening_click(raw_pos: Vector3, collider: Variant) -> void:
	# Doble salvaguarda: los vanos solo pueden planificarse o borrarse si se tiene el palo en la mano
	var bm = _get_building_manager()
	var tool_check: Dictionary = bm.get_equipped_construction_tool(player) if bm else {}
	if tool_check.is_empty():
		return

	# 1. Si estamos en modo Ventana completando el tamaño flexible (Paso 2)
	if active_element_type == 4 and window_step == WindowStep.SETTING_SIZE:
		if is_instance_valid(window_target_site):
			var p0: Vector3 = window_target_site.p0
			var p1: Vector3 = window_target_site.p1
			var wall_h: float = window_target_site.height
			var wall_dir := p1 - p0
			var wall_len := wall_dir.length()
			if wall_len >= 0.01:
				var u := wall_dir / wall_len
				var wall_normal := Vector3(-u.z, 0.0, u.x)
				var wall_plane := Plane(wall_normal, p0.dot(wall_normal))

				var cam_from: Vector3
				var cam_dir: Vector3
				if camera:
					if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
						cam_from = camera.global_position
						cam_dir = -camera.global_transform.basis.z
					else:
						var m_pos := camera.get_viewport().get_mouse_position()
						cam_from = camera.project_ray_origin(m_pos)
						cam_dir = camera.project_ray_normal(m_pos)

				var inter: Variant = wall_plane.intersects_ray(cam_from, cam_dir)
				var cur_pos: Vector3 = inter as Vector3 if inter != null else (p0 + u * window_start_t + Vector3(0, window_start_y, 0))
				var cur_t := clampf((cur_pos - p0).dot(u), 0.0, wall_len)
				var cur_y := clampf(cur_pos.y - p0.y, 0.0, wall_h)

				var t_min := minf(window_start_t, cur_t)
				var t_max := maxf(window_start_t, cur_t)
				if (t_max - t_min) < 0.3:
					if cur_t >= window_start_t:
						t_max = minf(t_min + 0.3, wall_len)
						t_min = maxf(0.0, t_max - 0.3)
					else:
						t_min = maxf(0.0, t_max - 0.3)
						t_max = minf(t_min + 0.3, wall_len)

				var y_min := clampf(minf(window_start_y, cur_y), 0.05, wall_h - 0.15)
				var y_max := clampf(maxf(window_start_y, cur_y), y_min + 0.2, wall_h)

				# Auto-snapping inteligente a marco de puerta o vano inferior si se coloca arriba
				for op in window_target_site.openings:
					var op_t_min: float = op.get("t_min", 0.0)
					var op_t_max: float = op.get("t_max", 1.0)
					var op_y_top: float = op.get("y_top", 2.1)
					if minf(t_max, op_t_max) - maxf(t_min, op_t_min) > 0.10:
						if absf(y_min - op_y_top) < 0.25:
							y_min = op_y_top
							if y_max < y_min + 0.2:
								y_max = minf(wall_h, y_min + 0.25)

				if not window_target_site.can_add_opening(t_min, t_max, y_min, y_max):
					print("[VectorialConstruction] ❌ No se puede colocar ventana: se superpone con un vano existente.")
					return

				window_target_site.add_window_opening(t_min, t_max, y_min, y_max)
				print("[VectorialConstruction] 🪟 Vano de ventana planificado: ancho=%.2fm, alto=%.2fm, antepecho=%.2fm." % [t_max - t_min, y_max - y_min, y_min])

		window_step = WindowStep.IDLE
		window_target_site = null
		get_viewport().set_input_as_handled()
		return

	# 2. Localizar el PlannedSite objetivo
	var site: PlannedSite = null
	if collider is CollisionObject3D:
		var meta_site = collider.get_meta("planned_site", null)
		if meta_site is PlannedSite:
			site = meta_site
		elif collider.get_parent() is PlannedSite:
			site = collider.get_parent()

	if site == null:
		# REGLA 5: Si golpeó una pared construida, bloquear edición con advertencia
		if construction_engine and construction_engine.has_method("get_element_material_at"):
			var cur_mat: int = construction_engine.call("get_element_material_at", raw_pos)
			if cur_mat >= 0:
				print("[VectorialConstruction] ❌ La pared ya está construida. Los vanos solo se pueden planificar antes de edificarla.")
				get_viewport().set_input_as_handled()
				return
		print("[VectorialConstruction] ℹ️ Apunta a un trazado de pared para planificar.")
		return

	if site.element_type != 1:
		print("[VectorialConstruction] ❌ Solo se pueden planificar vanos en trazados de pared.")
		return

	# 3. REGLA 4: Si se hace clic sobre un vano existente del mismo tipo -> ELIMINAR esa planeación
	var hovered_op: Dictionary = site.find_opening_at(raw_pos, active_element_type)
	if not hovered_op.is_empty():
		var op_id: int = hovered_op.get("id", -1)
		var op_type_name := "puerta" if active_element_type == 3 else "ventana"
		if site.remove_opening(op_id):
			print("[VectorialConstruction] 🗑️ Vano de %s planificado eliminado exitosamente." % op_type_name)
		door_hovered_opening_id = -1
		window_hovered_opening_id = -1
		get_viewport().set_input_as_handled()
		return

	# 4. Colocación de nueva planeación
	var p0: Vector3 = site.p0
	var p1: Vector3 = site.p1
	var wall_dir := p1 - p0
	var wall_len := wall_dir.length()
	if wall_len < 0.01:
		return
	var u := wall_dir / wall_len
	var t_raw := (raw_pos - p0).dot(u)

	if active_element_type == 3:
		# REGLA 2: "las puertas siempre deben ponerse ancladas al piso, porque actualmente permite ponerlas volando"
		var door_w := 1.30 # Puerta más ancha
		var door_h := minf(2.1, site.height)
		var t_center := clampf(t_raw, door_w * 0.5, maxf(door_w * 0.5, wall_len - door_w * 0.5))
		var t_min := t_center - door_w * 0.5
		var t_max := t_center + door_w * 0.5

		if not site.can_add_opening(t_min, t_max, 0.0, door_h):
			print("[VectorialConstruction] ❌ No se puede colocar puerta: se superpone con un vano existente.")
			return

		site.add_door_opening(t_center, door_w, door_h)
		print("[VectorialConstruction] 🚪 Vano de puerta planificado en t=%.2f (anclado estrictamente al piso)." % t_center)
		get_viewport().set_input_as_handled()

	elif active_element_type == 4:
		# REGLA 3: "las ventanas deben ser de tamaño flexible" (Paso 1: Fijar esquina inicial)
		var t_clamped := clampf(t_raw, 0.0, wall_len)
		var y_rel := clampf(raw_pos.y - p0.y, 0.05, site.height - 0.1)
		window_step = WindowStep.SETTING_SIZE
		window_target_site = site
		window_start_t = t_clamped
		window_start_y = y_rel
		print("[VectorialConstruction] 🪟 Paso 1: Esquina inicial de ventana fijada en t=%.2f, y=%.2f. Mueve el ratón para definir el tamaño flexible." % [t_clamped, y_rel])
		get_viewport().set_input_as_handled()

## Gestiona los 3 pasos de colocación de paredes
func _handle_wall_click(raw_pos: Vector3) -> void:
	match wall_step:
		WallStep.IDLE:
			# Clic 1: Verificar que esté en un piso y fijar P0
			var snap_info := _snap_point_to_floors(raw_pos, 0.45)
			if not snap_info.get("valid", false):
				print("[VectorialConstruction] ❌ No se puede construir pared: las paredes solo se pueden colocar dentro de un piso.")
				return

			wall_p0 = snap_info.get("position", raw_pos)
			wall_active_floor = snap_info.get("floor", {})
			wall_step = WallStep.SETTING_HEIGHT
			wall_current_height = 2.5
			first_point = wall_p0

			var is_edge: bool = snap_info.get("is_on_edge", false)
			var edge_text := " (anclado a orilla)" if is_edge else ""
			print("[VectorialConstruction] 🧱 Paso 1 completado: Inicio de pared fijado en piso%s en %s. Ahora define la altura." % [edge_text, wall_p0])
			get_viewport().set_input_as_handled()

		WallStep.SETTING_HEIGHT:
			# Clic 2: Confirmar altura
			wall_locked_height = wall_current_height
			wall_step = WallStep.SETTING_LENGTH
			print("[VectorialConstruction] 📏 Paso 2 completado: Altura fijada en %.1f m. Ahora define el largo dentro del piso." % wall_locked_height)
			get_viewport().set_input_as_handled()

		WallStep.SETTING_LENGTH:
			# Clic 3: Confirmar largo y construir la pared
			var p0: Vector3 = wall_p0
			var p1: Vector3 = current_preview_point
			var dist := Vector2(p1.x - p0.x, p1.z - p0.z).length()
			if dist < 0.95:
				print("[VectorialConstruction] ⚠️ La pared requiere un largo mínimo de 1.0 metro.")
				return
			if _check_wall_overlap(p0, p1):
				print("[VectorialConstruction] ❌ No se puede construir: ya existe una pared en esta posición.")
				return
			_execute_construction_span(p0, p1)
			_cancel_placement()
			print("[VectorialConstruction] ✅ Paso 3 completado: Pared construida sobre el piso.")
			get_viewport().set_input_as_handled()

## Gestiona los 2 pasos de colocación de pisos
func _handle_floor_click(raw_pos: Vector3) -> void:
	if first_point == null:
		var check_pos := raw_pos
		var hit: Variant = _raycast_from_camera()
		if hit != null:
			var collider = hit.get("collider")
			var site := _get_planned_site_from_collider(collider)
			if site != null and (site.element_type == 0 or site.element_type == 2):
				check_pos.y = site.p0.y
			else:
				for fl in _get_all_floors():
					if check_pos.x >= fl["min_x"] - 0.10 and check_pos.x <= fl["max_x"] + 0.10 and \
					   check_pos.z >= fl["min_z"] - 0.10 and check_pos.z <= fl["max_z"] + 0.10 and \
					   absf(check_pos.y - fl.get("y", check_pos.y)) <= 0.8:
						check_pos.y = fl["y"]
						break

		var proj_info := _project_point_outside_floors(check_pos, 0.40)
		var p0: Vector3 = proj_info.get("position", check_pos)
		if _is_point_inside_any_floor(p0):
			print("[VectorialConstruction] ❌ No se puede iniciar un piso dentro de un piso existente.")
			return
		first_point = p0
		var marker_type: String = active_tool_info.get("marker_type", "dirt_scrape")
		visual_marker.setup(marker_type, [first_point])
		print("[VectorialConstruction] Punto inicial P0 fijado en: ", first_point)
		get_viewport().set_input_as_handled()
	else:
		var p0: Vector3 = first_point
		var p1: Vector3 = current_preview_point
		if _check_floor_rect_overlap(p0, p1):
			print("[VectorialConstruction] ❌ No se puede construir suelo donde ya hay suelo.")
			return
		_execute_construction_span(p0, p1)
		_cancel_placement()
		get_viewport().set_input_as_handled()

func _execute_construction_span(p0: Vector3, p1: Vector3) -> void:
	var world_node := _get_world_node()
	if world_node == null:
		return

	var planned_site_script = preload("res://world/building/planned_site.gd")
	var site = planned_site_script.new()
	var height: float = wall_locked_height if active_element_type == 1 else 2.5
	site.setup(active_element_type, p0, p1, active_tool_info, height)
	world_node.add_child(site)

	var tool_name: String = active_tool_info.get("name", "Palo")
	print("[VectorialConstruction] ⛏️ Trazado completado con %s: la orilla queda delimitada en el terreno lista para edificar." % tool_name)

func _cancel_placement() -> void:
	first_point = null
	current_preview_point = Vector3.ZERO
	wall_step = WallStep.IDLE
	wall_p0 = Vector3.ZERO
	wall_active_floor = {}

	window_step = WindowStep.IDLE
	window_target_site = null
	window_hovered_opening_id = -1
	door_hovered_opening_id = -1

	if visual_marker:
		visual_marker.call("clear")
	if ghost_mesh:
		ghost_mesh.visible = false
	if dimension_label:
		dimension_label.visible = false
	if _aiming_marker:
		_aiming_marker.visible = false

func _raycast_from_camera() -> Variant:
	if camera == null:
		return null
	var space_state := camera.get_world_3d().direct_space_state
	var from: Vector3
	var dir: Vector3

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		from = camera.global_position
		dir = -camera.global_transform.basis.z
	else:
		var mouse_pos := camera.get_viewport().get_mouse_position()
		from = camera.project_ray_origin(mouse_pos)
		dir = camera.project_ray_normal(mouse_pos)

	var to := from + dir * max_reach_distance

	var query := PhysicsRayQueryParameters3D.create(from, to, ray_collision_mask)
	if player:
		query.exclude = [player.get_rid()]

	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		return result
	return null

func _detect_held_material_type() -> int:
	var inv := _get_inventory()
	if inv == null:
		return -1
	var def: ObjectDefinition = inv.get_selected_definition()
	if def == null:
		return -1
	var item_id := def.id.to_lower()
	var disp_name := def.display_name.to_lower()
	var res_path := def.resource_path.to_lower()
	var combined := item_id + " " + disp_name + " " + res_path

	if "wood" in combined or "madera" in combined or "log" in combined or "plank" in combined or "tronco" in combined or "tabla" in combined:
		return 0 # Wood
	elif "stone" in combined or "piedra" in combined or "rock" in combined or "roca" in combined:
		return 1 # Stone
	elif "brick" in combined or "ladrillo" in combined:
		return 2 # Brick
	elif "concrete" in combined or "hormigon" in combined or "concreto" in combined:
		return 3 # Concrete
	elif "metal" in combined or "iron" in combined or "hierro" in combined:
		return 4 # Metal
	return -1

func _get_material_name(mat_id: int) -> String:
	match mat_id:
		0: return "Madera"
		1: return "Piedra"
		2: return "Ladrillo"
		3: return "Concreto"
		4: return "Metal"
		5: return "Armazón"
		_: return "Desconocido"

func _on_radial_element_selected(elem_type: int, mat_type: int, recipe_name: String) -> void:
	active_element_type = elem_type
	active_material_type = mat_type
	active_mode_name = recipe_name
	_cancel_placement()
	mode_changed.emit(recipe_name)
	print("[VectorialConstruction] Modo seleccionado desde rueda radial: ", recipe_name)

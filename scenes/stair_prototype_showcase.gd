extends Node3D

## Escena de prueba del Prototipo de Escaleras Normalizadas (Play Sector X).
## Muestra los dos tipos de escalera (Recta y en U) conectando Planta Baja con un Segundo Piso a 2.80m.
## Permite al jugador subir y bajar con suavidad total gracias a la rampa de colisión continua.

const StairModuleScript = preload("res://world/building/stair_module.gd")
const PlayerScene = preload("res://player/player.tscn")

const BASE_Y := 10.0
const SECOND_FLOOR_HEIGHT := 2.80

var _player: CharacterBody3D
var _info_label: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_setup_environment()
	_setup_second_floor_platform()
	_setup_stairs()
	_setup_player()
	_setup_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _setup_environment() -> void:
	# 1. Dirección del sol / Luz direccional suave estilo PSX
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-45.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	# 2. Luz de relleno ambiente
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(45.0, -145.0, 0.0)
	fill.light_color = Color(0.70, 0.78, 0.90)
	fill.light_energy = 0.35
	add_child(fill)

	# 3. Suelo de Planta Baja (24m x 24m) elevado a BASE_Y (10.0m) para evitar el umbral de caída
	var floor_body := StaticBody3D.new()
	floor_body.name = "GroundFloor"
	var floor_mesh := MeshInstance3D.new()
	var box_m := BoxMesh.new()
	box_m.size = Vector3(24.0, 0.4, 24.0)
	floor_mesh.mesh = box_m

	var mat_floor := StandardMaterial3D.new()
	mat_floor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat_floor.albedo_color = Color(0.35, 0.38, 0.36)
	mat_floor.roughness = 0.90
	floor_mesh.material_override = mat_floor
	floor_body.add_child(floor_mesh)

	var floor_col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(24.0, 0.4, 24.0)
	floor_col.shape = box_col
	floor_body.add_child(floor_col)

	floor_body.position = Vector3(0.0, BASE_Y - 0.2, 0.0)
	add_child(floor_body)


func _setup_second_floor_platform() -> void:
	# Losa del segundo piso a BASE_Y + SECOND_FLOOR_HEIGHT
	var loft := StaticBody3D.new()
	loft.name = "SecondFloorLoft"

	var top_y := BASE_Y + SECOND_FLOOR_HEIGHT
	var slab_thickness := 0.20

	var mat_wood := StandardMaterial3D.new()
	mat_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var tex: Texture2D = load("res://assets/building/wood_floor.png")
	if tex:
		mat_wood.albedo_texture = tex
		mat_wood.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mat_wood.albedo_color = Color(0.70, 0.55, 0.40)

	# Plataforma superior principal (14m de ancho x 6m de fondo en Z = [4.0 .. 10.0])
	_add_floor_slab(loft, Vector3(0.0, top_y - slab_thickness * 0.5, 7.0), Vector3(14.0, slab_thickness, 6.0), mat_wood)

	# Barandales perimetrales de seguridad en la mezanina con HUECOS de acceso para las escaleras:
	# - Escalera Recta llega en X = -4.0 (hueco entre -4.6 y -3.4)
	# - Escalera en U llega en X = +4.0 (hueco en su desembarque X = 3.5 a 4.5)
	_add_guardrail_segment(loft, Vector3(-5.8, top_y, 4.0), 2.4, true) # Izquierda extrema
	_add_guardrail_segment(loft, Vector3(0.0, top_y, 4.0), 6.6, true)  # Centro entre ambas escaleras
	_add_guardrail_segment(loft, Vector3(5.8, top_y, 4.0), 2.4, true)  # Derecha extrema
	# Barandales laterales y trasero de la mezanina
	_add_guardrail_segment(loft, Vector3(-7.0, top_y, 7.0), 6.0, false) # Lateral izquierdo
	_add_guardrail_segment(loft, Vector3(7.0, top_y, 7.0), 6.0, false)  # Lateral derecho
	_add_guardrail_segment(loft, Vector3(0.0, top_y, 10.0), 14.0, true) # Fondo trasero

	add_child(loft)


func _add_floor_slab(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.position = pos
	parent.add_child(col)


func _add_guardrail_segment(parent: Node3D, base_pos: Vector3, length: float, horizontal_x: bool) -> void:
	var rail_h := 0.90
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.18, 0.20)
	mat.metallic = 0.50

	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	if horizontal_x:
		b.size = Vector3(length, 0.05, 0.05)
		mi.position = base_pos + Vector3(0.0, rail_h, 0.0)
	else:
		b.size = Vector3(0.05, 0.05, length)
		mi.position = base_pos + Vector3(0.0, rail_h, 0.0)
	mi.mesh = b
	mi.material_override = mat
	parent.add_child(mi)

	# Postes
	var num_p := maxi(2, int(length / 1.5) + 1)
	for i in range(num_p):
		var t := float(i) / float(num_p - 1)
		var p_pos: Vector3
		if horizontal_x:
			p_pos = base_pos + Vector3(-length * 0.5 + t * length, rail_h * 0.5, 0.0)
		else:
			p_pos = base_pos + Vector3(0.0, rail_h * 0.5, -length * 0.5 + t * length)
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.04, rail_h, 0.04)
		post.mesh = pb
		post.material_override = mat
		post.position = p_pos
		parent.add_child(post)


func _setup_stairs() -> void:
	# 1. Escalera Recta (Izquierda, X = -4.0m): Sube de Z = 1.0 a Z = 4.0m
	var stair_straight := StairModuleScript.new()
	stair_straight.name = "Stair_Straight_1x3m"
	stair_straight.stair_type = StairModuleScript.StairType.STRAIGHT
	stair_straight.stair_width = 1.0
	stair_straight.straight_length = 3.0
	stair_straight.target_height = SECOND_FLOOR_HEIGHT
	stair_straight.railing_left = true
	stair_straight.railing_right = true
	stair_straight.material_style = StairModuleScript.MaterialStyle.WOOD
	stair_straight.position = Vector3(-4.0, BASE_Y, 1.0)
	add_child(stair_straight)

	# 2. Escalera en "U" con Descanso (Derecha, X = +4.0m, huella 2m x 2m): Sube a Z = 4.0m
	var stair_u := StairModuleScript.new()
	stair_u.name = "Stair_UShape_2x2m"
	stair_u.stair_type = StairModuleScript.StairType.U_SHAPE
	stair_u.target_height = SECOND_FLOOR_HEIGHT
	stair_u.material_style = StairModuleScript.MaterialStyle.DARK_OAK
	# Rotar para que desembarque hacia la plataforma superior (+Z)
	stair_u.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	stair_u.position = Vector3(4.0, BASE_Y, 4.0)
	add_child(stair_u)


func _setup_player() -> void:
	_player = PlayerScene.instantiate()
	_player.name = "Player"
	_player.position = Vector3(0.0, BASE_Y + 0.2, -2.0)
	add_child(_player)


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShowcaseUI"

	_info_label = Label.new()
	_info_label.text = "PROTOTIPO DE ESCALERAS NORMALIZADAS (Play Sector X)\n" + \
		"----------------------------------------------------\n" + \
		"[Izquierda]: Escalera Recta (1.0m ancho x 3.0m largo) -> Sube 2.80m\n" + \
		"[Derecha]: Escalera en 'U' con Descanso (2.0m x 2.0m) -> Sube 2.80m\n" + \
		"WASD: Moverse | Raton: Mirar | Espacio: Saltar | Shift: Correr\n" + \
		"Haz Click en la pantalla para capturar el raton | ESC: Liberar raton"
	_info_label.position = Vector2(24, 24)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.70))
	_info_label.add_theme_font_size_override("font_size", 14)
	canvas.add_child(_info_label)

	add_child(canvas)

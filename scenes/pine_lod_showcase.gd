extends Node3D

const PSXPine = preload("res://world/vegetation/trees/psx_pine.gd")

@onready var cam: Camera3D = $Camera3D
@onready var tree_normal: Node3D = $TreeNormal
@onready var tree_dynamic: Node3D = $TreeDynamic
@onready var tree_lod: Node3D = $TreeLOD
@onready var dist_label: Label = $UI/Margin/Panel/VBox/DistanceLabel
@onready var lod_label: Label = $UI/Margin/Panel/VBox/LODStatusLabel

var rotating: bool = true
var rotation_speed: float = 0.4 # rad/s

# Controles de cámara libre
var move_speed: float = 20.0
var mouse_captured: bool = false
var pitch: float = deg_to_rad(8.0)
var yaw: float = 0.0


func _ready() -> void:
	_setup_trees()
	_setup_ui()
	_capture_mouse(false) # Iniciar con ratón visible para poder presionar botones de la UI


func _setup_trees() -> void:
	# 1. Árbol Normal (LOD 0 puro, 30 triángulos)
	var mesh_lod0 = PSXPine.get_lod0_mesh()
	var mi0 = MeshInstance3D.new()
	mi0.name = "Normal_Mesh"
	mi0.mesh = mesh_lod0
	tree_normal.add_child(mi0)
	
	# 2. Árbol Dinámico (Cambia a 100m)
	var pine_dyn = PSXPine.new()
	pine_dyn.name = "Dynamic_Pine"
	pine_dyn.lod_switch_distance = 100.0
	pine_dyn.max_view_distance = 400.0
	tree_dynamic.add_child(pine_dyn)
	
	# 3. Árbol LOD (LOD 1 puro, EXACTAMENTE 2 triángulos)
	var mesh_lod1 = PSXPine.get_lod1_mesh()
	var mi1 = MeshInstance3D.new()
	mi1.name = "LOD1_Mesh"
	mi1.mesh = mesh_lod1
	tree_lod.add_child(mi1)


func _setup_ui() -> void:
	$UI/Margin/Panel/VBox/BtnNear.pressed.connect(func(): _set_cam_preset(Vector3(-12, 18, 28), 10.0))
	$UI/Margin/Panel/VBox/BtnMid.pressed.connect(func(): _set_cam_preset(Vector3(-12, 18, 55), 8.0))
	$UI/Margin/Panel/VBox/Btn100m.pressed.connect(func(): _set_cam_preset(Vector3(-12, 18, 105), 5.0))
	$UI/Margin/Panel/VBox/BtnFar.pressed.connect(func(): _set_cam_preset(Vector3(-12, 18, 155), 4.0))
	$UI/Margin/Panel/VBox/BtnRotate.pressed.connect(func(): rotating = not rotating)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_capture_mouse(false)
		elif event.keycode == KEY_1:
			_set_cam_preset(Vector3(-12, 18, 28), 10.0)
		elif event.keycode == KEY_2:
			_set_cam_preset(Vector3(-12, 18, 55), 8.0)
		elif event.keycode == KEY_3:
			_set_cam_preset(Vector3(-12, 18, 105), 5.0)
		elif event.keycode == KEY_4:
			_set_cam_preset(Vector3(-12, 18, 155), 4.0)
		elif event.keycode == KEY_T or event.keycode == KEY_SPACE:
			rotating = not rotating
			
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
			# Si hace clic fuera de la UI, capturar ratón para volar libremente
			_capture_mouse(true)
			
	elif event is InputEventMouseMotion and mouse_captured:
		var sens := 0.003
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.4, 1.4)
		cam.rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	# Rotación turntable para apreciar los árboles en 360 grados
	if rotating:
		tree_normal.rotate_y(rotation_speed * delta)
		tree_dynamic.rotate_y(rotation_speed * delta)
		# En tree_lod el billboard se alinea automáticamente con la cámara
		tree_lod.rotate_y(rotation_speed * delta)
		
	# Movimiento de cámara cuando el ratón está capturado
	if mouse_captured:
		var dir := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): dir += -cam.global_transform.basis.z
		if Input.is_physical_key_pressed(KEY_S): dir += cam.global_transform.basis.z
		if Input.is_physical_key_pressed(KEY_A): dir += -cam.global_transform.basis.x
		if Input.is_physical_key_pressed(KEY_D): dir += cam.global_transform.basis.x
		if Input.is_physical_key_pressed(KEY_E): dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_Q): dir += Vector3.DOWN
		
		var spd = move_speed * (2.5 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		if dir.length_squared() > 0.001:
			cam.global_position += dir.normalized() * spd * delta
			
	# Actualizar telemetría UI
	var dist := cam.global_position.distance_to(tree_dynamic.global_position)
	if dist_label:
		dist_label.text = "Distancia de Cámara: %.1f m" % dist
	if lod_label:
		if dist < 100.0:
			lod_label.text = "Árbol Dinámico: [LOD 0] Activo (30 Triángulos 3D)"
			lod_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			lod_label.text = "Árbol Dinámico: [LOD 1] Activo (EXACTAMENTE 2 Triángulos)"
			lod_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


func _set_cam_preset(target_pos: Vector3, pitch_deg: float) -> void:
	cam.position = target_pos
	pitch = deg_to_rad(pitch_deg)
	yaw = 0.0
	cam.rotation = Vector3(pitch, yaw, 0.0)


func _capture_mouse(capture: bool) -> void:
	mouse_captured = capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

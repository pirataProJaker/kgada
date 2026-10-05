extends Node3D

var _car: Sedan80s = null
var _cam: Camera3D = null
var _frame := 0

func _ready() -> void:
	# 1. Fondo de estudio PSX idéntico al render de referencia
	var env := WorldEnvironment.new()
	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.18, 0.18, 0.19)
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env_res.ambient_light_color = Color(0.85, 0.88, 0.92)
	env_res.ambient_light_energy = 0.9
	env.environment = env_res
	add_child(env)

	# 2. Luces de estudio que iluminan directamente el frontal, vano motor y lateral izquierdo
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-60.0, 150.0, 0.0)
	rim.light_color = Color(0.85, 0.90, 1.0)
	rim.light_energy = 1.1
	add_child(rim)

	# 3. Suelo de estudio CON COLISIÓN para que el auto se pose naturalmente sobre sus ruedas
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorPhysics"
	var floor_col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(60.0, 2.0, 60.0)
	floor_col.shape = box_col
	floor_col.position = Vector3(0.0, -1.0, 0.0)
	floor_body.add_child(floor_col)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	var mat_floor := StandardMaterial3D.new()
	mat_floor.albedo_color = Color(0.14, 0.14, 0.15)
	mat_floor.roughness = 0.9
	floor_mesh.material_override = mat_floor
	floor_body.add_child(floor_mesh)
	add_child(floor_body)

	# 4. Instanciar el Sedán 80s
	_car = Sedan80s.new()
	_car.name = "ShowcaseCar"
	_car.position = Vector3(0.0, 0.29, 0.0)
	_car.freeze = true
	add_child(_car)

	# 5. Cámara de estudio
	_cam = Camera3D.new()
	_cam.name = "StudioCamera"
	add_child(_cam)
	_set_camera_ref_angle()


func _set_camera_ref_angle() -> void:
	# Ángulo 3/4 frontal idéntico a la imagen de referencia (media_1791160550217.png)
	_cam.position = Vector3(-3.4, 1.22, -3.8)
	_cam.look_at(Vector3(0.0, 0.55, -0.15), Vector3.UP)


func _set_camera_side_angle() -> void:
	_cam.position = Vector3(-4.8, 1.05, 0.0)
	_cam.look_at(Vector3(0.0, 0.55, 0.0), Vector3.UP)


func _process(_delta: float) -> void:
	_frame += 1

	# Frame 15: Foto 1 - Ángulo 3/4 frontal de referencia
	if _frame == 15:
		var img := get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			img.save_png(ProjectSettings.globalize_path("res://render_ref_angle.png"))
			var f := FileAccess.open("res://render_log.txt", FileAccess.WRITE)
			if f: f.store_line("Frame 15 saved")

	# Frame 18: Cambiar a perfil lateral
	if _frame == 18:
		_set_camera_side_angle()

	# Frame 25: Foto 2 - Perfil lateral
	if _frame == 25:
		var img := get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			img.save_png(ProjectSettings.globalize_path("res://render_side_angle.png"))
			var f := FileAccess.open("res://render_log.txt", FileAccess.READ_WRITE)
			if f:
				f.seek_end()
				f.store_line("Frame 25 saved")

	# Frame 28: Volver a 3/4 y abrir capó
	if _frame == 28:
		_set_camera_ref_angle()
		var hood_socket: PartSocket = _car.sockets.get(VehiclePartData.SlotType.HOOD)
		if hood_socket and hood_socket.installed_part:
			hood_socket.installed_part.toggle_open()
		var f := FileAccess.open("res://render_log.txt", FileAccess.READ_WRITE)
		if f:
			f.seek_end()
			f.store_line("Frame 28 hood toggled")

	# Frame 40: Foto 3 - Vista 3/4 elevada mirando hacia adentro del vano motor abierto
	if _frame == 40:
		_cam.position = Vector3(0.70, 1.45, -2.45)
		_cam.look_at(Vector3(-0.05, 0.45, -1.65), Vector3.UP)

	# Frame 50: Guardar foto del vano motor
	if _frame == 50:
		var img := get_viewport().get_texture().get_image()
		if img and not img.is_empty():
			var p := ProjectSettings.globalize_path("res://render_engine_bay.png")
			var err := img.save_png(p)
			var f := FileAccess.open("res://render_log.txt", FileAccess.READ_WRITE)
			if f:
				f.seek_end()
				f.store_line("Frame 50 saved to %s (err=%d)" % [p, err])
		get_tree().quit()


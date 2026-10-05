extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/PC 1/.gemini/antigravity-ide/brain/6a57df5d-14eb-46d8-b1be-55e6bda8c63c"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	var cam: Camera3D = _showcase_node._camera

	# Frame 5: Quitar techos para ver la distribución interior y la escalera desde arriba
	if _frames == 5:
		_showcase_node._show_roofs = false
		_showcase_node.regenerate_houses()

	elif _frames == 6:
		var d = _showcase_node._nw_house_data
		if d.has("res"):
			print("=== DATOS DE LA CASA NW ===")
			print("Escalera: ", d["res"].get("stair", {}))
			var rms = d["res"].get("rooms", [])
			print("Total cuartos: ", rms.size())
			for r in rms:
				print("  Piso %d | Cuarto %d (%s) | X: %d..%d, Z: %d..%d" % [r.get("floor", 0), r.get("id", 0), r.get("type_name", ""), r.get("x_min", 0), r.get("x_max", 0), r.get("z_min", 0), r.get("z_max", 0)])

	# Frame 15: Vista aérea cenital sobre la Sala y Escalera
	elif _frames == 15:
		cam.position = Vector3(-9.5, 9.5, -9.0)
		cam.look_at_from_position(cam.position, Vector3(-9.5, 0.5, -9.0))

	elif _frames == 20:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/procedural_stairs_top_down.png")
				print("✓ Guardado: procedural_stairs_top_down.png")

	# Frame 25: Vista interior en Planta Baja en la Sala mirando directo a la escalera en L
	elif _frames == 25:
		cam.position = Vector3(-10.8, 1.4, -11.0)
		cam.look_at_from_position(cam.position, Vector3(-7.8, 1.5, -8.0))

	elif _frames == 30:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/procedural_stairs_ground_floor.png")
				print("✓ Guardado: procedural_stairs_ground_floor.png")

	# Frame 35: Vista isométrica de Planta Alta (pasillo, barandales de seguridad y puertas independientes)
	elif _frames == 35:
		cam.position = Vector3(-5.5, 8.5, -5.0)
		cam.look_at_from_position(cam.position, Vector3(-9.5, 2.5, -9.5))

	elif _frames == 40:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/procedural_stairs_second_floor_isometric.png")
				print("✓ Guardado: procedural_stairs_second_floor_isometric.png")

	# Frame 45: Vista mirando hacia abajo de las escaleras desde la llegada de planta alta
	elif _frames == 45:
		cam.position = Vector3(-9.5, 4.0, -8.0)
		cam.look_at_from_position(cam.position, Vector3(-7.5, 1.5, -7.8))

	elif _frames == 50:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/procedural_stairs_looking_down.png")
				print("✓ Guardado: procedural_stairs_looking_down.png")

	# Frame 55: Volver a poner techos para inspeccionar la fachada exterior
	elif _frames == 55:
		_showcase_node._show_roofs = true
		_showcase_node.regenerate_houses()

	# Frame 65: Vista exterior de la fachada frente a la escalera (ventana vertical)
	elif _frames == 65:
		cam.position = Vector3(-8.0, 2.2, -4.0)
		cam.look_at_from_position(cam.position, Vector3(-8.0, 2.0, -8.0))

	elif _frames == 70:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/procedural_stairs_exterior_facade.png")
				print("✓ Guardado: procedural_stairs_exterior_facade.png")

	elif _frames >= 75:
		print("✓ Todas las capturas completadas.")
		quit(0)

	return false

extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

var _frames := 0
var _showcase_node = null

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	var cam: Camera3D = _showcase_node._camera

	# Frame 10: Acercamiento cenital/isométrico al techo de la Casa NW (Colonia Vieja)
	if _frames == 10:
		cam.position = Vector3(-13.0, 11.0, -13.0)
		cam.look_at(Vector3(-13.0, 3.0, -16.0))

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/roof_closeup_nw_colonia_vieja.png")
				print("✓ Captura techo NW: roof_closeup_nw_colonia_vieja.png")

	# Frame 20: Acercamiento cenital al techo de la Casa SE (Zona X L-Shape / 2 Pisos)
	elif _frames == 20:
		cam.position = Vector3(16.0, 14.0, 17.0)
		cam.look_at(Vector3(16.0, 3.0, 14.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/roof_closeup_se_zonax.png")
				print("✓ Captura techo SE: roof_closeup_se_zonax.png")

	# Frame 30: Acercamiento a los techos de Colonia Nueva (Infonavit NE)
	elif _frames == 30:
		cam.position = Vector3(14.0, 12.0, -14.0)
		cam.look_at(Vector3(14.0, 3.0, -17.0))

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/roof_closeup_ne_infonavit.png")
				print("✓ Captura techo NE: roof_closeup_ne_infonavit.png")

	# Frame 40: Medición de FPS en tiempo real durante 30 frames continuos
	elif _frames == 40:
		print("--- INICIANDO BENCHMARK DE RENDIMIENTO (FPS & FRAME TIME) ---")

	elif _frames >= 70:
		var fps = Engine.get_frames_per_second()
		var process_time = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var physics_time = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		var primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		print("=== REPORTE FINAL DE RENDIMIENTO ===")
		print("FPS: %d" % fps)
		print("Process Time: %.2f ms" % process_time)
		print("Physics Time: %.2f ms" % physics_time)
		print("Draw Calls: %d" % draw_calls)
		print("Polígonos/Triángulos: %d" % primitives)
		print("====================================")
		quit(0)

	return false

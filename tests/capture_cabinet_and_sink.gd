extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

var _frames := 0
var _showcase = null

func _init() -> void:
	print("=== INICIANDO CAPTURA DE GABINETES Y FREGADERO (ATLAS INTELIGENTE) ===")
	
	var showcase_scene := load("res://scenes/all_objects_engine_showcase.tscn")
	_showcase = showcase_scene.instantiate()
	root.add_child(_showcase)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 10: Ángulo idéntico al screenshot del usuario (X=4.3, mirando hacia abajo -35 deg)
	if _frames == 10:
		_showcase._teleport_to(Vector3(4.3, 1.80, 1.25), 0.0, deg_to_rad(-45.0))

	elif _frames == 14:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cabinets_and_sink_fixed.png")
				print("✓ Captura guardada: cabinets_and_sink_fixed.png")

	# Frame 18: Primer plano directo del fregadero (apreciando tarja rehundida, coladera y grifo)
	elif _frames == 18:
		_showcase._teleport_to(Vector3(5.0, 1.50, 0.75), 0.0, deg_to_rad(-55.0))

	elif _frames == 22:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/sink_recessed_closeup.png")
				print("✓ Captura guardada: sink_recessed_closeup.png")

	# Frame 26: Primer plano de la cubierta de granito (verificando 0% franja blanca)
	elif _frames == 26:
		_showcase._teleport_to(Vector3(3.6, 1.50, 0.75), 0.0, deg_to_rad(-55.0))

	elif _frames == 30:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/countertop_granite_closeup.png")
				print("✓ Captura guardada: countertop_granite_closeup.png")

	# Frame 34: Vista cenital (Top-Down -85 deg) idéntica a la foto del usuario sobre el fregadero
	elif _frames == 34:
		_showcase._teleport_to(Vector3(5.0, 1.55, 0.03), 0.0, deg_to_rad(-85.0))

	elif _frames == 38:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/sink_cutout_topdown.png")
				print("✓ Captura guardada: sink_cutout_topdown.png")

	elif _frames >= 42:
		print("=== CAPTURAS DE GABINETES FINALIZADAS CON ÉXITO ===")
		quit(0)

	return false

extends SceneTree
## Script de captura fotográfica de la infraestructura eléctrica CFE
## Verificando:
## 1) Pilares en la orilla del lote sin invadir/salir a la banqueta.
## 2) Lógica de pares compartidos: Pilar 1 (Casa 1-2 en X=14), NADA en X=21, Pilar 2 (Casa 3-4 en X=28).

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

func _init() -> void:
	var showcase_scn = load("res://scenes/cross_street_houses_showcase.tscn")
	_showcase_node = showcase_scn.instantiate()
	_showcase_node.is_capture_mode = true
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	var cam: Camera3D = _showcase_node._camera

	# Frame 10: Foto 1 - Vista de Banqueta y Calle mostrando los 2 pares:
	# Pilar 1 (Casa 1 y 2 en X=14), NADA en X=21 (Casa 2 y 3), Pilar 2 (Casa 3 y 4 en X=28)
	if _frames == 10:
		cam.position = Vector3(8.5, 1.65, -4.6)
		cam.look_at_from_position(cam.position, Vector3(24.0, 1.5, -7.2))

	elif _frames == 14:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_street_pairs_perspective.png")
				print("✓ Foto 1 guardada: cfe_street_pairs_perspective.png")

	# Frame 18: Foto 2 - Vista rasante de la Banqueta (Demostrando que la banqueta está 100% libre)
	elif _frames == 18:
		cam.position = Vector3(14.0, 1.30, -4.8)
		cam.look_at_from_position(cam.position, Vector3(14.0, 1.25, -7.24))

	elif _frames == 22:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_sidewalk_clear_front_view.png")
				print("✓ Foto 2 guardada: cfe_sidewalk_clear_front_view.png")

	# Frame 26: Foto 3 - Vista angular mostrando el límite entre banqueta y lote
	elif _frames == 26:
		cam.position = Vector3(12.0, 1.70, -5.5)
		cam.look_at_from_position(cam.position, Vector3(14.0, 1.30, -7.24))

	elif _frames == 30:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_pillar_lot_edge_closeup.png")
				print("✓ Foto 3 guardada: cfe_pillar_lot_edge_closeup.png")

	# Frame 34: Foto 4 - Vista intermedia en X=21 demostrando que NO HAY mufa entre Casa 2 y Casa 3
	elif _frames == 34:
		cam.position = Vector3(21.0, 1.60, -4.8)
		cam.look_at_from_position(cam.position, Vector3(21.0, 1.50, -7.24))

	elif _frames == 38:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_boundary_no_pillar_view.png")
				print("✓ Foto 4 guardada: cfe_boundary_no_pillar_view.png")

	# Frame 42: Foto 5 - Segundo Pilar Compartido (entre Casa 3 y Casa 4 en X=28)
	elif _frames == 42:
		cam.position = Vector3(28.0, 1.40, -5.1)
		cam.look_at_from_position(cam.position, Vector3(28.0, 1.30, -7.24))

	elif _frames == 46:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/cfe_pillar_pair2_house3_4.png")
				print("✓ Foto 5 guardada: cfe_pillar_pair2_house3_4.png")

	elif _frames >= 52:
		quit(0)

	return false

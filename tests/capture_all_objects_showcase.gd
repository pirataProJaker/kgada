extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/8b68b0e0-4083-4400-b598-cc1d0465c181"

const AllObjectsEngineShowcaseScript = preload("res://scenes/all_objects_engine_showcase.gd")

var _frames := 0
var _showcase_node: Node = null
var _cam: Camera3D = null


func _init() -> void:
	print("=== INICIANDO CAPTURA FOTOGRÁFICA DEL ESCAPARATE DE TODOS LOS OBJETOS ===")
	var scn := load("res://scenes/all_objects_engine_showcase.tscn") as PackedScene
	_showcase_node = scn.instantiate()
	root.add_child(_showcase_node)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()
	if _cam == null and _showcase_node._camera != null:
		_cam = _showcase_node._camera

	if _cam == null:
		return false

	# Frame 12: Toma 1 - Vista Panorámica Gran Angular de toda la colección alineada de menor a mayor
	if _frames == 12:
		_cam.fov = 55.0
		_cam.position = Vector3(8.0, 7.5, 24.0)
		_cam.look_at_from_position(_cam.position, Vector3(8.0, 2.0, 0.0))

	elif _frames == 16:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/all_objects_panoramic_lineup.png")
				print("✓ Foto 1 guardada: all_objects_panoramic_lineup.png")

	# Frame 20: Toma 2 - Sección Pequeña y Mediana (Medidor CFE, electrodomésticos, mesitas de noche abiertas/cerradas, sillón, cocina)
	elif _frames == 20:
		_cam.fov = 42.0
		_cam.position = Vector3(-4.0, 2.5, 7.5)
		_cam.look_at_from_position(_cam.position, Vector3(-4.0, 1.0, 0.0))

	elif _frames == 24:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/all_objects_small_medium_closeup.png")
				print("✓ Foto 2 guardada: all_objects_small_medium_closeup.png")

	# Frame 28: Toma 3 - Sección Grande y Comercial (Refrigeradores abiertos, camas tendida y destendida, góndola OXXO, vitrinas y poste de 7m)
	elif _frames == 28:
		_cam.fov = 45.0
		_cam.position = Vector3(20.0, 3.8, 10.5)
		_cam.look_at_from_position(_cam.position, Vector3(20.0, 1.8, 0.0))

	elif _frames == 32:
		if vp:
			var img := vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/all_objects_large_commercial_closeup.png")
				print("✓ Foto 3 guardada: all_objects_large_commercial_closeup.png")

	elif _frames >= 36:
		print("=== TODAS LAS CAPTURAS GUARDADAS CON ÉXITO ===")
		quit(0)

	return false

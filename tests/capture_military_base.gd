extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	var scn = load("res://scenes/military_base_showcase.tscn")
	_showcase_node = scn.instantiate()
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	# Frame 10: Enfoque al Portón Principal y Garita (Preset 1)
	if _frames == 10:
		_showcase_node._teleport_to_preset(1)

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_entrance.png")
				print("✓ Captura guardada: military_base_entrance.png")

	# Frame 20: Enfoque a Hangares y Helipuerto (Preset 2)
	elif _frames == 20:
		_showcase_node._teleport_to_preset(2)

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_hangars.png")
				print("✓ Captura guardada: military_base_hangars.png")

	# Frame 30: Enfoque al Sector de Cuarteles y Barracones (Preset 3)
	elif _frames == 30:
		_showcase_node._teleport_to_preset(3)

	elif _frames == 35:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_barracks.png")
				print("✓ Captura guardada: military_base_barracks.png")

	# Frame 40: Enfoque al Cuartel General y Acceso al Búnker Subterráneo (Preset 4)
	elif _frames == 40:
		_showcase_node._teleport_to_preset(4)

	elif _frames == 45:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_hq_bunker.png")
				print("✓ Captura guardada: military_base_hq_bunker.png")

	# Frame 50: Vista Aérea Panorámica Cenital (Preset 0)
	elif _frames == 50:
		_showcase_node._teleport_to_preset(0)

	elif _frames == 55:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_aerial_overview.png")
				print("✓ Captura guardada: military_base_aerial_overview.png")

	# Frame 60: Probar la regeneración con tecla R (cambio de semilla)
	elif _frames == 60:
		_showcase_node._regenerate_base()
		_showcase_node._teleport_to_preset(0)

	elif _frames == 65:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/military_base_regenerated_seed.png")
				print("✓ Captura guardada: military_base_regenerated_seed.png")

	elif _frames >= 70:
		print("✓ Todas las capturas y pruebas de la Base Militar completadas con éxito.")
		quit(0)

	return false

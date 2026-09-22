extends SceneTree

## Script de captura automatizada para las 4 vistas del ecosistema botánico y geográfico.

var _frames: int = 0
var _scene: Node

func _init() -> void:
	var res = load("res://scenes/meadow_sunset_showcase.tscn")
	_scene = res.instantiate()
	root.add_child(_scene)

func _process(_delta: float) -> bool:
	_frames += 1
	var showcase = _scene
	var vp = root.get_viewport()
	
	# Vista 0: Panorámica
	if _frames == 10:
		showcase.call("_apply_camera_viewpoint", 0)
	elif _frames == 18:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_sunset_panoramic.png")
				print("✓ Vista 0 Panorámica guardada en: res://tests/meadow_sunset_panoramic.png")
		showcase.call("_apply_camera_viewpoint", 1)
		
	# Vista 1: Interior del Bosque y Suelo de Tierra/Mantillo
	elif _frames == 30:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_forest_dirt_closeup.png")
				print("✓ Vista 1 Bosque y Suelo de Tierra guardada en: res://tests/meadow_forest_dirt_closeup.png")
		showcase.call("_apply_camera_viewpoint", 2)
		
	# Vista 2: Primer plano de lavandas
	elif _frames == 42:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_lavender_closeup.png")
				print("✓ Vista 2 Lavandas guardada en: res://tests/meadow_lavender_closeup.png")
		showcase.call("_apply_camera_viewpoint", 3)
		
	# Vista 3: Primer plano de margaritas y pasto verde en el claro
	elif _frames == 54:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_daisy_closeup.png")
				print("✓ Vista 3 Margaritas guardada en: res://tests/meadow_daisy_closeup.png")
		
		print("\n=== RESUMEN DE ECOSISTEMA Y VEGETACIÓN INSTANCIADA ===")
		print("• Bosque, arboledas y árboles solitarios generados exclusivamente con ProceduralTree")
		print("• Suelo diferenciado con shader PSX: Césped verde vs. Tierra/Mantillo bajo árboles y sendero")
		print("• Césped FBX: Densidad ecológica adaptada (ralo en tierra, exuberante en pradera)")
		print("• Flores silvestres: Concentradas en claros soleados y cresta libre de árboles")
		print("======================================================\n")
		
		quit(0)
		return true
		
	return false

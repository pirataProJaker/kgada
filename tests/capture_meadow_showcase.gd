extends SceneTree

## Script de captura automatizada para las 4 vistas del ecosistema botánico al atardecer con rosas únicas.

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
	
	# Vista 0: Panorámica Atardecer
	if _frames == 10:
		showcase.call("_apply_camera_viewpoint", 0)
	elif _frames == 18:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_sunset_panoramic.png")
				print("✓ Vista 0 Panorámica guardada en: res://tests/meadow_sunset_panoramic.png")
		showcase.call("_apply_camera_viewpoint", 1)
		
	# Vista 1: Rosas Únicas en Primer Plano
	elif _frames == 30:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_roses_macro.png")
				print("✓ Vista 1 Rosas Únicas Macro guardada en: res://tests/meadow_roses_macro.png")
		showcase.call("_apply_camera_viewpoint", 2)
		
	# Vista 2: Valle de Flores y Rosas al Atardecer
	elif _frames == 42:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_lavender_closeup.png")
				img.save_png("res://tests/meadow_valle_flores.png")
				print("✓ Vista 2 Valle de Flores guardada en: res://tests/meadow_valle_flores.png")
		showcase.call("_apply_camera_viewpoint", 3)
		
	# Vista 3: Cresta y Bosque en el Ocaso
	elif _frames == 54:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/meadow_daisy_closeup.png")
				img.save_png("res://tests/meadow_cresta_bosque.png")
				print("✓ Vista 3 Cresta y Bosque guardada en: res://tests/meadow_cresta_bosque.png")
		
		print("\n=== RESUMEN DE MEADOW SUNSET CON ROSAS ÚNICAS ===")
		print("• Rosas únicas individuales (WildRose): carmesí, coral, marfil, dorado y pastel")
		print("• Cero arbustos de rosas: cada flor se alza en su propio tallo leñoso esbelto")
		print("• Bosque lateral y pino solitario en la cresta (ProceduralTree)")
		print("• Paisaje panorámico abierto y niebla cálida de atardecer sin vacíos")
		print("==================================================\n")
		
		quit(0)
		return true
		
	return false

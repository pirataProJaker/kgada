extends SceneTree

## Script de captura comparativa: PSX_Grass (Textura FBX) vs TriangleGrass (Procedural)

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
	
	# Frame 12: Capturar PSX_Grass Panorámica
	if _frames == 12:
		showcase.set("current_grass_mode", 0) # PSX_TEXTURE
		showcase.call("_apply_camera_viewpoint", 0)
	elif _frames == 18:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/cmp_psx_grass_panoramic.png")
				print("✓ Guardado: res://tests/cmp_psx_grass_panoramic.png")
		# Cambiar a vista 1 (Lavandas)
		showcase.call("_apply_camera_viewpoint", 1)
		
	# Frame 28: Capturar PSX_Grass Lavandas
	elif _frames == 28:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/cmp_psx_grass_lavender.png")
				print("✓ Guardado: res://tests/cmp_psx_grass_lavender.png")
		# Cambiar a TriangleGrass para comparación directa
		showcase.set("current_grass_mode", 1) # TRIANGLE_PROCEDURAL
		showcase.call("_populate_vegetation_multimesh", RandomNumberGenerator.new())
		showcase.call("_apply_camera_viewpoint", 0)
		
	# Frame 38: Capturar TriangleGrass Panorámica
	elif _frames == 38:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/cmp_triangle_grass_panoramic.png")
				print("✓ Guardado: res://tests/cmp_triangle_grass_panoramic.png")
		# Cambiar a vista 1 (Lavandas con TriangleGrass)
		showcase.call("_apply_camera_viewpoint", 1)
		
	# Frame 48: Capturar TriangleGrass Lavandas
	elif _frames == 48:
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img:
				img.save_png("res://tests/cmp_triangle_grass_lavender.png")
				print("✓ Guardado: res://tests/cmp_triangle_grass_lavender.png")
		
		# Restaurar a PSX_Grass
		showcase.set("current_grass_mode", 0)
		showcase.call("_populate_vegetation_multimesh", RandomNumberGenerator.new())
		showcase.call("_apply_camera_viewpoint", 0)
		
		print("\n=== CAPTURAS COMPARATIVAS COMPLETADAS CON ÉXITO ===")
		quit(0)
		return true
		
	return false

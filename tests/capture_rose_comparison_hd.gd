extends SceneTree

var _frames: int = 0
var _scene: Node
var _phase: int = 0

func _init() -> void:
	var res = load("res://tests/test_procedural_rose.tscn")
	_scene = res.instantiate()
	root.add_child(_scene)

	# Configurar escena en modo Shrub Rose centrado
	var test = _scene
	test.set("_display_mode", 2)
	test.call("_apply_visibility")
	test.set("_current_color_idx", 1) # Rosa Coral / Salmón
	test.call("_apply_colors")
	test.set("_wind_active", false)
	test.get_node("RoseShrub").wind_enabled = false
	test.get_node("HUD").visible = false

	# Forzar LOD0 inicialmente
	test.set("_forced_lod", 0)
	test.call("_apply_lod")

func _process(_delta: float) -> bool:
	_frames += 1
	var test = _scene
	
	if _phase == 0 and _frames == 10:
		var vp = root.get_viewport()
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img != null:
				img.save_png("res://tests/rose_lod0_grass.png")
				print("✓ LOD0 guardado en res://tests/rose_lod0_grass.png")
		
		# Cambiar a LOD1
		test.set("_forced_lod", 1)
		test.call("_apply_lod")
		_phase = 1
	
	elif _phase == 1 and _frames == 20:
		var vp = root.get_viewport()
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img != null:
				img.save_png("res://tests/rose_lod1_grass.png")
				print("✓ LOD1 guardado en res://tests/rose_lod1_grass.png")
		quit(0)
		return true
		
	return false

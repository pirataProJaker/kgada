extends SceneTree

const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")

var _frames: int = 0

func _init() -> void:
	# WorldEnvironment y Luz
	var env_node = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.18, 1.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.8
	env_node.environment = env
	root.add_child(env_node)

	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.96, 0.90)
	light.light_energy = 1.2
	root.add_child(light)

	# 3 Rosales: LOD0, LOD1, LOD2
	var positions = [Vector3(-1.1, 0, 0), Vector3(0.0, 0, 0), Vector3(1.1, 0, 0)]
	var lods = [0, 1, 2]
	var labels = ["LOD0 (Full HD)", "LOD1 (Prisma 3D + Hojas Tri)", "LOD2 (Triángulo 2D)"]

	for i in range(3):
		var rose = ProceduralFlower.new()
		root.add_child(rose)
		rose.position = positions[i]
		rose.profile_id = "shrub_rose"
		rose.flower_seed = 12345
		rose.color_index = 1 # Rosa Coral
		rose.growth_progress = 1.0
		rose.wind_enabled = false
		rose.forced_lod_level = lods[i]
		rose.generate()

		var tris = rose.get_triangle_count_lod(lods[i])
		print("Bush %s: %d tris, %d flowers" % [labels[i], tris, rose.get_flower_count()])

	# Cámara
	var cam = Camera3D.new()
	cam.position = Vector3(0.0, 0.8, 2.3)
	root.add_child(cam)
	cam.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)
	cam.current = true

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 15:
		var vp = root.get_viewport()
		if vp:
			var img: Image = vp.get_texture().get_image()
			if img != null:
				img.save_png("res://tests/rose_lods_comparison.png")
				print("✓ Captura de comparación guardada en: res://tests/rose_lods_comparison.png")
		quit(0)
		return true
	return false

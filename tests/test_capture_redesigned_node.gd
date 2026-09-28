extends Node3D

var camera: Camera3D
var flower_node: Node3D
var frame_count: int = 0
var artifact_dir: String = "C:/Users/PC 1/.gemini/antigravity-ide/brain/7665bda4-35a4-4713-97f9-d4941a9911be"

func _ready() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.70)
	env.ambient_light_energy = 1.2
	env_node.environment = env
	add_child(env_node)
	
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 45, 0)
	light.light_color = Color(1.0, 0.96, 0.90)
	light.light_energy = 1.6
	add_child(light)
	
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(25, -135, 0)
	fill_light.light_color = Color(0.6, 0.7, 0.9)
	fill_light.light_energy = 0.6
	add_child(fill_light)
	
	camera = Camera3D.new()
	camera.fov = 40.0
	add_child(camera)
	
	flower_node = Node3D.new()
	add_child(flower_node)
	
	_spawn_solitary_white()

func _spawn_solitary_white():
	for c in flower_node.get_children():
		c.queue_free()
	
	var ProceduralFlowerScript = load("res://world/procedural_flora/procedural_flower.gd")
	var flower = ProceduralFlowerScript.new()
	flower.profile_id = "solitary_rose"
	flower.growth_progress = 1.0
	flower.forced_lod_level = 0
	flower.color_index = 3 # Blanco marfil
	flower_node.add_child(flower)
	
	camera.position = Vector3(0.18, 0.58, 0.32)
	camera.look_at(Vector3(0, 0.44, 0), Vector3.UP)

func _spawn_solitary_red_close():
	for c in flower_node.get_children():
		c.queue_free()
	
	var ProceduralFlowerScript = load("res://world/procedural_flora/procedural_flower.gd")
	var flower = ProceduralFlowerScript.new()
	flower.profile_id = "solitary_rose"
	flower.growth_progress = 1.0
	flower.forced_lod_level = 0
	flower.color_index = 0 # Rojo carmesí
	flower_node.add_child(flower)
	
	camera.position = Vector3(0.14, 0.56, 0.22)
	camera.look_at(Vector3(0, 0.45, 0), Vector3.UP)

func _spawn_shrub_thick_stems():
	for c in flower_node.get_children():
		c.queue_free()
	
	var ProceduralFlowerScript = load("res://world/procedural_flora/procedural_flower.gd")
	var flower = ProceduralFlowerScript.new()
	flower.profile_id = "shrub_rose"
	flower.growth_progress = 1.0
	flower.forced_lod_level = 0
	flower.color_index = 1 # Coral
	flower_node.add_child(flower)
	
	camera.position = Vector3(0.70, 0.72, 1.10)
	camera.look_at(Vector3(0, 0.45, 0), Vector3.UP)

func _process(_delta: float) -> void:
	frame_count += 1
	if frame_count == 2:
		var img = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(artifact_dir + "/redesigned_rose_white.png")
		_spawn_solitary_red_close()
	elif frame_count == 4:
		var img = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(artifact_dir + "/redesigned_rose_red.png")
		_spawn_shrub_thick_stems()
	elif frame_count == 6:
		var img = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(artifact_dir + "/redesigned_rose_shrub.png")
		get_tree().quit(0)

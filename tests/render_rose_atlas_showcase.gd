extends SceneTree

const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")

var _frames: int = 0
var _root_node: Node3D
var _vp: SubViewport

func _init() -> void:
	_root_node = Node3D.new()
	root.add_child(_root_node)
	
	# SubViewport 1280x720 para renderizado cristalino
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_root_node.add_child(_vp)
	
	var world := Node3D.new()
	_vp.add_child(world)
	
	# Iluminación y Cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.17, 0.19)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.60)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D().rotated(Vector3.UP, deg_to_rad(-45.0)).rotated(Vector3.RIGHT, deg_to_rad(-35.0))
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.shadow_enabled = true
	world.add_child(sun)
	
	# Suelo suave
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(20, 20)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.18, 0.22, 0.16)
	ground_mat.roughness = 0.95
	var ground := MeshInstance3D.new()
	ground.mesh = ground_mesh
	ground.material_override = ground_mat
	world.add_child(ground)
	
	# Rosas Solitarias en fila mostrando la textura fotográfica con diferentes tintes procedurales:
	# 1. Rosa Blanca Marfil (textura 100% pura original del atlas)
	var rose_white := ProceduralFlower.new()
	rose_white.profile_id = "solitary_rose"
	rose_white.color_index = 4 # Blanco Marfil
	rose_white.forced_lod_level = 0
	rose_white.wind_enabled = false
	rose_white.position = Vector3(-0.65, 0, 0.15)
	world.add_child(rose_white)
	
	# 2. Rosa Roja Carmesí (tinte terciopelo sobre pétalos reales)
	var rose_red := ProceduralFlower.new()
	rose_red.profile_id = "solitary_rose"
	rose_red.color_index = 0 # Carmesí
	rose_red.forced_lod_level = 0
	rose_red.wind_enabled = false
	rose_red.position = Vector3(-0.30, 0, 0.05)
	world.add_child(rose_red)
	
	# 3. Rosa Coral / Salmón (tinte salmón suave)
	var rose_coral := ProceduralFlower.new()
	rose_coral.profile_id = "solitary_rose"
	rose_coral.color_index = 1 # Coral
	rose_coral.forced_lod_level = 0
	rose_coral.wind_enabled = false
	rose_coral.position = Vector3(0.05, 0, -0.05)
	world.add_child(rose_coral)
	
	# 4. Rosa Amarilla Dorada
	var rose_yellow := ProceduralFlower.new()
	rose_yellow.profile_id = "solitary_rose"
	rose_yellow.color_index = 3 # Amarillo Oro
	rose_yellow.forced_lod_level = 0
	rose_yellow.wind_enabled = false
	rose_yellow.position = Vector3(0.40, 0, 0.10)
	world.add_child(rose_yellow)
	
	# 5. Rosal Arbustivo en floración completa con hojas serradas reales y tallos leñosos
	var shrub := ProceduralFlower.new()
	shrub.profile_id = "shrub_rose"
	shrub.color_index = 4 # Blanco Puro como el atlas
	shrub.forced_lod_level = 0
	shrub.flower_seed = 777
	shrub.wind_enabled = false
	shrub.position = Vector3(1.35, 0, -0.2)
	world.add_child(shrub)
	
	# Cámara cercana orbital
	var cam := Camera3D.new()
	cam.transform = Transform3D().looking_at(Vector3(0.2, 0.35, 0), Vector3.UP)
	cam.position = Vector3(0.15, 0.72, 1.45)
	cam.look_at(Vector3(0.25, 0.40, 0.0), Vector3.UP)
	cam.fov = 36.0
	_vp.add_child(cam)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames >= 15:
		var img: Image = _vp.get_texture().get_image()
		if img != null:
			img.save_png("res://tests/procedural_rose_atlas_showcase.png")
			print("✓ Showcase guardado en res://tests/procedural_rose_atlas_showcase.png")
		quit(0)
		return true
	return false

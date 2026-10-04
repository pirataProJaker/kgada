extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"

const FurnitureMultiMeshSystemScript = preload("res://world/furniture/furniture_multimesh_system.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const PlanarPropsManagerScript = preload("res://world/furniture/planar_props_manager.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D
var _env: Environment
var _sun: DirectionalLight3D
var _sky_mat: ProceduralSkyMaterial

func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	FurnitureTextureManagerScript.ensure_initialized()
	PlanarPropsManagerScript.ensure_initialized()

	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.24, 0.46, 0.72)
	_sky_mat.sky_horizon_color = Color(0.72, 0.80, 0.88)
	_sky_mat.ground_bottom_color = Color(0.25, 0.22, 0.18)
	_sky_mat.ground_horizon_color = Color(0.65, 0.62, 0.58)

	var sky := Sky.new()
	sky.sky_material = _sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color(0.68, 0.72, 0.78)
	_env.ambient_light_energy = 1.15
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var env_node := WorldEnvironment.new()
	env_node.environment = _env
	_root.add_child(env_node)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50.0, 42.0, 0.0)
	_sun.light_color = Color(1.0, 0.98, 0.90)
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_root.add_child(_sun)

	# Habitación
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.85, 0.78, 0.70)
	wall_mat.roughness = 0.90

	var wall_n := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(6.0, 2.8, 0.2)
	wall_n.mesh = wall_mesh
	wall_n.position = Vector3(0.0, 1.4, -2.5)
	wall_n.material_override = wall_mat
	_root.add_child(wall_n)

	var wall_w := MeshInstance3D.new()
	var wall_w_mesh := BoxMesh.new()
	wall_w_mesh.size = Vector3(0.2, 2.8, 6.0)
	wall_w.mesh = wall_w_mesh
	wall_w.position = Vector3(-2.5, 1.4, 0.0)
	wall_w.material_override = wall_mat
	_root.add_child(wall_w)

	var floor_inst := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(6.0, 0.1, 6.0)
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(0.0, -0.05, 0.0)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.80, 0.78, 0.75)
	floor_mat.roughness = 0.88
	floor_inst.material_override = floor_mat
	_root.add_child(floor_inst)

	var f_system := FurnitureMultiMeshSystemScript.new()
	_root.add_child(f_system)

	var bed_tf := Transform3D(Basis(), Vector3(-1.1, 0.0, -1.0))
	f_system.add_bed_single(bed_tf, 0, 0, 12, true, 0.0)

	var rug_tf := Transform3D(Basis(), Vector3(0.25, 0.005, -0.9))
	f_system.add_planar_floor_prop(rug_tf, "rug_10")

	var ns_tf := Transform3D(Basis(), Vector3(-1.9, 0.0, -1.8))
	f_system.add_nightstand(ns_tf)
	f_system.add_mug(ns_tf.translated_local(Vector3(0.0, 0.52, 0.0)))

	f_system.build(false)

	_cam = Camera3D.new()
	_cam.current = true
	_cam.fov = 42.0
	_cam.position = Vector3(-0.5, 3.8, 0.5)
	_cam.look_at_from_position(_cam.position, Vector3(-0.5, 0.2, -1.1))
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp := root.get_viewport()

	# Frame 10: ACES + Ambient Color balanceado cálido
	if _frames == 10:
		_env.tonemap_mode = Environment.TONE_MAPPER_ACES
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_env.ambient_light_color = Color(0.84, 0.82, 0.80)
		_env.ambient_light_energy = 0.90

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/diag_aces_warm_ambient.png")
				print("✓ Captura guardada: diag_aces_warm_ambient.png")

	# Frame 20: Vista general del vecindario para asegurar que el exterior también se vea espectacular
	elif _frames == 20:
		quit(0)

	return false

extends SceneTree

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/fe84eb72-a6fa-4f9f-8370-fc8059b277db"
const OBJ_DIR := "res://assets/textures/furniture/psx_pack/psx-furniture-free/obj/"
const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")

var _frames := 0
var _root: Node3D
var _cam: Camera3D

static func load_obj_mesh(filename: String, target_obj: String = "", offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
	var path := OBJ_DIR + filename
	var gpath := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(gpath):
		printerr("No existe: ", gpath)
		return null

	var file := FileAccess.open(gpath, FileAccess.READ)
	if file == null:
		printerr("Error al abrir: ", gpath)
		return null

	var vs: Array[Vector3] = []
	var vts: Array[Vector2] = []
	var vns: Array[Vector3] = []

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var current_o := "default"
	var triangles_added := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue

		var parts := line.split(" ", false)
		if parts.is_empty():
			continue

		var cmd := parts[0]
		if cmd == "v" and parts.size() >= 4:
			vs.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()) + offset)
		elif cmd == "vt" and parts.size() >= 3:
			vts.append(Vector2(parts[1].to_float(), 1.0 - parts[2].to_float()))
		elif cmd == "vn" and parts.size() >= 4:
			vns.append(Vector3(parts[1].to_float(), parts[2].to_float(), parts[3].to_float()))
		elif cmd == "o" and parts.size() >= 2:
			current_o = parts[1]
		elif cmd == "f" and parts.size() >= 4:
			if target_obj != "" and current_o != target_obj:
				continue

			var face_verts: Array[Dictionary] = []
			for i in range(1, parts.size()):
				var token := parts[i]
				var indices := token.split("/")
				var vi := indices[0].to_int() - 1
				var vti := -1
				var vni := -1
				if indices.size() > 1 and not indices[1].is_empty():
					vti = indices[1].to_int() - 1
				if indices.size() > 2 and not indices[2].is_empty():
					vni = indices[2].to_int() - 1
				face_verts.append({"v": vi, "vt": vti, "vn": vni})

			if face_verts.size() == 3:
				_add_triangle(st, vs, vts, vns, face_verts[0], face_verts[1], face_verts[2])
				triangles_added += 1
			elif face_verts.size() == 4:
				_add_triangle(st, vs, vts, vns, face_verts[0], face_verts[1], face_verts[2])
				_add_triangle(st, vs, vts, vns, face_verts[0], face_verts[2], face_verts[3])
				triangles_added += 2

	file.close()

	if triangles_added == 0:
		return null

	st.generate_tangents()
	return st.commit()


static func _add_triangle(st: SurfaceTool, vs: Array[Vector3], vts: Array[Vector2], vns: Array[Vector3], v0: Dictionary, v1: Dictionary, v2: Dictionary) -> void:
	for fv in [v0, v1, v2]:
		if fv.vn >= 0 and fv.vn < vns.size():
			st.set_normal(vns[fv.vn])
		if fv.vt >= 0 and fv.vt < vts.size():
			st.set_uv(vts[fv.vt])
		if fv.v >= 0 and fv.v < vs.size():
			st.add_vertex(vs[fv.v])


func _init() -> void:
	_root = Node3D.new()
	root.add_child(_root)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.85, 0.88, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.76)
	env.ambient_light_energy = 1.2
	env_node.environment = env
	_root.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.98, 0.94)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	_root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -140.0, 0.0)
	fill.light_color = Color(0.70, 0.78, 0.90)
	fill.light_energy = 0.55
	_root.add_child(fill)

	# Suelo
	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(20.0, 0.1, 20.0)
	floor_mesh.mesh = floor_box
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.90, 0.90, 0.88)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(0.0, -0.05, 0.0)
	_root.add_child(floor_mesh)

	var mat_props := FurniturePropsBuilderScript.get_props_material(0.65, 0.02)

	# 1. Cama Single Bed Oak
	var bed_mesh := load_obj_mesh("bed_single_oak.obj")
	var bed_node := MeshInstance3D.new()
	bed_node.mesh = bed_mesh
	bed_node.material_override = mat_props
	bed_node.position = Vector3(0.0, 0.0, -0.2)
	_root.add_child(bed_node)

	# 2. Ropero Wardrobe Oak
	var wd_mesh := load_obj_mesh("wardrobe_oak.obj")
	var wd_node := MeshInstance3D.new()
	wd_node.mesh = wd_mesh
	wd_node.material_override = mat_props
	wd_node.position = Vector3(1.6, 0.0, -1.0)
	_root.add_child(wd_node)

	# 3. Mesa de noche Nightstand Oak
	var ns_mesh := load_obj_mesh("nightstand_oak.obj")
	var ns_node := MeshInstance3D.new()
	ns_node.mesh = ns_mesh
	ns_node.material_override = mat_props
	ns_node.position = Vector3(-1.15, 0.0, -1.0)
	_root.add_child(ns_node)

	# 4. Librero Bookcase Tall
	var bc_mesh := load_obj_mesh("bookcase_tall.obj")
	var bc_node := MeshInstance3D.new()
	bc_node.mesh = bc_mesh
	bc_node.material_override = mat_props
	bc_node.position = Vector3(-2.2, 0.0, -1.2)
	_root.add_child(bc_node)

	# 5. Fregadero Sink Unit White
	var sink_mesh := load_obj_mesh("sink_unit_white.obj")
	var sink_node := MeshInstance3D.new()
	sink_node.mesh = sink_mesh
	sink_node.material_override = mat_props
	sink_node.position = Vector3(3.2, 0.0, -0.5)
	sink_node.rotation_degrees.y = -35.0
	_root.add_child(sink_node)

	# 6. Tapete trenzado
	var rug_mesh := load_obj_mesh("rug_braided.obj")
	var rug_node := MeshInstance3D.new()
	rug_node.mesh = rug_mesh
	rug_node.material_override = mat_props
	rug_node.position = Vector3(0.0, 0.002, 0.5)
	_root.add_child(rug_node)

	# 7. Consumibles: Leche, Cereal, Sopa, Cerveza, Taza, Plato
	var milk_mesh := load_obj_mesh("milk.obj")
	var milk_node := MeshInstance3D.new()
	milk_node.mesh = milk_mesh
	milk_node.material_override = mat_props
	milk_node.position = Vector3(-1.05, 0.71, -0.95)
	_root.add_child(milk_node)

	var cereal_mesh := load_obj_mesh("cereal_corn.obj")
	var cereal_node := MeshInstance3D.new()
	cereal_node.mesh = cereal_mesh
	cereal_node.material_override = mat_props
	cereal_node.position = Vector3(-1.20, 0.71, -1.05)
	_root.add_child(cereal_node)

	var soup_mesh := load_obj_mesh("can_soup.obj")
	var soup_node := MeshInstance3D.new()
	soup_node.mesh = soup_mesh
	soup_node.material_override = mat_props
	soup_node.position = Vector3(2.85, 0.88, -0.45)
	_root.add_child(soup_node)

	var beer_mesh := load_obj_mesh("beer_can.obj")
	var beer_node := MeshInstance3D.new()
	beer_node.mesh = beer_mesh
	beer_node.material_override = mat_props
	beer_node.position = Vector3(2.95, 0.88, -0.35)
	_root.add_child(beer_node)

	var plate_mesh := load_obj_mesh("plate.obj")
	var plate_node := MeshInstance3D.new()
	plate_node.mesh = plate_mesh
	plate_node.material_override = mat_props
	plate_node.position = Vector3(3.40, 0.88, -0.65)
	_root.add_child(plate_node)

	var news_mesh := load_obj_mesh("newspaper.obj")
	var news_node := MeshInstance3D.new()
	news_node.mesh = news_mesh
	news_node.material_override = mat_props
	news_node.position = Vector3(0.15, 0.45, 0.3)
	news_node.rotation_degrees.y = 15.0
	_root.add_child(news_node)

	_cam = Camera3D.new()
	_cam.current = true
	_root.add_child(_cam)


func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	if _frames == 10:
		_cam.position = Vector3(0.6, 2.2, 3.8)
		_cam.look_at_from_position(_cam.position, Vector3(0.2, 0.85, -0.5))

	elif _frames == 15:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/test_obj_perfect_lineup.png")
				print("✓ Captura guardada: test_obj_perfect_lineup.png")

	elif _frames == 20:
		_cam.position = Vector3(-1.15, 1.3, 0.3)
		_cam.look_at_from_position(_cam.position, Vector3(-1.15, 0.70, -1.0))

	elif _frames == 25:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/test_obj_perfect_closeup.png")
				print("✓ Captura guardada: test_obj_perfect_closeup.png")

	elif _frames >= 30:
		print("✓ Pruebas completadas.")
		quit(0)

	return false

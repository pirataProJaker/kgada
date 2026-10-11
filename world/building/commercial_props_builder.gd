class_name CommercialPropsBuilder
extends RefCounted

## Constructor y Ensamblador de Elementos e Infraestructura Comercial (Play Sector X)
## Especializado en Tiendas de Conveniencia (OTXO) y Negocios:
## - Tótem publicitario gigante exterior en esquina/frente con logo oficial iluminado.
## - Letrero de fachada sobre marquesina con logo oficial.
## - Pintura de cajones de estacionamiento y topes amarillos de concreto.
## - Bolardos amarillos de acero de protección peatonal en banqueta.
## - Hielera exterior ("HIELO") y botes dobles de basura.

const OTXO_LOGO_PATH := "res://assets/textures/commercial/otxo_logo.png"
const CommercialShelfModularScript = preload("res://world/furniture/commercial_shelf_modular.gd")
const CommercialRefrigeratorModularScript = preload("res://world/furniture/commercial_refrigerator_modular.gd")


static var _cached_logo_texture: Texture2D = null
static var _cached_logo_material: StandardMaterial3D = null
static var _cached_unit_cylinder: CylinderMesh = null
static var _cached_cylinder_material: StandardMaterial3D = null


## Obtiene la textura del logo OTXO de forma resiliente
static func get_logo_texture() -> Texture2D:
	if _cached_logo_texture != null:
		return _cached_logo_texture

	var gpath := ProjectSettings.globalize_path(OTXO_LOGO_PATH)
	if FileAccess.file_exists(gpath):
		var img := Image.load_from_file(gpath)
		if img and not img.is_empty():
			_cached_logo_texture = ImageTexture.create_from_image(img)
			return _cached_logo_texture

	if ResourceLoader.exists(OTXO_LOGO_PATH):
		_cached_logo_texture = load(OTXO_LOGO_PATH)

	return _cached_logo_texture


## Obtiene el material iluminado para los letreros OTXO
static func get_logo_material() -> StandardMaterial3D:
	if _cached_logo_material != null:
		return _cached_logo_material

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_texture = get_logo_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.roughness = 0.35
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Emisión sutil para simular letrero luminoso tipo caja de luz
	mat.emission_enabled = true
	mat.emission_texture = mat.albedo_texture
	mat.emission_energy_multiplier = 0.40

	_cached_logo_material = mat
	return _cached_logo_material


## Malla geométrica base unitaria low-poly de 12 lados (Estándar medidor CFE / PSX)
## Usada para hiperoptimización en 1 sola Draw Call para todos los props cilíndricos.
static func get_unit_cylinder_mesh() -> CylinderMesh:
	if _cached_unit_cylinder == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0
		cyl.bottom_radius = 1.0
		cyl.height = 1.0
		cyl.radial_segments = 12 # Exactamente 12 lados: estándar medidor CFE / estética PSX
		cyl.rings = 1
		_cached_unit_cylinder = cyl
	return _cached_unit_cylinder


## Material compartido PBR para todos los elementos cilíndricos con color por instancia
static func get_cylinder_shared_material() -> StandardMaterial3D:
	if _cached_cylinder_material == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.55
		mat.metallic = 0.45
		_cached_cylinder_material = mat
	return _cached_cylinder_material


## Registra una instancia cilíndrica calculando su transformación matemática y color al vuelo
static func add_cylinder_instance(list: Array[Dictionary], center: Vector3, radius: float, height: float, color: Color, rot_basis: Basis = Basis.IDENTITY) -> void:
	var b: Basis
	if rot_basis.is_equal_approx(Basis.IDENTITY):
		b = Basis.from_scale(Vector3(radius, height, radius))
	else:
		b = rot_basis.scaled(Vector3(radius, height, radius))
	list.append({
		"transform": Transform3D(b, center),
		"color": color
	})


## Construye y ancla todos los elementos comerciales al nodo de la tienda
static func build_all_commercial_elements(parent_node: Node3D, comm_data: Dictionary, rooms_data: Array = [], house_w: float = 16.0, house_d: float = 16.0) -> void:
	if comm_data.is_empty():
		return

	var root := Node3D.new()
	root.name = "CommercialInfrastructure"
	parent_node.add_child(root)

	var cylinder_instances: Array[Dictionary] = []

	# 1. Tótem Gigante Exterior (Poste de acero cilíndrico low-poly instanciado por GPU, 8 a 10 mts de altura)
	var totem_data: Dictionary = comm_data.get("totem_sign", {})
	if not totem_data.is_empty():
		var totem_pos: Vector3 = totem_data.get("position", Vector3.ZERO)
		var totem_h: float = float(totem_data.get("height", 8.8))
		# El poste del OTXO mide exactamente entre 8.0 y 10.0 metros de altura
		var pole_h: float = clampf(totem_h, 8.0, 10.0)
		# Mástil estructural instanciado por GPU con el cilindro medidor CFE (se detiene en la base del letrero)
		add_cylinder_instance(
			cylinder_instances,
			totem_pos + Vector3(0.0, pole_h * 0.5, 0.0),
			0.22,
			pole_h,
			Color(0.24, 0.25, 0.27)
		)
		var totem_node := build_totem_sign(totem_data)
		root.add_child(totem_node)

	# 2. Letreros de Fachada en Marquesina y Puertas Corredizas de Cristal
	var fascia_list: Array = comm_data.get("fascia_signs", [])
	for fs_dict in fascia_list:
		var sign_node := build_fascia_sign(fs_dict)
		root.add_child(sign_node)

	# Puertas automáticas de cristal templado en el acceso principal
	if not fascia_list.is_empty():
		var fs_dict: Dictionary = fascia_list[0]
		var fs_pos: Vector3 = fs_dict.get("position", Vector3.ZERO)
		var fs_rot: float = float(fs_dict.get("rotation_y", 0.0))
		var door_pos := Vector3(fs_pos.x, 0.0, fs_pos.z + 0.45)
		var door_basis := Basis(Vector3.UP, fs_rot)

		var sliding_doors := build_sliding_doors(door_pos, 2.0, 2.4, fs_rot)
		root.add_child(sliding_doors)

		# Agarraderas de la puerta de cristal: 2 puertas con agarraderas verticales centradas
		# Cada hoja de cristal tiene su manijón tubular rojo y pernos pasantes horizontales
		var h_red := Color(0.85, 0.08, 0.08) # Rojo corporativo OTXO
		var stud_dark := Color(0.20, 0.20, 0.20)
		var rot_horizontal := Basis(Vector3.RIGHT, PI * 0.5)

		# Hoja Izquierda: Manijón vertical centrado a 5cm de la unión (exterior e interior)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(-0.05, 1.05, -0.045), 0.022, 0.70, h_red, door_basis)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(-0.05, 1.05, 0.045), 0.022, 0.70, h_red, door_basis)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(-0.05, 0.76, 0.0), 0.012, 0.10, stud_dark, door_basis * rot_horizontal)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(-0.05, 1.34, 0.0), 0.012, 0.10, stud_dark, door_basis * rot_horizontal)

		# Hoja Derecha: Manijón vertical centrado a 5cm de la unión (exterior e interior)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(0.05, 1.05, -0.045), 0.022, 0.70, h_red, door_basis)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(0.05, 1.05, 0.045), 0.022, 0.70, h_red, door_basis)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(0.05, 0.76, 0.0), 0.012, 0.10, stud_dark, door_basis * rot_horizontal)
		add_cylinder_instance(cylinder_instances, door_pos + door_basis * Vector3(0.05, 1.34, 0.0), 0.012, 0.10, stud_dark, door_basis * rot_horizontal)

	# 3. Cajones de Estacionamiento (Líneas y Topes)
	var bays_list: Array = comm_data.get("parking_bays", [])
	if not bays_list.is_empty():
		var bays_node := build_parking_bays(bays_list)
		root.add_child(bays_node)

	# 4. Bolardos Amarillos en Banqueta (GPU Instancing del cilindro medidor CFE)
	var bollards_list: Array = comm_data.get("bollards", [])
	if not bollards_list.is_empty():
		for b_pos in bollards_list:
			# Cuerpo amarillo tráfico
			add_cylinder_instance(cylinder_instances, b_pos + Vector3(0.0, 0.425, 0.0), 0.10, 0.85, Color(0.96, 0.76, 0.05))
			# Franja reflectante negra superior
			add_cylinder_instance(cylinder_instances, b_pos + Vector3(0.0, 0.72, 0.0), 0.103, 0.12, Color(0.12, 0.12, 0.12))

		var bollards_node := build_bollards(bollards_list)
		root.add_child(bollards_node)

	# 5. Hielera Exterior
	if comm_data.has("ice_freezer"):
		var ice_pos: Vector3 = comm_data["ice_freezer"]
		var ice_node := build_ice_freezer(ice_pos)
		root.add_child(ice_node)

	# 6. Bote de Basura Cilíndrico de Banqueta (Cilindro low-poly medidor CFE)
	if comm_data.has("trash_bin"):
		var trash_pos: Vector3 = comm_data["trash_bin"]
		# Cuerpo cilíndrico metálico oscuro
		add_cylinder_instance(cylinder_instances, trash_pos + Vector3(0.0, 0.425, 0.0), 0.25, 0.85, Color(0.24, 0.26, 0.28))
		# Collarín / reborde superior
		add_cylinder_instance(cylinder_instances, trash_pos + Vector3(0.0, 0.89, 0.0), 0.265, 0.08, Color(0.14, 0.15, 0.16))
		# Abertura superior para depósito de basura
		add_cylinder_instance(cylinder_instances, trash_pos + Vector3(0.0, 0.935, 0.0), 0.18, 0.02, Color(0.04, 0.04, 0.04))

		var trash_node := build_trash_bin(trash_pos)
		root.add_child(trash_node)

	# =========================================================================
	# GPU HARDWARE INSTANCING (MultiMeshInstance3D) DE TODOS LOS ELEMENTOS CILÍNDRICOS
	# Poste de tótem + Bolardos + Bote de basura + Agarraderas de puerta en 1 SOLA DRAW CALL
	# =========================================================================
	if not cylinder_instances.is_empty():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.instance_count = cylinder_instances.size()
		mm.mesh = get_unit_cylinder_mesh()

		for idx in cylinder_instances.size():
			var inst: Dictionary = cylinder_instances[idx]
			mm.set_instance_transform(idx, inst["transform"])
			mm.set_instance_color(idx, inst["color"])

		var mm_inst := MultiMeshInstance3D.new()
		mm_inst.name = "CommercialCylindersMultiMesh"
		mm_inst.multimesh = mm
		mm_inst.material_override = get_cylinder_shared_material()
		root.add_child(mm_inst)

	# 7. Mobiliario Interior Característico de la Tienda OTXO (Cajas, Góndolas, Cuarto Frío, Café)
	for r in rooms_data:
		var r_name: String = r.get("name", "")
		if r_name == "Piso de Venta":
			var interior_node := build_interior_store(r, house_w, house_d)
			root.add_child(interior_node)
			break


## Genera una malla plana 2D (normal +Z) con esquinas redondeadas low-poly (estilo PSX)
## y coordenadas UV mapeadas de [0, 1] que cubren todo el logo OTXO.
static func create_lowpoly_squircle_quad(width: float, height: float, radius: float) -> ArrayMesh:
	var hw := width * 0.5
	var hh := height * 0.5
	var r := minf(radius, minf(hw, hh) * 0.8)

	# 12 vértices del perímetro (4 esquinas x 3 vértices / 2 segmentos cada esquina)
	var pts := PackedVector2Array()
	var corner_centers := [
		Vector2(hw - r, hh - r),   # 0: Superior Derecha
		Vector2(-hw + r, hh - r),  # 1: Superior Izquierda
		Vector2(-hw + r, -hh + r), # 2: Inferior Izquierda
		Vector2(hw - r, -hh + r),  # 3: Inferior Derecha
	]

	for c in 4:
		var center: Vector2 = corner_centers[c]
		var base_angle := float(c) * (PI * 0.5)
		pts.append(center + Vector2(cos(base_angle) * r, sin(base_angle) * r))
		pts.append(center + Vector2(cos(base_angle + PI * 0.25) * r, sin(base_angle + PI * 0.25) * r))
		pts.append(center + Vector2(cos(base_angle + PI * 0.50) * r, sin(base_angle + PI * 0.50) * r))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var normal := Vector3(0.0, 0.0, 1.0)
	var num_pts := pts.size()
	var center_uv := Vector2(0.5, 0.5)

	for i in num_pts:
		var i_next := (i + 1) % num_pts
		var p1 := pts[i]
		var p2 := pts[i_next]

		var uv1 := Vector2((p1.x / width) + 0.5, 0.5 - (p1.y / height))
		var uv2 := Vector2((p2.x / width) + 0.5, 0.5 - (p2.y / height))

		st.set_normal(normal)
		st.set_uv(center_uv)
		st.add_vertex(Vector3(0.0, 0.0, 0.0))

		st.set_normal(normal)
		st.set_uv(uv1)
		st.add_vertex(Vector3(p1.x, p1.y, 0.0))

		st.set_normal(normal)
		st.set_uv(uv2)
		st.add_vertex(Vector3(p2.x, p2.y, 0.0))

	return st.commit()


## Genera una caja 3D extruida con esquinas redondeadas low-poly (PSX) para marcos de letreros
static func create_lowpoly_squircle_box(width: float, height: float, depth: float, radius: float) -> ArrayMesh:
	var hw := width * 0.5
	var hh := height * 0.5
	var hd := depth * 0.5
	var r := minf(radius, minf(hw, hh) * 0.8)

	var pts := PackedVector2Array()
	var corner_centers := [
		Vector2(hw - r, hh - r),
		Vector2(-hw + r, hh - r),
		Vector2(-hw + r, -hh + r),
		Vector2(hw - r, -hh + r),
	]

	for c in 4:
		var center: Vector2 = corner_centers[c]
		var base_angle := float(c) * (PI * 0.5)
		pts.append(center + Vector2(cos(base_angle) * r, sin(base_angle) * r))
		pts.append(center + Vector2(cos(base_angle + PI * 0.25) * r, sin(base_angle + PI * 0.25) * r))
		pts.append(center + Vector2(cos(base_angle + PI * 0.50) * r, sin(base_angle + PI * 0.50) * r))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var num_pts := pts.size()

	# 1. Tapa Frontal (+Z)
	for i in num_pts:
		var i_next := (i + 1) % num_pts
		var p1 := pts[i]
		var p2 := pts[i_next]
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(0, 0, hd))
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(p1.x, p1.y, hd))
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(Vector3(p2.x, p2.y, hd))

	# 2. Tapa Trasera (-Z)
	for i in num_pts:
		var i_next := (i + 1) % num_pts
		var p1 := pts[i]
		var p2 := pts[i_next]
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(0, 0, -hd))
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(p2.x, p2.y, -hd))
		st.set_normal(Vector3(0, 0, -1))
		st.add_vertex(Vector3(p1.x, p1.y, -hd))

	# 3. Lados perimetrales extruidos
	for i in num_pts:
		var i_next := (i + 1) % num_pts
		var p1 := pts[i]
		var p2 := pts[i_next]
		var edge := p2 - p1
		var side_norm := Vector3(edge.y, -edge.x, 0.0).normalized()

		st.set_normal(side_norm)
		st.add_vertex(Vector3(p1.x, p1.y, hd))
		st.set_normal(side_norm)
		st.add_vertex(Vector3(p2.x, p2.y, hd))
		st.set_normal(side_norm)
		st.add_vertex(Vector3(p2.x, p2.y, -hd))

		st.set_normal(side_norm)
		st.add_vertex(Vector3(p1.x, p1.y, hd))
		st.set_normal(side_norm)
		st.add_vertex(Vector3(p2.x, p2.y, -hd))
		st.set_normal(side_norm)
		st.add_vertex(Vector3(p1.x, p1.y, -hd))

	return st.commit()


## Construye el tótem publicitario gigante con caja luminosa de dos caras (mástil vía GPU instancing)
static func build_totem_sign(data: Dictionary) -> Node3D:
	var totem := Node3D.new()
	totem.name = "OTXO_TotemSign"
	totem.position = data.get("position", Vector3.ZERO)
	totem.rotation.y = data.get("rotation_y", 0.0)
	var height: float = float(data.get("height", 8.8))
	var pole_h: float = clampf(height, 8.0, 10.0)

	# Colisión física en el poste para vehículos y jugador
	var pole_body := StaticBody3D.new()
	pole_body.name = "PoleCollision"
	var col_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.24
	cyl_shape.height = pole_h
	col_shape.shape = cyl_shape
	col_shape.position.y = pole_h * 0.5
	pole_body.add_child(col_shape)
	totem.add_child(pole_body)

	# Dimensiones del letrero OTXO: alargado hacia los lados (+25% de ancho)
	var box_w := 3.125 # 2.50 * 1.25 (+25% horizontal)
	var box_h := 2.05
	var box_d := 0.35
	var corner_r := 0.34
	# Elevado para reposar limpiamente sobre el mástil sin que el tubo penetre en el letrero
	var box_y := pole_h + (box_h * 0.5) + 0.15

	# Soporte estructural de acero entre el mástil y la base del letrero
	var bracket := MeshInstance3D.new()
	bracket.name = "PoleMountBracket"
	var bracket_mesh := BoxMesh.new()
	bracket_mesh.size = Vector3(1.35, 0.18, 0.26)
	bracket.mesh = bracket_mesh
	var mat_bracket := StandardMaterial3D.new()
	mat_bracket.albedo_color = Color(0.20, 0.21, 0.23)
	bracket.material_override = mat_bracket
	bracket.position.y = pole_h + 0.09
	totem.add_child(bracket)

	# Marco perimetral rojo de la caja de luz con esquinas redondeadas low-poly
	var frame_mesh := create_lowpoly_squircle_box(box_w + 0.10, box_h + 0.10, box_d, corner_r + 0.02)
	var mat_frame := StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.85, 0.08, 0.08) # Rojo OTXO
	mat_frame.roughness = 0.50

	var frame_inst := MeshInstance3D.new()
	frame_inst.name = "SignboardFrame"
	frame_inst.mesh = frame_mesh
	frame_inst.material_override = mat_frame
	frame_inst.position.y = box_y
	totem.add_child(frame_inst)

	# Caras frontal y trasera con malla squircle low-poly
	var squircle_mesh := create_lowpoly_squircle_quad(box_w, box_h, corner_r)

	# Cara frontal (-Z)
	var front_quad := MeshInstance3D.new()
	front_quad.name = "SignboardLogoFront"
	front_quad.mesh = squircle_mesh
	front_quad.material_override = get_logo_material()
	front_quad.position = Vector3(0.0, box_y, -box_d * 0.5 - 0.01)
	front_quad.rotation.y = PI
	totem.add_child(front_quad)

	# Cara trasera (+Z)
	var back_quad := MeshInstance3D.new()
	back_quad.name = "SignboardLogoBack"
	back_quad.mesh = squircle_mesh
	back_quad.material_override = get_logo_material()
	back_quad.position = Vector3(0.0, box_y, box_d * 0.5 + 0.01)
	totem.add_child(back_quad)

	return totem


## Construye el letrero de marquesina OTXO ubicado sobre la puerta de entrada (alargado +25% horizontal)
static func build_fascia_sign(data: Dictionary) -> Node3D:
	var sign_node := Node3D.new()
	sign_node.name = "OTXO_FasciaSign"
	sign_node.position = data.get("position", Vector3.ZERO)
	sign_node.rotation.y = data.get("rotation_y", 0.0)

	var raw_sz: Vector2 = data.get("size", Vector2(2.95, 1.80))
	var sz := Vector2(raw_sz.x * 1.25 if raw_sz.x < 2.8 else raw_sz.x, raw_sz.y)
	var corner_r := 0.32

	# Marco perimetral rojo con esquinas redondeadas low-poly
	var back_mesh := create_lowpoly_squircle_box(sz.x + 0.08, sz.y + 0.08, 0.12, corner_r + 0.02)
	var mat_back := StandardMaterial3D.new()
	mat_back.albedo_color = Color(0.85, 0.08, 0.08)
	var back_inst := MeshInstance3D.new()
	back_inst.name = "FasciaSignFrame"
	back_inst.mesh = back_mesh
	back_inst.material_override = mat_back
	sign_node.add_child(back_inst)

	# Panel frontal squircle con textura del logo orientada al cliente
	var front_mesh := create_lowpoly_squircle_quad(sz.x, sz.y, corner_r)
	var sign_inst := MeshInstance3D.new()
	sign_inst.name = "FasciaLogoQuad"
	sign_inst.mesh = front_mesh
	sign_inst.material_override = get_logo_material()
	sign_inst.position.z = -0.07
	sign_inst.rotation.y = PI # Apunta hacia el cliente (-Z local)
	sign_node.add_child(sign_inst)

	return sign_node


## Construye las 2 puertas corredizas de cristal templado (las agarraderas están en el centro e instanciadas por GPU)
static func build_sliding_doors(pos: Vector3, width: float = 2.0, height: float = 2.4, rot_y: float = 0.0) -> Node3D:
	var door_group := Node3D.new()
	door_group.name = "OTXO_AutomaticSlidingDoors"
	door_group.position = pos
	door_group.rotation.y = rot_y

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.20, 0.20, 0.22) # Aluminio negro mate
	frame_mat.metallic = 0.60
	frame_mat.roughness = 0.40

	var glass_mat := StandardMaterial3D.new()
	glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_mat.albedo_color = Color(0.82, 0.92, 1.0, 0.35)
	glass_mat.metallic = 0.10
	glass_mat.roughness = 0.10

	var panel_w := width * 0.52
	var panel_h := height - 0.08

	# Hoja izquierda de cristal
	var left_door := Node3D.new()
	left_door.position = Vector3(-width * 0.25, panel_h * 0.5, -0.02)
	var lg_inst := MeshInstance3D.new()
	var lg_mesh := BoxMesh.new()
	lg_mesh.size = Vector3(panel_w, panel_h, 0.025)
	lg_inst.mesh = lg_mesh
	lg_inst.material_override = glass_mat
	left_door.add_child(lg_inst)

	# Perfiles de aluminio superior e inferior
	var lf_top := MeshInstance3D.new()
	var lf_top_mesh := BoxMesh.new()
	lf_top_mesh.size = Vector3(panel_w, 0.05, 0.04)
	lf_top.mesh = lf_top_mesh
	lf_top.material_override = frame_mat
	lf_top.position.y = panel_h * 0.5 - 0.025
	left_door.add_child(lf_top)

	var lf_bot := MeshInstance3D.new()
	var lf_bot_mesh := BoxMesh.new()
	lf_bot_mesh.size = Vector3(panel_w, 0.10, 0.04)
	lf_bot.mesh = lf_bot_mesh
	lf_bot.material_override = frame_mat
	lf_bot.position.y = -panel_h * 0.5 + 0.05
	left_door.add_child(lf_bot)

	door_group.add_child(left_door)

	# Hoja derecha de cristal
	var right_door := Node3D.new()
	right_door.position = Vector3(width * 0.25, panel_h * 0.5, 0.02)
	var rg_inst := MeshInstance3D.new()
	rg_inst.mesh = lg_mesh
	rg_inst.material_override = glass_mat
	right_door.add_child(rg_inst)

	var rf_top := MeshInstance3D.new()
	rf_top.mesh = lf_top_mesh
	rf_top.material_override = frame_mat
	rf_top.position.y = panel_h * 0.5 - 0.025
	right_door.add_child(rf_top)

	var rf_bot := MeshInstance3D.new()
	rf_bot.mesh = lf_bot_mesh
	rf_bot.material_override = frame_mat
	rf_bot.position.y = -panel_h * 0.5 + 0.05
	right_door.add_child(rf_bot)

	door_group.add_child(right_door)

	# Riel superior automático
	var track := MeshInstance3D.new()
	var track_mesh := BoxMesh.new()
	track_mesh.size = Vector3(width + 0.10, 0.12, 0.12)
	track.mesh = track_mesh
	track.material_override = frame_mat
	track.position = Vector3(0.0, height - 0.06, 0.0)
	door_group.add_child(track)

	# Umbral / riel inferior de piso
	var threshold := MeshInstance3D.new()
	var th_mesh := BoxMesh.new()
	th_mesh.size = Vector3(width + 0.06, 0.02, 0.08)
	threshold.mesh = th_mesh
	threshold.material_override = frame_mat
	threshold.position = Vector3(0.0, 0.01, 0.0)
	door_group.add_child(threshold)

	return door_group


## Construye las líneas amarillas de pintura y los topes de estacionamiento en el asfalto
static func build_parking_bays(bays: Array) -> Node3D:
	var group := Node3D.new()
	group.name = "ParkingBaysGroup"

	# Material para líneas amarillas en el piso
	var mat_yellow_stripe := StandardMaterial3D.new()
	mat_yellow_stripe.albedo_color = Color(0.95, 0.80, 0.10)
	mat_yellow_stripe.roughness = 0.80

	# Material para tope de concreto amarillo
	var mat_curb_concrete := StandardMaterial3D.new()
	mat_curb_concrete.albedo_color = Color(0.90, 0.75, 0.15)
	mat_curb_concrete.roughness = 0.90

	for i in bays.size():
		var bay_dict: Dictionary = bays[i]
		var bay_pos: Vector3 = bay_dict.get("position", Vector3.ZERO)
		var bay_sz: Vector2 = bay_dict.get("size", Vector2(2.5, 5.0))
		var bay_rot: float = float(bay_dict.get("rotation_y", 0.0))

		var bay_node := Node3D.new()
		bay_node.name = "Bay_%d" % i
		bay_node.position = bay_pos
		bay_node.rotation.y = bay_rot
		group.add_child(bay_node)

		# Líneas delimitadoras izquierda y derecha (10cm ancho x 4.8m largo)
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.12, 0.015, bay_sz.y - 0.20)

		var left_stripe := MeshInstance3D.new()
		left_stripe.mesh = stripe_mesh
		left_stripe.material_override = mat_yellow_stripe
		left_stripe.position = Vector3(-bay_sz.x * 0.5, 0.008, 0.0)
		bay_node.add_child(left_stripe)

		var right_stripe := MeshInstance3D.new()
		right_stripe.mesh = stripe_mesh
		right_stripe.material_override = mat_yellow_stripe
		right_stripe.position = Vector3(bay_sz.x * 0.5, 0.008, 0.0)
		bay_node.add_child(right_stripe)

		# Tope de concreto amarillo al fondo del cajón (+Z local hacia la banqueta)
		var curb_node := StaticBody3D.new()
		curb_node.name = "WheelStopCurb"
		curb_node.position = Vector3(0.0, 0.08, bay_sz.y * 0.5 - 0.45)

		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(2.0, 0.16, 0.18)

		var curb_inst := MeshInstance3D.new()
		curb_inst.mesh = curb_mesh
		curb_inst.material_override = mat_curb_concrete
		curb_node.add_child(curb_inst)

		var curb_col := CollisionShape3D.new()
		var curb_shape := BoxShape3D.new()
		curb_shape.size = curb_mesh.size
		curb_col.shape = curb_shape
		curb_node.add_child(curb_col)

		bay_node.add_child(curb_node)

	return group


## Construye las colisiones de los bolardos protectores amarillos (mallas vía GPU instancing)
static func build_bollards(bollard_positions: Array) -> Node3D:
	var group := Node3D.new()
	group.name = "SafetyBollardsGroup"

	for i in bollard_positions.size():
		var b_pos: Vector3 = bollard_positions[i]
		var bol_body := StaticBody3D.new()
		bol_body.name = "Bollard_%d" % i
		bol_body.position = b_pos

		# Colisión física cilíndrica
		var col_shape := CollisionShape3D.new()
		var cyl_shape := CylinderShape3D.new()
		cyl_shape.radius = 0.12
		cyl_shape.height = 0.85
		col_shape.shape = cyl_shape
		col_shape.position.y = 0.425
		bol_body.add_child(col_shape)

		group.add_child(bol_body)

	return group


## Construye la clásica hielera exterior ("HIELO") metálica con candado
static func build_ice_freezer(pos: Vector3) -> Node3D:
	var freezer := StaticBody3D.new()
	freezer.name = "OTXO_IceFreezer"
	freezer.position = pos

	# Gabinete principal blanco
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.80, 1.25, 0.85)

	var mat_white := StandardMaterial3D.new()
	mat_white.albedo_color = Color(0.92, 0.92, 0.94)
	mat_white.roughness = 0.35
	mat_white.metallic = 0.10

	var body_inst := MeshInstance3D.new()
	body_inst.mesh = body_mesh
	body_inst.material_override = mat_white
	body_inst.position.y = 1.25 * 0.5
	freezer.add_child(body_inst)

	# Puerta inclinada superior
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.70, 0.08, 0.45)
	var mat_lid := StandardMaterial3D.new()
	mat_lid.albedo_color = Color(0.20, 0.45, 0.75) # Azul glaciar
	mat_lid.roughness = 0.30

	var lid_inst := MeshInstance3D.new()
	lid_inst.mesh = lid_mesh
	lid_inst.material_override = mat_lid
	lid_inst.position = Vector3(0.0, 1.15, 0.15)
	lid_inst.rotation.x = -0.35
	freezer.add_child(lid_inst)

	# Franja decorativa frontal "HIELO"
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(1.40, 0.28, 0.02)
	var mat_banner := StandardMaterial3D.new()
	mat_banner.albedo_color = Color(0.12, 0.40, 0.85) # Azul glaciar ICE
	mat_banner.roughness = 0.40
	var banner_inst := MeshInstance3D.new()
	banner_inst.name = "IceBanner"
	banner_inst.mesh = banner_mesh
	banner_inst.material_override = mat_banner
	banner_inst.position = Vector3(0.0, 0.65, -0.85 * 0.5 - 0.01)
	freezer.add_child(banner_inst)

	# Colisión
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = body_mesh.size
	col.shape = shape
	col.position.y = 1.25 * 0.5
	freezer.add_child(col)

	return freezer


## Construye la colisión física del bote de basura cilíndrico de banqueta (malla vía GPU instancing)
static func build_trash_bin(pos: Vector3) -> Node3D:
	var bin_node := StaticBody3D.new()
	bin_node.name = "OTXO_TrashBin"
	bin_node.position = pos

	# Colisión física cilíndrica coincidente con el tambo/bote exterior
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.28
	shape.height = 0.90
	col.shape = shape
	col.position.y = 0.45
	bin_node.add_child(col)

	return bin_node


# =========================================================================
# MOBILIARIO Y AMBIENTACIÓN INTERIOR OTXO (Piso de Venta)
# =========================================================================

## Construye la tienda interior: Cajas registradoras, góndolas, cuarto frío, café
static func build_interior_store(sales_room: Dictionary, house_w: float, house_d: float) -> Node3D:
	var store_interior := Node3D.new()
	store_interior.name = "StoreInterior"

	var x_min: float = float(sales_room.get("x_min", 0))
	var x_max: float = float(sales_room.get("x_max", house_w))
	var z_min: float = float(sales_room.get("z_min", 0))
	var z_max: float = float(sales_room.get("z_max", house_d))

	var x0 := x_min - house_w * 0.5
	var x1 := x_max - house_w * 0.5
	var z0 := z_min - house_d * 0.5
	var z1 := z_max - house_d * 0.5

	# A. Mostrador de Cajas Registradoras (Caja 1 y Caja 2 con estante de cigarros)
	var checkout := _build_checkout_counter(x0, x1, z0, z1)
	store_interior.add_child(checkout)

	# B. Vitrinas Refrigeradas de Cuarto Frío al fondo (Bebidas, Cerveza, Refrescos)
	var coolers := _build_refrigerated_display_wall(x0, x1, z1)
	store_interior.add_child(coolers)

	# C. Góndolas Centrales de Botanas y Abarrotes (Sabritas, Galletas, Latas)
	var aisles := _build_gondola_shelving_aisles(x0, x1, z0, z1)
	store_interior.add_child(aisles)

	# D. Estación de Café y Vikingos (Hot Drinks Bar)
	var coffee_bar := _build_coffee_and_snack_bar(x0, x1, z0, z1)
	store_interior.add_child(coffee_bar)

	# E. Lámparas LED de Techo (Iluminación Comercial Brillante)
	var lights := _build_ceiling_lights(x0, x1, z0, z1)
	store_interior.add_child(lights)

	return store_interior


static func _build_checkout_counter(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var checkout_node := Node3D.new()
	checkout_node.name = "OTXO_CheckoutCounter"

	var counter_x := x0 + 2.4
	var counter_z := z0 + 1.8
	var c_len := 2.4
	var c_w := 0.85
	var c_h := 0.95

	# 1. Cuerpo del mostrador principal (StaticBody3D con colisión)
	var counter_body := StaticBody3D.new()
	counter_body.name = "CounterDesk"
	counter_body.position = Vector3(counter_x, 0.0, counter_z)

	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(c_len, c_h, c_w)

	var mat_desk := StandardMaterial3D.new()
	mat_desk.albedo_color = Color(0.25, 0.25, 0.27) # Antracita
	mat_desk.roughness = 0.60

	var desk_inst := MeshInstance3D.new()
	desk_inst.mesh = desk_mesh
	desk_inst.material_override = mat_desk
	desk_inst.position.y = c_h * 0.5
	counter_body.add_child(desk_inst)

	# Franja decorativa frontal roja OTXO
	var red_stripe := BoxMesh.new()
	red_stripe.size = Vector3(c_len + 0.02, 0.12, 0.02)
	var mat_stripe := StandardMaterial3D.new()
	mat_stripe.albedo_color = Color(0.85, 0.08, 0.08) # Rojo OTXO
	var stripe_inst := MeshInstance3D.new()
	stripe_inst.mesh = red_stripe
	stripe_inst.material_override = mat_stripe
	stripe_inst.position = Vector3(0.0, c_h * 0.6, c_w * 0.5 + 0.01)
	counter_body.add_child(stripe_inst)

	# Encimera superior (Cubierta tipo granito claro)
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(c_len + 0.06, 0.06, c_w + 0.06)
	var mat_top := StandardMaterial3D.new()
	mat_top.albedo_color = Color(0.88, 0.88, 0.90)
	mat_top.roughness = 0.35
	var top_inst := MeshInstance3D.new()
	top_inst.mesh = top_mesh
	top_inst.material_override = mat_top
	top_inst.position.y = c_h + 0.03
	counter_body.add_child(top_inst)

	# Colisión física
	var col_shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(c_len, c_h, c_w)
	col_shape.shape = box_shape
	col_shape.position.y = c_h * 0.5
	counter_body.add_child(col_shape)
	checkout_node.add_child(counter_body)

	# 2. Caja Registradora 1 (Activa, pantalla verde)
	var reg1 := _build_pos_register(true)
	reg1.position = Vector3(counter_x - 0.50, c_h + 0.06, counter_z)
	checkout_node.add_child(reg1)

	# 3. Caja Registradora 2 (Cerrada / Memé clásico OXXO: "Cerrada")
	var reg2 := _build_pos_register(false)
	reg2.position = Vector3(counter_x + 0.50, c_h + 0.06, counter_z)
	checkout_node.add_child(reg2)

	# 4. Mueble Exhibidor de Cigarros detrás del cajero (en la pared frontal)
	var cig_rack := _build_cigarette_rack()
	cig_rack.position = Vector3(counter_x, 0.0, z0 + 0.35)
	checkout_node.add_child(cig_rack)

	return checkout_node


static func _build_pos_register(is_active: bool) -> Node3D:
	var reg := Node3D.new()
	reg.name = "POS_Register"

	# Cajón de dinero y base
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.38, 0.08, 0.36)
	var mat_base := StandardMaterial3D.new()
	mat_base.albedo_color = Color(0.18, 0.18, 0.20)
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.material_override = mat_base
	base_inst.position.y = 0.04
	reg.add_child(base_inst)

	# Poste del monitor
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 0.18
	var pole_inst := MeshInstance3D.new()
	pole_inst.mesh = pole_mesh
	pole_inst.position = Vector3(0.0, 0.15, -0.05)
	reg.add_child(pole_inst)

	# Pantalla táctil inclinada hacia el cajero
	var scr_mesh := BoxMesh.new()
	scr_mesh.size = Vector3(0.34, 0.25, 0.04)
	var mat_scr := StandardMaterial3D.new()
	mat_scr.albedo_color = Color(0.15, 0.55, 0.25) if is_active else Color(0.55, 0.15, 0.15)
	mat_scr.emission_enabled = true
	mat_scr.emission_energy_multiplier = 0.60
	mat_scr.emission = mat_scr.albedo_color

	var scr_inst := MeshInstance3D.new()
	scr_inst.mesh = scr_mesh
	scr_inst.material_override = mat_scr
	scr_inst.position = Vector3(0.0, 0.28, -0.05)
	scr_inst.rotation.x = deg_to_rad(-15.0)
	reg.add_child(scr_inst)

	# Tarjeta amarilla "CERRADA" en Caja 2
	if not is_active:
		var card_mesh := BoxMesh.new()
		card_mesh.size = Vector3(0.18, 0.10, 0.02)
		var mat_card := StandardMaterial3D.new()
		mat_card.albedo_color = Color(0.95, 0.80, 0.10)
		var card_inst := MeshInstance3D.new()
		card_inst.mesh = card_mesh
		card_inst.material_override = mat_card
		card_inst.position = Vector3(0.0, 0.38, -0.03)
		reg.add_child(card_inst)

	return reg


static func _build_cigarette_rack() -> Node3D:
	var rack := Node3D.new()
	rack.name = "CigaretteRack"

	var rw := 2.20
	var rh := 1.70
	var rd := 0.25

	# Armazón oscuro
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(rw, rh, rd)
	var mat_f := StandardMaterial3D.new()
	mat_f.albedo_color = Color(0.15, 0.15, 0.18)
	var frame_inst := MeshInstance3D.new()
	frame_inst.mesh = frame_mesh
	frame_inst.material_override = mat_f
	frame_inst.position.y = rh * 0.5 + 0.30
	rack.add_child(frame_inst)

	# Repisas con cajetillas de colores variados
	var shelf_colors := [
		Color(0.85, 0.15, 0.15), # Rojo Marlboro
		Color(0.15, 0.35, 0.85), # Azul Pall Mall
		Color(0.85, 0.75, 0.15), # Dorado Benson
		Color(0.15, 0.65, 0.35), # Verde mentolado
	]

	for s_idx in range(4):
		var sy := 0.50 + float(s_idx) * 0.35
		var shelf_mesh := BoxMesh.new()
		shelf_mesh.size = Vector3(rw - 0.10, 0.20, 0.08)
		var mat_s := StandardMaterial3D.new()
		mat_s.albedo_color = shelf_colors[s_idx % shelf_colors.size()]
		var s_inst := MeshInstance3D.new()
		s_inst.mesh = shelf_mesh
		s_inst.material_override = mat_s
		s_inst.position = Vector3(0.0, sy, rd * 0.5 + 0.02)
		rack.add_child(s_inst)

	return rack


static func _build_refrigerated_display_wall(x0: float, x1: float, z1: float) -> Node3D:
	var wall_node := Node3D.new()
	wall_node.name = "RefrigeratedDisplayWall"

	var start_x := x0 + 1.2
	var end_x := x1 - 1.2
	var span_w := end_x - start_x
	if span_w < 1.0:
		return wall_node

	var cooler_depth := 0.88
	# El refrigerador tiene su frente hacia +Z en local. Lo rotamos 180° (PI) para que mire hacia -Z (el interior de la tienda).
	var z_center := z1 - cooler_depth * 0.5 - 0.04

	# Planificar distribución de vitrinas de 1.8m (doble puerta) y 1.0m (individual)
	var placed_coolers: Array[Dictionary] = [] # {"type": int, "w": float}
	var rem_w := span_w
	while rem_w >= 1.80:
		placed_coolers.append({"type": CommercialRefrigeratorModularScript.RefrigeratorType.DOUBLE_DOOR, "w": 1.80})
		rem_w -= 1.85
	if rem_w >= 1.00:
		placed_coolers.append({"type": CommercialRefrigeratorModularScript.RefrigeratorType.SINGLE_DOOR, "w": 1.00})
		rem_w -= 1.05

	if placed_coolers.is_empty() and span_w >= 0.95:
		placed_coolers.append({"type": CommercialRefrigeratorModularScript.RefrigeratorType.SINGLE_DOOR, "w": 1.00})

	var total_coolers_w := 0.0
	for c in placed_coolers:
		total_coolers_w += c["w"]
	var total_spacing := span_w - total_coolers_w
	var gap := 0.04
	if placed_coolers.size() > 1:
		gap = clampf(total_spacing / float(placed_coolers.size() + 1), 0.02, 0.15)

	var cur_x := (start_x + end_x - total_coolers_w - gap * float(placed_coolers.size() - 1)) * 0.5
	for i in range(placed_coolers.size()):
		var info = placed_coolers[i]
		var c_width: float = info["w"]
		var c_type: int = info["type"]
		var cooler := CommercialRefrigeratorModularScript.new()
		cooler.name = "OTXO_CommercialCooler_%d" % i
		cooler.refrigerator_type = c_type
		cooler.finish_color = CommercialRefrigeratorModularScript.FinishColor.WHITE_HOSPITALITY
		cooler.width = c_width
		cooler.depth = cooler_depth
		cooler.height = 2.05
		cooler.auto_stock = true
		cooler.stock_seed = 2000 + i * 421
		cooler.enable_collision = true
		# Rotar 180° para que las puertas miren hacia el interior de la tienda (-Z)
		cooler.rotation.y = PI
		cooler.position = Vector3(cur_x + c_width * 0.5, 0.0, z_center)
		wall_node.add_child(cooler)
		cur_x += c_width + gap

	return wall_node


static func _build_gondola_shelving_aisles(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var aisles_node := Node3D.new()
	aisles_node.name = "GondolaShelvingAisles"

	# Despeje frontal (cajas y entrada) y posterior (cuarto frío / vitrinas refrigeradas)
	var z_start := z0 + 3.1
	var z_end := z1 - 1.5
	var z_available := z_end - z_start
	if z_available < 1.4:
		return aisles_node

	# REGLA: Las estanterías van de IZQUIERDA a DERECHA (a lo largo del eje X)
	# Calculamos el ancho disponible en X dejando pasillos de circulación en ambos lados
	var margin_left := 1.3  # Espacio para transitar hacia cajas y mostrador
	var margin_right := 1.3 # Espacio para transitar hacia la barra de café
	var min_x := x0 + margin_left
	var max_x := x1 - margin_right
	var span_x := max_x - min_x
	if span_x < 2.0:
		return aisles_node

	# Cantidad de módulos de 1.0m de largo que caben de izquierda a derecha
	var modules_count := clampi(int(floor(span_x)), 2, 7)
	var center_x := (min_x + max_x) * 0.5

	# Determinamos cuántas filas paralelas caben en profundidad Z (con pasillos de 1.2m - 1.5m)
	# Cada góndola doble cara mide ~0.88m de fondo
	var shelf_depth := 0.88
	var row_z_positions: Array[float] = []

	if z_available < 3.2:
		# 1 fila central
		row_z_positions.append((z_start + z_end) * 0.5)
	elif z_available < 5.4:
		# 2 filas paralelas con pasillo central
		var step := (z_available - shelf_depth) * 0.5
		row_z_positions.append(z_start + shelf_depth * 0.5 + step * 0.3)
		row_z_positions.append(z_end - shelf_depth * 0.5 - step * 0.3)
	else:
		# 3 filas paralelas para tiendas profundas
		var step_3 := (z_available - shelf_depth * 3.0) / 4.0
		row_z_positions.append(z_start + step_3 + shelf_depth * 0.5)
		row_z_positions.append((z_start + z_end) * 0.5)
		row_z_positions.append(z_end - step_3 - shelf_depth * 0.5)

	# Catálogo de productos para el planograma en las repisas
	var item_catalog: Array[Dictionary] = [
		{"id": "cereal", "name": "Caja de Cereal", "size": Vector3(0.18, 0.26, 0.08), "type": "box", "can_stack": false},
		{"id": "soup", "name": "Lata de Conserva", "size": Vector3(0.08, 0.11, 0.08), "type": "can", "can_stack": true},
		{"id": "beer", "name": "Lata de Refresco/Cerveza", "size": Vector3(0.07, 0.13, 0.07), "type": "can", "can_stack": true},
		{"id": "milk", "name": "Cartón de Leche/Jugo", "size": Vector3(0.09, 0.20, 0.09), "type": "carton", "can_stack": false},
		{"id": "chips_yellow", "name": "Sabritas Clásicas", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.95, 0.82, 0.10)},
		{"id": "chips_red", "name": "Sabritas Flamin Hot", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.85, 0.15, 0.15)},
		{"id": "chips_orange", "name": "Doritos Nacho", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.90, 0.50, 0.15)},
		{"id": "chips_blue", "name": "Ruffles Queso", "size": Vector3(0.16, 0.22, 0.09), "type": "chips", "color": Color(0.15, 0.45, 0.85)}
	]

	# Instanciar cada estantería modular nueva (de izquierda a derecha)
	for r_idx in range(row_z_positions.size()):
		var rz := row_z_positions[r_idx]

		var shelf := CommercialShelfModularScript.new()
		shelf.name = "OTXO_GondolaShelfRow_%d" % r_idx
		shelf.modules_count = modules_count
		shelf.shelf_style = CommercialShelfModularScript.ShelfStyle.DOUBLE_SIDED_ISLAND
		shelf.shelf_preset = CommercialShelfModularScript.ShelfPreset.CONVENIENCE_OTXO
		shelf.has_price_strips = true
		shelf.enable_collision = true
		shelf.auto_stock = true
		shelf.stock_seed = 1000 + r_idx * 333
		shelf.position = Vector3(center_x, 0.0, rz)
		aisles_node.add_child(shelf)

	return aisles_node


static func _build_coffee_and_snack_bar(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var bar_node := Node3D.new()
	bar_node.name = "CoffeeAndSnackBar"

	var bar_x := x1 - 0.45
	var bar_z := (z0 + z1) * 0.5
	var bar_len := 2.4
	var bar_w := 0.65
	var bar_h := 0.92

	# Mueble base
	var bar_body := StaticBody3D.new()
	bar_body.position = Vector3(bar_x, 0.0, bar_z)

	var desk_mesh := BoxMesh.new()
	desk_mesh.size = Vector3(bar_w, bar_h, bar_len)
	var mat_wood := StandardMaterial3D.new()
	mat_wood.albedo_color = Color(0.32, 0.22, 0.16) # Madera oscura tipo cafetería
	var desk_inst := MeshInstance3D.new()
	desk_inst.mesh = desk_mesh
	desk_inst.material_override = mat_wood
	desk_inst.position.y = bar_h * 0.5
	bar_body.add_child(desk_inst)

	# Encimera de acero inoxidable
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(bar_w + 0.06, 0.05, bar_len + 0.06)
	var mat_steel := StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.78, 0.80, 0.82)
	mat_steel.metallic = 0.85
	mat_steel.roughness = 0.25
	var top_inst := MeshInstance3D.new()
	top_inst.mesh = top_mesh
	top_inst.material_override = mat_steel
	top_inst.position.y = bar_h + 0.025
	bar_body.add_child(top_inst)

	# Colisión
	var col_shape := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(bar_w, bar_h, bar_len)
	col_shape.shape = bshape
	col_shape.position.y = bar_h * 0.5
	bar_body.add_child(col_shape)
	bar_node.add_child(bar_body)

	# Cafeteras comerciales tipo Andatti (2 termos metálicos)
	for c in range(2):
		var cz := bar_z - 0.55 + float(c) * 0.50
		var urn_mesh := CylinderMesh.new()
		urn_mesh.top_radius = 0.12
		urn_mesh.bottom_radius = 0.12
		urn_mesh.height = 0.42
		var urn_inst := MeshInstance3D.new()
		urn_inst.mesh = urn_mesh
		urn_inst.material_override = mat_steel
		urn_inst.position = Vector3(bar_x, bar_h + 0.05 + 0.21, cz)
		bar_node.add_child(urn_inst)

	# Microondas
	var micro_mesh := BoxMesh.new()
	micro_mesh.size = Vector3(0.40, 0.28, 0.52)
	var mat_micro := StandardMaterial3D.new()
	mat_micro.albedo_color = Color(0.20, 0.20, 0.22)
	var micro_inst := MeshInstance3D.new()
	micro_inst.mesh = micro_mesh
	micro_inst.material_override = mat_micro
	micro_inst.position = Vector3(bar_x, bar_h + 0.05 + 0.14, bar_z + 0.65)
	bar_node.add_child(micro_inst)

	return bar_node


static func _build_ceiling_lights(x0: float, x1: float, z0: float, z1: float) -> Node3D:
	var lights_node := Node3D.new()
	lights_node.name = "CeilingLights"

	var mat_light := StandardMaterial3D.new()
	mat_light.albedo_color = Color(1.0, 0.98, 0.94)
	mat_light.emission_enabled = true
	mat_light.emission = Color(1.0, 0.98, 0.94)
	mat_light.emission_energy_multiplier = 1.60

	var x_pts := [x0 + (x1 - x0) * 0.30, x0 + (x1 - x0) * 0.70]
	var z_pts := [z0 + (z1 - z0) * 0.30, z0 + (z1 - z0) * 0.70]

	for lx in x_pts:
		for lz in z_pts:
			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(1.20, 0.03, 0.60)
			var panel_inst := MeshInstance3D.new()
			panel_inst.mesh = panel_mesh
			panel_inst.material_override = mat_light
			panel_inst.position = Vector3(lx, 2.76, lz)
			lights_node.add_child(panel_inst)

	# Luz ambiental sutil interior
	var omni := OmniLight3D.new()
	omni.name = "StoreInteriorLight"
	omni.position = Vector3((x0 + x1) * 0.5, 2.5, (z0 + z1) * 0.5)
	omni.light_color = Color(1.0, 0.97, 0.92)
	omni.light_energy = 0.90
	omni.omni_range = 10.0
	omni.omni_attenuation = 1.0
	lights_node.add_child(omni)

	return lights_node


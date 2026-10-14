class_name FacilityCompoundController
extends Node3D

## Controlador de Alto Nivel para Instalaciones, Complejos y Bases Militares en Godot.
## Consume el motor nativo de alto rendimiento en Rust (`FacilityEngine`) vía GDExtension.
##
## Características:
## 1. Mallas GPU Instanced (+0 Draw Calls por tipo de superficie).
## 2. Texturas tácticas triplanares desde `res://assets/textures/military/`.
## 3. Integración con el Motor de Objetos (`ObjectBuilder`) para barreras de pluma y sacos de arena.
## 4. Calcomanías militares y de peligro registradas automáticamente en `WallDecalSystem`.
## 5. Colisiones físicas completas (`StaticBody3D`).
## 6. Socket de conexión vertical hacia el búnker / dungeon subterráneo.

const WallDecalSystemScript = preload("res://world/city/wall_decal_system.gd")
const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ObjectBuilderScript = preload("res://world/object_engine/object_builder.gd")
const BarrierGateRecipeScript = preload("res://world/object_engine/recipes/barrier_gate_recipe.gd")
const SandbagsRecipesScript = preload("res://world/object_engine/recipes/sandbags_recipes.gd")

const GroundShader = preload("res://world/facility/facility_ground.gdshader")
static var _ground_texture_array: Texture2DArray = null

@export_group("Dimensiones y Configuración")
@export var width_m: float = 80.0
@export var depth_m: float = 96.0
@export_enum("Base Militar:0", "Planta Nuclear:1", "Laboratorio Científico:2", "Prisión:3") var facility_type: int = 0
@export var rng_seed: int = 54321
@export var auto_generate: bool = true

@export_group("Materiales Tácticos")
@export var ground_texture: Texture2D = preload("res://assets/textures/military/military_tile_04_r0_c3.png")
@export var wall_texture: Texture2D = preload("res://assets/textures/military/walls/military_wall_04_r0_c3.png")
@export var concrete_texture: Texture2D = preload("res://assets/textures/military/walls/military_wall_02_r0_c1.png")

var _facility_engine: Variant = null
var _content_root: Node3D = null

# Metadatos públicos de salida para el juego y el dungeon subterráneo
var bunker_entrance_position: Vector3 = Vector3.ZERO
var checkpoint_gate_position: Vector3 = Vector3.ZERO
var generated_structures: Array = []


## Compila dinámicamente el Texture2DArray con todas las 36 texturas de suelo modular militar
static func get_ground_texture_array() -> Texture2DArray:
	if _ground_texture_array != null:
		return _ground_texture_array

	var dir_path := "res://assets/textures/military/"
	var dir := DirAccess.open(dir_path)
	var tile_files: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.begins_with("military_tile_") and file_name.ends_with(".png"):
				tile_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	tile_files.sort()

	var images: Array[Image] = []
	for fname in tile_files:
		var fpath := dir_path + fname
		var img: Image = null
		var gpath := ProjectSettings.globalize_path(fpath)
		if FileAccess.file_exists(gpath):
			img = Image.load_from_file(gpath)
		elif ResourceLoader.exists(fpath):
			var tex = load(fpath)
			if tex is Texture2D:
				img = tex.get_image()

		if img and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != 256 or img.get_height() != 256:
				img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps()
			images.append(img)
		else:
			printerr("[FacilityCompoundController] No se pudo cargar imagen de suelo: ", fpath)

	if images.is_empty():
		printerr("[FacilityCompoundController] No se encontraron texturas de suelo militar.")
		return null

	var tex_arr := Texture2DArray.new()
	var err := tex_arr.create_from_images(images)
	if err != OK:
		printerr("[FacilityCompoundController] ERROR al crear Texture2DArray de suelo militar: ", err)
		return null

	_ground_texture_array = tex_arr
	print("[FacilityCompoundController] ✓ Texture2DArray militar compilado con %d capas." % images.size())
	return _ground_texture_array


func _ready() -> void:
	if auto_generate:
		generate_compound()


func clear_compound() -> void:
	if _content_root != null and is_instance_valid(_content_root):
		_content_root.queue_free()
		_content_root = null
	generated_structures.clear()


## Genera o regenera el complejo completo con la semilla especificada
func generate_compound(new_seed: int = -1) -> void:
	if new_seed >= 0:
		rng_seed = new_seed

	clear_compound()

	_content_root = Node3D.new()
	_content_root.name = "FacilityCompoundRoot"
	add_child(_content_root)

	# 1. Instanciar el motor nativo de Rust
	if ClassDB.class_exists("FacilityEngine"):
		_facility_engine = ClassDB.instantiate("FacilityEngine")
	else:
		push_error("[FacilityCompoundController] La clase GDExtension 'FacilityEngine' no está registrada en Godot.")
		return

	# 2. Generar plano maestro y mallas en Rust (se ejecuta en microsegundos)
	var data: Dictionary = _facility_engine.generate_facility(width_m, depth_m, facility_type, rng_seed)
	if data.is_empty():
		push_error("[FacilityCompoundController] FacilityEngine devolvió datos vacíos.")
		return

	bunker_entrance_position = data.get("bunker_entrance", Vector3.ZERO)
	checkpoint_gate_position = data.get("checkpoint_gate", Vector3.ZERO)
	generated_structures = data.get("placed_structures", [])

	# 3. Ensamblar MultiMeshes con materiales triplanares PSX y Texture2DArray
	_setup_multimeshes(data)

	# 4. Ensamblar colisiones físicas (StaticBody3D)
	_setup_collision_body(data)

	# 5. Instanciar Props del Motor de Objetos (Pluma, Sacos de arena, etc.)
	_setup_object_props(data)

	# 6. Proyectar calcomanías militares (WallDecalSystem)
	_setup_decals(data)

	# 7. Marcador visual de la entrada al búnker subterráneo
	_setup_bunker_hatch_marker()

	print("[FacilityCompoundController] Complejo militar generado con éxito: %d estructuras, Semilla: %d" % [
		generated_structures.size(), rng_seed
	])


func _setup_multimeshes(data: Dictionary) -> void:
	# 1. Suelo Modular Cuadrícula 1x1 (Texture2DArray: franjas de advertencia, asfalto, losas, rejillas)
	if data.has("ground_multimesh"):
		var g_inst := MultiMeshInstance3D.new()
		g_inst.name = "Ground_MultiMesh"
		g_inst.multimesh = data["ground_multimesh"]
		var ground_shader_mat := ShaderMaterial.new()
		ground_shader_mat.shader = GroundShader
		ground_shader_mat.set_shader_parameter("tile_array", get_ground_texture_array())
		g_inst.material_override = ground_shader_mat
		_content_root.add_child(g_inst)

	# 2. Material de Muro Perimetral (Verde oliva militar con triplanar)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	wall_mat.vertex_color_use_as_albedo = true
	wall_mat.roughness = 0.85
	wall_mat.albedo_texture = wall_texture
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_triplanar_sharpness = 8.0
	wall_mat.uv1_scale = Vector3(0.20, 0.20, 0.20)

	if data.has("perimeter_multimesh"):
		var p_inst := MultiMeshInstance3D.new()
		p_inst.name = "Perimeter_MultiMesh"
		p_inst.multimesh = data["perimeter_multimesh"]
		p_inst.material_override = wall_mat
		_content_root.add_child(p_inst)

	# 3. Material de Estructuras (Cuarteles, Hangares, Garitas, Búnker, Talleres)
	var struct_mat := StandardMaterial3D.new()
	struct_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	struct_mat.vertex_color_use_as_albedo = true
	struct_mat.roughness = 0.82
	struct_mat.albedo_texture = concrete_texture
	struct_mat.uv1_triplanar = true
	struct_mat.uv1_triplanar_sharpness = 8.0
	struct_mat.uv1_scale = Vector3(0.20, 0.20, 0.20)

	if data.has("structures_multimesh"):
		var s_inst := MultiMeshInstance3D.new()
		s_inst.name = "Structures_MultiMesh"
		s_inst.multimesh = data["structures_multimesh"]
		s_inst.material_override = struct_mat
		_content_root.add_child(s_inst)


func _setup_collision_body(data: Dictionary) -> void:
	var col_boxes: Array = data.get("collision_boxes", [])
	if col_boxes.is_empty():
		return

	var body := StaticBody3D.new()
	body.name = "FacilityCollision"

	for b_entry in col_boxes:
		if b_entry is Dictionary:
			var shape := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = b_entry["size"]
			shape.shape = box_shape
			shape.position = b_entry["position"]
			body.add_child(shape)

	_content_root.add_child(body)


func _setup_object_props(data: Dictionary) -> void:
	var props_list: Array = data.get("placed_props", [])
	if props_list.is_empty():
		return

	var engine: ObjectEngine = ObjectEngineScript.new()
	engine.name = "TacticalPropsEngine"
	_content_root.add_child(engine)
	var builder: ObjectBuilder = engine.get_builder()

	for p in props_list:
		if not (p is Dictionary):
			continue
		var recipe_name: String = p.get("recipe", "")
		var pos: Vector3 = p.get("position", Vector3.ZERO)
		var rot_y: float = p.get("rotation_y", 0.0)

		var t := Transform3D(Basis(Vector3.UP, rot_y), pos)

		match recipe_name:
			"barrier_gate":
				# Pluma de acceso vehicular con franjas amarillo/negro cubriendo el portón de 6m
				BarrierGateRecipeScript.build(builder, t, {
					"length": 5.6,
					"is_open": false,
					"stripes": "yellow_black",
					"color": "yellow"
				})
			"sandbags":
				# Parapeto táctico de sacos de arena militar
				for layer in range(3):
					for sack_idx in range(5):
						var offset_x: float = (sack_idx - 2.0) * 0.52
						var offset_y: float = layer * 0.13
						var sack_t := t * Transform3D(Basis.IDENTITY, Vector3(offset_x, offset_y, 0.0))
						SandbagsRecipesScript.SandbagRecipe.build(builder, sack_t, {
							"variation": (layer * 5 + sack_idx) % 20
						})

	engine.commit()


func _setup_decals(data: Dictionary) -> void:
	var decals_list: Array = data.get("decals", [])
	if decals_list.is_empty():
		return

	# Asegurar que la carpeta de calcomanías militares esté registrada en WallDecalSystem
	WallDecalSystemScript.register_folder("military_decal", "res://assets/textures/military/decals")

	var decal_details: Array = []
	for d in decals_list:
		if d is Dictionary:
			decal_details.append({
				"category": d.get("category", "military_decal"),
				"position": d.get("position", Vector3.ZERO),
				"normal": d.get("normal", Vector3.FORWARD),
				"size": d.get("size", Vector2(2.0, 2.0)),
				"style_id": d.get("style_id", 0),
				"tilt": 0.0,
				"flip_h": false,
				"flip_v": false,
				"is_small": false
			})

	var decal_mm = WallDecalSystemScript.create_house_decals_multimesh(decal_details)
	if decal_mm != null:
		decal_mm.name = "MilitaryDecalsMultiMesh"
		_content_root.add_child(decal_mm)


func _setup_bunker_hatch_marker() -> void:
	if bunker_entrance_position == Vector3.ZERO:
		return

	# Escotilla blindada con volante en el suelo para acceso al búnker
	var hatch_root := Node3D.new()
	hatch_root.name = "SubterraneanBunkerHatch"
	hatch_root.position = bunker_entrance_position
	_content_root.add_child(hatch_root)

	# 1. Base cuadrada de hormigón reforzado
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(4.2, 0.18, 4.2)
	var pad_inst := MeshInstance3D.new()
	pad_inst.mesh = pad_mesh
	pad_inst.position = Vector3(0.0, 0.09, 0.0)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.35, 0.36, 0.34)
	pad_mat.roughness = 0.90
	pad_inst.material_override = pad_mat
	hatch_root.add_child(pad_inst)

	# 2. Aro exterior de acero blindado
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.50
	ring_mesh.bottom_radius = 1.50
	ring_mesh.height = 0.28
	var ring_inst := MeshInstance3D.new()
	ring_inst.mesh = ring_mesh
	ring_inst.position = Vector3(0.0, 0.23, 0.0)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.22, 0.23, 0.22)
	ring_mat.metallic = 0.85
	ring_mat.roughness = 0.35
	ring_inst.material_override = ring_mat
	hatch_root.add_child(ring_inst)

	# 3. Compuerta central de búnker (amarillo industrial táctico)
	var door_mesh := CylinderMesh.new()
	door_mesh.top_radius = 1.32
	door_mesh.bottom_radius = 1.32
	door_mesh.height = 0.32
	var door_inst := MeshInstance3D.new()
	door_inst.mesh = door_mesh
	door_inst.position = Vector3(0.0, 0.26, 0.0)

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.85, 0.65, 0.12)
	door_mat.metallic = 0.6
	door_mat.roughness = 0.5
	door_inst.material_override = door_mat
	hatch_root.add_child(door_inst)

	# 4. Volante manual de apertura hidráulica (Torus de acero rojo de seguridad)
	var wheel_mesh := TorusMesh.new()
	wheel_mesh.inner_radius = 0.32
	wheel_mesh.outer_radius = 0.48
	var wheel_inst := MeshInstance3D.new()
	wheel_inst.mesh = wheel_mesh
	wheel_inst.position = Vector3(0.0, 0.44, 0.0)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.82, 0.16, 0.14)
	wheel_mat.metallic = 0.8
	wheel_mat.roughness = 0.4
	wheel_inst.material_override = wheel_mat
	hatch_root.add_child(wheel_inst)

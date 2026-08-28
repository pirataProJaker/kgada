extends Node3D
## Escena de inspeccion: recorre assets/URBAN y genera una instancia de cada
## modelo .fbx en una grilla, con un Label3D con su nombre justo arriba.
## Sirve para ver de un vistazo que forma tiene cada pieza (recta, curva,
## cruce en T, cruce en cruz, etc) y asi poder mapear nombre -> tipo de
## conexion para el futuro generador de calles/ciudades.

const URBAN_ROOT := "res://assets/URBAN/URBAN"
const URBAN_TEXTURES_DIR := "res://assets/URBAN/URBAN/textures"

## normalized(nombre textura sin extension) -> res path. Se llena una sola
## vez desde la carpeta compartida assets/URBAN/URBAN/textures.
var _shared_textures: Dictionary = {}

## Separacion extra (metros) entre el borde de un modelo y el siguiente -
## se suma al tamaño real de cada modelo, que se mide con su AABB (igual
## que hace DrainageDungeonGenerator con las piezas del drenaje), asi que
## modelos grandes (un puente) y chicos (un tubo) quedan bien separados
## sin amontonarse ni dejar huecos gigantes entre los chicos.
@export var margin: float = 2.5
## Ancho maximo (metros) de fila antes de saltar a la siguiente - controla
## que tan "cuadrada" queda la grilla general.
@export var max_row_width: float = 60.0
@export var label_extra_height: float = 0.4
## Si es true, solo se listan los nombres en consola (no se instancian mallas).
## Util para sacar rapido la lista completa de nombres sin cargar todo.
@export var names_only: bool = false
## Si es true, imprime por consola (en vez de construir la grilla) que
## textura tiene cada material de cada modelo - para diagnosticar
## texturas blancas/faltantes o estiradas.
@export var debug_materials: bool = false


func _ready() -> void:
	_index_shared_textures()
	var entries := _collect_models(URBAN_ROOT)
	entries.sort_custom(func(a, b): return a["relative"] < b["relative"])

	print("[UrbanCatalog] %d modelos encontrados en %s" % [entries.size(), URBAN_ROOT])

	if names_only:
		for entry in entries:
			print(entry["relative"])
		return

	if debug_materials:
		_debug_print_materials(entries)
		return

	_build_grid(entries)


## Escanea assets/URBAN/URBAN/textures y guarda cada textura bajo una
## clave normalizada (minusculas, sin extension, espacios -> guion bajo).
## Algunos materiales del FBX (ej. "concrete", "Plackard_wall") quedan sin
## albedo_texture porque esa textura no venia embebida en el fbx - viven
## sueltas en esta carpeta compartida y hay que asignarlas a mano.
func _index_shared_textures() -> void:
	var dir := DirAccess.open(URBAN_TEXTURES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			var key := _normalize_name(file_name.get_basename())
			_shared_textures[key] = URBAN_TEXTURES_DIR.path_join(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


static func _normalize_name(s: String) -> String:
	return s.to_lower().replace(" ", "_")


## Busca en _shared_textures una textura para `material_name`: primero
## coincidencia exacta, si no hay, la primera cuyo nombre normalizado
## contenga (o este contenido en) el nombre normalizado del material -
## cubre casos como material "concrete" -> textura "concrete_bare.jpg".
func _find_shared_texture(material_name: String) -> String:
	if material_name == "":
		return ""
	var key := _normalize_name(material_name)
	if _shared_textures.has(key):
		return _shared_textures[key]
	for tex_key in _shared_textures.keys():
		if tex_key.contains(key) or key.contains(tex_key):
			return _shared_textures[tex_key]
	return ""


## Recorre todos los MeshInstance3D de `instance` y a cualquier material
## sin albedo_texture (se veria blanco) le asigna la textura compartida
## que le corresponda por nombre, si se encuentra una.
func _fix_missing_textures(instance: Node) -> void:
	var mesh_instances: Array = []
	_collect_mesh_instances(instance, mesh_instances)
	for mi in mesh_instances:
		var mesh_instance: MeshInstance3D = mi
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface_idx in range(mesh.get_surface_count()):
			var mat: Material = mesh_instance.get_active_material(surface_idx)
			if mat == null or not (mat is BaseMaterial3D):
				continue
			var base_mat: BaseMaterial3D = mat
			if base_mat.albedo_texture != null:
				continue
			var tex_path := _find_shared_texture(mat.resource_name)
			if tex_path == "":
				continue
			var fixed_mat: BaseMaterial3D = base_mat.duplicate()
			fixed_mat.albedo_texture = load(tex_path)
			mesh_instance.set_surface_override_material(surface_idx, fixed_mat)


func _collect_models(root: String) -> Array:
	var results: Array = []
	_scan_dir(root, root, results)
	return results


func _scan_dir(root: String, current: String, results: Array) -> void:
	var dir := DirAccess.open(current)
	if dir == null:
		push_warning("[UrbanCatalog] No se pudo abrir: %s" % current)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name in [".", ".."]:
			file_name = dir.get_next()
			continue

		var full_path := current.path_join(file_name)
		if dir.current_is_dir():
			_scan_dir(root, full_path, results)
		elif file_name.get_extension().to_lower() == "fbx":
			var relative := full_path.substr(root.length() + 1)
			results.append({
				"path": full_path,
				"relative": relative,
				"name": file_name.get_basename(),
			})
		file_name = dir.get_next()
	dir.list_dir_end()


## Recorre cada modelo, y por cada MeshInstance3D/superficie imprime el
## nombre del material y si tiene (o no) una albedo_texture asignada -
## para saber cuales quedan blancos por falta de textura real.
func _debug_print_materials(entries: Array) -> void:
	for entry in entries:
		var packed: PackedScene = load(entry["path"])
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		_fix_missing_textures(instance)
		var mesh_instances: Array = []
		_collect_mesh_instances(instance, mesh_instances)
		for mi in mesh_instances:
			var mesh_instance: MeshInstance3D = mi
			var mesh: Mesh = mesh_instance.mesh
			if mesh == null:
				continue
			for surface_idx in range(mesh.get_surface_count()):
				var mat: Material = mesh_instance.get_active_material(surface_idx)
				var mat_name := "<sin material>"
				var tex_info := "<sin textura>"
				if mat != null:
					mat_name = mat.resource_name if mat.resource_name != "" else str(mat.get_class())
					if mat is BaseMaterial3D:
						var tex: Texture2D = (mat as BaseMaterial3D).albedo_texture
						if tex != null:
							tex_info = tex.resource_path
				print("%s | mesh=%s surf=%d | material=%s | %s" % [entry["relative"], mesh_instance.name, surface_idx, mat_name, tex_info])
		instance.free()


func _collect_mesh_instances(node: Node, out_list: Array) -> void:
	if node is MeshInstance3D:
		out_list.append(node)
	for child in node.get_children():
		_collect_mesh_instances(child, out_list)


## Empaqueta los modelos en filas (como packing de texto): mide el tamaño
## real de cada modelo con su AABB y avanza el cursor X esa cantidad + el
## margen antes del siguiente; cuando la fila se pasa de max_row_width,
## salta a la siguiente fila (usando la profundidad maxima de la fila
## anterior). Asi cada modelo respeta su propio tamaño en vez de compartir
## una celda fija que le queda chica a los modelos grandes y enorme a los
## chicos.
func _build_grid(entries: Array) -> void:
	var cursor_x := 0.0
	var cursor_z := 0.0
	var row_depth := 0.0

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]

		var packed: PackedScene = load(entry["path"])
		if packed == null:
			push_warning("[UrbanCatalog] No se pudo cargar: %s" % entry["path"])
			continue

		var instance: Node3D = packed.instantiate()
		_fix_missing_textures(instance)
		var model_aabb := _compute_local_aabb(instance)
		var footprint_x: float = maxf(model_aabb.size.x, 0.1)
		var footprint_z: float = maxf(model_aabb.size.z, 0.1)

		if cursor_x > 0.0 and cursor_x + footprint_x > max_row_width:
			cursor_x = 0.0
			cursor_z += row_depth + margin
			row_depth = 0.0

		var cell := Node3D.new()
		cell.name = "Model_%d" % i
		# Desplazamos la celda para que el borde MIN del AABB del modelo
		# (no su origen/pivote, que puede estar en cualquier lado) quede
		# justo en cursor_x/cursor_z - asi el packing usa el tamaño real.
		cell.position = Vector3(cursor_x - model_aabb.position.x, 0.0, cursor_z - model_aabb.position.z)
		add_child(cell)
		cell.add_child(instance)

		var label := Label3D.new()
		label.text = entry["name"]
		label.position = Vector3(
			model_aabb.position.x + model_aabb.size.x * 0.5,
			model_aabb.position.y + model_aabb.size.y + label_extra_height,
			model_aabb.position.z + model_aabb.size.z * 0.5
		)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 32
		label.outline_size = 8
		label.pixel_size = 0.01
		cell.add_child(label)

		cursor_x += footprint_x + margin
		row_depth = maxf(row_depth, footprint_z)


## Combina el AABB de todas las mallas (VisualInstance3D) debajo de `root`,
## medido en el espacio local de `root` - misma tecnica que usa
## DrainageDungeonGenerator._compute_local_aabb() para medir el tamaño
## real de cada pieza del drenaje.
func _compute_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var stack: Array = [[root, Transform3D.IDENTITY]]

	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var relative_transform: Transform3D = entry[1]

		if node is VisualInstance3D:
			var mesh_aabb: AABB = (node as VisualInstance3D).get_aabb()
			var relative_aabb: AABB = relative_transform * mesh_aabb
			if not initialized:
				result = relative_aabb
				initialized = true
			else:
				result = result.merge(relative_aabb)

		for child in node.get_children():
			if child is Node3D:
				stack.append([child, relative_transform * (child as Node3D).transform])
			else:
				stack.append([child, relative_transform])

	return result

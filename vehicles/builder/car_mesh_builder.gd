class_name CarMeshBuilder
extends RefCounted

## Gestor de Mallas del Sedán 80s Modular Fiel al Modelo Original
## Extrae y sirve las mallas directamente de res://assets/models/vehicles/sedan_80s/sedan_modular.glb
## garantizando fidelidad 1:1, textura sin distorsión y pivotes de bisagra exactos.

const GLB_PATH := "res://assets/models/vehicles/sedan_80s/sedan_modular.glb"
const Atlas = preload("res://vehicles/models/sedan_80s/sedan_atlas_data.gd")

# =========================================================================
# HITOS GEOMÉTRICOS DEL VEHÍCULO 1:1 (EN METROS)
# =========================================================================
# Eje Z (Frente = -Z, Trasera = +Z en convención Godot):
const Z_BUMPER_F: float = -2.4349
const Z_WHEEL_F: float  = -1.6151
const Z_DOOR_F: float   = -1.0206
const Z_HOOD_PIVOT: float = -1.2004
const Z_DOOR_R: float   = -0.0729
const Z_WHEEL_R: float  =  0.9906
const Z_TRUNK_PIVOT: float = 1.3704
const Z_BUMPER_R: float =  2.1870

# Alturas Y (Suelo = 0.0):
const Y_GROUND: float   = 0.0
const Y_AXLE: float     = 0.2957
const Y_DOOR_F: float   = 0.5670
const Y_DOOR_R: float   = 0.5670
const Y_HOOD_PIVOT: float = 0.8894
const Y_TRUNK_PIVOT: float = 0.9371

# Semi-anchos X:
const HW_BODY: float   = 0.7857
const HW_TRACK: float  = 0.6739

static var default_paint_color: Color = Color.WHITE

static var _cached_meshes: Dictionary = {}
static var _initialized: bool = false


static func _ensure_loaded() -> void:
	if _initialized and not _cached_meshes.is_empty():
		return
	_initialized = true

	if not ResourceLoader.exists(GLB_PATH):
		push_error("CarMeshBuilder: No se encontró " + GLB_PATH)
		return

	var scene: PackedScene = load(GLB_PATH)
	if scene == null:
		push_error("CarMeshBuilder: Error al instanciar " + GLB_PATH)
		return

	var root := scene.instantiate()
	_extract_meshes_recursive(root)
	root.queue_free()


static func _extract_meshes_recursive(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var m: Mesh = node.mesh
		# Asignar el material oficial de textura blanca y filtro nearest
		m.surface_set_material(0, Atlas.get_vehicle_material())
		_cached_meshes[node.name] = m

	for child in node.get_children():
		_extract_meshes_recursive(child)


# =========================================================================
# ACCESORES DE MALLAS PARA LAS PIEZAS MODULARES
# =========================================================================

static func create_chassis_mesh() -> Mesh:
	_ensure_loaded()
	return _cached_meshes.get("Chassis", null)


static func create_hood_mesh() -> Mesh:
	_ensure_loaded()
	return _cached_meshes.get("Part_Hood", null)


static func create_trunk_mesh() -> Mesh:
	_ensure_loaded()
	return _cached_meshes.get("Part_Trunk", null)


static func create_front_door_mesh(is_left: bool = true) -> Mesh:
	_ensure_loaded()
	var key := "Part_Door_FL" if is_left else "Part_Door_FR"
	return _cached_meshes.get(key, null)


static func create_rear_door_mesh(is_left: bool = true) -> Mesh:
	_ensure_loaded()
	var key := "Part_Door_RL" if is_left else "Part_Door_RR"
	return _cached_meshes.get(key, null)


static func create_wheel_mesh(_radius: float = 0.296, _width: float = 0.20, _sides: int = 16) -> Mesh:
	_ensure_loaded()
	# Retorna la malla de rueda calibrada
	var w: Mesh = _cached_meshes.get("Part_Wheel_FL", null)
	if w == null:
		w = _cached_meshes.get("Part_Wheel_FR", null)
	return w


static func get_wheel_mesh(is_left: bool = true, is_front: bool = true) -> Mesh:
	_ensure_loaded()
	var key := ""
	if is_front:
		key = "Part_Wheel_FL" if is_left else "Part_Wheel_FR"
	else:
		key = "Part_Wheel_RL" if is_left else "Part_Wheel_RR"
	return _cached_meshes.get(key, create_wheel_mesh())

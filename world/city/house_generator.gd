extends Node3D
class_name HouseGenerator
## Generador procedural modular de casas desde cero para Play Sector X.
## Construye residencias con lógica arquitectónica humana y zonificación de colonias:
## - COLONIA_VIEJA: Casas adosadas pared con pared (100% ancho del lote), muros ciegos laterales,
##   alturas y estilos variados, distribución con recámaras al patio trasero sin pasillo en medio.
## - COLONIA_NUEVA: Casas de fraccionamiento / Infonavit serializadas, mismo estilo y tamaño en la manzana,
##   pasillo lateral exterior de servicio (1m), retiro frontal para cochera, sin pasillos en medio.
## - ZONA_X: Residencias de lujo en terrenos enormes, casas aisladas con jardines a los 4 vientos,
##   techos altos, ventanales panorámicos y arquitectura única.
##
## Geometría 100% GPU Instanced (MultiMeshInstance3D con 1 solo Draw Call por casa).
## Vanos de puertas y ventanas cortados limpiamente sin booleanos CSG y con colisión física exacta.

enum HouseZoneType {
	COLONIA_VIEJA = 0, # Barrio tradicional: pared con pared, estilos y colores variados
	COLONIA_NUEVA = 1, # Fraccionamiento Infonavit: casas serializadas idénticas
	ZONA_X = 2         # Mansión / Riquillos: terreno enorme, aislada con jardines a 4 vientos
}

# Alias para compatibilidad con código existente
enum HouseTier {
	POOR = 0,
	MIDDLE = 1,
	RICH = 2
}

# Configuración pública consumida por CityLayoutGenerator
@export var auto_generate: bool = true
@export var parcel_source_path: NodePath = NodePath("..")
@export var house_count: int = 0
@export var randomize_seed_on_run: bool = false
@export var rng_seed: int = 1009
@export var show_debug_labels: bool = false
@export var show_roofs: bool = true
@export var show_fences: bool = false # BARDAS ELIMINADAS POR DIRECTIVA
@export_range(0.0, 1.0, 0.05) var fence_probability: float = 0.0
@export_range(0.0, 1.0, 0.05) var vacant_lot_probability: float = 0.12
@export var front_yard_depth: float = 3.5
@export var rear_yard_depth: float = 3.0

# Datos públicos consumidos por CityDecoration
var generated_houses: Array[Dictionary] = []
var vacant_parcels: Array[Dictionary] = []

# Malla base compartida para GPU Instancing
static var _unit_box_mesh: BoxMesh = null
static var _house_material: StandardMaterial3D = null

var _rng: RandomNumberGenerator


func _ready() -> void:
	_init_shared_resources()
	if auto_generate:
		generate_houses()


static func _init_shared_resources() -> void:
	if _unit_box_mesh == null:
		_unit_box_mesh = BoxMesh.new()
		_unit_box_mesh.size = Vector3(1.0, 1.0, 1.0)

	if _house_material == null:
		_house_material = StandardMaterial3D.new()
		_house_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_house_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		_house_material.vertex_color_use_as_albedo = true
		_house_material.roughness = 0.88
		_house_material.metallic = 0.02
		_house_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func clear_houses() -> void:
	generated_houses.clear()
	vacant_parcels.clear()
	for child in get_children():
		child.queue_free()


## Punto de entrada principal para generar todas las casas en las parcelas disponibles
func generate_houses() -> void:
	_init_shared_resources()
	clear_houses()

	_rng = RandomNumberGenerator.new()
	if randomize_seed_on_run:
		_rng.randomize()
		rng_seed = _rng.seed
	else:
		_rng.seed = rng_seed

	var parcels := _gather_parcels()
	if parcels.is_empty():
		return

	for i in parcels.size():
		var parcel_data: Dictionary = parcels[i]
		var parcel_rect: Rect2 = parcel_data.get("rect", Rect2())
		var front_side: int = int(parcel_data.get("front_side", 2))
		var zone_type: int = int(parcel_data.get("zone_type", -1))
		var prototype_seed: int = int(parcel_data.get("prototype_seed", rng_seed))

		var facing_dir: Vector3
		match front_side:
			0: facing_dir = Vector3(0.0, 0.0, -1.0)
			1: facing_dir = Vector3(1.0, 0.0, 0.0)
			2: facing_dir = Vector3(0.0, 0.0, 1.0)
			3: facing_dir = Vector3(-1.0, 0.0, 0.0)
			_: facing_dir = parcel_data.get("facing_direction", Vector3(0.0, 0.0, 1.0))

		if parcel_rect.size.x < 5.0 or parcel_rect.size.y < 5.0:
			continue

		# Evaluar si el lote queda como terreno baldío
		if _rng.randf() < vacant_lot_probability:
			vacant_parcels.append({
				"rect": parcel_rect,
				"front_side": front_side,
				"facing_direction": facing_dir
			})
			continue

		var house_seed := rng_seed + i * 31337
		var house_res := _build_single_house(parcel_rect, front_side, facing_dir, house_seed, zone_type, prototype_seed)
		if not house_res.is_empty() and house_res.get("node") != null:
			var house_node: Node3D = house_res["node"]
			add_child(house_node)
			generated_houses.append({
				"house_node": house_node,
				"parcel_rect": parcel_rect,
				"front_side": front_side,
				"facing_direction": facing_dir,
				"house_center": Vector2(parcel_rect.position.x + parcel_rect.size.x * 0.5, parcel_rect.position.y + parcel_rect.size.y * 0.5),
				"width": house_res.get("width", 8.0),
				"depth": house_res.get("depth", 8.0),
				"tier": house_res.get("tier", HouseZoneType.COLONIA_VIEJA),
				"zone_type": house_res.get("zone_type", HouseZoneType.COLONIA_VIEJA)
			})

	print("[HouseGenerator] Generación completa: %d casas construidas, %d lotes baldíos (Semilla: %d)" % [
		generated_houses.size(), vacant_parcels.size(), rng_seed
	])


func _gather_parcels() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source_node := get_node_or_null(parcel_source_path)
	if source_node != null and "block_parcels" in source_node:
		var list = source_node.block_parcels
		if list is Array:
			for item in list:
				if item is Dictionary:
					result.append(item)
	return result


# ==============================================================================
# CONSTRUCCIÓN DE UNA CASA INDIVIDUAL
# ==============================================================================

class BoxInstanceCollector:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var collision_boxes: Array[Dictionary] = [] # { "pos": Vector3, "size": Vector3 }

	func add_box(pos: Vector3, size: Vector3, color: Color, has_collision: bool = true) -> void:
		if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
			return
		var t := Transform3D(Basis().scaled(size), pos)
		transforms.append(t)
		colors.append(color)
		if has_collision:
			collision_boxes.append({"pos": pos, "size": size})


func _build_single_house(
	parcel_rect: Rect2,
	front_side: int,
	facing_dir: Vector3,
	house_seed: int,
	zone_type_override: int = -1,
	prototype_seed: int = 0
) -> Dictionary:
	var h_rng := RandomNumberGenerator.new()
	h_rng.seed = house_seed

	# 1. Determinar dimensiones del lote según frente y fondo en espacio local
	var lot_w: float
	var lot_d: float
	if front_side == 1 or front_side == 3:
		lot_w = parcel_rect.size.y
		lot_d = parcel_rect.size.x
	else:
		lot_w = parcel_rect.size.x
		lot_d = parcel_rect.size.y

	# 2. Determinar zona / tipología
	var zone_type: HouseZoneType
	if zone_type_override >= 0:
		zone_type = zone_type_override as HouseZoneType
	else:
		var area := lot_w * lot_d
		if area > 350.0 or lot_w >= 18.0:
			zone_type = HouseZoneType.ZONA_X
		elif lot_w <= 7.2:
			zone_type = HouseZoneType.COLONIA_NUEVA
		else:
			zone_type = HouseZoneType.COLONIA_VIEJA

	# 3. Nodo contenedor de la casa
	var house_root := Node3D.new()
	house_root.name = "House_%s_%d" % [_zone_name(zone_type), house_seed % 10000]

	# Orientación: transformar de espacio local a espacio de mundo
	var parcel_center_3d := Vector3(
		parcel_rect.position.x + parcel_rect.size.x * 0.5,
		0.0,
		parcel_rect.position.y + parcel_rect.size.y * 0.5
	)
	house_root.position = parcel_center_3d

	var angle_y := atan2(facing_dir.x, facing_dir.z)
	house_root.rotation = Vector3(0.0, angle_y, 0.0)

	# 4. Dimensionamiento según Tipología
	var house_w: float
	var house_d: float
	var wall_h: float
	var wall_thick: float
	var f_yard: float
	var r_yard: float
	var house_offset_x: float = 0.0

	match zone_type:
		HouseZoneType.COLONIA_VIEJA:
			# PARED CON PARED: Ocupa el 100% del ancho del terreno
			house_w = lot_w
			f_yard = h_rng.randf_range(0.0, 1.5) # Directo a la banqueta o retiro muy corto
			house_d = clampf(lot_d * h_rng.randf_range(0.65, 0.78), 8.5, lot_d - f_yard - 3.0)
			r_yard = lot_d - f_yard - house_d # Patio trasero normal (3m a 6m)
			wall_h = h_rng.randf_range(2.65, 3.20) # Altura variada por vecino
			wall_thick = 0.20

		HouseZoneType.COLONIA_NUEVA:
			# FRACCIONAMIENTO INFONAVIT: Ocupa el 75-85% del lote con zotehuela trasera
			var proto_rng := RandomNumberGenerator.new()
			proto_rng.seed = prototype_seed if prototype_seed != 0 else (house_seed / 100)

			var service_hallway := 0.75 # Pasillo de servicio lateral exterior angosto
			house_w = minf(lot_w - service_hallway, 5.80)
			house_offset_x = -service_hallway * 0.5
			f_yard = 2.50 # Retiro uniforme frontal de cochera
			house_d = clampf(lot_d - f_yard - 2.8, 8.0, 12.5) # Ocupa casi todo el fondo
			r_yard = lot_d - f_yard - house_d # Zotehuela de servicio trasera (2.5m - 3.5m)
			wall_h = 2.65 # Altura idéntica institucional
			wall_thick = 0.18

		HouseZoneType.ZONA_X:
			# ZONA DE RIQUILLOS: Mansión con jardín perimetral amplio, alberca y cochera
			var side_yard := h_rng.randf_range(2.5, 4.5)
			house_w = clampf(lot_w - side_yard * 2.0, 14.0, 28.0)
			f_yard = h_rng.randf_range(4.5, 7.5)
			r_yard = h_rng.randf_range(6.0, 12.0)
			house_d = clampf(lot_d - f_yard - r_yard, 12.0, 24.0)
			wall_h = h_rng.randf_range(3.50, 4.30) # Techos altos
			wall_thick = 0.24

	# Centro local de la casa desplazado respecto al frente (+Z calle, -Z fondo)
	# Garantiza que el frente de la casa quede exactamente a f_yard de la calle
	var local_z_center := (lot_d * 0.5 - f_yard) - house_d * 0.5
	var house_origin := Vector3(house_offset_x, 0.0, local_z_center)

	# 5. Paleta de colores sólidos
	var palette := _pick_palette(zone_type, h_rng, prototype_seed)

	# 6. Generar geometría por GPU Instancing
	var collector := BoxInstanceCollector.new()

	# A. Losa de piso
	var floor_size := Vector3(house_w, 0.15, house_d)
	var floor_pos := house_origin + Vector3(0.0, 0.075, 0.0)
	collector.add_box(floor_pos, floor_size, palette["floor"], true)

	# B. Losa de techo con alero
	if show_roofs:
		# En Colonia Vieja, NO hay alero lateral en X para no chocar con la pared del vecino
		var overhang_x: float = 0.0 if zone_type == HouseZoneType.COLONIA_VIEJA else (0.35 if zone_type == HouseZoneType.COLONIA_NUEVA else 0.85)
		var overhang_z: float = 0.40 if zone_type == HouseZoneType.COLONIA_VIEJA else (0.50 if zone_type == HouseZoneType.COLONIA_NUEVA else 0.85)
		var roof_size := Vector3(house_w + overhang_x * 2.0, 0.20, house_d + overhang_z * 2.0)
		var roof_pos := house_origin + Vector3(0.0, wall_h + 0.10, 0.0)
		collector.add_box(roof_pos, roof_size, palette["roof"], true)

	# C. Distribución arquitectónica de cuartos y muros (SIN PASILLO EN MEDIO)
	_build_house_layout(collector, house_origin, house_w, house_d, wall_h, wall_thick, zone_type, palette, h_rng)

	# D. BARDAS ELIMINADAS: Ya no se generan bardas perimetrales según directiva

	# 7. Ensamblar MultiMeshInstance3D
	if collector.transforms.is_empty():
		house_root.queue_free()
		return {}

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _unit_box_mesh
	mm.instance_count = collector.transforms.size()

	for idx in collector.transforms.size():
		mm.set_instance_transform(idx, collector.transforms[idx])
		mm.set_instance_color(idx, collector.colors[idx])

	var mm_inst := MultiMeshInstance3D.new()
	mm_inst.name = "HouseGeometry_MultiMesh"
	mm_inst.multimesh = mm
	mm_inst.material_override = _house_material
	house_root.add_child(mm_inst)

	# 8. Ensamblar StaticBody3D de colisiones físicas exactas
	var body := StaticBody3D.new()
	body.name = "HouseCollision"
	for box in collector.collision_boxes:
		var col_shape := CollisionShape3D.new()
		var b_shape := BoxShape3D.new()
		b_shape.size = box["size"]
		col_shape.shape = b_shape
		col_shape.position = box["pos"]
		body.add_child(col_shape)
	house_root.add_child(body)

	return {
		"node": house_root,
		"width": house_w,
		"depth": house_d,
		"wall_h": wall_h,
		"tier": zone_type,
		"zone_type": zone_type
	}


## Helper público para construir una casa individual para escenas de prueba, depuración o colocación libre
func build_standalone_house(lot_w: float, lot_d: float, zone_or_tier: int, house_seed: int) -> Node3D:
	_init_shared_resources()
	var rect := Rect2(-lot_w * 0.5, -lot_d * 0.5, lot_w, lot_d)
	var res := _build_single_house(rect, 2, Vector3(0.0, 0.0, 1.0), house_seed, zone_or_tier, house_seed)
	return res.get("node", null) as Node3D


# ==============================================================================
# SUBDIVISIÓN ARQUITECTÓNICA Y GENERACIÓN DE MUROS CON VANOS
# ==============================================================================

func _build_house_layout(
	collector: BoxInstanceCollector,
	origin: Vector3,
	w: float,
	d: float,
	h: float,
	thick: float,
	zone_type: HouseZoneType,
	palette: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var half_w := w * 0.5
	var half_d := d * 0.5

	# Coordenadas locales de esquinas del perímetro
	var x_left := origin.x - half_w
	var x_right := origin.x + half_w
	var z_back := origin.z - half_d
	var z_front := origin.z + half_d

	match zone_type:
		HouseZoneType.COLONIA_VIEJA:
			_build_colonia_vieja_layout(collector, origin, x_left, x_right, z_back, z_front, h, thick, palette, rng)
		HouseZoneType.COLONIA_NUEVA:
			_build_colonia_nueva_layout(collector, origin, x_left, x_right, z_back, z_front, h, thick, palette, rng)
		HouseZoneType.ZONA_X:
			_build_zona_x_layout(collector, origin, x_left, x_right, z_back, z_front, h, thick, palette, rng)


## Tipología COLONIA VIEJA (Barrio Tradicional, Pared con Pared):
## - La casa ocupa todo el frente del lote (pared con pared con los vecinos de los lados).
## - Muros laterales IZQUIERDO Y DERECHO CIEGOS (sin ventanas a los lados, dan a la pared del vecino).
## - Ventilación e iluminación exclusivamente por el frente (calle) y por atrás (patio posterior).
## - DISTRIBUCIÓN SIN PASILLOS EN MEDIO:
##   * Frente: Sala y Cocina/Comedor comunicados abiertamente.
##   * Fondo: Muro divisorio transversal con puertas que abren DIRECTO a 1-2 recámaras y 1 baño.
func _build_colonia_vieja_layout(
	c: BoxInstanceCollector,
	origin: Vector3,
	x_l: float,
	x_r: float,
	z_b: float,
	z_f: float,
	h: float,
	th: float,
	pal: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var w := x_r - x_l
	var d := z_f - z_b

	var door_w := 0.90
	var door_h := 2.15
	var win_w := clampf(w * 0.28, 1.20, 1.60)
	var win_h := 1.20
	var win_sill := 0.95

	# 1. Fachada Frontal (+Z): Puerta de acceso peatonal + ventana a la calle
	var door_on_left := rng.randf() < 0.5
	var door_x := (x_l + 1.20) if door_on_left else (x_r - 1.20 - door_w)
	var win_x := (x_r - 1.40 - win_w) if door_on_left else (x_l + 1.40)

	_add_wall_x_with_openings(c, x_l, x_r, z_f, h, th, [
		{"type": "door", "start_x": door_x, "w": door_w, "h": door_h},
		{"type": "window", "start_x": win_x, "w": win_w, "h": win_h, "sill": win_sill}
	], pal["wall_ext"])

	# 2. Fachada Trasera (-Z): Ventanas de las recámaras y puerta de salida al patio
	var patio_door_w := 0.85
	var patio_door_h := 2.05
	var rear_win_w := 1.10
	var rear_win_h := 1.10
	var rear_sill := 1.00

	_add_wall_x_with_openings(c, x_l, x_r, z_b, h, th, [
		{"type": "window", "start_x": x_l + w * 0.22 - rear_win_w * 0.5, "w": rear_win_w, "h": rear_win_h, "sill": rear_sill},
		{"type": "door", "start_x": x_l + w * 0.52 - patio_door_w * 0.5, "w": patio_door_w, "h": patio_door_h},
		{"type": "window", "start_x": x_l + w * 0.82 - rear_win_w * 0.5, "w": rear_win_w, "h": rear_win_h, "sill": rear_sill}
	], pal["wall_ext"])

	# 3. Muros Laterales Exteriores CIEGOS (Pared con pared del vecino)
	_add_wall_z_solid(c, x_l, z_b, z_f, h, th, pal["wall_ext"])
	_add_wall_z_solid(c, x_r, z_b, z_f, h, th, pal["wall_ext"])

	# 4. Muro Divisorio Transversal (separa área social al frente de recámaras al fondo)
	# ¡SIN PASILLO EN MEDIO! Las puertas dan directo a la sala/comedor
	var z_divider := z_b + d * 0.48
	var x_split := x_l + w * 0.52
	var int_door_w := 0.85
	var int_door_h := 2.05

	# Puertas interiores a recámaras izquierda y derecha
	_add_wall_x_with_openings(c, x_l, x_r, z_divider, h, th, [
		{"type": "door", "start_x": x_l + (x_split - x_l) * 0.5 - int_door_w * 0.5, "w": int_door_w, "h": int_door_h},
		{"type": "door", "start_x": x_split + (x_r - x_split) * 0.5 - int_door_w * 0.5, "w": int_door_w, "h": int_door_h}
	], pal["wall_int"])

	# 5. Muro divisorio entre las dos recámaras traseras
	_add_wall_z_solid(c, x_split, z_b, z_divider, h, th, pal["wall_int"])

	# 6. Baño compacto dentro de una de las alas traseras con puerta directa
	var bath_w := 1.80
	var bath_z := z_b + 2.40
	if (x_r - x_split) >= 3.0:
		_add_wall_x_with_openings(c, x_r - bath_w, x_r, bath_z, h, th, [
			{"type": "door", "start_x": x_r - bath_w + 0.15, "w": 0.75, "h": 2.00}
		], pal["wall_int"])
		_add_wall_z_solid(c, x_r - bath_w, z_b, bath_z, h, th, pal["wall_int"])


## Tipología COLONIA NUEVA (Fraccionamiento / Infonavit):
## - Casas idénticas y serializadas en toda la calle/manzana.
## - Pasillo lateral exterior de servicio (1m) para acceder al patio trasero.
## - Retiro frontal uniforme (3.5m) para cochera abierta de 1 auto.
## - DISTRIBUCIÓN INFONAVIT SIN PASILLO EN MEDIO:
##   * Frente: Sala y Cocineta en concepto social continuo.
##   * Fondo: 2 recámaras y baño completo en medio, abriendo directamente al área social.
func _build_colonia_nueva_layout(
	c: BoxInstanceCollector,
	origin: Vector3,
	x_l: float,
	x_r: float,
	z_b: float,
	z_f: float,
	h: float,
	th: float,
	pal: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var w := x_r - x_l
	var d := z_f - z_b

	var door_w := 0.90
	var door_h := 2.15
	var win_w := 1.30
	var win_h := 1.15
	var win_sill := 0.95

	# 1. Fachada Frontal (+Z): Puerta peatonal + ventana amplia de sala
	var door_x := x_l + 0.90
	var win_x := x_r - win_w - 0.90

	_add_wall_x_with_openings(c, x_l, x_r, z_f, h, th, [
		{"type": "door", "start_x": door_x, "w": door_w, "h": door_h},
		{"type": "window", "start_x": win_x, "w": win_w, "h": win_h, "sill": win_sill}
	], pal["wall_ext"])

	# 2. Fachada Trasera (-Z): 2 ventanas de recámaras hacia el patio de servicio
	var rear_win_w := 1.10
	var rear_win_h := 1.10
	var rear_sill := 1.05

	_add_wall_x_with_openings(c, x_l, x_r, z_b, h, th, [
		{"type": "window", "start_x": x_l + w * 0.25 - rear_win_w * 0.5, "w": rear_win_w, "h": rear_win_h, "sill": rear_sill},
		{"type": "window", "start_x": x_l + w * 0.75 - rear_win_w * 0.5, "w": rear_win_w, "h": rear_win_h, "sill": rear_sill}
	], pal["wall_ext"])

	# 3. Muros Laterales:
	# Lado izquierdo (ciego)
	_add_wall_z_solid(c, x_l, z_b, z_f, h, th, pal["wall_ext"])
	# Lado derecho (con pasillo de servicio exterior): ventana de ventilación para cocina/patio y puerta de servicio
	_add_wall_z_with_openings(c, x_r, z_b, z_f, h, th, [
		{"type": "window", "start_z": z_f - 1.80, "w": 0.80, "h": 0.80, "sill": 1.40},
		{"type": "door", "start_z": z_b + 1.20, "w": 0.80, "h": 2.05}
	], pal["wall_ext"])

	# 4. Distribución Interior (Transversal a 46% de profundidad):
	# Separa área social frontal de las 2 recámaras y baño trasero
	# ¡SIN PASILLO EN MEDIO!
	var z_divider := z_b + d * 0.46
	var int_door_w := 0.80
	var int_door_h := 2.05

	# Puertas que dan directamente desde la sala-comedor
	var x_rec1_door := x_l + 0.60
	var x_bath_door := x_l + w * 0.50 - 0.40
	var x_rec2_door := x_r - 0.60 - int_door_w

	_add_wall_x_with_openings(c, x_l, x_r, z_divider, h, th, [
		{"type": "door", "start_x": x_rec1_door, "w": int_door_w, "h": int_door_h},
		{"type": "door", "start_x": x_bath_door, "w": 0.75, "h": int_door_h},
		{"type": "door", "start_x": x_rec2_door, "w": int_door_w, "h": int_door_h}
	], pal["wall_int"])

	# 5. Muros longitudinales del baño entre las dos recámaras
	var bath_x0 := x_l + w * 0.38
	var bath_x1 := x_l + w * 0.62
	_add_wall_z_solid(c, bath_x0, z_b, z_divider, h, th, pal["wall_int"])
	_add_wall_z_solid(c, bath_x1, z_b, z_divider, h, th, pal["wall_int"])


## Tipología ZONA X (Zona Residencial de Lujo / Riquillos):
## - Terreno enorme. Casa aislada centrada en el lote con jardines a los 4 lados.
## - Techos monumentales de 3.4m a 3.8m.
## - Gran puerta monumental pivotante (1.6m x 2.8m).
## - Ventanales panorámicos de piso a techo en todas las caras.
## - DISTRIBUCIÓN OPEN-CONCEPT CONTEMPORÁNEA (SIN PASILLOS OSCUROS):
##   * Gran Salón social (Great Room) a doble altura con ventanales continuos hacia la terraza.
##   * Ala privada con Master Suite con vestidor y baño propio, y recámaras secundarias amplias.
func _build_zona_x_layout(
	c: BoxInstanceCollector,
	origin: Vector3,
	x_l: float,
	x_r: float,
	z_b: float,
	z_f: float,
	h: float,
	th: float,
	pal: Dictionary,
	rng: RandomNumberGenerator
) -> void:
	var w := x_r - x_l
	var d := z_f - z_b

	# Puerta monumental y ventanales panorámicos
	var grand_door_w := 1.60
	var grand_door_h := 2.80
	var panorama_win_w := clampf(w * 0.35, 3.2, 5.5)
	var panorama_win_h := 2.60

	# 1. Fachada Frontal (+Z): Entrada monumental + ventanal elegante
	var door_x := x_l + w * 0.32 - grand_door_w * 0.5
	var win_x := x_l + w * 0.72 - panorama_win_w * 0.5
	_add_wall_x_with_openings(c, x_l, x_r, z_f, h, th, [
		{"type": "door", "start_x": door_x, "w": grand_door_w, "h": grand_door_h},
		{"type": "window", "start_x": win_x, "w": panorama_win_w, "h": panorama_win_h, "sill": 0.20}
	], pal["wall_ext"])

	# 2. Fachada Trasera (-Z): Ventanales panorámicos de piso a techo hacia el jardín/terraza
	_add_wall_x_with_openings(c, x_l, x_r, z_b, h, th, [
		{"type": "window", "start_x": x_l + w * 0.25 - panorama_win_w * 0.5, "w": panorama_win_w, "h": panorama_win_h, "sill": 0.05},
		{"type": "window", "start_x": x_l + w * 0.75 - panorama_win_w * 0.5, "w": panorama_win_w, "h": panorama_win_h, "sill": 0.05}
	], pal["wall_ext"])

	# 3. Muros Laterales Exteriores con ventanales esbeltos
	_add_wall_z_with_openings(c, x_l, z_b, z_f, h, th, [
		{"type": "window", "start_z": z_f - d * 0.40 - 0.75, "w": 1.50, "h": 2.20, "sill": 0.40}
	], pal["wall_ext"])
	_add_wall_z_with_openings(c, x_r, z_b, z_f, h, th, [
		{"type": "window", "start_z": z_f - d * 0.40 - 0.75, "w": 1.50, "h": 2.20, "sill": 0.40}
	], pal["wall_ext"])

	# 4. Distribución Open-Concept:
	# El 60% del ancho es el Gran Salón (Great Room) sin paredes divisorias
	# El 40% lateral aloja la Master Suite y el baño privado
	var x_wing_divider := x_l + w * 0.58
	var z_suite_split := z_b + d * 0.50

	var master_door_w := 1.00
	var master_door_h := 2.40
	_add_wall_z_with_openings(c, x_wing_divider, z_b, z_f, h, th, [
		{"type": "door", "start_z": z_f - d * 0.35 - master_door_w * 0.5, "w": master_door_w, "h": master_door_h}
	], pal["wall_int"])

	# Muro que separa la Master Suite del baño privado dentro del ala
	_add_wall_x_with_openings(c, x_wing_divider, x_r, z_suite_split, h, th, [
		{"type": "door", "start_x": x_wing_divider + (x_r - x_wing_divider) * 0.5 - master_door_w * 0.5, "w": master_door_w, "h": master_door_h}
	], pal["wall_int"])


# ==============================================================================
# SUBDIVISIÓN GEOMÉTRICA DE MUROS (BOX SPLITTING SIN BOOLEANOS)
# ==============================================================================

## Construye un muro continuo a lo largo del eje X (desde x0 hasta x1, en z_pos)
## cortando limpiamente los vanos de puertas y ventanas mediante cajas contiguas.
func _add_wall_x_with_openings(
	c: BoxInstanceCollector,
	x0: float,
	x1: float,
	z_pos: float,
	wall_h: float,
	thick: float,
	openings: Array[Dictionary], # [{ "type": "door"|"window", "start_x": float, "w": float, "h": float, "sill": float }]
	color: Color
) -> void:
	if x1 <= x0:
		return

	# Ordenar vanos de izquierda a derecha
	var sorted_openings := openings.duplicate()
	sorted_openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("start_x", 0.0)) < float(b.get("start_x", 0.0))
	)

	var current_x := x0
	for op in sorted_openings:
		var op_start: float = clampf(float(op.get("start_x", 0.0)), x0, x1)
		var op_w: float = minf(float(op.get("w", 0.9)), x1 - op_start)
		var op_end: float = op_start + op_w

		if op_start > current_x:
			# Tramo de muro sólido antes del vano
			var seg_w := op_start - current_x
			var seg_center_x := current_x + seg_w * 0.5
			c.add_box(Vector3(seg_center_x, wall_h * 0.5, z_pos), Vector3(seg_w, wall_h, thick), color)

		var op_type: String = op.get("type", "door")
		if op_type == "door":
			# Puerta: dintel superior sobre el vano
			var door_h: float = minf(float(op.get("h", 2.10)), wall_h - 0.15)
			var lintel_h := wall_h - door_h
			var lintel_y := door_h + lintel_h * 0.5
			c.add_box(Vector3(op_start + op_w * 0.5, lintel_y, z_pos), Vector3(op_w, lintel_h, thick), color)

		elif op_type == "window":
			# Ventana: antepecho inferior y dintel superior
			var sill: float = clampf(float(op.get("sill", 0.90)), 0.0, wall_h - 0.6)
			var win_h: float = clampf(float(op.get("h", 1.20)), 0.3, wall_h - sill - 0.2)
			var lintel_h := wall_h - (sill + win_h)
			var lintel_y := sill + win_h + lintel_h * 0.5

			# Antepecho
			if sill > 0.01:
				c.add_box(Vector3(op_start + op_w * 0.5, sill * 0.5, z_pos), Vector3(op_w, sill, thick), color)
			# Dintel
			if lintel_h > 0.01:
				c.add_box(Vector3(op_start + op_w * 0.5, lintel_y, z_pos), Vector3(op_w, lintel_h, thick), color)

		current_x = op_end

	# Tramo final de muro si sobra espacio después del último vano
	if current_x < x1:
		var last_w := x1 - current_x
		c.add_box(Vector3(current_x + last_w * 0.5, wall_h * 0.5, z_pos), Vector3(last_w, wall_h, thick), color)


## Construye un muro continuo a lo largo del eje Z (desde z0 hasta z1, en x_pos) con vanos.
func _add_wall_z_with_openings(
	c: BoxInstanceCollector,
	x_pos: float,
	z0: float,
	z1: float,
	wall_h: float,
	thick: float,
	openings: Array[Dictionary],
	color: Color
) -> void:
	if z1 <= z0:
		return

	var sorted_openings := openings.duplicate()
	sorted_openings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("start_z", 0.0)) < float(b.get("start_z", 0.0))
	)

	var current_z := z0
	for op in sorted_openings:
		var op_start: float = clampf(float(op.get("start_z", 0.0)), z0, z1)
		var op_w: float = minf(float(op.get("w", 0.9)), z1 - op_start)
		var op_end: float = op_start + op_w

		if op_start > current_z:
			var seg_d := op_start - current_z
			c.add_box(Vector3(x_pos, wall_h * 0.5, current_z + seg_d * 0.5), Vector3(thick, wall_h, seg_d), color)

		var op_type: String = op.get("type", "door")
		if op_type == "door":
			var door_h: float = minf(float(op.get("h", 2.10)), wall_h - 0.15)
			var lintel_h := wall_h - door_h
			var lintel_y := door_h + lintel_h * 0.5
			c.add_box(Vector3(x_pos, lintel_y, op_start + op_w * 0.5), Vector3(thick, lintel_h, op_w), color)

		elif op_type == "window":
			var sill: float = clampf(float(op.get("sill", 0.90)), 0.0, wall_h - 0.6)
			var win_h: float = clampf(float(op.get("h", 1.20)), 0.3, wall_h - sill - 0.2)
			var lintel_h := wall_h - (sill + win_h)
			var lintel_y := sill + win_h + lintel_h * 0.5

			if sill > 0.01:
				c.add_box(Vector3(x_pos, sill * 0.5, op_start + op_w * 0.5), Vector3(thick, sill, op_w), color)
			if lintel_h > 0.01:
				c.add_box(Vector3(x_pos, lintel_y, op_start + op_w * 0.5), Vector3(thick, lintel_h, op_w), color)

		current_z = op_end

	if current_z < z1:
		var last_d := z1 - current_z
		c.add_box(Vector3(x_pos, wall_h * 0.5, current_z + last_d * 0.5), Vector3(thick, wall_h, last_d), color)


## Construye un muro sólido sin vanos en el eje X
func _add_wall_x_solid(c: BoxInstanceCollector, x0: float, x1: float, z_pos: float, wall_h: float, thick: float, color: Color) -> void:
	var w := x1 - x0
	if w <= 0.001:
		return
	c.add_box(Vector3(x0 + w * 0.5, wall_h * 0.5, z_pos), Vector3(w, wall_h, thick), color)


## Construye un muro sólido sin vanos en el eje Z
func _add_wall_z_solid(c: BoxInstanceCollector, x_pos: float, z0: float, z1: float, wall_h: float, thick: float, color: Color) -> void:
	var d := z1 - z0
	if d <= 0.001:
		return
	c.add_box(Vector3(x_pos, wall_h * 0.5, z0 + d * 0.5), Vector3(thick, wall_h, d), color)


# ==============================================================================
# PALETAS DE COLOR SÓLIDAS CALIBRADAS
# ==============================================================================

func _pick_palette(zone: HouseZoneType, rng: RandomNumberGenerator, proto_seed: int = 0) -> Dictionary:
	match zone:
		HouseZoneType.COLONIA_VIEJA:
			# Paleta viva e individual de barrio tradicional (bloques, adobe, colores contrastantes)
			var ext_colors: Array[Color] = [
				Color(0.50, 0.48, 0.45), # Bloque de cemento crudo
				Color(0.58, 0.42, 0.32), # Ladrillo / Adobe tostado
				Color(0.42, 0.48, 0.52), # Azul deslavado
				Color(0.68, 0.45, 0.35), # Teja / terracota
				Color(0.55, 0.52, 0.46), # Yeso grisáceo
				Color(0.72, 0.65, 0.45)  # Amarillo ocre tradicional
			]
			return {
				"wall_ext": ext_colors[rng.randi() % ext_colors.size()],
				"wall_int": Color(0.62, 0.60, 0.56),
				"floor": Color(0.38, 0.36, 0.33),
				"roof": Color(0.32, 0.30, 0.28)
			}

		HouseZoneType.COLONIA_NUEVA:
			# Paleta uniforme institucional estilo fraccionamiento / Infonavit
			var p_rng := RandomNumberGenerator.new()
			p_rng.seed = proto_seed if proto_seed != 0 else rng.seed
			var base_colors: Array[Color] = [
				Color(0.92, 0.90, 0.86), # Estuco marfil
				Color(0.85, 0.82, 0.74), # Arena cálida
				Color(0.80, 0.78, 0.75), # Gris perla uniforme
				Color(0.78, 0.68, 0.58)  # Cantera suave
			]
			var chosen_base := base_colors[p_rng.randi() % base_colors.size()]
			# Ligerísima variación para no verse plano computacional
			var jitter := rng.randf_range(-0.02, 0.02)
			var wall_color := Color(
				clampf(chosen_base.r + jitter, 0.0, 1.0),
				clampf(chosen_base.g + jitter, 0.0, 1.0),
				clampf(chosen_base.b + jitter, 0.0, 1.0)
			)
			return {
				"wall_ext": wall_color,
				"wall_int": Color(0.95, 0.94, 0.92),
				"floor": Color(0.56, 0.52, 0.48),
				"roof": Color(0.26, 0.28, 0.30)
			}

		HouseZoneType.ZONA_X:
			# Paleta de autor contemporánea / de lujo
			var ext_colors: Array[Color] = [
				Color(0.97, 0.97, 0.97), # Blanco minimalista puro
				Color(0.18, 0.20, 0.22), # Antracita moderno
				Color(0.25, 0.19, 0.14), # Madera oscura / acero corten
				Color(0.86, 0.84, 0.80)  # Concreto arquitectónico pulido
			]
			return {
				"wall_ext": ext_colors[rng.randi() % ext_colors.size()],
				"wall_int": Color(0.98, 0.98, 0.98),
				"floor": Color(0.88, 0.86, 0.82), # Mármol / Porcelanato
				"roof": Color(0.12, 0.14, 0.16)
			}

	return {
		"wall_ext": Color(0.7, 0.7, 0.7),
		"wall_int": Color(0.9, 0.9, 0.9),
		"floor": Color(0.4, 0.4, 0.4),
		"roof": Color(0.2, 0.2, 0.2)
	}


func _zone_name(zone: HouseZoneType) -> String:
	match zone:
		HouseZoneType.COLONIA_VIEJA: return "ColoniaVieja"
		HouseZoneType.COLONIA_NUEVA: return "ColoniaNueva_Infonavit"
		HouseZoneType.ZONA_X: return "ZonaX_Luxury"
	return "House"

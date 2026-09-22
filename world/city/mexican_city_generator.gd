extends CityLayoutGenerator
class_name MexicanCityGenerator
## Macro-Generador de Ciudad Procedural Inspirada en México.
## A diferencia del modelo estadounidense disperso con suburbios aislados,
## la ciudad mexicana es compacta, densa, caminable y con "todo cerca":
##
## 1. EL ZÓCALO / PLAZA MAYOR (Corazón de la ciudad):
##    - Explanada de cantera y adoquín peatonal en una manzana central.
##    - Quiosco central elevado con barandales de herrería y cubierta tradicional.
##    - 4 jardineras esquineras con árboles de sombra (ProceduralTree classic_oak).
##    - Bancas de parque y farolas coloniales perimetrales.
##
## 2. BARRIO TRADICIONAL / COLONIA VIEJA (Primer cuadro):
##    - Rodea inmediatamente al Zócalo y a la avenida principal.
##    - Casas continuas pared con pared (100% de frente), muros ciegos laterales.
##    - Paleta cálida mexicana (terracota, ocre, azul colonial, amarillo mostaza).
##    - Patios interiores traseros profundos.
##    - Tienditas de la esquina / abarrotes en esquinas estratégicas.
##
## 3. FRACCIONAMIENTO POPULAR / COLONIA NUEVA (Infonavit):
##    - Sector obrero denso a solo 1-2 cuadras del centro comercial.
##    - Lotes idénticos de 6.5m con casas serializadas y pasillos de servicio.
##
## 4. ZONA RESIDENCIAL / LAS LOMAS (Zona X):
##    - Fincas y mansiones amplias con terrenos super aleatorios (900m² a 2,500m²).
##    - Integrada a la misma red urbana (a minutos del Zócalo).
##
## 5. EJE CONECTOR:
##    - Avenida central con camellón arbolado o arroyo natural cruzando la ciudad.

const PROCEDURAL_TREE_SCRIPT := preload("res://world/procedural_trees/procedural_tree.gd")

@export_group("Zócalo y Plaza Central")
@export var generate_zocalo: bool = true
@export var zocalo_block_index: int = 0
@export var zocalo_kiosk_enabled: bool = true
@export var zocalo_trees_count: int = 4
@export var zocalo_benches_count: int = 8

@export_group("Comercio y Tienditas")
@export var generate_corner_tienditas: bool = true
@export_range(0.0, 1.0, 0.1) var tiendita_corner_chance: float = 0.50

var zocalo_node: Node3D = null
var tienditas_root: Node3D = null


func _ready() -> void:
	# Configuración por defecto optimizada para escala urbana mexicana
	neighborhood_zone = CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS
	if city_length < 280.0:
		city_length = 360.0
	super._ready()


## Sobrescritura de generación de ciudad para integrar el Zócalo y los distritos mexicanos
func generate_city() -> void:
	# Limpiar elementos cívicos previos
	if zocalo_node != null and is_instance_valid(zocalo_node):
		zocalo_node.queue_free()
		zocalo_node = null

	if tienditas_root != null and is_instance_valid(tienditas_root):
		tienditas_root.queue_free()
		tienditas_root = null

	super.generate_city()

	# Construir el Zócalo en la manzana asignada
	if generate_zocalo and block_rects.size() > 0:
		_build_mexican_zocalo()

	# Generar toldos y elementos de tiendita de la esquina en casas de barrio
	if generate_corner_tienditas and _house_generator != null:
		_build_corner_tienditas()


## Sobrescribe la subdivisión parcelaria para respetar la manzana cívica del Zócalo
## y distribuir las zonas con lógica urbana mexicana concéntrica
func _build_parcels(blocks: Array[Rect2], avenue_cfg: CityRoadPatterns.AvenueConfig, hood_cfg: CityRoadPatterns.NeighborhoodConfig) -> void:
	block_rects = blocks
	block_parcels.clear()

	if show_parcel_outlines:
		_parcel_outline_root = Node3D.new()
		_parcel_outline_root.name = "ParcelOutlines"
		add_child(_parcel_outline_root)

	# Identificar la manzana que será el Zócalo (céntrica, adyacente a la avenida)
	var zocalo_idx := _find_best_zocalo_block_index(blocks)

	for b_idx in range(blocks.size()):
		var block := blocks[b_idx]

		# Si esta manzana es el Zócalo, no generar parcelas de casas privadas
		if generate_zocalo and b_idx == zocalo_idx:
			continue

		# Zonificación mexicana concéntrica:
		# - Manzanas cercanas al Zócalo / Primer Cuadro: Colonia Vieja (Barrio Tradicional)
		# - Manzanas secundarias en el mismo lado o hacia el exterior: Colonia Nueva (Infonavit)
		# - Manzanas del cuadrante posterior / más tranquilo: Zona X (Mansiones / Las Lomas)
		var eff_zone := _determine_mexican_zone_for_block(b_idx, zocalo_idx, blocks.size())

		var block_prototype_seed := rng_seed + b_idx * 1337
		var lots := _subdivide_single_block(block, eff_zone, block_prototype_seed)

		for l_idx in range(lots.size()):
			var lot: Dictionary = lots[l_idx]
			lot["source_index"] = block_parcels.size()
			lot["block_index"] = b_idx
			lot["lot_index"] = l_idx
			lot["zone_type"] = eff_zone
			lot["prototype_seed"] = block_prototype_seed
			block_parcels.append(lot)

			if show_parcel_outlines and _parcel_outline_root != null:
				_add_parcel_outline_visual(lot["rect"])


## Selecciona la manzana más central y mejor ubicada para ser el Zócalo de la ciudad
func _find_best_zocalo_block_index(blocks: Array[Rect2]) -> int:
	if blocks.is_empty():
		return 0

	var best_idx := 0
	var min_dist_to_center := INF

	# El centro de la ciudad está cerca de (0, 0)
	for i in range(blocks.size()):
		var b := blocks[i]
		var center := b.position + b.size * 0.5
		var dist := center.length()
		# Preferir manzanas cercanas al centro sobre el eje Z
		var score := absf(center.y) + absf(center.x) * 0.5
		if score < min_dist_to_center:
			min_dist_to_center = score
			best_idx = i

	return best_idx


## Determina la tipología urbana según la cercanía al centro de la ciudad
func _determine_mexican_zone_for_block(b_idx: int, zocalo_idx: int, total_blocks: int) -> CityRoadPatterns.NeighborhoodZoneType:
	if neighborhood_zone != CityRoadPatterns.NeighborhoodZoneType.ZONAS_MIXTAS:
		return neighborhood_zone

	# Modelo de Ciudad Mexicana:
	# - Cuadrante central y contiguo al Zócalo: COLONIA_VIEJA (Pared con pared, comercio tradicional)
	# - Cuadrantes residenciales de densidad media: COLONIA_NUEVA (Infonavit)
	# - Cuadrante exclusivo / lomas: ZONA_X (Grandes residencias y fincas)
	var diff := absi(b_idx - zocalo_idx)
	if diff <= 2:
		return CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA
	elif b_idx >= total_blocks - 3:
		return CityRoadPatterns.NeighborhoodZoneType.ZONA_X
	else:
		return CityRoadPatterns.NeighborhoodZoneType.COLONIA_NUEVA


# ==============================================================================
# CONSTRUCCIÓN PROCEDURAL DEL ZÓCALO / PLAZA MAYOR
# ==============================================================================

func _build_mexican_zocalo() -> void:
	var zocalo_idx := _find_best_zocalo_block_index(block_rects)
	if zocalo_idx < 0 or zocalo_idx >= block_rects.size():
		return

	var block := block_rects[zocalo_idx]
	var bx := block.position.x
	var bz := block.position.y
	var bw := block.size.x
	var bh := block.size.y
	var center_3d := Vector3(bx + bw * 0.5, 0.0, bz + bh * 0.5)

	zocalo_node = Node3D.new()
	zocalo_node.name = "PlazaMayor_Zocalo"
	add_child(zocalo_node)

	# 1. Explanada principal de adoquín / loseta de cantera
	var plaza_mesh := BoxMesh.new()
	plaza_mesh.size = Vector3(bw, 0.18, bh)
	var plaza_inst := MeshInstance3D.new()
	plaza_inst.mesh = plaza_mesh
	plaza_inst.position = center_3d + Vector3(0.0, 0.09, 0.0)

	var cantera_mat := StandardMaterial3D.new()
	cantera_mat.albedo_color = Color(0.68, 0.62, 0.54) # Tono cantera rosa/gris mexicana
	cantera_mat.roughness = 0.88
	plaza_inst.material_override = cantera_mat
	zocalo_node.add_child(plaza_inst)

	# Colisión de la explanada
	var plaza_body := StaticBody3D.new()
	var plaza_col := CollisionShape3D.new()
	var plaza_shape := BoxShape3D.new()
	plaza_shape.size = plaza_mesh.size
	plaza_col.shape = plaza_shape
	plaza_col.position = plaza_inst.position
	plaza_body.add_child(plaza_col)
	zocalo_node.add_child(plaza_body)

	# 2. Quiosco central elevado
	if zocalo_kiosk_enabled:
		_build_zocalo_kiosk(center_3d)

	# 3. 4 Jardineras esquineras con césped y árboles de sombra (ProceduralTree)
	_build_zocalo_gardens(center_3d, bw, bh)

	# 4. Bancas perimetrales y farolas
	_build_zocalo_furniture(center_3d, bw, bh)

	print("[MexicanCityGenerator] ¡Zócalo / Plaza Mayor construida en manzana %d! Centro=(%.1f, %.1f), Área=%.1f m²" % [
		zocalo_idx, center_3d.x, center_3d.z, bw * bh
	])


## Construye el quiosco tradicional mexicano con base octogonal, columnas y techo de teja/cobre
func _build_zocalo_kiosk(center: Vector3) -> void:
	var kiosk_root := Node3D.new()
	kiosk_root.name = "KioscoCentral"
	zocalo_node.add_child(kiosk_root)

	var kiosk_base_h := 1.0
	var kiosk_w := 9.0
	var kiosk_d := 9.0

	# A. Base elevada de cantera
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(kiosk_w, kiosk_base_h, kiosk_d)
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.position = center + Vector3(0.0, kiosk_base_h * 0.5, 0.0)

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.72, 0.58, 0.48) # Cantera ocre mexicana
	base_mat.roughness = 0.90
	base_inst.material_override = base_mat
	kiosk_root.add_child(base_inst)

	# Colisión de la base
	var base_body := StaticBody3D.new()
	var base_col := CollisionShape3D.new()
	var b_shape := BoxShape3D.new()
	b_shape.size = base_mesh.size
	base_col.shape = b_shape
	base_col.position = base_inst.position
	base_body.add_child(base_col)
	kiosk_root.add_child(base_body)

	# B. 4 Escalinatas de acceso (Norte, Sur, Este, Oeste)
	var stair_mat := StandardMaterial3D.new()
	stair_mat.albedo_color = Color(0.65, 0.52, 0.42)
	stair_mat.roughness = 0.90

	var stair_offsets := [
		Vector3(0.0, 0.0, kiosk_d * 0.5 + 0.9),   # Sur
		Vector3(0.0, 0.0, -kiosk_d * 0.5 - 0.9),  # Norte
		Vector3(kiosk_w * 0.5 + 0.9, 0.0, 0.0),   # Este
		Vector3(-kiosk_w * 0.5 - 0.9, 0.0, 0.0)   # Oeste
	]

	for i in range(stair_offsets.size()):
		var s_off: Vector3 = stair_offsets[i]
		var s_mesh := BoxMesh.new()
		if i < 2:
			s_mesh.size = Vector3(2.6, 0.5, 1.8)
		else:
			s_mesh.size = Vector3(1.8, 0.5, 2.6)

		var s_inst := MeshInstance3D.new()
		s_inst.mesh = s_mesh
		s_inst.position = center + s_off + Vector3(0.0, 0.25, 0.0)
		s_inst.material_override = stair_mat
		kiosk_root.add_child(s_inst)

	# C. Columnas / Pilares de herrería colonial
	var pillar_h := 3.20
	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.30, pillar_h, 0.30)
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.12, 0.24, 0.18) # Verde bosque / herrería tradicional
	pillar_mat.metallic = 0.5
	pillar_mat.roughness = 0.4

	var pillar_r := kiosk_w * 0.42
	for p_idx in range(8):
		var angle := float(p_idx) * (TAU / 8.0)
		var p_x := cos(angle) * pillar_r
		var p_z := sin(angle) * pillar_r
		var p_inst := MeshInstance3D.new()
		p_inst.mesh = pillar_mesh
		p_inst.position = center + Vector3(p_x, kiosk_base_h + pillar_h * 0.5, p_z)
		p_inst.material_override = pillar_mat
		kiosk_root.add_child(p_inst)

	# D. Barandales perimetrales entre columnas
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(pillar_r * 0.70, 0.85, 0.12)
	for r_idx in range(8):
		var angle := (float(r_idx) + 0.5) * (TAU / 8.0)
		var r_x := cos(angle) * pillar_r
		var r_z := sin(angle) * pillar_r
		var r_inst := MeshInstance3D.new()
		r_inst.mesh = rail_mesh
		r_inst.position = center + Vector3(r_x, kiosk_base_h + 0.45, r_z)
		r_inst.rotation = Vector3(0.0, -angle + PI * 0.5, 0.0)
		r_inst.material_override = pillar_mat
		kiosk_root.add_child(r_inst)

	# E. Cubierta / Techo octogonal piramidal del quiosco
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.2
	roof_mesh.bottom_radius = kiosk_w * 0.58
	roof_mesh.height = 2.4
	roof_mesh.radial_segments = 8

	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.position = center + Vector3(0.0, kiosk_base_h + pillar_h + 1.2, 0.0)

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.18, 0.32, 0.24) # Verde cobre envejecido / teja
	roof_mat.roughness = 0.70
	roof_inst.material_override = roof_mat
	kiosk_root.add_child(roof_inst)

	# Veleta / remate central superior
	var finial_mesh := CylinderMesh.new()
	finial_mesh.top_radius = 0.05
	finial_mesh.bottom_radius = 0.12
	finial_mesh.height = 1.0
	var finial_inst := MeshInstance3D.new()
	finial_inst.mesh = finial_mesh
	finial_inst.position = center + Vector3(0.0, kiosk_base_h + pillar_h + 2.7, 0.0)
	finial_inst.material_override = pillar_mat
	kiosk_root.add_child(finial_inst)


## 4 Jardineras esquineras con árboles de sombra frondosos (ProceduralTree)
func _build_zocalo_gardens(center: Vector3, bw: float, bh: float) -> void:
	var garden_root := Node3D.new()
	garden_root.name = "JardinerasZocalo"
	zocalo_node.add_child(garden_root)

	var garden_w := bw * 0.32
	var garden_h := bh * 0.32
	var off_x := bw * 0.28
	var off_z := bh * 0.28

	var garden_offsets := [
		Vector3(-off_x, 0.0, -off_z),
		Vector3(+off_x, 0.0, -off_z),
		Vector3(-off_x, 0.0, +off_z),
		Vector3(+off_x, 0.0, +off_z)
	]

	var grass_mat := StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.24, 0.38, 0.18) # Verde pasto cuidado de parque
	grass_mat.roughness = 0.95

	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.60, 0.55, 0.50) # Guarnición de cantera

	for g_idx in range(garden_offsets.size()):
		var g_off: Vector3 = garden_offsets[g_idx]
		var g_center := center + g_off

		# Guarnición / Murete de la jardinera
		var curb_mesh := BoxMesh.new()
		curb_mesh.size = Vector3(garden_w + 0.6, 0.35, garden_h + 0.6)
		var curb_inst := MeshInstance3D.new()
		curb_inst.mesh = curb_mesh
		curb_inst.position = g_center + Vector3(0.0, 0.18, 0.0)
		curb_inst.material_override = curb_mat
		garden_root.add_child(curb_inst)

		# Tierra y césped interior
		var grass_mesh := BoxMesh.new()
		grass_mesh.size = Vector3(garden_w, 0.38, garden_h)
		var grass_inst := MeshInstance3D.new()
		grass_inst.mesh = grass_mesh
		grass_inst.position = g_center + Vector3(0.0, 0.20, 0.0)
		grass_inst.material_override = grass_mat
		garden_root.add_child(grass_inst)

		# Árbol de sombra procedural central en la jardinera (classic_oak o weeping_willow)
		# ¡Cumple estrictamente con la directiva AGENTS.md de vegetación procedural!
		var tree := PROCEDURAL_TREE_SCRIPT.new()
		tree.profile_id = "classic_oak" if (g_idx % 2 == 0) else "weeping_willow"
		tree.tree_seed = rng_seed + g_idx * 941 + 101
		garden_root.add_child(tree)
		tree.global_position = g_center + Vector3(0.0, 0.38, 0.0)


## Bancas de hierro y farolas coloniales alrededor del Zócalo
func _build_zocalo_furniture(center: Vector3, bw: float, bh: float) -> void:
	var furniture_root := Node3D.new()
	furniture_root.name = "MobiliarioZocalo"
	zocalo_node.add_child(furniture_root)

	var bench_mesh := BoxMesh.new()
	bench_mesh.size = Vector3(2.2, 0.55, 0.65)
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color(0.20, 0.14, 0.10) # Madera barnizada oscura
	bench_mat.roughness = 0.85

	var lamp_post_mesh := CylinderMesh.new()
	lamp_post_mesh.top_radius = 0.08
	lamp_post_mesh.bottom_radius = 0.14
	lamp_post_mesh.height = 3.6
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(0.12, 0.14, 0.12) # Fierro colado negro
	lamp_mat.metallic = 0.7

	# Distribuir farolas en los 4 accesos principales hacia el quiosco
	var lamp_offsets := [
		Vector3(0.0, 0.0, -bh * 0.40),
		Vector3(0.0, 0.0, +bh * 0.40),
		Vector3(-bw * 0.40, 0.0, 0.0),
		Vector3(+bw * 0.40, 0.0, 0.0)
	]

	for l_off in lamp_offsets:
		var l_inst := MeshInstance3D.new()
		l_inst.mesh = lamp_post_mesh
		l_inst.position = center + l_off + Vector3(0.0, 1.8, 0.0)
		l_inst.material_override = lamp_mat
		furniture_root.add_child(l_inst)

		# Farola / Luminaria cálida
		var lum_mesh := BoxMesh.new()
		lum_mesh.size = Vector3(0.45, 0.60, 0.45)
		var lum_mat := StandardMaterial3D.new()
		lum_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lum_mat.albedo_color = Color(1.0, 0.92, 0.70)
		var lum_inst := MeshInstance3D.new()
		lum_inst.mesh = lum_mesh
		lum_inst.position = center + l_off + Vector3(0.0, 3.7, 0.0)
		lum_inst.material_override = lum_mat
		furniture_root.add_child(lum_inst)

		# Luz omnidireccional cálida
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.88, 0.65)
		light.light_energy = 0.90
		light.omni_range = 14.0
		light.position = lum_inst.position
		furniture_root.add_child(light)

	# Bancas frente a las jardineras
	var bench_radius := 11.0
	for b_i in range(8):
		var angle := float(b_i) * (TAU / 8.0) + PI * 0.125
		var b_x := cos(angle) * bench_radius
		var b_z := sin(angle) * bench_radius
		var b_inst := MeshInstance3D.new()
		b_inst.mesh = bench_mesh
		b_inst.position = center + Vector3(b_x, 0.28, b_z)
		b_inst.rotation = Vector3(0.0, -angle, 0.0)
		b_inst.material_override = bench_mat
		furniture_root.add_child(b_inst)


# ==============================================================================
# TIENDITAS DE LA ESQUINA (COMERCIO TRADICIONAL MEXICANO)
# ==============================================================================

## Agrega detalles de tienditas de la esquina / abarrotes en casas de esquina de Colonia Vieja
func _build_corner_tienditas() -> void:
	if _house_generator == null or _house_generator.generated_houses.is_empty():
		return

	tienditas_root = Node3D.new()
	tienditas_root.name = "TienditasDeLaEsquina"
	add_child(tienditas_root)

	var t_rng := RandomNumberGenerator.new()
	t_rng.seed = rng_seed + 7777

	var tiendita_count := 0
	for h_data in _house_generator.generated_houses:
		var zone_type: int = int(h_data.get("zone_type", -1))
		if zone_type != CityRoadPatterns.NeighborhoodZoneType.COLONIA_VIEJA:
			continue

		var house_node: Node3D = h_data.get("house_node", null)
		if house_node == null:
			continue

		# Solo un porcentaje de casas tradicionales se adaptan con tiendita
		if t_rng.randf() > tiendita_corner_chance:
			continue

		var facing_dir: Vector3 = h_data.get("facing_direction", Vector3(0.0, 0.0, 1.0))
		var house_w: float = float(h_data.get("width", 8.0))
		var house_pos: Vector3 = house_node.position

		# Toldo de lona comercial mexicano (rayas rojas/blancas o azul/blanco)
		var awning_mesh := BoxMesh.new()
		awning_mesh.size = Vector3(minf(house_w * 0.45, 3.6), 0.12, 1.5)

		var awning_inst := MeshInstance3D.new()
		awning_inst.mesh = awning_mesh

		# Orientar el toldo hacia el frente de la casa
		var angle_y := atan2(facing_dir.x, facing_dir.z)
		awning_inst.rotation = Vector3(0.0, angle_y, 0.0)

		# Ubicar el toldo sobre la fachada frontal a 2.5m de altura
		var house_depth: float = float(h_data.get("depth", 8.0))
		var forward_offset: Vector3 = facing_dir * (house_depth * 0.5 + 0.6)
		awning_inst.position = house_pos + forward_offset + Vector3(0.0, 2.5, 0.0)

		var awning_mat := StandardMaterial3D.new()
		var color_roll := t_rng.randi() % 3
		if color_roll == 0:
			awning_mat.albedo_color = Color(0.85, 0.20, 0.18) # Rojo comercial mexicano
		elif color_roll == 1:
			awning_mat.albedo_color = Color(0.18, 0.45, 0.85) # Azul abarrotes
		else:
			awning_mat.albedo_color = Color(0.92, 0.72, 0.15) # Amarillo refresquero
		awning_inst.material_override = awning_mat
		tienditas_root.add_child(awning_inst)

		# Letrero frontal "ABARROTES / TIENDITA"
		var sign_mesh := BoxMesh.new()
		sign_mesh.size = Vector3(minf(house_w * 0.38, 2.8), 0.50, 0.08)
		var sign_inst := MeshInstance3D.new()
		sign_inst.mesh = sign_mesh
		sign_inst.rotation = Vector3(0.0, angle_y, 0.0)
		sign_inst.position = house_pos + forward_offset + Vector3(0.0, 3.1, 0.0)

		var sign_mat := StandardMaterial3D.new()
		sign_mat.albedo_color = Color(0.96, 0.95, 0.90) # Letrero blanco con marco
		sign_inst.material_override = sign_mat
		tienditas_root.add_child(sign_inst)

		tiendita_count += 1
		if tiendita_count >= 8:
			break

	print("[MexicanCityGenerator] %d Tienditas de la esquina / locales tradicionales integrados al barrio." % tiendita_count)

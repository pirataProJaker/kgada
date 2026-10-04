class_name BedSingleOak
extends Node3D

## Cama Individual de Roble con Ropa de Cama Dinámica (Single Bed Oak - Play Sector X)
## - 4 Estados modulares:
##   * MADE: Tendida con cobija estirada, sábana bajera y almohada.
##   * UNMADE: Destendida con cobija arrugada hacia los pies y almohada ladeada.
##   * STRIPPED: Sin cobija, sábana bajera completamente expuesta.
##   * BARE_MATTRESS: Sin sábana ni cobija, colchón vintage rayado expuesto.
## - Catálogo de 40 estampados de telas extraídos al atlas maestro:
##   * 16 Sábanas bajeras seleccionables (sheet_pattern_id 0 a 15)
##   * 24 Cobijas seleccionables incluyendo el icónico Lobo San Marcos (blanket_pattern_id 0 a 23)
## - Simulación de suciedad (dirt_pct de 0.0 a 1.0) con tinte percudido gradual en la tela.
## - Mecánica de Descanso Reparador: Afecta moral, confort y recuperación de estamina según el estado de la cama.
## - Loop de Lavandería: Desequipar sábanas/cobijas como ítems para lavadora/secadora y reequipar.

const FurniturePropsBuilderScript = preload("res://world/furniture/furniture_props_builder.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

enum BedState {
	MADE = 0,          ## Cama tendida y arreglada
	UNMADE = 1,        ## Cama destendida con cobija arrugada
	STRIPPED = 2,      ## Cama sin cobija (solo sábana bajera)
	BARE_MATTRESS = 3  ## Cama sin sábana ni cobija (colchón desnudo)
}

@export_group("Estado de la Cama")
@export var bed_state: BedState = BedState.MADE:
	set(val):
		bed_state = val
		if is_inside_tree():
			rebuild_bed()

@export var has_pillow: bool = true:
	set(val):
		has_pillow = val
		if is_inside_tree():
			rebuild_bed()

@export_range(0, 15) var sheet_pattern_id: int = 0:
	set(val):
		sheet_pattern_id = clampi(val, 0, 15)
		if is_inside_tree():
			rebuild_bed()

@export_range(0, 23) var blanket_pattern_id: int = 12: # Default: Cobertor Lobo San Marcos
	set(val):
		blanket_pattern_id = clampi(val, 0, 23)
		if is_inside_tree():
			rebuild_bed()

@export_range(0.0, 1.0) var dirt_pct: float = 0.0:
	set(val):
		dirt_pct = clampf(val, 0.0, 1.0)
		if is_inside_tree():
			rebuild_bed()

@export var is_wet: bool = false:
	set(val):
		is_wet = val
		if is_inside_tree():
			rebuild_bed()

@export var enable_collision: bool = true

@export_group("Dimensiones")
@export var width: float = 1.05
@export var depth: float = 2.14
@export var height: float = 1.095

var _frame_instance: MeshInstance3D = null
var _mattress_instance: MeshInstance3D = null
var _quilt_instance: MeshInstance3D = null
var _pillow_instance: MeshInstance3D = null
var _collision_body: StaticBody3D = null


## Retorna la malla compartida base para GPU Instancing
static func get_shared_mesh() -> ArrayMesh:
	return FurniturePropsBuilderScript.get_bed_mesh()


## Retorna la malla combinada exacta para cualquier configuración de estado
static func get_mesh_for_state(state: BedState, sheet_id: int = 0, blanket_id: int = 12, pillow: bool = true, dirt: float = 0.0) -> ArrayMesh:
	return FurniturePropsBuilderScript.get_bed_custom_mesh(state, sheet_id, blanket_id, pillow, dirt)


## Retorna las cajas de colisión para física de la cama
static func get_collision_boxes(w: float = 1.05, d: float = 2.14, h: float = 1.095) -> Array[Dictionary]:
	return [
		{
			"position": Vector3(0.0, 0.25, 0.0),
			"size": Vector3(w, 0.50, d)
		},
		{
			"position": Vector3(0.0, h * 0.5, -d * 0.5 + 0.06),
			"size": Vector3(w, h, 0.12)
		}
	]


func _ready() -> void:
	rebuild_bed()
	_build_collision()


## Reconstruye y actualiza dinámicamente las submallas de la cama
func rebuild_bed() -> void:
	# 1. Armazón de madera de roble
	if _frame_instance == null:
		_frame_instance = MeshInstance3D.new()
		_frame_instance.name = "FrameMesh"
		_frame_instance.mesh = FurniturePropsBuilderScript.get_bed_frame_mesh()
		_frame_instance.material_override = FurniturePropsBuilderScript.get_props_material(0.65, 0.02)
		add_child(_frame_instance)

	# 2. Colchón (sábana bajera o colchón desnudo)
	var is_bare := (bed_state == BedState.BARE_MATTRESS)
	if _mattress_instance == null:
		_mattress_instance = MeshInstance3D.new()
		_mattress_instance.name = "MattressMesh"
		_mattress_instance.material_override = FurniturePropsBuilderScript.get_linens_material(0.75, 0.01)
		add_child(_mattress_instance)
	_mattress_instance.mesh = FurniturePropsBuilderScript.get_bed_mattress_mesh(sheet_pattern_id, is_bare, dirt_pct)

	# 3. Cobija / Edredón
	if bed_state == BedState.MADE or bed_state == BedState.UNMADE:
		if _quilt_instance == null:
			_quilt_instance = MeshInstance3D.new()
			_quilt_instance.name = "QuiltMesh"
			_quilt_instance.material_override = FurniturePropsBuilderScript.get_linens_material(0.75, 0.01)
			add_child(_quilt_instance)
		_quilt_instance.visible = true
		if bed_state == BedState.MADE:
			_quilt_instance.mesh = FurniturePropsBuilderScript.get_bed_quilt_made_mesh(blanket_pattern_id, dirt_pct)
		else:
			_quilt_instance.mesh = FurniturePropsBuilderScript.get_bed_quilt_unmade_mesh(blanket_pattern_id, dirt_pct)
	else:
		if _quilt_instance != null:
			_quilt_instance.visible = false

	# 4. Almohada
	if has_pillow:
		if _pillow_instance == null:
			_pillow_instance = MeshInstance3D.new()
			_pillow_instance.name = "PillowMesh"
			_pillow_instance.material_override = FurniturePropsBuilderScript.get_linens_material(0.75, 0.01)
			add_child(_pillow_instance)
		_pillow_instance.visible = true
		var is_unmade := (bed_state == BedState.UNMADE)
		_pillow_instance.mesh = FurniturePropsBuilderScript.get_bed_pillow_mesh(is_unmade, dirt_pct)
	else:
		if _pillow_instance != null:
			_pillow_instance.visible = false


func _build_collision() -> void:
	if not enable_collision or _collision_body != null:
		return
	_collision_body = StaticBody3D.new()
	_collision_body.name = "BedCollision"
	var boxes := get_collision_boxes(width, depth, height)
	for b in boxes:
		var c_shape := CollisionShape3D.new()
		var b_shape := BoxShape3D.new()
		b_shape.size = b["size"]
		c_shape.shape = b_shape
		c_shape.position = b["position"]
		_collision_body.add_child(c_shape)
	add_child(_collision_body)


# =========================================================================
# MECÁNICAS INTERACTIVAS Y DE JUEGO (DESCANSO REPARADOR & LAVANDERÍA)
# =========================================================================

## Tiende la cama si cuenta con cobija
func make_bed() -> bool:
	if bed_state == BedState.STRIPPED or bed_state == BedState.BARE_MATTRESS:
		return false # No se puede tender una cama sin cobija
	bed_state = BedState.MADE
	return true


## Destiende la cama (simula haberse levantado o desordenar la cama)
func unmake_bed() -> bool:
	if bed_state == BedState.MADE:
		bed_state = BedState.UNMADE
		return true
	return false


## Retira la sábana bajera como ítem de inventario para lavarla o cambiarla
func strip_sheet() -> Dictionary:
	if bed_state == BedState.BARE_MATTRESS:
		return {} # Ya no tiene sábana

	var sheet_item := {
		"id": "bed_sheet",
		"name": FurnitureTextureManagerScript.get_sheet_name(sheet_pattern_id),
		"pattern_id": sheet_pattern_id,
		"dirt_pct": dirt_pct,
		"wetness_pct": 1.0 if is_wet else 0.0
	}
	# Al retirar la sábana, la cama pasa a BARE_MATTRESS
	bed_state = BedState.BARE_MATTRESS
	return sheet_item


## Coloca una sábana del inventario en la cama
func equip_sheet(item: Dictionary) -> bool:
	if item.is_empty() or item.get("id", "") != "bed_sheet":
		return false

	sheet_pattern_id = item.get("pattern_id", 0)
	dirt_pct = item.get("dirt_pct", 0.0)
	is_wet = item.get("wetness_pct", 0.0) > 0.15

	# Si la cama estaba desnuda, ahora tiene sábana bajera
	if bed_state == BedState.BARE_MATTRESS:
		bed_state = BedState.STRIPPED
	rebuild_bed()
	return true


## Retira la cobija como ítem de inventario para lavarla o cambiarla
func strip_blanket() -> Dictionary:
	if bed_state == BedState.STRIPPED or bed_state == BedState.BARE_MATTRESS:
		return {} # No tiene cobija colocada

	var blanket_item := {
		"id": "bed_blanket",
		"name": FurnitureTextureManagerScript.get_blanket_name(blanket_pattern_id),
		"pattern_id": blanket_pattern_id,
		"dirt_pct": dirt_pct,
		"wetness_pct": 1.0 if is_wet else 0.0
	}
	# Al retirar la cobija, la cama pasa a STRIPPED
	bed_state = BedState.STRIPPED
	return blanket_item


## Coloca una cobija del inventario en la cama
func equip_blanket(item: Dictionary) -> bool:
	if item.is_empty() or item.get("id", "") != "bed_blanket":
		return false

	blanket_pattern_id = item.get("pattern_id", 12)
	dirt_pct = maxf(dirt_pct, item.get("dirt_pct", 0.0))
	is_wet = is_wet or (item.get("wetness_pct", 0.0) > 0.15)

	# Se coloca la cobija tendida
	if bed_state != BedState.BARE_MATTRESS:
		bed_state = BedState.MADE
	else:
		bed_state = BedState.MADE # Cobija colocada directamente
	rebuild_bed()
	return true


## Retira la almohada como ítem de inventario
func strip_pillow() -> Dictionary:
	if not has_pillow:
		return {}
	has_pillow = false
	return {
		"id": "bed_pillow",
		"name": "Almohada Blanca Suave",
		"dirt_pct": dirt_pct,
		"wetness_pct": 1.0 if is_wet else 0.0
	}


## Coloca una almohada en la cama
func equip_pillow(item: Dictionary) -> bool:
	if item.is_empty() or item.get("id", "") != "bed_pillow":
		return false
	has_pillow = true
	dirt_pct = maxf(dirt_pct, item.get("dirt_pct", 0.0))
	rebuild_bed()
	return true


## Aplica suciedad con el tiempo o uso
func apply_dirt(amount: float) -> void:
	dirt_pct = clampf(dirt_pct + amount, 0.0, 1.0)


## Evalúa la Calidad del Descanso Reparador que ofrece esta cama al jugador
## Retorna un diccionario con multiplicadores de estamina, moral y estado anímico
func get_rest_quality() -> Dictionary:
	var quality: float = 100.0
	var status_tags: Array[String] = []

	# 1. Penalización por sábana
	if bed_state == BedState.BARE_MATTRESS:
		quality -= 40.0
		status_tags.append("Colchón áspero y desnudo (-40%)")

	# 2. Penalización por cobija
	if bed_state == BedState.STRIPPED or bed_state == BedState.BARE_MATTRESS:
		quality -= 25.0
		status_tags.append("Frío nocturno sin cobija (-25%)")
	elif bed_state == BedState.UNMADE:
		quality -= 10.0
		status_tags.append("Cama desordenada (-10%)")

	# 3. Penalización por almohada
	if not has_pillow:
		quality -= 20.0
		status_tags.append("Sin almohada / dolor de cuello (-20%)")

	# 4. Penalización por humedad
	if is_wet:
		quality -= 35.0
		status_tags.append("Ropa de cama húmeda / incómoda (-35%)")

	# 5. Penalización por suciedad acumulada
	var dirt_penalty := dirt_pct * 30.0
	quality -= dirt_penalty
	if dirt_pct > 0.40:
		status_tags.append("Cama percudida/sucia (-%.0f%%)" % dirt_penalty)

	quality = clampf(quality, 5.0, 100.0)

	var rating := "Pésimo / Insomnio"
	var stamina_mult := 0.50
	var morale_buff := -5

	if quality >= 90.0:
		rating = "Descanso Reparador Óptimo"
		stamina_mult = 1.30
		morale_buff = 15
		status_tags.append("¡Bien descansado! (+15 Moral, +30% Estamina)")
	elif quality >= 70.0:
		rating = "Buen Descanso"
		stamina_mult = 1.10
		morale_buff = 5
	elif quality >= 45.0:
		rating = "Descanso Regular / Incómodo"
		stamina_mult = 0.85
		morale_buff = 0

	return {
		"quality_score": quality,
		"rating": rating,
		"stamina_multiplier": stamina_mult,
		"morale_buff": morale_buff,
		"status_tags": status_tags,
		"is_optimal": quality >= 90.0
	}

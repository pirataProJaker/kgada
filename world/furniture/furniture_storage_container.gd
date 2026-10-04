class_name FurnitureStorageContainer
extends RefCounted

## Sistema Centralizado de Almacenamiento Inteligente para Mobiliario (Play Sector X)
## Arquitectura desacoplada y orientada a datos (Data-Driven):
## 1. Muebles Cerrados: NO renderizan objetos (0 vértices, 0 draw calls). Los ítems viven solo en RAM como diccionarios.
## 2. Consumibles con Estado: La leche, cereal, sopa, etc. registran porcentaje de contenido (fill_pct), frescura y propiedades libres.
## 3. Modo Polimórfico:
##    - SLOTS_3D: Ranuras espaciales fijas (Refrigerador, Alacena, Librero, Mesas).
##    - DRAWER_SLIDING: Cajones interactivos que se deslizan en Z y revelan su contenido.
##    - ABSTRACT_METRIC: Lavadoras, secadoras, tanques y botes que solo gestionan porcentajes de carga y ciclos sin renderizar ropa.

enum StorageMode {
	SLOTS_3D = 0,         ## Repisas / ranuras visuales fijas (abierto = visible, cerrado = oculto)
	DRAWER_SLIDING = 1,   ## Cajón deslizante en Z
	ABSTRACT_METRIC = 2   ## Solo porcentaje de capacidad y estados de proceso (lavadora, secadora, basura)
}

signal storage_changed()
signal container_opened()
signal container_closed()
signal cycle_completed(cycle_name: String)

var mode: StorageMode = StorageMode.SLOTS_3D
var max_slots: int = 8
var max_capacity_units: float = 10.0 # Litros, kilos, o prendas según el mueble
var is_open: bool = false
var open_ratio: float = 0.0:
	set(val):
		open_ratio = clampf(val, 0.0, 1.0)

# Inventario en memoria RAM (clave: slot_index -> diccionario de ítem)
var _slots: Dictionary = {}

# Estados de proceso para lavadora / secadora
var is_processing: bool = false
var process_progress: float = 0.0 # 0.0 a 1.0
var active_cycle: String = "idle"


func _init(p_mode: StorageMode = StorageMode.SLOTS_3D, p_max_slots: int = 8, p_max_capacity: float = 10.0) -> void:
	mode = p_mode
	max_slots = p_max_slots
	max_capacity_units = p_max_capacity


# =========================================================================
# GESTIÓN DE ÍTEMS Y CONSUMIBLES
# =========================================================================

## Agrega un ítem al contenedor. Si no se especifica slot, busca la primera ranura libre.
func add_item(item_data: Dictionary, target_slot: int = -1) -> bool:
	if mode == StorageMode.ABSTRACT_METRIC:
		# En lavadora o secadora, se agrega por peso/volumen sin requerir ranura fija
		var slot_idx := _slots.size()
		if slot_idx >= max_slots:
			return false
		_slots[slot_idx] = item_data.duplicate(true)
		storage_changed.emit()
		return true

	var slot_to_use := target_slot
	if slot_to_use < 0:
		slot_to_use = get_first_empty_slot()

	if slot_to_use < 0 or slot_to_use >= max_slots or _slots.has(slot_to_use):
		return false

	var stored := item_data.duplicate(true)
	stored["slot"] = slot_to_use

	# Valores por defecto para consumibles
	if not stored.has("fill_pct"):
		stored["fill_pct"] = 1.0 # 100% lleno por defecto
	if not stored.has("freshness_pct"):
		stored["freshness_pct"] = 1.0 # 100% fresco por defecto

	_slots[slot_to_use] = stored
	storage_changed.emit()
	return true


## Remueve y retorna el ítem de una ranura específica
func remove_item_at_slot(slot: int) -> Dictionary:
	if _slots.has(slot):
		var item: Dictionary = _slots[slot]
		_slots.erase(slot)
		storage_changed.emit()
		return item
	return {}


## Obtiene los datos del ítem en una ranura sin removerlo
func get_item_at_slot(slot: int) -> Dictionary:
	return _slots.get(slot, {})


## Consume una porción de un consumible (e.g. tomar 250ml de leche de 1 litro = amount_pct = 0.25)
func consume_item(slot: int, amount_pct: float) -> float:
	if not _slots.has(slot):
		return 0.0

	var item: Dictionary = _slots[slot]
	var current_fill: float = float(item.get("fill_pct", 1.0))
	var consumed := minf(current_fill, amount_pct)
	item["fill_pct"] = maxf(0.0, current_fill - consumed)

	# Si se vació por completo, se conserva el envase vacío a menos que se configure auto-remover
	storage_changed.emit()
	return consumed


## Retorna la primera ranura libre
func get_first_empty_slot() -> int:
	for i in range(max_slots):
		if not _slots.has(i):
			return i
	return -1


## Retorna la cantidad de ítems actualmente almacenados
func get_item_count() -> int:
	return _slots.size()


## Retorna todos los ítems como un diccionario de ranuras
func get_all_items() -> Dictionary:
	return _slots


# =========================================================================
# MÉTRICAS Y PORCENTAJES (LAVADORA, SECADORA, BASURA, CAPACIDAD)
# =========================================================================

## Retorna qué tan lleno está el contenedor (0.0 = vacío, 1.0 = 100% lleno)
func get_fill_percentage() -> float:
	if max_slots <= 0:
		return 0.0
	return float(_slots.size()) / float(max_slots)


## Retorna un resumen en texto para HUD o interacción del jugador
func get_status_summary() -> String:
	if mode == StorageMode.ABSTRACT_METRIC:
		var fill_p := int(round(get_fill_percentage() * 100.0))
		var status_str := "Inactivo"
		if is_processing:
			status_str = "%s (%d%%)" % [active_cycle.capitalize(), int(round(process_progress * 100.0))]
		return "Carga: %d/%d (%d%%) | Estado: %s" % [_slots.size(), max_slots, fill_p, status_str]
	else:
		return "Contenedor: %d/%d ranuras ocupadas (%s)" % [
			_slots.size(),
			max_slots,
			"Abierto" if is_open else "Cerrado"
		]


# =========================================================================
# LÓGICA DE PROCESO (LAVADORA Y SECADORA)
# =========================================================================

## Ejecuta un ciclo de lavado o secado transformando las propiedades de la ropa
func run_laundry_cycle(cycle_type: String) -> void:
	active_cycle = cycle_type
	is_processing = true
	process_progress = 0.0

	if cycle_type == "wash":
		# Lavado: la ropa queda 100% limpia y 100% mojada
		for k in _slots:
			var item: Dictionary = _slots[k]
			item["dirt_pct"] = 0.0
			item["wetness_pct"] = 1.0
			item["is_clean"] = true
	elif cycle_type == "dry":
		# Secado: la ropa mojada queda seca
		for k in _slots:
			var item: Dictionary = _slots[k]
			item["wetness_pct"] = 0.0
			item["is_dry"] = true

	is_processing = false
	process_progress = 1.0
	cycle_completed.emit(cycle_type)
	storage_changed.emit()


# =========================================================================
# CONTROL DE APERTURA / CIERRE (LAZY EVALUATION PARA GPU)
# =========================================================================

## Abre o cierra el contenedor
func set_open_state(open: bool) -> void:
	if is_open == open:
		return
	is_open = open
	open_ratio = 1.0 if open else 0.0
	if is_open:
		container_opened.emit()
	else:
		container_closed.emit()


## Alterna apertura
func toggle_open() -> void:
	set_open_state(not is_open)


## Debe renderizar contenido? Solo si está abierto o si es un mueble de repisa abierta
func should_render_contents() -> bool:
	if mode == StorageMode.ABSTRACT_METRIC:
		return false # Lavadoras y secadoras NUNCA renderizan ropa
	return is_open or open_ratio > 0.05


# =========================================================================
# FÁBRICA DE CONSUMIBLES CON PORCENTAJE DE ESTADO (DATA-DRIVEN)
# =========================================================================

## Crea un diccionario genérico para un objeto consumible con estado y porcentajes
static func create_consumable(id: String, name: String, fill_pct: float = 1.0, freshness_pct: float = 1.0, extra: Dictionary = {}) -> Dictionary:
	var item := {
		"id": id,
		"name": name,
		"fill_pct": clampf(fill_pct, 0.0, 1.0),
		"freshness_pct": clampf(freshness_pct, 0.0, 1.0),
		"is_consumable": true
	}
	for k in extra:
		item[k] = extra[k]
	return item


## Cartón de Leche (1 Litro por defecto, con seguimiento de porcentaje de llenado y frescura)
static func create_milk(fill_pct: float = 1.0, freshness_pct: float = 1.0) -> Dictionary:
	return create_consumable("milk", "Cartón de Leche", fill_pct, freshness_pct, {
		"capacity_liters": 1.0,
		"unit": "L",
		"icon_key": "milk"
	})


## Caja de Cereal (Corn Flakes con porcentaje de llenado)
static func create_cereal(fill_pct: float = 1.0, freshness_pct: float = 1.0) -> Dictionary:
	return create_consumable("cereal", "Caja de Cereal Corn Flakes", fill_pct, freshness_pct, {
		"capacity_grams": 500.0,
		"unit": "g",
		"icon_key": "cereal_corn"
	})


## Lata de Sopa de Tomate
static func create_soup(fill_pct: float = 1.0, freshness_pct: float = 1.0) -> Dictionary:
	return create_consumable("soup", "Lata de Sopa", fill_pct, freshness_pct, {
		"capacity_grams": 350.0,
		"unit": "g",
		"icon_key": "can_soup"
	})


## Lata de Cerveza Lager
static func create_beer(fill_pct: float = 1.0) -> Dictionary:
	return create_consumable("beer", "Cerveza Lager", fill_pct, 1.0, {
		"capacity_ml": 355.0,
		"unit": "ml",
		"alcohol_pct": 5.0,
		"icon_key": "beer_can"
	})


## Taza con Café o Bebida
static func create_mug(fill_pct: float = 1.0, beverage: String = "café caliente") -> Dictionary:
	return create_consumable("mug", "Taza de " + beverage, fill_pct, 1.0, {
		"beverage": beverage,
		"temperature_c": 65.0 if fill_pct > 0.0 else 20.0,
		"icon_key": "mug"
	})


## Libro modular para libreros y mesas
static func create_book(book_type: String = "bible", custom_title: String = "") -> Dictionary:
	var def_title := "Libro"
	match book_type:
		"bible": def_title = "Santa Biblia"
		"atlas": def_title = "Atlas Mundial Ilustrado"
		"recipes": def_title = "Recetario de Cocina Clásica"
		"novel": def_title = "Novela de Ficción"
	var t := custom_title if not custom_title.is_empty() else def_title
	return {
		"id": "book_" + book_type,
		"book_type": book_type,
		"name": t,
		"read_pct": 0.0,
		"is_consumable": false
	}


## Periódico doblado
static func create_newspaper(headline: String = "Daily News") -> Dictionary:
	return {
		"id": "newspaper",
		"name": "Periódico - " + headline,
		"headline": headline,
		"is_consumable": false
	}


## Obtiene el porcentaje de llenado (0.0 a 1.0) del consumible en una ranura
func get_item_fill_pct(slot: int) -> float:
	if _slots.has(slot):
		return float(_slots[slot].get("fill_pct", 1.0))
	return 0.0


## Obtiene el porcentaje de frescura (0.0 a 1.0) del consumible en una ranura
func get_item_freshness_pct(slot: int) -> float:
	if _slots.has(slot):
		return float(_slots[slot].get("freshness_pct", 1.0))
	return 0.0


## Genera una etiqueta descriptiva con porcentaje para la interfaz de usuario / HUD
func get_item_label(slot: int) -> String:
	if not _slots.has(slot):
		return "Vacío"
	var item: Dictionary = _slots[slot]
	var iname: String = item.get("name", "Ítem")
	if item.get("is_consumable", false):
		var pct := int(round(float(item.get("fill_pct", 1.0)) * 100.0))
		var fresh := int(round(float(item.get("freshness_pct", 1.0)) * 100.0))
		return "%s (%d%% lleno, %d%% fresco)" % [iname, pct, fresh]
	return iname


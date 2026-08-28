extends RefCounted
class_name DrainagePieceCatalog
## Traduce el bitmask de aberturas que pide una celda del layout (ver
## DrainageLayoutGenerator) a la pieza real que hay que instanciar + la
## rotacion en Y necesaria para que calce con sus vecinas.
##
## La configuracion de que pieza usar y hacia donde abre originalmente ya
## NO esta hardcodeada aca: se recibe como un Dictionary<String,
## DrainagePieceConfig> (uno por forma: dead_end, straight, corner,
## t_junction, cross), editable desde el Inspector en los recursos .tres
## bajo world/drainage/piece_configs/ o en las propiedades @export de
## DrainageDungeonGenerator - asi el usuario puede ajustar la orientacion
## "original" de cada pieza (con checkboxes Norte/Este/Sur/Oeste) sin
## tocar codigo.

const PIECE_SOURCE_PATH := "res://assets/drenaje/Models/Sewers.fbx"

var _shape_configs: Dictionary # String (shape_key) -> DrainagePieceConfig


## `shape_configs` debe traer las 5 claves: "dead_end", "straight",
## "corner", "t_junction", "cross".
func _init(shape_configs: Dictionary) -> void:
	_shape_configs = shape_configs


## Devuelve {"node": <nombre del nodo>, "rotation_degrees": <float>} con la
## pieza y la rotacion en Y necesarias para que calce.
func resolve(bitmask: int) -> Dictionary:
	var bit_count := 0
	for i in range(4):
		if bitmask & (1 << i):
			bit_count += 1

	var shape_key: String
	match bit_count:
		1:
			shape_key = "dead_end"
		2:
			shape_key = "straight" if _is_opposite_pair(bitmask) else "corner"
		3:
			shape_key = "t_junction"
		4:
			shape_key = "cross"
		_:
			shape_key = "dead_end" # bitmask 0 no deberia pasar (celda sin conexiones)

	var config: DrainagePieceConfig = _shape_configs.get(shape_key)
	if config == null:
		push_warning("DrainagePieceCatalog: falta configurar la pieza '%s' (asignar un DrainagePieceConfig en el Inspector)" % shape_key)
		return {"node": "", "rotation_degrees": 0.0, "canonical_openings": 0, "config": null}

	var rotation_steps := _find_rotation_steps(config.canonical_openings, bitmask)
	return {
		"node": config.node_name,
		"rotation_degrees": rotation_steps * 90.0 * config.rotation_direction,
		# Bitmask SIN rotar (Norte/Este/Sur/Oeste tal como esta seteado en
		# el .tres) - DrainageDungeonGenerator lo necesita para calcular el
		# pivote real de piezas asimetricas (esquina, T) antes de rotarlas.
		"canonical_openings": config.canonical_openings,
		# El config completo - DrainageDungeonGenerator lo necesita para
		# leer/actualizar la caja de depuracion (box_min/box_max).
		"config": config,
	}


static func _is_opposite_pair(bitmask: int) -> bool:
	return bitmask == 0b0101 or bitmask == 0b1010


static func _find_rotation_steps(canonical_mask: int, target_mask: int) -> int:
	for steps in range(4):
		if _rotate_mask(canonical_mask, steps) == target_mask:
			return steps
	push_warning("DrainagePieceCatalog: no se encontro rotacion para mask %d desde %d" % [target_mask, canonical_mask])
	return 0


## Rota el bitmask `steps` pasos de 90 grados (sentido N->E->S->W->N).
static func _rotate_mask(mask: int, steps: int) -> int:
	var rotated := 0
	for i in range(4):
		if mask & (1 << i):
			rotated |= 1 << ((i + steps) % 4)
	return rotated

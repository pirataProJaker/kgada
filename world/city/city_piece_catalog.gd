extends RefCounted
class_name CityPieceCatalog
## Traduce el bitmask de aberturas que necesita una interseccion de la
## grilla de calles a la pieza real (CityPieceConfig) + rotacion en Y
## necesaria para que calce - misma logica exacta que DrainagePieceCatalog
## (bit_count 2 opuestos = recta, 2 adyacentes = esquina, 3 = T, 4 = cruz),
## solo que aca las 4 formas son piezas sueltas del pack URBAN en vez de
## nodos de un unico modelo compartido.

var _shape_configs: Dictionary # String (shape_key) -> CityPieceConfig


## `shape_configs` debe traer las 4 claves: "straight", "corner",
## "t_junction", "cross".
func _init(shape_configs: Dictionary) -> void:
	_shape_configs = shape_configs


## Devuelve {"config": CityPieceConfig, "rotation_degrees": float,
## "canonical_openings": int} con la pieza y rotacion que calzan con
## `bitmask`.
func resolve(bitmask: int) -> Dictionary:
	var bit_count := 0
	for i in range(4):
		if bitmask & (1 << i):
			bit_count += 1

	var shape_key: String
	match bit_count:
		2:
			shape_key = "straight" if _is_opposite_pair(bitmask) else "corner"
		3:
			shape_key = "t_junction"
		4:
			shape_key = "cross"
		_:
			shape_key = "cross" # no deberia pasar en una grilla de calles real

	var config: CityPieceConfig = _shape_configs.get(shape_key)
	if config == null:
		push_warning("CityPieceCatalog: falta configurar la pieza '%s' (asignar un CityPieceConfig en el Inspector)" % shape_key)
		return {"config": null, "rotation_degrees": 0.0, "canonical_openings": 0}

	var rotation_steps := _find_rotation_steps(config.canonical_openings, bitmask)
	return {
		"config": config,
		"shape": shape_key,
		"rotation_degrees": rotation_steps * 90.0 * config.rotation_direction,
		"canonical_openings": config.canonical_openings,
	}


static func _is_opposite_pair(bitmask: int) -> bool:
	return bitmask == 0b0101 or bitmask == 0b1010


static func _find_rotation_steps(canonical_mask: int, target_mask: int) -> int:
	for steps in range(4):
		if _rotate_mask(canonical_mask, steps) == target_mask:
			return steps
	push_warning("CityPieceCatalog: no se encontro rotacion para mask %d desde %d" % [target_mask, canonical_mask])
	return 0


## Rota el bitmask `steps` pasos de 90 grados.
##
## OJO: el sentido tiene que coincidir con como Godot rota de verdad un
## Node3D en +90 grados sobre Y con rotation_direction=1.0 (physicamente
## N -> O -> S -> E -> N, sentido antihorario visto desde arriba, porque
## en este proyecto Norte=-Z, Este=+X - ver DIR_OFFSETS en
## city_rotation_calibration.gd). Antes esto rotaba "hacia adelante"
## (N->E->S->O->N, sentido horario) - funcionaba SOLO en steps pares
## (0/180, donde ambos sentidos dan el mismo resultado, 180=-180) pero
## quedaba invertido en steps impares (90/270) - confirmado visualmente:
## una T con canonical_openings=7 (N,E,S abiertos, O cerrado) rotada 90
## grados de verdad muestra N,E,O abiertos/S cerrado (mask 11), pero la
## formula vieja calculaba E,S,O abiertos/N cerrado (mask 14) - justo lo
## que reporto el usuario via tests/city_rotation_calibration.tscn.
static func _rotate_mask(mask: int, steps: int) -> int:
	var rotated := 0
	for i in range(4):
		if mask & (1 << i):
			rotated |= 1 << (((i - steps) % 4 + 4) % 4)
	return rotated

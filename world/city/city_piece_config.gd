extends Resource
class_name CityPieceConfig
## Configuracion editable (Inspector) de UNA pieza de calle (pack URBAN).
##
## A diferencia de DrainagePieceConfig (que apunta a un nodo con nombre
## dentro de un unico .fbx compartido, Sewers.fbx), cada pieza de URBAN es
## su propio archivo .fbx suelto (road_1_straight.fbx, road_1_corner.fbx,
## etc) - por eso aca se guarda directamente el PackedScene de la pieza en
## vez de un node_name + fuente compartida.
##
## `canonical_openings`: hacia donde abre esa pieza TAL CUAL viene en el
## archivo original, SIN rotarla (0 grados) - si al probar en la escena de
## test se ve rotada/espejada, ajustar estas casillas o `rotation_direction`
## desde el Inspector, sin tocar codigo (mismo criterio que
## DrainagePieceConfig).

@export var model_scene: PackedScene
@export_flags("Norte", "Este", "Sur", "Oeste") var canonical_openings: int = 0
## 1.0 o -1.0 - cambiar SOLO si esta pieza especifica queda rotada en
## espejo respecto de lo que pide el layout.
@export var rotation_direction: float = 1.0

@export_group("Caja de la celda (para ver y ajustar el tamaño real)")
## Si esta activo, la caja se recalcula sola cada vez que corre la escena,
## ajustada al tamaño real de la pieza. Desactivar para fijar box_min/
## box_max a mano.
@export var use_auto_box: bool = true
@export var box_min: Vector3 = Vector3.ZERO
@export var box_max: Vector3 = Vector3.ZERO

extends Resource
class_name DrainagePieceConfig
## Configuracion editable (Inspector) de UNA pieza del pack de drenaje.
##
## `node_name`: nombre exacto del nodo dentro de Sewers.fbx (ej. "Serwers01_005").
## `canonical_openings`: hacia donde abre esa pieza TAL CUAL viene en el
## archivo original, SIN rotarla (0 grados) - marcar las casillas que
## correspondan mirando la pieza en tests/drenaje_pieces_test.tscn. El
## generador (DrainageDungeonGenerator) usa esto para calcular solo cuantos
## pasos de 90 grados hay que rotarla para que calce con sus vecinas; no
## hay que tocar codigo, solo estos checkboxes.

@export var node_name: String = ""
@export_flags("Norte", "Este", "Sur", "Oeste") var canonical_openings: int = 0
## 1.0 o -1.0 - cambiar SOLO si esta pieza especifica queda rotada en
## espejo respecto de lo que pide el layout (por ejemplo, una esquina que
## deberia abrir hacia la derecha pero abre hacia la izquierda). Cada forma
## puede necesitar un signo distinto porque el modelo original (dentro del
## FBX) de cada una se exporto con su propia orientacion/manija - no hay
## una unica convencion global que sirva para todas.
@export var rotation_direction: float = 1.0

@export_group("Caja de la celda (para ver y ajustar el tamaño real)")
## Si esta activo, la caja se recalcula sola cada vez que se corre la
## escena, ajustada al tamaño real de la pieza tal como queda parada en su
## socket (mirar la consola / este mismo recurso mientras corre el juego
## para ver los numeros calculados). Desactivarlo para fijar box_min /
## box_max a mano vos mismo - una vez desactivado tus valores no se tocan
## mas.
@export var use_auto_box: bool = true
## Esquina minima de la caja (metros), en el espacio LOCAL del socket de la
## celda - (0,0,0) es el punto exacto donde la pieza se conecta con sus
## vecinas. Editar X/Y/Z para achicar la caja hacia ese lado.
@export var box_min: Vector3 = Vector3.ZERO
## Esquina maxima de la caja (metros), mismo espacio que box_min. Editar
## X/Y/Z para agrandar la caja hacia ese lado (por ejemplo subir Y para que
## la caja sea mas alta).
@export var box_max: Vector3 = Vector3.ZERO

extends TextureButton
class_name ButtonAnim
## Animaciones de boton estilo Minecraft: al pasar el mouse se agranda
## ligeramente (hover), y al hacer click se "hunde" (se desplaza hacia abajo
## y se encoge) para dar feedback tactil. Al soltar vuelve a su tamaño.
##
## Se aplica a cualquier TextureButton (agregar este script al nodo). Usa
## Tween para animaciones suaves.

# Escala al pasar el mouse (hover)
@export var hover_scale := 1.05
# Escala al presionar (click) - menor que 1 = se hunde
@export var pressed_scale := 0.95
# Desplazamiento vertical al presionar (px) - positivo = se hunde
@export var pressed_offset_y := 4.0
# Duracion de las animaciones (segundos)
@export var anim_duration := 0.12

var _base_scale := Vector2.ONE
var _base_position := Vector2.ZERO
var _tween: Tween = null


func _ready() -> void:
	_base_scale = scale
	_base_position = position
	mouse_entered.connect(_on_hover_start)
	mouse_exited.connect(_on_hover_end)
	button_down.connect(_on_press)
	button_up.connect(_on_release)


## Al pasar el mouse: agrandar suavemente.
func _on_hover_start() -> void:
	_animate_scale(hover_scale)


## Al salir el mouse: volver al tamaño base.
func _on_hover_end() -> void:
	_animate_scale(_base_scale.x)


## Al presionar: hundir el boton (encoger + bajar).
func _on_press() -> void:
	_animate_scale(pressed_scale)
	_animate_position(_base_position + Vector2(0, pressed_offset_y))


## Al soltar: volver al tamaño base y posicion.
func _on_release() -> void:
	_animate_scale(_base_scale.x)
	_animate_position(_base_position)


## Anima la escala del boton con un Tween suave.
func _animate_scale(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE * target, anim_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Anima la posicion del boton con un Tween suave.
func _animate_position(target: Vector2) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", target, anim_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

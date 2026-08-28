extends StaticBody3D
class_name ChoppableTree
## Colision "talable" de un arbol: chunk_manager.gd la agrega como el
## StaticBody3D de colision de cada arbol (ver _add_vegetation_collision),
## asi que golpearlo con el raycast de MeleeController llama directo a
## take_damage() aqui (el StaticBody3D es lo que el raycast realmente
## golpea). Acumula golpes hasta que su vida llega a 0, momento en el que el
## arbol completo (su padre) cae con una animacion simple y se elimina.

@export var max_health: float = 30.0

var _health: float
var _felled := false


func _ready() -> void:
	_health = max_health


func take_damage(amount: float) -> void:
	if _felled:
		return
	_health -= amount
	if _health <= 0.0:
		_fell_tree()


func _fell_tree() -> void:
	_felled = true

	# Se desactiva la colision de inmediato para que el jugador ya pueda
	# caminar sobre donde estaba el arbol mientras termina de caer.
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	var tree := get_parent()
	if tree == null or not (tree is Node3D):
		queue_free()
		return

	# Tumba el arbol rotandolo sobre su propia base (el pivote del modelo
	# esta en el suelo, ver chunk_manager._try_place_vegetation) en vez de
	# solo hacerlo desaparecer - se ve como que realmente lo talaron. Se
	# anima con un tween (no instantaneo) para que se vea como una caida,
	# y despues de un momento en el suelo se elimina del todo.
	var fall_angle := randf_range(-1.0, 1.0) * deg_to_rad(88.0)
	var tween := tree.create_tween()
	tween.tween_property(tree, "rotation:x", fall_angle, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_interval(1.0)
	tween.tween_callback(tree.queue_free)

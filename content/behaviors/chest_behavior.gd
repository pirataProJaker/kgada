extends StaticBody3D
class_name ChestBehavior
## Logica real del tipo de comportamiento "Cofre". Toma una ChestConfig (los
## valores que cualquiera configuro sin programar) y se arma solo: carga el
## modelo, crea el inventario del tamaño correcto, y guarda la durabilidad.
##
## Este archivo es el "codigo" que programamos UNA sola vez para que el tipo
## Cofre exista. Agregar un cofre nuevo en el futuro (mas adelante, desde el
## editor de contenido) NO deberia requerir tocar este archivo - solo crear
## otra ChestConfig con otros valores/modelo.

@export var config: ChestConfig

var inventory: Array = []
var current_durability: int = 0
var is_open: bool = false


func _ready() -> void:
	if config == null:
		push_warning("[ChestBehavior] No se asigno una ChestConfig - este cofre no hace nada.")
		return

	inventory.resize(config.slots)
	current_durability = config.durability
	_load_model()
	_setup_collision()


func _setup_collision() -> void:
	# Caja de colision generica - el editor real podria dejar ajustar esto
	# por objeto mas adelante; por ahora sirve para poder interactuar/pisar
	# el cofre sin que el jugador lo atraviese.
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	add_child(collision)


func _load_model() -> void:
	# ContentLoader sabe cargar tanto modelos dentro del proyecto (res://) como
	# archivos GLB externos importados desde el editor de contenido, y ya
	# aplica el model_scale configurado (para modelos que vienen enormes o
	# diminutos segun la unidad con la que fueron modelados).
	var instance := ContentLoader.load_model_for_definition(config)
	if instance == null:
		if not config.model_path.is_empty():
			push_warning(
				"[ChestBehavior] '%s' no pudo cargar su modelo (model_path='%s') - se usa una caja de referencia." % [config.id, config.model_path]
			)
		var placeholder := MeshInstance3D.new()
		placeholder.mesh = BoxMesh.new()
		placeholder.scale = Vector3.ONE * config.model_scale
		add_child(placeholder)
		return

	add_child(instance)


## Punto de interaccion (ej. desde el jugador via raycast + input de "usar").
func toggle_open() -> void:
	is_open = not is_open
	# TODO: reproducir animacion de abrir/cerrar cuando definamos el pipeline
	# de animaciones custom (misma idea que la "puerta" del diseño original).


## Convencion generica usada por InteractController (tecla E): cualquier
## cosa "interactuable" del mundo expone `interact(interactor)`.
func interact(_interactor: Node) -> void:
	toggle_open()


func take_damage(amount: int) -> void:
	current_durability = max(current_durability - amount, 0)
	if current_durability == 0:
		queue_free() # TODO: efecto/sonido de romperse en vez de solo desaparecer

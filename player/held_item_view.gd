extends Node3D
class_name HeldItemView
## "Viewmodel" simple: como todavia no tenemos modelo de manos, muestra
## directamente el modelo del objeto seleccionado en el hotbar flotando en
## una esquina de la camara, como si el jugador lo tuviera en la mano.
## Se actualiza solo cuando cambia el slot seleccionado o su contenido.

const HELD_OFFSET := Vector3(0.35, -0.3, -0.6)
const HELD_SCALE := 0.4

var _current_model: Node3D = null
var _current_definition: ObjectDefinition = null
var _inventory: Inventory = null


func _ready() -> void:
	# owner es el Player raiz de la escena (este nodo vive anidado bajo
	# Head/Camera3D dentro de player.tscn).
	if not owner.is_multiplayer_authority():
		set_process(false)
		visible = false
		return
	_inventory = owner.get_node("Inventory")


func _process(_delta: float) -> void:
	var definition := _inventory.get_selected_definition()
	if definition != _current_definition:
		_rebuild(definition)


func _rebuild(definition: ObjectDefinition) -> void:
	if _current_model != null:
		_current_model.queue_free()
		_current_model = null
	_current_definition = definition
	if definition == null:
		return

	var model := ContentLoader.load_model_for_definition(definition)
	if model == null:
		model = MeshInstance3D.new()
		model.mesh = BoxMesh.new()
		model.scale = Vector3.ONE * definition.model_scale

	model.position = HELD_OFFSET
	model.scale *= HELD_SCALE
	add_child(model)
	_current_model = model

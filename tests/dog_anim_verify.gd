extends SceneTree
## Verifica que dog.gd encuentra el AnimationPlayer del modelo y puede
## reproducir la animacion de correr. Se ejecuta con:
##   godot --headless --path . -s tests/dog_anim_verify.gd

func _initialize() -> void:
	var holder := Node3D.new()
	holder.name = "Holder"
	root.add_child(holder)

	var dog_scene: PackedScene = load("res://world/mobs/dog.tscn")
	if dog_scene == null:
		print("[verify] FALLO: no se pudo cargar dog.tscn")
		quit(1)
		return
	var dog: Node = dog_scene.instantiate()
	holder.add_child(dog)

	# Esperar un frame para que _ready() corra y build_model() agregue el modelo
	await process_frame
	await process_frame

	# Buscar el AnimationPlayer dentro del modelo
	var model := dog.get_node_or_null("Model")
	print("[verify] Model encontrado: %s" % (model != null))
	if model == null:
		print("[verify] FALLO: no hay nodo Model")
		quit(1)
		return

	var ap := _find_anim_player(model)
	print("[verify] AnimationPlayer encontrado: %s" % (ap != null))
	if ap == null:
		print("[verify] FALLO: no hay AnimationPlayer")
		quit(1)
		return

	var anims := ap.get_animation_list()
	print("[verify] Animaciones: %s" % anims)
	if ap.has_animation("Dog1_Run"):
		ap.play("Dog1_Run")
		print("[verify] OK: Dog1_Run se puede reproducir")
		quit(0)
	else:
		print("[verify] FALLO: no existe Dog1_Run")
		quit(1)


func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null

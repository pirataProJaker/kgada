class_name FurnitureInteractProxy
extends StaticBody3D

## Proxy de colisión física para interacción con tecla [E] (InteractController)
## Reenvía la llamada interact() a un Callable o nodo objetivo para animar
## apertura y cierre de puertas, cajones y mecanismos.

var target_callable: Callable
var target_node: Node = null


func interact(interactor: Node = null) -> void:
	if target_callable.is_valid():
		target_callable.call()
	elif target_node != null and target_node.has_method("interact"):
		target_node.interact(interactor)

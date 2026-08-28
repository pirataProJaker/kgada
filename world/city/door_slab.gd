extends StaticBody3D
## Puente entre el sistema generico de interaccion (InteractController,
## MeleeController - ambos hacen intersect_ray y llaman interact()/
## take_damage() DIRECTO sobre el collider que golpea el rayo) y la puerta
## interactiva real.
##
## InteractiveDoor (world/city/interactive_door.gd) es el PIVOTE/bisagra: un
## Node3D que gira, padre de esta hoja. La colision real (lo que el rayo de
## la tecla E o el mordisco del machete realmente golpea) vive en ESTE
## StaticBody3D ("DoorSlab"), no en el pivote. Sin este script, el rayo
## encuentra este nodo, `collider.has_method("interact")` da false (un
## StaticBody3D liso no tiene ese metodo) y la tecla E no hace nada -
## exactamente el bug reportado ("le doy E a la puerta y no se abre").
## Este script simplemente reenvia ambas llamadas al pivote padre.


func interact(interactor: Node) -> void:
	var door := get_parent()
	if door != null and door.has_method("interact"):
		door.interact(interactor)


func take_damage(amount: float = 0.0) -> void:
	var door := get_parent()
	if door != null and door.has_method("take_damage"):
		door.take_damage(amount)

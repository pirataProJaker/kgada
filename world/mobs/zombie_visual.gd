extends Node3D
class_name ZombieVisual
## Version puramente visual del zombie (sin IA, sin fisica): la usa el
## sistema generico de item-en-mano/fantasma de colocacion (huevo de
## invocacion /give egg:zombie). Cuando se coloca de verdad, PlacementController
## instancia el mob REAL (world/mobs/zombie.tscn, con IA en Rust).

func _ready() -> void:
	ZombieModelUtils.build_model(self)

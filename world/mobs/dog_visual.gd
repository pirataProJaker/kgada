extends Node3D
class_name DogVisual
## Version puramente visual del mob (sin IA, sin fisica, sin
## CharacterBody3D): la usa el sistema generico de item-en-mano/fantasma de
## colocacion (ContentLoader.load_model_for_definition) para el "huevo de
## invocacion" (/give egg:dog). Cuando de verdad se coloca, PlacementController
## instancia el mob REAL (world/mobs/dog.tscn, con IA en Rust) - esta escena
## nunca se mueve ni piensa, solo se ve.
##
## El modelo es el mismo gato real (assets/cat/cat.fbx) que usa el mob real
## (ver DogModelUtils.build_model) - el perro original no importa en Godot.

func _ready() -> void:
	DogModelUtils.build_model(self)


extends Node3D
class_name CatVisual
## Version puramente visual del mob (sin IA, sin fisica, sin
## CharacterBody3D): la usa el sistema generico de item-en-mano/fantasma de
## colocacion (ContentLoader.load_model_for_definition) para el "huevo de
## invocacion" (/give egg:cat). Cuando de verdad se coloca, PlacementController
## instancia el mob REAL (world/mobs/cat.tscn, con IA en Rust) - esta escena
## nunca se mueve ni piensa, solo se ve.
##
## El modelo es el gato real (assets/cat/cat.fbx) que usa el mob real
## (ver CatModelUtils.build_model).

func _ready() -> void:
	CatModelUtils.build_model(self)

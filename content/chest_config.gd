extends ObjectDefinition
class_name ChestConfig
## Configuracion del primer "tipo de comportamiento" base: el Cofre. Nosotros
## programamos este script UNA vez (los campos + la logica en
## content/behaviors/chest_behavior.gd); crear un cofre nuevo despues es solo
## llenar estos valores + subir un modelo, sin tocar codigo.

@export_range(1, 50) var slots: int = 5
@export_range(1, 1000) var durability: int = 100

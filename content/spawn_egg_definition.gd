extends ObjectDefinition
class_name SpawnEggDefinition
## "Huevo de invocacion" (estilo Minecraft): un item de inventario que, al
## colocarlo con el sistema normal de fantasma/colocacion, no crea un objeto
## estatico (como ChestBehavior) sino que invoca una entidad real completa
## (ver EntityTypes) - PlacementController detecta este tipo con `is` y la
## trata distinto al resto de los ObjectDefinition.
##
## model_path (heredado de ObjectDefinition) apunta a la escena VISUAL de la
## entidad (sin IA/fisica) para que el item-en-mano y el fantasma se vean
## como la entidad real sin correr su logica todavia.

@export var entity_key: String = "" ## clave dentro de EntityTypes.TYPES

extends RefCounted
class_name EntityTypes
## Registro central de "entidades invocables" (mobs, NPCs...) para el comando
## de chat /summon y para los "huevos de invocacion" (/give egg:<entidad>).
## Agregar una entidad nueva requiere sumar UNA entrada aqui - el chat
## (autocompletado, /summon, /give egg:) y el sistema de colocacion la
## detectan solos, sin tocar nada mas.
##
## "scene": la entidad REAL con IA/fisica, la que aparece de verdad en el
##          mundo (con /summon o al colocar un huevo).
## "visual_scene": version SOLO visual (sin IA/fisica) que se usa para el
##          item-en-mano y el fantasma de colocacion del huevo - asi no
##          corre fisica/IA mientras el objeto solo se esta previsualizando.
const TYPES := {
	"perro": {
		"display_name": "Perro",
		"scene": "res://world/mobs/dog.tscn",
		"visual_scene": "res://world/mobs/dog_visual.tscn",
	},
}


## Busca por nombre exacto o parcial (case-insensitive) entre las claves de
## TYPES. Devuelve la clave encontrada o "" si no hay match.
static func find_key(query: String) -> String:
	var query_lower := query.to_lower()
	if TYPES.has(query_lower):
		return query_lower
	for key in TYPES.keys():
		if key.contains(query_lower):
			return key
	return ""

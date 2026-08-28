extends RefCounted
class_name BehaviorTypes
## Registro central de "tipos de comportamiento" del sistema sin-codigo.
## Unica fuente de verdad: agregar un tipo nuevo (Door, Weapon...) requiere
## sumar UNA entrada aqui - el editor de contenido, el registro de objetos y
## el sistema de colocacion (fantasma / "/give") lo detectan solo, sin tocar
## nada mas.

const TYPES := {
	"Cofre": {
		"config_script": "res://content/chest_config.gd",
		"behavior_script": "res://content/behaviors/chest_behavior.gd",
	},
}


## Dado el path del script de config de una ObjectDefinition ya cargada,
## regresa el path del script de comportamiento que sabe usarla, o "" si el
## tipo no esta registrado.
static func behavior_script_for_config(config_script_path: String) -> String:
	for entry in TYPES.values():
		if entry["config_script"] == config_script_path:
			return entry["behavior_script"]
	return ""

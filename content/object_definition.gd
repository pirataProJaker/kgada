extends Resource
class_name ObjectDefinition
## Clase base para toda "definicion de objeto sin programar". Cada tipo de
## comportamiento (Chest, Door, Weapon...) que programamos nosotros extiende
## esta clase agregando sus propios @export - esos son los unicos campos que
## un jugador llena en el editor, nunca toca este archivo ni el del tipo.
##
## Ver diseño completo en la memoria del repo (content-system-design.md).

@export var id: String = "" ## unico, namespaced: "autor/nombre_objeto"
@export var display_name: String = "Objeto sin nombre"
## Por ahora apunta a un recurso DENTRO del proyecto (res://...). Soportar
## subida real de archivos externos (fuera de res://) requiere cargar GLB en
## runtime via GLTFDocument/GLTFState - se agrega cuando construyamos el
## flujo real de "subir tu modelo" en el editor.
@export_file("*.glb", "*.tscn") var model_path: String = ""
## Muchos modelos GLB vienen modelados en unidades distintas a metros (cm,
## etc.) y aparecen enormes o diminutos al cargarlos tal cual. Este factor
## se aplica sobre el modelo cada vez que se carga (ghost, item en mano,
## objeto colocado) - se puede ajustar en vivo desde la vista previa del
## editor de contenido.
@export_range(0.001, 20.0, 0.001) var model_scale: float = 1.0
@export_file("*.png") var icon_path: String = ""

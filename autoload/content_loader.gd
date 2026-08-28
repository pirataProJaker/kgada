extends Node
## Autoload ("ContentLoader"): unico lugar que sabe cargar un modelo 3D sin
## importar si viene de DENTRO del proyecto (res://, ya importado por el
## editor de Godot) o de un archivo GLB externo elegido por el jugador desde
## el editor de contenido (copiado a user://content_models/ y cargado en
## tiempo real via GLTFDocument, sin pasar por el pipeline de importacion).

const MODELS_DIR := "user://content_models"


## Copia un archivo de modelo (elegido con un FileDialog del sistema, path
## absoluto de disco) dentro de user://content_models/ para que quede
## disponible para cargarse en cualquier momento futuro. Regresa el path
## final (usar ese valor como model_path de la ObjectDefinition) o "" si
## fallo.
func import_model_file(source_path: String) -> String:
	if source_path.is_empty():
		return ""

	DirAccess.make_dir_recursive_absolute(MODELS_DIR)
	var file_name := source_path.get_file()
	var dest_path := "%s/%s" % [MODELS_DIR, file_name]

	var src := FileAccess.open(source_path, FileAccess.READ)
	if src == null:
		push_warning("[ContentLoader] No se pudo abrir '%s' (err=%d)" % [source_path, FileAccess.get_open_error()])
		return ""
	var bytes := src.get_buffer(src.get_length())
	src.close()

	var dst := FileAccess.open(dest_path, FileAccess.WRITE)
	if dst == null:
		push_warning("[ContentLoader] No se pudo escribir '%s' (err=%d)" % [dest_path, FileAccess.get_open_error()])
		return ""
	dst.store_buffer(bytes)
	dst.close()

	return dest_path


## Instancia un modelo 3D listo para meter en la escena, a partir de un
## model_path que puede ser res://... (modelo dentro del proyecto) o un
## archivo GLB externo ya importado con import_model_file(). Regresa null si
## no hay modelo o no se pudo cargar (el llamador decide poner una caja de
## referencia en ese caso).
func load_model(model_path: String) -> Node3D:
	if model_path.is_empty():
		return null

	if model_path.begins_with("res://"):
		if not ResourceLoader.exists(model_path):
			push_warning("[ContentLoader] '%s' no existe." % model_path)
			return null
		var res := load(model_path)
		if res is PackedScene:
			return res.instantiate()
		push_warning("[ContentLoader] '%s' no es una escena instanciable." % model_path)
		return null

	if not FileAccess.file_exists(model_path):
		push_warning("[ContentLoader] El modelo '%s' no existe." % model_path)
		return null

	var gltf_doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err := gltf_doc.append_from_file(model_path, gltf_state)
	if err != OK:
		push_warning("[ContentLoader] Error cargando GLB '%s' (codigo %d)." % [model_path, err])
		return null

	return gltf_doc.generate_scene(gltf_state)


## Igual que load_model(), pero ya aplica el model_scale configurado en la
## ObjectDefinition - este es el que deben usar el fantasma de colocacion,
## el item en mano y el comportamiento real (ChestBehavior, etc.) para que
## todos se vean con el mismo tamaño ajustado desde el editor de contenido.
func load_model_for_definition(definition: ObjectDefinition) -> Node3D:
	if definition == null:
		return null
	var model := load_model(definition.model_path)
	if model == null:
		return null
	model.scale = Vector3.ONE * definition.model_scale
	return model

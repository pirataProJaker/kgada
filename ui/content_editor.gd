extends Control
## Editor de contenido "pedorrillo" (primera version, para validar el
## sistema de punta a punta): elige un tipo de comportamiento base, arma un
## formulario AUTOMATICAMENTE leyendo los @export de ese tipo (sin
## programar un formulario a mano por tipo), y guarda el resultado como un
## .tres de configuracion. Cuando se agregue Door/Weapon, solo hay que
## sumarlos a BEHAVIOR_TYPES - el formulario se genera solo.

const BEHAVIOR_TYPES := BehaviorTypes.TYPES

# Propiedades de Resource que no queremos mostrar en el formulario (son
# internals, no configuracion del objeto).
const HIDDEN_PROPERTIES := ["resource_local_to_scene", "resource_path", "resource_name", "script"]

@onready var type_option: OptionButton = $VBox/TypeOption
@onready var fields_container: VBoxContainer = $VBox/ScrollContainer/FieldsContainer
@onready var save_button: Button = $VBox/Buttons/SaveButton
@onready var back_button: Button = $VBox/Buttons/BackButton
@onready var status_label: Label = $VBox/StatusLabel
@onready var model_file_dialog: FileDialog = $ModelFileDialog
@onready var preview_root: Node3D = $PreviewContainer/SubViewport/PreviewRoot

var _current_config: Resource = null
var _field_inputs: Dictionary = {} # nombre de propiedad -> nodo de input


func _ready() -> void:
	for type_name in BEHAVIOR_TYPES.keys():
		type_option.add_item(type_name)
	type_option.item_selected.connect(_on_type_selected)
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(_on_back_pressed)
	model_file_dialog.file_selected.connect(_on_model_file_selected)

	if type_option.item_count > 0:
		_on_type_selected(0)


func _on_type_selected(index: int) -> void:
	var type_name: String = type_option.get_item_text(index)
	var config_script_path: String = BEHAVIOR_TYPES[type_name]["config_script"]
	var script: Script = load(config_script_path)
	_current_config = script.new()
	_build_form()
	_refresh_preview()
	status_label.text = ""


## El corazon del sistema: lee get_property_list() del tipo elegido y arma
## una fila de UI por cada @export - asi agregar un tipo nuevo (Door,
## Weapon...) nunca requiere tocar este archivo.
func _build_form() -> void:
	for child in fields_container.get_children():
		child.queue_free()
	_field_inputs.clear()

	for prop in _current_config.get_property_list():
		if not (prop["usage"] & PROPERTY_USAGE_EDITOR):
			continue
		if prop["name"] in HIDDEN_PROPERTIES:
			continue

		var row := HBoxContainer.new()
		fields_container.add_child(row)

		var label := Label.new()
		label.text = prop["name"]
		label.custom_minimum_size.x = 160
		row.add_child(label)

		if prop["name"] == "model_path":
			_add_model_picker_row(row)
			continue

		var input: Control = _make_input_for_property(prop)
		if input == null:
			continue
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(input)
		_field_inputs[prop["name"]] = input

		# El slider de escala refresca la vista previa 3D en vivo, sin esperar
		# a guardar - asi se puede ajustar el tamaño del modelo viendolo.
		if prop["name"] == "model_scale" and input is SpinBox:
			(input as SpinBox).value_changed.connect(_on_model_scale_changed)


## Fila especial para model_path: en vez de una simple caja de texto, un
## LineEdit de solo lectura + un boton que abre el explorador de archivos
## del sistema para elegir un .glb real desde el disco.
func _add_model_picker_row(row: HBoxContainer) -> void:
	var line := LineEdit.new()
	line.editable = false
	line.text = _current_config.get("model_path")
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)

	var browse_button := Button.new()
	browse_button.text = "Elegir modelo..."
	browse_button.pressed.connect(_on_browse_model_pressed)
	row.add_child(browse_button)

	_field_inputs["model_path"] = line


func _make_input_for_property(prop: Dictionary) -> Control:
	var current_value = _current_config.get(prop["name"])

	match prop["type"]:
		TYPE_INT, TYPE_FLOAT:
			var spin := SpinBox.new()
			spin.min_value = -100000
			spin.max_value = 100000
			spin.step = 1 if prop["type"] == TYPE_INT else 0.01
			# Si el campo tiene @export_range (como model_scale, slots,
			# durability...), se respeta ese min/max/step en vez del generico.
			if prop["hint"] == PROPERTY_HINT_RANGE and prop["hint_string"] != "":
				var hint_parts: PackedStringArray = prop["hint_string"].split(",")
				if hint_parts.size() >= 2:
					spin.min_value = hint_parts[0].to_float()
					spin.max_value = hint_parts[1].to_float()
				if hint_parts.size() >= 3:
					spin.step = hint_parts[2].to_float()
			spin.value = current_value
			return spin
		TYPE_STRING:
			var line := LineEdit.new()
			line.text = current_value
			return line
		_:
			return null


## Refresca la vista previa 3D con el modelo actual (ya escalado segun
## model_scale) - se llama al cambiar de tipo, al importar un modelo nuevo,
## y cada vez que se mueve el slider de escala.
func _refresh_preview() -> void:
	for child in preview_root.get_children():
		child.queue_free()

	if _current_config == null:
		return

	var instance := ContentLoader.load_model_for_definition(_current_config)
	if instance != null:
		preview_root.add_child(instance)


func _on_model_scale_changed(value: float) -> void:
	if _current_config:
		_current_config.set("model_scale", value)
	_refresh_preview()


func _on_save_pressed() -> void:
	for prop_name in _field_inputs.keys():
		var input: Control = _field_inputs[prop_name]
		if input is SpinBox:
			_current_config.set(prop_name, input.value)
		elif input is LineEdit:
			_current_config.set(prop_name, input.text)

	var id_value: String = _current_config.get("id")
	if id_value.is_empty():
		status_label.text = "Falta llenar el 'id' del objeto."
		return

	var safe_name := id_value.replace("/", "_")
	var save_dir := "user://custom_objects"
	var save_path := "%s/%s.tres" % [save_dir, safe_name]
	DirAccess.make_dir_recursive_absolute(save_dir)

	var err := ResourceSaver.save(_current_config, save_path)
	if err == OK:
		status_label.text = "Guardado: %s" % save_path
		ObjectRegistry.refresh() # disponible al instante para /give, sin reiniciar
	else:
		status_label.text = "Error al guardar (codigo %d)" % err


func _on_browse_model_pressed() -> void:
	model_file_dialog.popup_centered()


func _on_model_file_selected(path: String) -> void:
	var imported_path := ContentLoader.import_model_file(path)
	if imported_path.is_empty():
		status_label.text = "No se pudo importar el modelo."
		return

	_current_config.set("model_path", imported_path)
	var line: LineEdit = _field_inputs.get("model_path")
	if line:
		line.text = imported_path
	status_label.text = "Modelo importado: %s" % imported_path.get_file()
	_refresh_preview()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")

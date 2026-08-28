extends Node3D
class_name MapEditor
## Editor del mundo real: ChunkManager construye la misma malla Marching Cubes,
## material PSX y colision que usa el jugador. Este script solo controla la
## camara, la interfaz, el terreno y las construcciones modulares.

const MAP_DOCUMENT_SCRIPT := preload("res://map_editor/map_document.gd")
const MAP_LIBRARY_SCRIPT := preload("res://map_editor/map_library.gd")
const CONSTRUCTION_CATALOG_SCRIPT := preload("res://map_editor/construction_catalog.gd")
const MAP_DRAFT_PATH := "user://map_editor_draft.json"
const MAP_PLAYTEST_PATH := "user://map_editor_playtest.json"
const CHUNK_RESOLUTION := 17
const VOXEL_SIZE := 2.5
const CHUNK_WORLD_SIZE := 40.0
const CHUNK_SAMPLE_STRIDE := CHUNK_RESOLUTION - 1
const MAP_SIZE_OPTIONS := [2, 4, 6, 8]
const DEFAULT_MAP_SIZE_INDEX := 1
const BRUSH_RADIUS_CELLS := 4.5
const BRUSH_HEIGHT_DELTA := VOXEL_SIZE
const MIN_CAMERA_DISTANCE := 24.0
const MAX_CAMERA_DISTANCE := 500.0
const INITIAL_CAMERA_DISTANCE := 82.0
const CAMERA_MOVE_SPEED := 22.0
const CAMERA_ROTATE_SENSITIVITY := 0.3
const MIN_CAMERA_ELEVATION := 25.0
const MAX_CAMERA_ELEVATION := 88.0

@onready var camera: Camera3D = $Camera3D
@onready var terrain_manager: Node3D = $Terrain/ChunkManager
@onready var construction_manager: Node3D = $ConstructionManager
@onready var editor_anchor: Node3D = $Terrain/EditorAnchor
@onready var edit_grid: Node3D = $EditorOverlay/EditGrid
@onready var cursor_mesh: MeshInstance3D = $EditorOverlay/Cursor
@onready var map_name_edit: LineEdit = $Interface/RightPanel/PanelContent/MapNameEdit
@onready var grid_info_label: Label = $Interface/RightPanel/PanelContent/GridInfo
@onready var cell_info_label: Label = $Interface/RightPanel/PanelContent/CellInfo
@onready var status_label: Label = $Interface/RightPanel/PanelContent/Status
@onready var grid_check: CheckButton = $Interface/LeftPanel/PanelContent/GridCheck
@onready var test_button: Button = $Interface/TopBar/Actions/TestButton
@onready var map_size_option: OptionButton = $Interface/RightPanel/PanelContent/MapSizeOption
@onready var resize_button: Button = $Interface/RightPanel/PanelContent/ResizeButton
@onready var map_menu_backdrop: ColorRect = $Interface/MapMenuBackdrop
@onready var map_menu: PanelContainer = $Interface/MapMenu
@onready var saved_map_list: ItemList = $Interface/MapMenu/PanelContent/SavedMapList
@onready var open_map_button: Button = $Interface/MapMenu/PanelContent/Buttons/OpenMapButton
@onready var create_map_button: Button = $Interface/MapMenu/PanelContent/Buttons/CreateMapButton
@onready var close_map_button: Button = $Interface/MapMenu/PanelContent/Buttons/CloseButton
@onready var new_map_dialog: ConfirmationDialog = $Interface/NewMapDialog
@onready var new_map_name_input: LineEdit = $Interface/NewMapDialog/Content/MapNameInput
@onready var new_map_error_label: Label = $Interface/NewMapDialog/Content/ErrorLabel
@onready var construction_button: Button = $Interface/LeftPanel/PanelContent/ConstructionButton
@onready var construction_browser: VBoxContainer = $Interface/LeftPanel/PanelContent/ConstructionBrowser
@onready var construction_title: Label = $Interface/LeftPanel/PanelContent/ConstructionBrowser/Title
@onready var construction_back_button: Button = $Interface/LeftPanel/PanelContent/ConstructionBrowser/BackButton
@onready var construction_category_view: VBoxContainer = $Interface/LeftPanel/PanelContent/ConstructionBrowser/CategoryView
@onready var construction_type_view: VBoxContainer = $Interface/LeftPanel/PanelContent/ConstructionBrowser/TypeView

var document
var _active_map_path := ""
var _tool := "select"
var _hover_sample := Vector2i(-1, -1)
var _selected_sample := Vector2i(-1, -1)
var _is_orbiting := false
var _is_panning := false
var _camera_focus := Vector3(40.0, 10.0, 40.0)
var _camera_distance := INITIAL_CAMERA_DISTANCE
var _camera_elevation := 58.0
var _camera_yaw := 0.0
var _grid_material: StandardMaterial3D
var _selected_construction_type_id := ""


func _ready() -> void:
	_camera_setup()
	_setup_map_size_options()
	document = _load_document()
	_select_map_size_for_document()
	map_name_edit.text = document.map_name
	map_name_edit.text_changed.connect(_on_map_name_changed)
	$Interface/TopBar/Actions/NewButton.pressed.connect(_on_new_button_pressed)
	$Interface/TopBar/Actions/SaveButton.pressed.connect(_on_save_pressed)
	test_button.pressed.connect(_on_test_pressed)
	$Interface/TopBar/Actions/BackButton.pressed.connect(_on_back_pressed)
	resize_button.pressed.connect(_on_resize_pressed)
	map_size_option.item_selected.connect(_on_map_size_selected)
	saved_map_list.item_selected.connect(_on_saved_map_selected)
	saved_map_list.item_activated.connect(_on_saved_map_activated)
	open_map_button.pressed.connect(_on_open_map_pressed)
	create_map_button.pressed.connect(_on_create_map_pressed)
	close_map_button.pressed.connect(_close_map_menu)
	new_map_dialog.confirmed.connect(_on_new_map_confirmed)
	$Interface/LeftPanel/PanelContent/SelectButton.pressed.connect(func() -> void: _set_tool("select"))
	$Interface/LeftPanel/PanelContent/RaiseButton.pressed.connect(func() -> void: _set_tool("raise"))
	$Interface/LeftPanel/PanelContent/LowerButton.pressed.connect(func() -> void: _set_tool("lower"))
	$Interface/LeftPanel/PanelContent/FlattenButton.pressed.connect(func() -> void: _set_tool("flatten"))
	construction_button.pressed.connect(_open_construction_categories)
	construction_back_button.pressed.connect(_on_construction_back_pressed)
	_build_construction_categories()
	grid_check.toggled.connect(_on_grid_toggled)

	editor_anchor.global_position = _camera_focus
	_grid_material = StandardMaterial3D.new()
	_grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_material.albedo_color = Color(0.04, 0.07, 0.06, 0.7)
	_grid_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_reset_camera_for_document()
	terrain_manager.configure_editor(document.heights, document.grid_size)
	construction_manager.call("configure_document", document)
	_rebuild_edit_grid()
	_set_tool("select")
	_update_cell_info()
	_refresh_saved_map_list()
	map_menu.visible = false
	map_menu_backdrop.visible = false
	open_map_button.disabled = true


func _process(delta: float) -> void:
	_navigate_with_arrows(delta)
	_update_cursor(get_viewport().get_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = mouse_event.pressed
			return
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mouse_event.pressed
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.85)
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.18)
			return
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_apply_tool_at(mouse_event.position)
			return

	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if _is_orbiting:
			_camera_yaw -= motion_event.relative.x * CAMERA_ROTATE_SENSITIVITY
			_camera_elevation = clampf(
				_camera_elevation + motion_event.relative.y * CAMERA_ROTATE_SENSITIVITY,
				MIN_CAMERA_ELEVATION,
				MAX_CAMERA_ELEVATION,
			)
			_sync_camera()
		elif _is_panning:
			_pan(motion_event.relative)
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_apply_tool_at(motion_event.position)

	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		if document.is_valid_cell(_hover_sample) and bool(construction_manager.call("remove_object_at_cell", _hover_sample)):
			_selected_sample = _hover_sample
			status_label.text = "Construcción eliminada"
			_update_cell_info()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if map_menu.visible:
			_close_map_menu()
			return
		_set_tool("select")


func _camera_setup() -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 52.0
	camera.near = 0.1
	camera.far = 1000.0
	_sync_camera()


func _load_document():
	var requested_path := ""
	if get_tree().has_meta("map_editor_document_path"):
		requested_path = str(get_tree().get_meta("map_editor_document_path"))
		get_tree().remove_meta("map_editor_document_path")
	if not requested_path.is_empty():
		var requested_document = MAP_DOCUMENT_SCRIPT.load_from_file(requested_path)
		if requested_document != null and _is_supported_grid_size(requested_document.grid_size) and is_equal_approx(float(requested_document.cell_size), VOXEL_SIZE):
			_active_map_path = "" if requested_path == MAP_DRAFT_PATH else requested_path
			status_label.text = "Mapa cargado: %s" % requested_document.map_name
			return requested_document

	var loaded = MAP_DOCUMENT_SCRIPT.load_from_file(MAP_DRAFT_PATH)
	if loaded != null:
		if _is_supported_grid_size(loaded.grid_size) and is_equal_approx(float(loaded.cell_size), VOXEL_SIZE):
			status_label.text = "Borrador real cargado"
			return loaded

	status_label.text = "Mapa nuevo: terreno plano real"
	return MAP_DOCUMENT_SCRIPT.new(_selected_grid_size())


func _setup_map_size_options() -> void:
	for chunk_count in MAP_SIZE_OPTIONS:
		var world_size := int(chunk_count * CHUNK_WORLD_SIZE)
		map_size_option.add_item("%d x %d m  (%d chunks)" % [world_size, world_size, chunk_count * chunk_count])
	map_size_option.select(DEFAULT_MAP_SIZE_INDEX)


func _selected_grid_size() -> Vector2i:
	var option_index := clampi(map_size_option.selected, 0, MAP_SIZE_OPTIONS.size() - 1)
	var chunk_count: int = MAP_SIZE_OPTIONS[option_index]
	return Vector2i(
		chunk_count * CHUNK_SAMPLE_STRIDE + 1,
		chunk_count * CHUNK_SAMPLE_STRIDE + 1,
	)


func _is_supported_grid_size(size: Vector2i) -> bool:
	if size.x != size.y or size.x < CHUNK_RESOLUTION:
		return false
	var chunk_count: int = (size.x - 1) / CHUNK_SAMPLE_STRIDE
	return chunk_count >= MAP_SIZE_OPTIONS[0] and chunk_count <= MAP_SIZE_OPTIONS[MAP_SIZE_OPTIONS.size() - 1] and size.x - 1 == chunk_count * CHUNK_SAMPLE_STRIDE


func _select_map_size_for_document() -> void:
	for option_index in MAP_SIZE_OPTIONS.size():
		var chunk_count: int = MAP_SIZE_OPTIONS[option_index]
		if document.grid_size == Vector2i(
			chunk_count * CHUNK_SAMPLE_STRIDE + 1,
			chunk_count * CHUNK_SAMPLE_STRIDE + 1
		):
			map_size_option.select(option_index)
			return
	map_size_option.select(DEFAULT_MAP_SIZE_INDEX)


func _on_new_button_pressed() -> void:
	_open_map_menu()


func _on_new_pressed() -> void:
	var new_document = MAP_DOCUMENT_SCRIPT.new(_selected_grid_size())
	new_document.map_name = "Nuevo mapa"
	_apply_document(new_document, "")
	status_label.text = "Mapa nuevo: %.0f m" % _map_world_size()


func _apply_document(next_document, map_path: String) -> void:
	document = next_document
	_active_map_path = map_path
	_select_map_size_for_document()
	map_name_edit.text = document.map_name
	_hover_sample = Vector2i(-1, -1)
	_selected_sample = Vector2i(-1, -1)
	_reset_camera_for_document()
	terrain_manager.configure_editor(document.heights, document.grid_size)
	construction_manager.call("configure_document", document)
	_rebuild_edit_grid()
	_update_cell_info()


func _open_map_menu() -> void:
	_refresh_saved_map_list()
	map_menu_backdrop.visible = true
	map_menu.visible = true
	_update_open_map_button()
	saved_map_list.grab_focus()


func _close_map_menu() -> void:
	map_menu.visible = false
	map_menu_backdrop.visible = false


func _refresh_saved_map_list() -> void:
	saved_map_list.clear()
	var selected_index := -1
	var map_paths := _get_saved_map_paths()
	for path in map_paths:
		var saved_document = MAP_DOCUMENT_SCRIPT.load_from_file(path)
		if saved_document == null:
			continue
		var item_text := "%s  |  %d x %d" % [
			str(saved_document.map_name),
			saved_document.grid_size.x,
			saved_document.grid_size.y,
		]
		var item_index := saved_map_list.add_item(item_text)
		saved_map_list.set_item_metadata(item_index, path)
		if path == _active_map_path:
			selected_index = item_index

	if saved_map_list.item_count == 0:
		if FileAccess.file_exists(MAP_DRAFT_PATH):
			var draft = MAP_DOCUMENT_SCRIPT.load_from_file(MAP_DRAFT_PATH)
			if draft != null:
				var draft_index := saved_map_list.add_item("%s  |  borrador actual" % str(draft.map_name))
				saved_map_list.set_item_metadata(draft_index, MAP_DRAFT_PATH)
				saved_map_list.set_item_disabled(draft_index, false)
				selected_index = draft_index
		if saved_map_list.item_count == 0:
			var empty_index := saved_map_list.add_item("No hay mapas guardados todavía")
			saved_map_list.set_item_metadata(empty_index, "")
			saved_map_list.set_item_disabled(empty_index, true)
	elif selected_index < 0:
		selected_index = 0

	if selected_index >= 0:
		saved_map_list.select(selected_index)
	_update_open_map_button()


func _update_open_map_button() -> void:
	var selected_items := saved_map_list.get_selected_items()
	open_map_button.disabled = selected_items.is_empty()
	if not selected_items.is_empty():
		open_map_button.disabled = str(saved_map_list.get_item_metadata(selected_items[0])).is_empty()


func _on_saved_map_selected(_index: int) -> void:
	_update_open_map_button()


func _on_saved_map_activated(_index: int) -> void:
	_load_selected_map()


func _on_open_map_pressed() -> void:
	_load_selected_map()


func _load_selected_map() -> void:
	var selected_items := saved_map_list.get_selected_items()
	if selected_items.is_empty():
		return
	var map_path := str(saved_map_list.get_item_metadata(selected_items[0]))
	if map_path.is_empty():
		return
	var loaded_document = MAP_DOCUMENT_SCRIPT.load_from_file(map_path)
	if loaded_document == null:
		status_label.text = "No se pudo cargar el mapa"
		_refresh_saved_map_list()
		return
	_apply_document(loaded_document, "" if map_path == MAP_DRAFT_PATH else map_path)
	_close_map_menu()
	status_label.text = "Mapa cargado: %s" % document.map_name


func _on_create_map_pressed() -> void:
	new_map_name_input.clear()
	new_map_error_label.text = ""
	new_map_dialog.popup_centered()
	call_deferred("_focus_new_map_name")


func _focus_new_map_name() -> void:
	if new_map_dialog.visible:
		new_map_name_input.grab_focus()


func _on_new_map_confirmed() -> void:
	var map_name := new_map_name_input.text.strip_edges()
	if map_name.is_empty():
		new_map_error_label.text = "Escribe un nombre para el mapa."
		new_map_dialog.popup_centered()
		call_deferred("_focus_new_map_name")
		return

	var new_document = MAP_DOCUMENT_SCRIPT.new(_selected_grid_size())
	new_document.map_name = map_name
	var map_path := _next_map_path()
	if not new_document.save_to_file(map_path) or not new_document.save_to_file(MAP_DRAFT_PATH):
		new_map_error_label.text = "No se pudo guardar el mapa."
		new_map_dialog.popup_centered()
		return

	new_map_dialog.hide()
	_apply_document(new_document, map_path)
	_close_map_menu()
	status_label.text = "Mapa creado: %s" % document.map_name


func _get_saved_map_paths() -> Array[String]:
	return MAP_LIBRARY_SCRIPT.get_saved_map_paths()


func _next_map_path() -> String:
	return MAP_LIBRARY_SCRIPT.next_map_path()


func _save_document_files() -> bool:
	if _active_map_path.is_empty():
		_active_map_path = _next_map_path()
	if not document.save_to_file(_active_map_path):
		return false
	return document.save_to_file(MAP_DRAFT_PATH)


func _on_resize_pressed() -> void:
	if document == null:
		return
	var target_size := _selected_grid_size()
	if target_size == document.grid_size:
		status_label.text = "El mapa ya tiene ese tamaño"
		return

	var resized = MAP_DOCUMENT_SCRIPT.new(target_size)
	resized.map_name = document.map_name
	resized.world_seed = document.world_seed
	resized.terrain_mode = document.terrain_mode
	resized.cell_size = document.cell_size
	resized.sea_level = document.sea_level
	resized.objects = document.objects.duplicate(true)
	var copy_width: int = mini(document.grid_size.x, target_size.x)
	var copy_depth: int = mini(document.grid_size.y, target_size.y)
	for sample_z in copy_depth:
		for sample_x in copy_width:
			resized.set_height(Vector2i(sample_x, sample_z), document.get_height(Vector2i(sample_x, sample_z)))

	document = resized
	_hover_sample = Vector2i(-1, -1)
	_selected_sample = Vector2i(-1, -1)
	map_name_edit.text = document.map_name
	_reset_camera_for_document()
	terrain_manager.configure_editor(document.heights, document.grid_size)
	construction_manager.call("configure_document", document)
	_rebuild_edit_grid()
	status_label.text = "Mapa redimensionado: %.0f m" % _map_world_size()


func _on_map_size_selected(_index: int) -> void:
	status_label.text = "Tamaño preparado: %.0f m. Pulsa Redimensionar." % (_selected_grid_size().x * document.cell_size - document.cell_size)


func _on_save_pressed() -> void:
	document.map_name = map_name_edit.text.strip_edges()
	if document.map_name.is_empty():
		document.map_name = "Nuevo mapa"
		map_name_edit.text = document.map_name
	if _save_document_files():
		status_label.text = "Guardado: %s" % document.map_name
	else:
		status_label.text = "No se pudo guardar"


func _on_test_pressed() -> void:
	if document == null:
		status_label.text = "No hay mapa para probar"
		return
	if not _save_document_files() or not document.save_to_file(MAP_PLAYTEST_PATH):
		status_label.text = "No se pudo preparar la prueba"
		return
	status_label.text = "Cargando mapa de prueba..."
	call_deferred("_start_playtest")


func _start_playtest() -> void:
	var result := get_tree().change_scene_to_file("res://tests/world_test.tscn")
	if result != OK:
		status_label.text = "No se pudo abrir WorldTest (%s)" % result


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_map_name_changed(value: String) -> void:
	if document != null:
		document.map_name = value


func _on_grid_toggled(enabled: bool) -> void:
	edit_grid.visible = enabled


func _set_tool(tool: String) -> void:
	_tool = tool
	status_label.text = "Herramienta: %s" % _tool_name(tool)


func _open_construction_categories() -> void:
	_set_terrain_tools_visible(false)
	construction_browser.visible = true
	construction_category_view.visible = true
	construction_type_view.visible = false
	construction_title.text = "CONSTRUCCIONES"
	_selected_construction_type_id = ""
	_set_tool("select")


func _close_construction_browser() -> void:
	_set_terrain_tools_visible(true)
	construction_browser.visible = false
	_selected_construction_type_id = ""
	_set_tool("select")


func _on_construction_back_pressed() -> void:
	if construction_type_view.visible:
		_open_construction_categories()
		return
	_close_construction_browser()


func _set_terrain_tools_visible(enabled: bool) -> void:
	$Interface/LeftPanel/PanelContent/SelectButton.visible = enabled
	$Interface/LeftPanel/PanelContent/RaiseButton.visible = enabled
	$Interface/LeftPanel/PanelContent/LowerButton.visible = enabled
	$Interface/LeftPanel/PanelContent/FlattenButton.visible = enabled
	$Interface/LeftPanel/PanelContent/Spacer.visible = enabled
	grid_check.visible = enabled
	construction_button.visible = enabled


func _build_construction_categories() -> void:
	for child in construction_category_view.get_children():
		child.free()
	for category in CONSTRUCTION_CATALOG_SCRIPT.get_categories():
		var category_id := str(category.get("id", ""))
		var category_button := Button.new()
		category_button.text = str(category.get("name", category_id))
		category_button.pressed.connect(_show_construction_types.bind(category_id))
		construction_category_view.add_child(category_button)


func _show_construction_types(category_id: String) -> void:
	for child in construction_type_view.get_children():
		child.free()
	construction_category_view.visible = false
	construction_type_view.visible = true
	construction_title.text = CONSTRUCTION_CATALOG_SCRIPT.get_category_name(category_id)
	for definition in CONSTRUCTION_CATALOG_SCRIPT.get_definitions_for_category(category_id):
		var type_id := str(definition.type_id)
		var type_button := Button.new()
		type_button.text = str(definition.display_name)
		type_button.pressed.connect(_select_construction_type.bind(type_id))
		construction_type_view.add_child(type_button)
	if construction_type_view.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "Próximamente"
		construction_type_view.add_child(empty_label)


func _select_construction_type(type_id: String) -> void:
	_selected_construction_type_id = type_id
	_set_tool("construction")


func _apply_tool_at(screen_position: Vector2) -> void:
	var world_position: Variant = _world_at_screen(screen_position)
	if world_position == null:
		return
	var sample := _sample_from_world(world_position as Vector3)
	if not document.is_valid_cell(sample):
		return

	_hover_sample = sample
	if _tool == "select":
		_selected_sample = sample
		_update_cell_info()
		return
	if _tool == "construction" and not _selected_construction_type_id.is_empty():
		if bool(construction_manager.call("place_object", sample, _selected_construction_type_id, 0)):
			_selected_sample = sample
			status_label.text = "Construcción colocada"
			_update_cell_info()
		return

	_apply_height_brush(sample)
	_selected_sample = sample
	_update_cell_info()


func _apply_height_brush(center: Vector2i) -> void:
	var radius := ceili(BRUSH_RADIUS_CELLS)
	var minimum := Vector2i(maxi(center.x - radius, 0), maxi(center.y - radius, 0))
	var maximum := Vector2i(
		mini(center.x + radius, document.grid_size.x - 1),
		mini(center.y + radius, document.grid_size.y - 1),
	)
	var center_height: float = float(document.get_height(center))
	var voxel_step: float = float(document.cell_size)

	for sample_y in range(minimum.y, maximum.y + 1):
		for sample_x in range(minimum.x, maximum.x + 1):
			var sample := Vector2i(sample_x, sample_y)
			var distance := Vector2(sample_x - center.x, sample_y - center.y).length()
			if distance > BRUSH_RADIUS_CELLS:
				continue
			var normalized_distance: float = distance / BRUSH_RADIUS_CELLS
			var falloff: float = 1.0 - normalized_distance * normalized_distance * (3.0 - 2.0 * normalized_distance)
			var current_height: float = float(document.get_height(sample))
			match _tool:
				"raise":
					document.set_height(sample, current_height + voxel_step * falloff)
				"lower":
					document.set_height(sample, current_height - voxel_step * falloff)
				"flatten":
					document.set_height(sample, lerpf(current_height, center_height, falloff * 0.35))

	terrain_manager.update_editor_heightfield(document.heights, minimum, maximum)
	construction_manager.call("update_terrain_region", minimum, maximum)
	_rebuild_edit_grid_for_sample_bounds(minimum, maximum)
	status_label.text = "Terreno Marching Cubes regenerando..."


func _rebuild_edit_grid() -> void:
	for child in edit_grid.get_children():
		child.free()
	var chunk_stride := CHUNK_RESOLUTION - 1
	var chunk_count_x := ceili(float(document.grid_size.x - 1) / float(chunk_stride))
	var chunk_count_z := ceili(float(document.grid_size.y - 1) / float(chunk_stride))
	for chunk_z in chunk_count_z:
		for chunk_x in chunk_count_x:
			_rebuild_edit_grid_chunk(Vector2i(chunk_x, chunk_z))


func _rebuild_edit_grid_for_sample_bounds(sample_min: Vector2i, sample_max: Vector2i) -> void:
	var chunk_stride := CHUNK_RESOLUTION - 1
	var safe_min := Vector2i(
		clampi(sample_min.x - 1, 0, document.grid_size.x - 1),
		clampi(sample_min.y - 1, 0, document.grid_size.y - 1),
	)
	var safe_max := Vector2i(
		clampi(sample_max.x + 1, 0, document.grid_size.x - 1),
		clampi(sample_max.y + 1, 0, document.grid_size.y - 1),
	)
	var first_chunk := Vector2i(
		floori(float(safe_min.x) / float(chunk_stride)),
		floori(float(safe_min.y) / float(chunk_stride)),
	)
	var last_chunk := Vector2i(
		floori(float(safe_max.x) / float(chunk_stride)),
		floori(float(safe_max.y) / float(chunk_stride)),
	)
	for chunk_z in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x in range(first_chunk.x, last_chunk.x + 1):
			_rebuild_edit_grid_chunk(Vector2i(chunk_x, chunk_z))


func _rebuild_edit_grid_chunk(coord: Vector2i) -> void:
	var chunk_name := "GridChunk_%d_%d" % [coord.x, coord.y]
	var old_grid := edit_grid.get_node_or_null(NodePath(chunk_name))
	if old_grid != null:
		old_grid.free()

	var chunk_stride := CHUNK_RESOLUTION - 1
	var start_x := coord.x * chunk_stride
	var start_z := coord.y * chunk_stride
	var cell_count_x := mini(chunk_stride, document.grid_size.x - 1 - start_x)
	var cell_count_z := mini(chunk_stride, document.grid_size.y - 1 - start_z)
	if cell_count_x <= 0 or cell_count_z <= 0:
		return

	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	for local_z in cell_count_z:
		for local_x in cell_count_x:
			var cell_x := start_x + local_x
			var cell_z := start_z + local_z
			var corners: Array[Vector3] = [
				_world_from_sample(Vector2i(cell_x, cell_z)),
				_world_from_sample(Vector2i(cell_x + 1, cell_z)),
				_world_from_sample(Vector2i(cell_x + 1, cell_z + 1)),
				_world_from_sample(Vector2i(cell_x, cell_z + 1)),
			]
			for corner_index in 4:
				var next_index := (corner_index + 1) % 4
				var first: Vector3 = corners[corner_index]
				var second: Vector3 = corners[next_index]
				first.y = _cell_corner_height(cell_x, cell_z, corner_index) + 0.08
				second.y = _cell_corner_height(cell_x, cell_z, next_index) + 0.08
				immediate.surface_add_vertex(first)
				immediate.surface_add_vertex(second)
	immediate.surface_end()

	var grid_chunk := MeshInstance3D.new()
	grid_chunk.name = chunk_name
	grid_chunk.mesh = immediate
	grid_chunk.material_override = _grid_material
	edit_grid.add_child(grid_chunk)


func _cell_corner_height(cell_x: int, cell_z: int, corner_index: int) -> float:
	var sample := Vector2i(cell_x, cell_z)
	if corner_index == 1:
		sample.x += 1
	elif corner_index == 2:
		sample += Vector2i(1, 1)
	elif corner_index == 3:
		sample.y += 1
	return float(document.get_height(sample))


func _update_cursor(screen_position: Vector2) -> void:
	if document == null:
		return
	var world_position: Variant = _world_at_screen(screen_position)
	if world_position == null:
		cursor_mesh.visible = false
		return
	var sample := _sample_from_world(world_position as Vector3)
	if not document.is_valid_cell(sample):
		cursor_mesh.visible = false
		return
	_hover_sample = sample
	cursor_mesh.visible = true
	cursor_mesh.global_position = _world_from_sample(sample)
	cursor_mesh.global_position.y = float(document.get_height(sample)) + 0.18
	_update_cell_info()


func _update_cell_info() -> void:
	if document == null:
		return
	var voxel_step: float = float(document.cell_size)
	grid_info_label.text = "Marching Cubes real\nMapa: %.0f x %.0f m\nVoxel: %.1f m\nMuestras: %d x %d" % [
		_map_world_size(), _map_world_size(), voxel_step, document.grid_size.x, document.grid_size.y
	]
	if not document.is_valid_cell(_hover_sample):
		cell_info_label.text = "Muestra: --"
		return
	var height: float = float(document.get_height(_hover_sample))
	var object_data = construction_manager.call("get_object_at_cell", _hover_sample)
	var object_text := "Objeto: --"
	if object_data is Dictionary:
		var connectivity_mask := int(object_data.get("connectivity_mask", 0))
		object_text = "Objeto: %s\nN:%d E:%d S:%d O:%d" % [
			str(object_data.get("type_id", "")),
			int((connectivity_mask & 1) != 0),
			int((connectivity_mask & 2) != 0),
			int((connectivity_mask & 4) != 0),
			int((connectivity_mask & 8) != 0),
		]
	cell_info_label.text = "Muestra: %d, %d\nAltura: %.2f m\n%s\nRadio pincel: %.1f" % [
		_hover_sample.x, _hover_sample.y, height, object_text, BRUSH_RADIUS_CELLS
	]


func _world_at_screen(screen_position: Vector2):
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		return result["position"]

	if absf(ray_direction.y) < 0.0001:
		return null
	var terrain_height: float = float(document.get_height(Vector2i.ZERO))
	var distance := (terrain_height - ray_origin.y) / ray_direction.y
	if distance < 0.0:
		return null
	return ray_origin + ray_direction * distance


func _sample_from_world(world_position: Vector3) -> Vector2i:
	var cell_size: float = float(document.cell_size)
	var maximum_x: float = float(document.grid_size.x - 1) * cell_size
	var maximum_z: float = float(document.grid_size.y - 1) * cell_size
	if world_position.x < 0.0 or world_position.z < 0.0 or world_position.x > maximum_x or world_position.z > maximum_z:
		return Vector2i(-1, -1)
	return Vector2i(
		roundi(world_position.x / cell_size),
		roundi(world_position.z / cell_size),
	)


func _world_from_sample(sample: Vector2i) -> Vector3:
	return Vector3(
		float(sample.x) * float(document.cell_size),
		float(document.get_height(sample)),
		float(sample.y) * float(document.cell_size),
	)


func _zoom(factor: float) -> void:
	_camera_distance = clampf(
		_camera_distance * factor,
		MIN_CAMERA_DISTANCE,
		MAX_CAMERA_DISTANCE,
	)
	_sync_camera()


func _pan(relative: Vector2) -> void:
	var viewport_height := maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var world_per_pixel: float = _camera_distance / viewport_height
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	_camera_focus += right * (-relative.x * world_per_pixel)
	_camera_focus += forward * (relative.y * world_per_pixel)
	_sync_camera()


func _navigate_with_arrows(delta: float) -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit:
		return
	var horizontal: float = float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	var vertical: float = float(Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_DOWN))
	if is_zero_approx(horizontal) and is_zero_approx(vertical):
		return
	var right := camera.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var movement := right * horizontal + forward * vertical
	_camera_focus += movement.normalized() * CAMERA_MOVE_SPEED * delta
	_sync_camera()


func _sync_camera() -> void:
	var elevation_rad: float = deg_to_rad(_camera_elevation)
	var yaw_rad: float = deg_to_rad(_camera_yaw)
	var horizontal_distance: float = cos(elevation_rad) * _camera_distance
	var vertical_distance: float = sin(elevation_rad) * _camera_distance
	var offset := Vector3(
		sin(yaw_rad) * horizontal_distance,
		vertical_distance,
		cos(yaw_rad) * horizontal_distance,
	)
	camera.global_position = _camera_focus + offset
	camera.look_at(_camera_focus, Vector3.UP)
	editor_anchor.global_position = _camera_focus


func _reset_camera_for_document() -> void:
	var map_size := _map_world_size()
	_camera_focus = Vector3(map_size * 0.5, 10.0, map_size * 0.5)
	_camera_distance = clampf(maxf(INITIAL_CAMERA_DISTANCE, map_size * 0.75), MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	_sync_camera()


func _map_world_size() -> float:
	if document == null:
		return CHUNK_WORLD_SIZE
	return float(document.grid_size.x - 1) * float(document.cell_size)


func _tool_name(tool: String) -> String:
	match tool:
		"select":
			return "Seleccionar"
		"raise":
			return "Elevar terreno"
		"lower":
			return "Bajar terreno"
		"flatten":
			return "Aplanar"
		"construction":
			return "Construcción"
	return tool

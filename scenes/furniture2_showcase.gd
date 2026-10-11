class_name Furniture2Showcase
extends Node3D

## Escaparate Oficial de la Colección Completa "Furniture 2.0" (Interior Village)
## Play Sector X - Motor de Objetos (+0 Draw Calls - Hardware Instancing)
##
## Controles:
## - Clic Izquierdo / Escape: Alternar captura de mouse
## - WASD / Espacio / Ctrl: Mover la cámara
## - Shift: Acelerar cámara
## - E o F: Abrir/Cerrar cajones y puertas en muebles de almacenamiento

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")

const MOVE_SPEED := 8.0
const SPRINT_SPEED := 22.0
const MOUSE_SENSITIVITY := 0.0025

var _engine: ObjectEngine = null
var _camera: Camera3D = null
var _mouse_captured: bool = false
var _cam_yaw: float = 0.0
var _cam_pitch: float = -0.30
var _drawers_open: bool = false


func _ready() -> void:
	print("=======================================================================")
	print("=== ESCAPARATE DE MOBILIARIO Y PROPS FURNITURE 2.0 (81 MODELOS) =======")
	print("=======================================================================")

	_setup_lighting_and_environment()
	_rebuild_collection(false)
	_setup_camera()


func _setup_lighting_and_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.07, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.72, 0.80)
	env.ambient_light_energy = 0.90
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "StudioSun"
	sun.rotation_degrees = Vector3(-42.0, 32.0, 0.0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(25.0, -145.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.70, 0.80, 0.95)
	add_child(fill)


func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.current = true
	add_child(_camera)
	_camera.position = Vector3(0.0, 5.0, 10.0)
	_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _rebuild_collection(drawers_open: bool) -> void:
	if _engine != null:
		remove_child(_engine)
		_engine.queue_free()

	_engine = ObjectEngineScript.new()
	_engine.name = "ShowcaseObjectEngine"
	add_child(_engine)

	var builder = _engine.get_builder()

	# 1. Asientos (12 modelos) - Fila Z = 0
	var seating := [
		"sofa_damask_gold", "sofa_floral_cottage", "sofa_wood_minimal",
		"sofa_chesterfield_red", "armchair_chesterfield_red", "armchair_wingback_leather",
		"armchair_tufted_charcoal", "armchair_tufted_skyblue", "armchair_velvet_mustard",
		"chair_dining_cream", "chair_baroque_oval", "armchair_louis_xv_blue"
	]
	_place_row(builder, seating, -12.0, 0.0, 2.2)

	# 2. Camas (5 modelos) - Fila Z = 4.0
	var beds := [
		"bed_single_plaid", "bed_double_iron_arabesque", "bed_double_grey_duvet",
		"bed_double_rustic_band", "bed_double_rustic_wrinkled"
	]
	_place_row(builder, beds, -6.0, 4.0, 2.8)

	# 3. Almacenamiento (16 modelos) - Fila Z = 8.0
	var storage := [
		"chest_drawers_tall_5", "chest_drawers_light_4", "chest_drawers_white_3",
		"nightstand_tapered_legs_3", "nightstand_tapered_legs_2", "sideboard_buffet_3drawers",
		"sideboard_low_2doors", "cupboard_welsh_dresser", "cupboard_vitrine_books",
		"cupboard_vitrine_books_02", "cupboard_glass_tall", "bookcase_full_books_tall",
		"bookcase_full_books_tall_01", "bookcase_books_low", "wardrobe_open_clothes",
		"wardrobe_open_coats"
	]
	_place_row(builder, storage, -15.0, 8.0, 2.0, {"is_open": drawers_open})

	# 4. Cocina y Comedor (12 modelos) - Fila Z = 12.0
	var kitchen := [
		"kitchen_corner_wall_cabinet", "kitchen_base_counter_sink", "kitchen_island",
		"kitchen_stove_gas_white", "kitchen_refrigerator_beige", "table_hex_gingham_rack",
		"table_rect_gingham", "table_rect_lace_floral", "kitchen_hanging_utensils",
		"chair_kitchen_slat", "chair_kitchen_spindle", "chair_kitchen_upholstered"
	]
	_place_row(builder, kitchen, -12.0, 12.0, 2.2)

	# 5. Props, Lámparas, Radios y Comida (36 modelos) - Filas Z = 16.0 y Z = 18.0
	var props_row1 := [
		"fan_pedestal_tall", "fan_desk_table", "fan_ceiling", "lamp_table_shade",
		"lamp_banker_green", "lamp_desk_gooseneck_black", "lamp_desk_gooseneck_white",
		"socket_lightbulb_stand", "alarm_clock_digital_red", "alarm_clock_digital_green",
		"radio_vintage_dial", "radio_portable", "walkie_talkie_military",
		"phone_rotary_black", "phone_pushbutton_beige", "paintings_wall_canvas",
		"magazines_books_stack", "trash_can_liner"
	]
	_place_row(builder, props_row1, -12.0, 16.0, 1.4)

	var props_row2 := [
		"garbage_bag_full", "vase_flower_rose", "vase_flower_lavender",
		"food_pizza_box_open", "food_pizza_slice", "food_roast_chicken",
		"food_fried_basket", "food_meat_cuts", "food_soup_bowl",
		"food_dinner_plate", "food_pie_slice", "food_flan",
		"food_ice_cream_tub", "food_popsicle_red", "drink_soda_bottle",
		"drink_milk_jug", "drink_milk_strawberry", "drink_can"
	]
	_place_row(builder, props_row2, -12.0, 18.0, 1.4)

	_engine.commit(builder)

	var stats := _engine.get_stats()
	print("✓ Telemetría Furniture 2.0 (81 modelos activos):")
	print("   - Instancias GPU: %d" % stats["total_instances"])
	print("   - Draw Calls: %d" % stats["draw_calls"])


func _place_row(builder: Variant, models: Array, start_x: float, z: float, spacing: float, params: Dictionary = {}) -> void:
	var cur_x := start_x
	for m_key in models:
		var t := Transform3D(Basis.IDENTITY, Vector3(cur_x, 0.0, z))
		builder.add_furniture_by_script(m_key, t, params)
		cur_x += spacing


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_mouse_captured = !_mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _mouse_captured else Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseMotion and _mouse_captured:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)

	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_F:
			_drawers_open = !_drawers_open
			print("Alternando estado de cajones: %s" % ("ABIERTOS" if _drawers_open else "CERRADOS"))
			_rebuild_collection(_drawers_open)
		elif event.keycode == KEY_ESCAPE:
			_mouse_captured = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not _mouse_captured or _camera == null:
		return

	var input_vec := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): input_vec.z -= 1.0
	if Input.is_key_pressed(KEY_S): input_vec.z += 1.0
	if Input.is_key_pressed(KEY_A): input_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D): input_vec.x += 1.0
	if Input.is_key_pressed(KEY_SPACE): input_vec.y += 1.0
	if Input.is_key_pressed(KEY_CTRL): input_vec.y -= 1.0

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else MOVE_SPEED
	var cam_basis := _camera.global_transform.basis
	var move_dir := (cam_basis * input_vec).normalized()
	_camera.global_position += move_dir * speed * delta

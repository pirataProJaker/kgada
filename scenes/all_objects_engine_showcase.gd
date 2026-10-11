class_name AllObjectsEngineShowcase
extends Node3D

## Escaparate Maestro de Todos los Objetos de Play Sector X (Motor de Objetos)
## Exhibe todos los muebles, electrodomésticos y props ordenados estrictamente por tamaño:
## De Menor a Mayor (Desde el Medidor CFE de 20cm hasta el Poste de Luz de 7m).
## Renderiza todos los objetos simultáneamente en solo 3 Draw Calls vía Hardware Instancing.

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ElectricMeterCFERecipeScript = preload("res://world/object_engine/recipes/electric_meter_cfe_recipe.gd")
const StreetlightPoleRecipeScript = preload("res://world/object_engine/recipes/streetlight_pole_recipe.gd")
const HouseFurnitureRecipesScript = preload("res://world/object_engine/recipes/house_furniture_recipes.gd")
const AppliancesRecipesScript = preload("res://world/object_engine/recipes/appliances_recipes.gd")
const CommercialRecipesScript = preload("res://world/object_engine/recipes/commercial_recipes.gd")

@export var auto_rotate_camera: bool = false

var _engine: ObjectEngine = null
var _camera: Camera3D = null


func _ready() -> void:
	print("=======================================================================")
	print("=== ESCAPARATE MAESTRO DE OBJETOS PLAY SECTOR X (MOTOR DE OBJETOS) ===")
	print("=======================================================================")

	_setup_lighting_and_environment()
	_build_all_showcase_objects()


const MOVE_SPEED := 9.0
const SPRINT_SPEED := 24.0
const MOUSE_SENSITIVITY := 0.0025
const PITCH_LIMIT := 1.45

var _mouse_captured: bool = true
var _cam_yaw: float = 0.0
var _cam_pitch: float = 0.0
var _hud_label: Label = null


func _setup_lighting_and_environment() -> void:
	# Iluminación direccional de galería
	var light := DirectionalLight3D.new()
	light.name = "ShowcaseSun"
	light.rotation_degrees = Vector3(-35.0, 45.0, 0.0)
	light.light_energy = 1.35
	light.shadow_enabled = true
	add_child(light)

	# Entorno con cielo neutro PSX
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.70, 0.74)
	env_node.environment = env
	add_child(env_node)

	# Cámara de jugador / libre interactiva
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.position = Vector3(-8.0, 1.8, 4.0)
	_camera.fov = 65.0
	_camera.current = true
	add_child(_camera)

	# Orientar inicialmente hacia los objetos
	_cam_yaw = 0.0
	_cam_pitch = deg_to_rad(-8.0)
	_update_cam_rotation()

	# Capturar el ratón por defecto
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Crear HUD de ayuda en pantalla
	_create_hud()


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ShowcaseHUD"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -340
	panel.offset_top = 12
	panel.offset_right = -12

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 14
	style.content_margin_top = 10
	style.content_margin_right = 14
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)

	_hud_label = Label.new()
	_hud_label.text = "🎮 CONTROLES DEL ESCAPARATE:\n" + \
		"• WASD: Moverse | Shift: Correr rápido\n" + \
		"• Espacio / E: Subir | Ctrl / Q: Bajar\n" + \
		"• Ratón: Mirar libremente | ESC: Liberar cursor\n" + \
		"• Teletransporte rápido:\n" + \
		"  [1] Pequeños (Medidor CFE, Tostadora, Micro)\n" + \
		"  [2] Medianos (Mesitas, Sillas, Cocina, Lavadoras)\n" + \
		"  [3] Muebles Grandes (Comedor, Roperos, Camas)\n" + \
		"  [4] Tienda OXXO (Góndola, Vitrinas comerciales)\n" + \
		"  [5] Poste de Luz (Gigante 7m)\n" + \
		"  [0] Vista Panorámica General"
	_hud_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	_hud_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(_hud_label)
	canvas.add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	# Liberar o recapturar cursor
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and not _mouse_captured:
		_mouse_captured = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	# Control de cámara con mouse
	if _mouse_captured and event is InputEventMouseMotion:
		_cam_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_cam_pitch = clampf(_cam_pitch - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		_update_cam_rotation()
		return

	# Atajos de teletransporte numérico
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_teleport_to(Vector3(-10.0, 1.6, 2.5), 0.0, -0.1)
			KEY_2:
				_teleport_to(Vector3(0.0, 1.6, 3.5), 0.0, -0.1)
			KEY_3:
				_teleport_to(Vector3(14.0, 2.0, 4.5), 0.0, -0.1)
			KEY_4:
				_teleport_to(Vector3(24.0, 2.2, 4.5), 0.0, -0.1)
			KEY_5:
				_teleport_to(Vector3(29.5, 3.5, 7.5), 0.0, -0.25)
			KEY_0:
				_teleport_to(Vector3(8.0, 6.0, 18.0), 0.0, -0.28)


func _process(delta: float) -> void:
	if not is_instance_valid(_camera):
		return

	# Movimiento WASD / Libre
	var speed := SPRINT_SPEED if Input.is_physical_key_pressed(KEY_SHIFT) else MOVE_SPEED
	var input_dir := Vector3.ZERO

	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.z += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	var vert_dir := 0.0
	if Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_E):
		vert_dir += 1.0
	if Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_Q):
		vert_dir -= 1.0

	if input_dir.length_squared() > 0.001:
		input_dir = input_dir.normalized()
		var move_basis := Basis(Vector3.UP, _cam_yaw)
		var global_dir := (move_basis * input_dir)
		_camera.global_position += global_dir * speed * delta

	if absf(vert_dir) > 0.001:
		_camera.global_position.y += vert_dir * speed * delta


func _update_cam_rotation() -> void:
	if is_instance_valid(_camera):
		_camera.rotation = Vector3(_cam_pitch, _cam_yaw, 0.0)


func _teleport_to(pos: Vector3, yaw: float, pitch: float) -> void:
	if is_instance_valid(_camera):
		_camera.global_position = pos
		_cam_yaw = yaw
		_cam_pitch = pitch
		_update_cam_rotation()


func _build_all_showcase_objects() -> void:
	_engine = ObjectEngineScript.new()
	_engine.name = "ShowcaseObjectEngine"
	add_child(_engine)

	var builder := _engine.get_builder()

	# Plataforma pasarela del escaparate (Suelo largo de madera/concreto de 54m de largo)
	builder.add_box(
		Transform3D(Basis.IDENTITY, Vector3(10.5, -0.10, 0.0)),
		Vector3(54.0, 0.20, 8.0),
		"roble_claro",
		Rect2(0.0, 0.0, 6.0, 1.0),
		0.85, 0.0, true
	)

	# =========================================================================
	# LÍNEA DE EXPOSICIÓN ORDENADA POR TAMAÑO (De X=-12.0 a X=+28.0)
	# =========================================================================

	# 1. Medidor CFE (20cm) en pedestal/muro (X = -12.0)
	var wall_meter_t := Transform3D(Basis.IDENTITY, Vector3(-12.0, 1.0, -0.40))
	builder.add_box(wall_meter_t, Vector3(0.80, 2.0, 0.15), "commercial_cooler", Rect2(0.5, 0.5, 0.5, 0.5), 0.70, 0.0, true)
	ElectricMeterCFERecipeScript.build(builder, Transform3D(Basis.IDENTITY, Vector3(-12.0, 1.45, -0.32)), {"include_enclosure": true, "include_switch_box": true})

	# 2. Tostadora de Pan (26cm) sobre repisa (X = -10.5)
	builder.add_box(Transform3D(Basis.IDENTITY, Vector3(-10.5, 0.40, 0.0)), Vector3(0.60, 0.80, 0.60), "roble_claro", Rect2(0.0, 0.0, 0.5, 0.5), 0.55, 0.02, true)
	AppliancesRecipesScript.ToasterRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-10.5, 0.80, 0.0)))

	# 3. Horno Microondas (52cm) sobre repisa (X = -9.0)
	builder.add_box(Transform3D(Basis.IDENTITY, Vector3(-9.0, 0.40, 0.0)), Vector3(0.70, 0.80, 0.60), "roble_claro", Rect2(0.0, 0.0, 0.5, 0.5), 0.55, 0.02, true)
	AppliancesRecipesScript.MicrowaveRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-9.0, 0.80, 0.0)))

	# 4. Mesita de Noche (Cerrada) (48cm x 70cm) (X = -7.5)
	HouseFurnitureRecipesScript.NightstandRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-7.5, 0.0, 0.0)), {"is_open": false})

	# 5. Mesita de Noche (Cajón abierto deslizante) (X = -6.2)
	HouseFurnitureRecipesScript.NightstandRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-6.2, 0.0, 0.0)), {"is_open": true})

	# 6. Silla de Madera (44cm x 85cm) (X = -4.8)
	HouseFurnitureRecipesScript.ChairRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-4.8, 0.0, 0.0)))

	# 7. Sillón de Cuero (95cm x 85cm) (X = -3.2)
	HouseFurnitureRecipesScript.ArmchairRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-3.2, 0.0, 0.0)))

	# 8. Lavadora de Ropa (68cm x 90cm) (X = -1.6)
	AppliancesRecipesScript.WasherRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-1.6, 0.0, 0.0)))

	# 9. Secadora de Ropa (68cm x 90cm) (X = -0.5)
	AppliancesRecipesScript.DryerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.0, 0.0)))

	# 10. Estufa de Cocina con Quemadores (76cm x 86cm) (X = 0.8)
	AppliancesRecipesScript.StoveRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(0.8, 0.0, 0.0)))

	# 11. Mueble de Cocina Base (Cerrado) (85cm x 86cm) (X = 2.2)
	AppliancesRecipesScript.CabinetRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(2.2, 0.0, 0.0)), {"is_wall": false, "is_open": false})

	# 12. Mueble de Cocina Base (Puertas Abiertas) (X = 3.6)
	AppliancesRecipesScript.CabinetRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(3.6, 0.0, 0.0)), {"is_wall": false, "is_open": true})

	# 13. Fregadero / Tarja de Cocina con Grifo (85cm x 86cm) (X = 5.0)
	AppliancesRecipesScript.SinkRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(5.0, 0.0, 0.0)))

	# 14. Alacena Aérea de Pared (Wall Cabinet) (85cm x 68cm) suspendida a 1.2m (X = 6.4)
	AppliancesRecipesScript.CabinetRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(6.4, 0.60, 0.0)), {"is_wall": true, "is_open": true})

	# 15. Mesa de Comedor Maciza (1.40m x 85cm x 75cm) (X = 8.0)
	HouseFurnitureRecipesScript.TableRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(8.0, 0.0, 0.0)))

	# 16. Refrigerador Doméstico (Cerrado) (74cm x 1.70m) (X = 9.8)
	AppliancesRecipesScript.RefrigeratorRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(9.8, 0.0, 0.0)), {"is_open": false})

	# 17. Refrigerador Doméstico (Abierto con repisas y manijas) (X = 11.2)
	AppliancesRecipesScript.RefrigeratorRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(11.2, 0.0, 0.0)), {"is_open": true})

	# 18. Librero Alto (90cm x 1.90m) (X = 12.8)
	HouseFurnitureRecipesScript.BookcaseRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(12.8, 0.0, 0.0)))

	# 19. Ropero Alto (Cerrado) (1.10m x 1.95m) (X = 14.5)
	HouseFurnitureRecipesScript.WardrobeRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(14.5, 0.0, 0.0)), {"is_open": false})

	# 20. Ropero Alto (Puertas Abiertas con perchero) (X = 16.2)
	HouseFurnitureRecipesScript.WardrobeRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(16.2, 0.0, 0.0)), {"is_open": true})

	# 21. Cama Individual TENDIDA (MADE) (1.05m x 2.14m) con cobija Lobo San Marcos (#12) (X = 18.0)
	HouseFurnitureRecipesScript.BedRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(18.0, 0.0, 0.0)), {"bed_state": HouseFurnitureRecipesScript.BedRecipe.BedState.MADE, "blanket_id": 12, "sheet_id": 1})

	# 22. Cama Individual DESTENDIDA (UNMADE) (almohada ladeada 14° y cobija doblada a los pies) (X = 19.8)
	HouseFurnitureRecipesScript.BedRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(19.8, 0.0, 0.0)), {"bed_state": HouseFurnitureRecipesScript.BedRecipe.BedState.UNMADE, "blanket_id": 1, "sheet_id": 8})

	# 23. Cama Individual SIN COBIJA (STRIPPED) (solo sábana azul marino #6 y almohada) (X = 21.6)
	HouseFurnitureRecipesScript.BedRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(21.6, 0.0, 0.0)), {"bed_state": HouseFurnitureRecipesScript.BedRecipe.BedState.STRIPPED, "sheet_id": 6})

	# 24. Cama Individual COLCHÓN DESNUDO (BARE_MATTRESS) (colchón vintage rayado expuesto) (X = 23.4)
	HouseFurnitureRecipesScript.BedRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(23.4, 0.0, 0.0)), {"bed_state": HouseFurnitureRecipesScript.BedRecipe.BedState.BARE_MATTRESS})

	# 25. Estantería Comercial OXXO (2 Módulos, 2.0m x 1.80m) (X = 25.6)
	CommercialRecipesScript.CommercialShelfRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(25.6, 0.0, 0.0)), {"modules": 2})

	# 26. Vitrina Refrigerada Comercial 1 Puerta (1.0m x 2.05m) (X = 27.6)
	CommercialRecipesScript.CommercialCoolerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(27.6, 0.0, 0.0)), {"is_double": false, "doors_open": false})

	# 27. Vitrina Refrigerada Comercial 2 Puertas (Abierta con termostato -2.4°C) (1.8m x 2.05m) (X = 29.8)
	CommercialRecipesScript.CommercialCoolerRecipe.build(builder, Transform3D(Basis.IDENTITY, Vector3(29.8, 0.0, 0.0)), {"is_double": true, "doors_open": true})

	# 28. Poste de Alumbrado Público Gigante (6.80m de alto) (X = 33.0)
	StreetlightPoleRecipeScript.build(builder, Transform3D(Basis.IDENTITY, Vector3(33.0, 0.0, 0.0)), {"height": 6.8, "double_arm": true, "arm_reach": 1.5})

	# =========================================================================
	# EMPAQUETADO CENTRAL EN EL MOTOR DE OBJETOS
	# =========================================================================
	_engine.commit()

	var stats := _engine.get_stats()
	print("-----------------------------------------------------------------------")
	print("RESULTADOS TELEMETRÍA DE LA COLECCIÓN COMPLETA:")
	print("- Total de Objetos Distintos en Exposición: 26 Variantes")
	print("- Total de Piezas Geométricas en Escena: %d Instancias" % stats["total_instances"])
	print("- DRAW CALLS TOTALES PARA TODA LA COLECCIÓN: EXACTAMENTE %d" % stats["draw_calls"])
	print("- Primitivas Base Activas: %s" % str(stats["primitives_active"]))
	print("- Formas de Colisión Consolidadas: %d" % stats["collision_shapes"])
	print("-----------------------------------------------------------------------")

extends Node3D

const ProceduralFlower = preload("res://world/procedural_flora/procedural_flower.gd")
const FlowerProfiles = preload("res://world/procedural_flora/procedural_flower_profiles.gd")

## Visor interactivo e inspección del sistema botánico de rosas y flores.
## Permite experimentar con el ciclo de crecimiento en vivo, alternar entre
## la rosa de corte (tallo solitario) y el rosal arbustivo (zarza leñosa),
## cambiar de color, cosechar y rotar la cámara orbital.

@onready var rose_solitary: ProceduralFlower = $RoseSolitary
@onready var rose_shrub: ProceduralFlower = $RoseShrub
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

# Elementos del HUD
@onready var label_title: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelTitle
@onready var label_mode: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelMode
@onready var label_stage: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelStage
@onready var label_color: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelColor
@onready var label_seed: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelSeed
@onready var label_stats: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelStats
@onready var label_lod: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelLOD
@onready var label_autogrow: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelAutoGrow
@onready var label_wind: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelWind
@onready var progress_slider: HSlider = $HUD/Margin/VBox/Panel/Margin/VBox/HBoxSlider/SliderGrowth

var _camera_distance: float = 1.20
var _camera_pitch: float = deg_to_rad(24.0)
var _camera_yaw: float = 0.0
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _display_mode := 2 # 2 = Rosal Arbustivo, 1 = Solo Solitaria (Rosa de corte), 0 = Lado a Lado
var _current_seed := 12345
var _current_color_idx := 1 # 1 = Rosa Coral / Salmón (como la foto de referencia que envió el usuario)
var _current_growth := 1.0
var _forced_lod := -1 # -1 = Auto (distancia), 0 = LOD0, 1 = LOD1, 2 = LOD2
var _wind_active := true
var _auto_grow_active := false

var _hud_update_timer: float = 0.0

func _ready() -> void:
	var vp = get_viewport()
	if vp:
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	
	_update_camera_transform()
	_apply_setup()
	
	if progress_slider:
		progress_slider.value = _current_growth
		progress_slider.value_changed.connect(_on_slider_changed)


func _process(delta: float) -> void:
	if _auto_grow_active:
		_current_growth += delta * 0.05
		if _current_growth > 1.0:
			_current_growth = 0.0 # Bucle de germinación continua
		if progress_slider:
			progress_slider.set_value_no_signal(_current_growth)
		_sync_growth_to_flowers()
	
	_hud_update_timer += delta
	if _hud_update_timer >= 0.1:
		_hud_update_timer = 0.0
		_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# [Espacio] o [R]: Nueva semilla aleatoria
		if event.keycode == KEY_R or event.keycode == KEY_SPACE:
			_current_seed = randi() % 1000000
			_apply_setup()
			return
		
		# [M]: Alternar modo de visualización (Ambas / Solitaria / Arbusto)
		if event.keycode == KEY_M:
			_display_mode = (_display_mode + 1) % 3
			_apply_visibility()
			return
		
		# [C]: Ciclar entre las 6 paletas de colores de rosas
		if event.keycode == KEY_C:
			_current_color_idx = (_current_color_idx + 1) % FlowerProfiles.ROSE_PALETTES.size()
			_apply_colors()
			return
		
		# [G]: Alternar crecimiento automático
		if event.keycode == KEY_G:
			_auto_grow_active = not _auto_grow_active
			return
		
		# [W]: Alternar viento en shader
		if event.keycode == KEY_W:
			_wind_active = not _wind_active
			rose_solitary.wind_enabled = _wind_active
			rose_shrub.wind_enabled = _wind_active
			return
		
		# [L]: Alternar nivel de LOD (-1 = Auto por distancia, 0 = LOD0, 1 = LOD1, 2 = LOD2)
		if event.keycode == KEY_L:
			_forced_lod = -1 if _forced_lod >= 2 else _forced_lod + 1
			_apply_lod()
			return
		
		# [H]: Cosechar rosas (Harvest)
		if event.keycode == KEY_H:
			_harvest_active_flowers()
			return
		
		# [1 - 4]: Saltar directamente a etapas botánicas
		if event.keycode == KEY_1:
			_set_growth_value(0.10) # Brote
		elif event.keycode == KEY_2:
			_set_growth_value(0.40) # Vegetativo
		elif event.keycode == KEY_3:
			_set_growth_value(0.68) # Capullo
		elif event.keycode == KEY_4:
			_set_growth_value(1.00) # Floración plena
		
		# Flechas Izquierda/Derecha: Crecimiento manual paso a paso
		if event.keycode == KEY_LEFT:
			_set_growth_value(maxf(_current_growth - 0.05, 0.0))
		elif event.keycode == KEY_RIGHT:
			_set_growth_value(minf(_current_growth + 0.05, 1.0))
	
	# Control orbital de cámara
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_dragging = event.pressed
			_last_mouse_pos = event.position
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_distance = maxf(_camera_distance - 0.25, 0.7)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_distance = minf(_camera_distance + 0.35, 12.0)
			_update_camera_transform()
	
	if event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.008
		_camera_pitch = clampf(_camera_pitch + delta.y * 0.008, deg_to_rad(-20.0), deg_to_rad(75.0))
		_update_camera_transform()


func _on_slider_changed(val: float) -> void:
	_auto_grow_active = false
	_current_growth = val
	_sync_growth_to_flowers()


func _set_growth_value(val: float) -> void:
	_auto_grow_active = false
	_current_growth = val
	if progress_slider:
		progress_slider.value = val
	_sync_growth_to_flowers()


func _sync_growth_to_flowers() -> void:
	if is_instance_valid(rose_solitary):
		rose_solitary.growth_progress = _current_growth
	if is_instance_valid(rose_shrub):
		rose_shrub.growth_progress = _current_growth


func _apply_setup() -> void:
	if not is_instance_valid(rose_solitary) or not is_instance_valid(rose_shrub):
		return
	rose_solitary.begin_batch_update()
	rose_solitary.profile_id = "solitary_rose"
	rose_solitary.flower_seed = _current_seed
	rose_solitary.color_index = _current_color_idx
	rose_solitary.wind_enabled = _wind_active
	rose_solitary.growth_progress = _current_growth
	rose_solitary.end_batch_update()
	
	rose_shrub.begin_batch_update()
	rose_shrub.profile_id = "shrub_rose"
	rose_shrub.flower_seed = _current_seed + 999
	rose_shrub.color_index = _current_color_idx
	rose_shrub.wind_enabled = _wind_active
	rose_shrub.growth_progress = _current_growth
	rose_shrub.end_batch_update()
	
	rose_solitary.forced_lod_level = _forced_lod
	rose_shrub.forced_lod_level = _forced_lod
	
	_apply_visibility()
	_update_hud()


func _apply_lod() -> void:
	if is_instance_valid(rose_solitary):
		rose_solitary.forced_lod_level = _forced_lod
	if is_instance_valid(rose_shrub):
		rose_shrub.forced_lod_level = _forced_lod
	_update_hud()


func _apply_visibility() -> void:
	match _display_mode:
		0: # Ambas (Comparativa Lado a Lado)
			rose_solitary.visible = true
			rose_shrub.visible = true
			rose_solitary.position = Vector3(-0.35, 0, 0.15)
			rose_shrub.position = Vector3(0.42, 0, -0.10)
			camera_pivot.position = Vector3(0.12, 0.40, 0)
			_camera_distance = 1.95
			_camera_pitch = deg_to_rad(20.0)
		1: # Solo solitaria (Rosa de corte como en la foto)
			rose_solitary.visible = true
			rose_shrub.visible = false
			rose_solitary.position = Vector3(0.28, 0, 0)
			camera_pivot.position = Vector3(0.28, 0.35, 0)
			_camera_distance = 0.68
			_camera_pitch = deg_to_rad(20.0)
			_camera_yaw = deg_to_rad(-16.0)
		2: # Solo arbusto (Rosal silvestre)
			rose_solitary.visible = false
			rose_shrub.visible = true
			rose_shrub.position = Vector3(0.28, 0, 0)
			camera_pivot.position = Vector3(0.28, 0.45, 0)
			_camera_distance = 1.45
			_camera_pitch = deg_to_rad(22.0)
			_camera_yaw = deg_to_rad(-12.0)
	
	_update_camera_transform()


func _apply_colors() -> void:
	rose_solitary.color_index = _current_color_idx
	rose_shrub.color_index = _current_color_idx
	_update_hud()


func _harvest_active_flowers() -> void:
	var harvested_count := 0
	if rose_solitary.visible:
		var y1 = rose_solitary.harvest()
		if not y1.is_empty():
			harvested_count += int(y1["flower_count"])
	if rose_shrub.visible:
		var y2 = rose_shrub.harvest()
		if not y2.is_empty():
			harvested_count += int(y2["flower_count"])
	
	if harvested_count > 0:
		_current_growth = rose_shrub.growth_progress if _display_mode == 2 else rose_solitary.growth_progress
		if progress_slider:
			progress_slider.value = _current_growth
		_update_hud()


func _update_camera_transform() -> void:
	var x := _camera_distance * cos(_camera_pitch) * sin(_camera_yaw)
	var y := _camera_distance * sin(_camera_pitch)
	var z := _camera_distance * cos(_camera_pitch) * cos(_camera_yaw)
	camera.position = Vector3(x, y, z)
	camera.look_at(camera_pivot.global_position, Vector3.UP)


func _update_hud() -> void:
	if not label_mode:
		return
	
	var mode_names = ["Comparativa (Lado a Lado)", "Rosa Solitaria (Corte)", "Rosal Arbustivo (Zarza)"]
	label_mode.text = "Modo: %s [M]" % mode_names[_display_mode]
	
	var stage_name := rose_shrub.get_stage_name() if _display_mode == 2 else rose_solitary.get_stage_name()
	label_stage.text = "Etapa: %s (%d%%)" % [stage_name, int(_current_growth * 100.0)]
	
	var color_name: String = FlowerProfiles.ROSE_COLOR_NAMES[_current_color_idx]
	label_color.text = "Color: %s [C]" % color_name
	label_seed.text = "Semilla: %d [R/Espacio]" % _current_seed
	
	var h_sol := rose_solitary.get_flower_height() * 100.0
	var h_shrub := rose_shrub.get_flower_height() * 100.0
	var f_sol := rose_solitary.get_flower_count()
	var f_shrub := rose_shrub.get_flower_count()
	
	var active_plant: ProceduralFlower = rose_shrub if _display_mode == 2 else rose_solitary
	var tris_active := active_plant.get_triangle_count()
	var verts_active := active_plant.get_vertex_count()
	
	if _display_mode == 0:
		var tris_sol := rose_solitary.get_triangle_count()
		var tris_shrub := rose_shrub.get_triangle_count()
		var verts_sol := rose_solitary.get_vertex_count()
		var verts_shrub := rose_shrub.get_vertex_count()
		label_stats.text = "Solitaria: %d tris (%d v) | Rosal: %d tris (%d v)" % [tris_sol, verts_sol, tris_shrub, verts_shrub]
	elif _display_mode == 1:
		label_stats.text = "Altura: %.1f cm | Flores: %d | Triángulos: %d (Vértices: %d)" % [h_sol, f_sol, tris_active, verts_active]
	else:
		label_stats.text = "Altura: %.1f cm | Flores: %d | Triángulos: %d (Vértices: %d)" % [h_shrub, f_shrub, tris_active, verts_active]
	
	if label_lod:
		var lod_str := "AUTO (Distancia)"
		match _forced_lod:
			0: lod_str = "FORZADO: LOD 0 (Alta calidad)"
			1: lod_str = "FORZADO: LOD 1 (Prisma 3D + Planos)"
			2: lod_str = "FORZADO: LOD 2 (Triángulo 2D)"
		
		var t0: int = active_plant.get_triangle_count_lod(0)
		var t1: int = active_plant.get_triangle_count_lod(1)
		var t2: int = active_plant.get_triangle_count_lod(2)
		var p1: float = (1.0 - float(t1) / maxf(float(t0), 1.0)) * 100.0
		var p2: float = (1.0 - float(t2) / maxf(float(t0), 1.0)) * 100.0
		
		label_lod.text = "LOD: %s [L]\n  LOD0: %d tris | LOD1: %d tris (-%.0f%%) | LOD2: %d tris (-%.0f%%)" % [
			lod_str, t0, t1, p1, t2, p2
		]
	
	label_autogrow.text = "Auto-crecimiento: %s [G]" % ("ACTIVADO (45s ciclo)" if _auto_grow_active else "Pausado")
	label_wind.text = "Viento en Shader: %s [W]" % ("ON" if _wind_active else "OFF")


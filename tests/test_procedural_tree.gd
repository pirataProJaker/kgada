extends Node3D

const ProceduralTree = preload("res://world/procedural_trees/procedural_tree.gd")
## Controlador interactivo de la escena de prueba de arboles procedurales.
## Permite regenerar arboles con la tecla [R], cambiar perfiles con [1-6],
## forzar niveles de LOD con [L], y navegar con la camara para observar
## la optimizacion de cerca y de lejos.

@onready var tree: ProceduralTree = $ProceduralTree
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var camera_pivot: Node3D = $CameraPivot

# Elementos del HUD
@onready var label_title: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelTitle
@onready var label_profile: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelProfile
@onready var label_seed: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelSeed
@onready var label_distance: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelDistance
@onready var label_lod: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelLOD
@onready var label_stats: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelStats
@onready var label_draw_calls: Label = $HUD/Margin/VBox/Panel/Margin/VBox/LabelDrawCalls

var _camera_distance: float = 14.0
var _camera_pitch: float = deg_to_rad(15.0)
var _camera_yaw: float = 0.0
var _is_mouse_dragging := false
var _last_mouse_pos := Vector2.ZERO

var _profile_keys := [
	"pine_boreal",
	"classic_oak",
	"autumn_birch",
	"weeping_willow",
	"dead_tree",
	"shrub_sapling"
]
var _current_profile_index := 0
var _current_seed := 12345
var _forced_lod_state := -1 # -1 = Auto, 0 = LOD0, 1 = LOD1, 2 = LOD2


func _ready() -> void:
	# Activar antialiasing nativo para eliminar ruido en follaje con corte alfa
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_update_camera_transform()
	_apply_tree_generation(_current_seed, _profile_keys[_current_profile_index])


func _process(_delta: float) -> void:
	_update_hud_realtime()


func _unhandled_input(event: InputEvent) -> void:
	# Regenerar con nueva semilla aleatoria con [R] o [Espacio]
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R or event.keycode == KEY_SPACE:
			_current_seed = randi() % 1000000
			_apply_tree_generation(_current_seed, _profile_keys[_current_profile_index])
			return
		
		# Seleccionar especie por numero [1 a 6]
		if event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var idx: int = int(event.keycode) - int(KEY_1)
			if idx < _profile_keys.size():
				_current_profile_index = idx
				_apply_tree_generation(_current_seed, _profile_keys[_current_profile_index])
			return
		
		# Alternar modo forzado de LOD con [L]
		if event.keycode == KEY_L:
			_forced_lod_state += 1
			if _forced_lod_state > 2:
				_forced_lod_state = -1 # Regresar a Auto
			tree.forced_lod_level = _forced_lod_state
			return
		
		# Alternar textura de ramillete de hojas con [T]
		if event.keycode == KEY_T:
			tree.use_foliage_textures = not tree.use_foliage_textures
			return
	
	# Control de camara orbital con raton
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_mouse_dragging = event.pressed
			_last_mouse_pos = event.position
		
		# Zoom con rueda de raton
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_camera_distance = maxf(_camera_distance - 1.5, 1.5)
			_update_camera_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_camera_distance = minf(_camera_distance + 2.5, 150.0)
			_update_camera_transform()
	
	if event is InputEventMouseMotion and _is_mouse_dragging:
		var delta: Vector2 = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_camera_yaw -= delta.x * 0.008
		_camera_pitch = clampf(_camera_pitch - delta.y * 0.008, deg_to_rad(-25.0), deg_to_rad(85.0))
		_update_camera_transform()


func _update_camera_transform() -> void:
	if camera_pivot == null or camera == null:
		return
	camera_pivot.rotation = Vector3(_camera_pitch, _camera_yaw, 0.0)
	camera.position = Vector3(0.0, 0.0, _camera_distance)


func _apply_tree_generation(seed_val: int, prof_id: String) -> void:
	if tree == null:
		return
	var res := tree.generate(seed_val, prof_id)
	
	# Centrar el pivote de la camara a una altura proporcional a este arbol
	var target_y := 4.0
	if tree.current_profile:
		target_y = (tree.current_profile.trunk_height_min + tree.current_profile.trunk_height_max) * 0.35
	camera_pivot.position = Vector3(0.0, target_y, 0.0)


func _update_hud_realtime() -> void:
	if tree == null or tree.current_profile == null or tree.current_generation_result == null:
		return
	
	var prof := tree.current_profile
	var res := tree.current_generation_result
	var dist := camera.global_position.distance_to(tree.global_position + Vector3(0, camera_pivot.position.y, 0))
	
	label_title.text = "ARBOL PROCEDURAL ULTRA-OPTIMIZADO"
	label_profile.text = "Especie: %s\nBioma: %s" % [prof.name, prof.biome_description]
	label_seed.text = "Semilla (Seed): %d" % res.seed_used
	label_distance.text = "Distancia de Camara: %.1f m" % dist
	
	# Determinar cual LOD esta activo segun distancia o forzado
	var active_lod := 0
	if _forced_lod_state >= 0:
		active_lod = _forced_lod_state
		label_lod.text = "Modo LOD: FORZADO A LOD %d (Presiona [L] para cambiar)" % active_lod
	else:
		if dist < tree.lod0_range_end:
			active_lod = 0
		elif dist < tree.lod1_range_end:
			active_lod = 1
		else:
			active_lod = 2
		label_lod.text = "Modo LOD: AUTOMATICO (Activo: LOD %d)" % active_lod
	
	# Mostrar estadisticas del nivel activo
	var b_count := 0
	var l_count := 0
	match active_lod:
		0:
			b_count = res.lod0_branches_count
			l_count = res.lod0_leaves_count
		1:
			b_count = res.lod1_branches_count
			l_count = res.lod1_leaves_count
		2:
			b_count = res.lod2_branches_count
			l_count = res.lod2_leaves_count
	
	var total_triangles := (b_count * 12) + (l_count * 1) # 12 tri por cono (6 caras x 2), 1 tri por hoja
	label_stats.text = "Instancias activas en LOD %d:\n • Conos de madera: %d\n • Hojas (1 triangulo): %d\n • Total triangulos estimados: %d" % [
		active_lod, b_count, l_count, total_triangles
	]
	
	var tex_status := "ACTIVADA (Ramillete con corte alfa)" if tree.use_foliage_textures else "DESACTIVADA (Color base)"
	label_draw_calls.text = "Draw Calls totales: EXACTAMENTE 2 (GPU MultiMesh)\nTextura de Hojas: %s [T]" % tex_status

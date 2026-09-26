extends Node3D

const BotanicalTreeView = preload("res://world/botanical_trees/botanical_tree_view.gd")

# Nodos Principales
@onready var cam: Camera3D = $Camera3D
@onready var single_tree_container: Node3D = $SingleTreeContainer
@onready var lod_lineup_container: Node3D = $LODLineupContainer
@onready var timeline_container: Node3D = $TimelineContainer

# UI Elements
@onready var mode_tabs: HBoxContainer = $UI/PanelMain/VBox/ModeTabs
@onready var growth_box: VBoxContainer = $UI/PanelMain/VBox/GrowthControls
@onready var lod_box: VBoxContainer = $UI/PanelMain/VBox/LODControls
@onready var prune_box: VBoxContainer = $UI/PanelMain/VBox/PruneControls

@onready var age_slider: HSlider = $UI/PanelMain/VBox/GrowthControls/AgeSlider
@onready var age_value_label: Label = $UI/PanelMain/VBox/GrowthControls/AgeValueLabel

@onready var info_species: Label = $UI/PanelStats/VBox/SpeciesLabel
@onready var info_height: Label = $UI/PanelStats/VBox/HeightLabel
@onready var info_branches: Label = $UI/PanelStats/VBox/BranchesLabel
@onready var info_triangles: Label = $UI/PanelStats/VBox/TrianglesLabel
@onready var info_lod: Label = $UI/PanelStats/VBox/LODLabel

# Estado de Showcase
var current_mode: int = 0 # 0: Interactivo, 1: Comparativa LODs, 2: Línea de tiempo
var main_tree: BotanicalTreeView = null
var rotating: bool = true
var rotation_speed: float = 0.35

# LOD Lineup Trees
var lod_trees: Array[BotanicalTreeView] = []

# Timeline Trees
var timeline_trees: Array[BotanicalTreeView] = []

# Cámara libre
var mouse_captured: bool = false
var pitch: float = deg_to_rad(6.0)
var yaw: float = 0.0
var move_speed: float = 16.0

var _initialized: bool = false

func _ready() -> void:
	if _initialized:
		return
	_initialized = true
	_setup_main_tree()
	_setup_lod_lineup()
	_setup_timeline()
	_setup_ui()
	_switch_mode(0)
	_capture_mouse(false)

func _setup_main_tree() -> void:
	main_tree = BotanicalTreeView.new()
	main_tree.name = "InteractiveTree"
	main_tree.species_id = "alnus_acuminata"
	main_tree.tree_seed = 12345
	main_tree.age = 0.85
	main_tree.forced_lod = 0
	main_tree.tree_updated.connect(_on_main_tree_updated)
	single_tree_container.add_child(main_tree)
	_update_stats()

func _setup_lod_lineup() -> void:
	lod_trees.clear()
	var offsets = [-9.0, -3.0, 3.0, 9.0]
	
	for lod in range(4):
		var tree = BotanicalTreeView.new()
		tree.name = "Tree_LOD%d" % lod
		tree.species_id = "alnus_acuminata"
		tree.tree_seed = 12345
		tree.age = 0.85
		tree.forced_lod = lod
		tree.position = Vector3(offsets[lod], 0, 0)
		lod_lineup_container.add_child(tree)
		lod_trees.append(tree)

func _setup_timeline() -> void:
	timeline_trees.clear()
	var ages = [0.08, 0.30, 0.65, 1.0]
	var offsets = [-9.0, -3.0, 3.0, 9.0]
	
	for i in range(4):
		var tree = BotanicalTreeView.new()
		tree.name = "Tree_Timeline_%d" % i
		tree.species_id = "alnus_acuminata"
		tree.tree_seed = 12345
		tree.age = ages[i]
		tree.forced_lod = 0
		tree.position = Vector3(offsets[i], 0, 0)
		timeline_container.add_child(tree)
		timeline_trees.append(tree)

func _setup_ui() -> void:
	# Mode buttons
	$UI/PanelMain/VBox/ModeTabs/BtnModeInteractive.pressed.connect(func(): _switch_mode(0))
	$UI/PanelMain/VBox/ModeTabs/BtnModeLODs.pressed.connect(func(): _switch_mode(1))
	$UI/PanelMain/VBox/ModeTabs/BtnModeTimeline.pressed.connect(func(): _switch_mode(2))
	
	# Age slider
	age_slider.value_changed.connect(_on_age_slider_changed)
	
	# Growth stages quick buttons
	$UI/PanelMain/VBox/GrowthControls/StageButtons/BtnSprout.pressed.connect(func(): _set_tree_age(0.08))
	$UI/PanelMain/VBox/GrowthControls/StageButtons/BtnSapling.pressed.connect(func(): _set_tree_age(0.30))
	$UI/PanelMain/VBox/GrowthControls/StageButtons/BtnYoung.pressed.connect(func(): _set_tree_age(0.60))
	$UI/PanelMain/VBox/GrowthControls/StageButtons/BtnMature.pressed.connect(func(): _set_tree_age(1.0))
	
	# Pruning buttons
	$UI/PanelMain/VBox/PruneControls/BtnPrune.pressed.connect(_on_prune_pressed)
	$UI/PanelMain/VBox/PruneControls/BtnRestore.pressed.connect(_on_restore_pressed)
	$UI/PanelMain/VBox/PruneControls/BtnNewSeed.pressed.connect(_on_new_seed_pressed)
	
	# LOD buttons
	$UI/PanelMain/VBox/LODControls/LODButtons/BtnLODAuto.pressed.connect(func(): _set_forced_lod(-1))
	$UI/PanelMain/VBox/LODControls/LODButtons/BtnLOD0.pressed.connect(func(): _set_forced_lod(0))
	$UI/PanelMain/VBox/LODControls/LODButtons/BtnLOD1.pressed.connect(func(): _set_forced_lod(1))
	$UI/PanelMain/VBox/LODControls/LODButtons/BtnLOD2.pressed.connect(func(): _set_forced_lod(2))
	$UI/PanelMain/VBox/LODControls/LODButtons/BtnLOD3.pressed.connect(func(): _set_forced_lod(3))
	
	# Camera and turntable
	$UI/PanelMain/VBox/ControlsMisc/BtnRotate.pressed.connect(func(): rotating = not rotating)
	$UI/PanelMain/VBox/ControlsMisc/BtnCamReset.pressed.connect(_reset_camera)

func _switch_mode(mode: int) -> void:
	current_mode = mode
	single_tree_container.visible = (mode == 0)
	lod_lineup_container.visible = (mode == 1)
	timeline_container.visible = (mode == 2)
	
	growth_box.visible = (mode == 0)
	lod_box.visible = (mode == 0)
	prune_box.visible = (mode == 0)
	
	if mode == 0:
		_set_cam_preset(Vector3(1.5, 8.5, 20), 4.0)
		_update_stats()
	elif mode == 1:
		_set_cam_preset(Vector3(2.5, 9.0, 26), 4.0)
		_update_lod_lineup_stats()
	elif mode == 2:
		_set_cam_preset(Vector3(2.5, 9.0, 26), 4.0)
		_update_timeline_stats()

func _on_age_slider_changed(val: float) -> void:
	_set_tree_age(val)

func _set_tree_age(val: float) -> void:
	age_slider.value = val
	if main_tree:
		main_tree.age = val
	
	# Si estamos en modo LODs, actualizar todos los árboles de la comparativa
	for t in lod_trees:
		t.age = val

func _set_forced_lod(lod: int) -> void:
	if main_tree:
		main_tree.forced_lod = lod
		_update_stats()

func _on_prune_pressed() -> void:
	if main_tree:
		var cut: int = main_tree.prune_random_branch()
		print("Poda ejecutada: %d nodos retirados." % cut)
		_update_stats()

func _on_restore_pressed() -> void:
	if main_tree:
		main_tree.restore_all_branches()
		_update_stats()

func _on_new_seed_pressed() -> void:
	var new_s := randi() % 999999 + 1
	if main_tree:
		main_tree.tree_seed = new_s
	for t in lod_trees:
		t.tree_seed = new_s
	for t in timeline_trees:
		t.tree_seed = new_s
	_update_stats()

func _on_main_tree_updated(_h: float, _tris: int, _branches: int) -> void:
	_update_stats()

func _update_stats() -> void:
	if not main_tree:
		return
	
	var h := main_tree.get_height()
	var tris := main_tree.get_total_triangles()
	var branches := main_tree.get_branch_count()
	var lod_str := "LOD %d" % (main_tree.forced_lod if main_tree.forced_lod >= 0 else 0)
	if main_tree.forced_lod < 0:
		lod_str = "Auto (Dinámico)"
	
	var age_pct := int(round(main_tree.age * 100.0))
	age_value_label.text = "Edad: %d%% (%.2f / 1.00)" % [age_pct, main_tree.age]
	
	info_species.text = "Especie: Alnus acuminata (Aliso común)"
	info_height.text = "Altura Biológica: %.2f metros" % h
	info_branches.text = "Ramas Vivas: %d" % branches
	info_triangles.text = "Triángulos Totales: %d" % tris
	info_lod.text = "Nivel de LOD: %s" % lod_str

func _update_lod_lineup_stats() -> void:
	info_species.text = "Modo: Comparativa de 4 LODs Simultáneos"
	info_height.text = "Altura Común: %.2f m" % (lod_trees[0].get_height() if lod_trees.size() > 0 else 0.0)
	info_branches.text = "Ramas: %d" % (lod_trees[0].get_branch_count() if lod_trees.size() > 0 else 0)
	
	var t0 = lod_trees[0].get_total_triangles(0) if lod_trees.size() > 0 else 0
	var t1 = lod_trees[1].get_total_triangles(1) if lod_trees.size() > 1 else 0
	var t2 = lod_trees[2].get_total_triangles(2) if lod_trees.size() > 2 else 0
	var t3 = lod_trees[3].get_total_triangles(3) if lod_trees.size() > 3 else 0
	info_triangles.text = "LOD0: %d | LOD1: %d | LOD2: %d | LOD3: %d" % [t0, t1, t2, t3]
	info_lod.text = "LOD 0 -> 1 -> 2 -> 3"

func _update_timeline_stats() -> void:
	info_species.text = "Modo: Línea de Tiempo de Crecimiento Continuo"
	info_height.text = "Evolución: 0.22 m (Brote) -> 18.0 m (Adulto)"
	info_branches.text = "Morfología: Engrosamiento de ramas primarias"
	info_triangles.text = "Geometría: Prismas triangulares ultra-ligeros"
	info_lod.text = "LOD 0 completo"

func _process(delta: float) -> void:
	if rotating:
		if current_mode == 0 and single_tree_container:
			single_tree_container.rotate_y(rotation_speed * delta)
		elif current_mode == 1 and lod_lineup_container:
			for t in lod_trees:
				t.rotate_y(rotation_speed * delta)
		elif current_mode == 2 and timeline_container:
			for t in timeline_trees:
				t.rotate_y(rotation_speed * delta)
	
	if mouse_captured:
		var dir := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): dir += -cam.global_transform.basis.z
		if Input.is_physical_key_pressed(KEY_S): dir += cam.global_transform.basis.z
		if Input.is_physical_key_pressed(KEY_A): dir += -cam.global_transform.basis.x
		if Input.is_physical_key_pressed(KEY_D): dir += cam.global_transform.basis.x
		if Input.is_physical_key_pressed(KEY_E): dir += Vector3.UP
		if Input.is_physical_key_pressed(KEY_Q): dir += Vector3.DOWN
		
		var spd = move_speed * (2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
		if dir.length_squared() > 0.001:
			cam.global_position += dir.normalized() * spd * delta

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_capture_mouse(false)
		elif event.keycode == KEY_1:
			_switch_mode(0)
		elif event.keycode == KEY_2:
			_switch_mode(1)
		elif event.keycode == KEY_3:
			_switch_mode(2)
		elif event.keycode == KEY_R or event.keycode == KEY_SPACE:
			rotating = not rotating
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
			_capture_mouse(true)
	elif event is InputEventMouseMotion and mouse_captured:
		var sens := 0.003
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, -1.4, 1.4)
		cam.rotation = Vector3(pitch, yaw, 0.0)

func _set_cam_preset(target_pos: Vector3, pitch_deg: float) -> void:
	cam.position = target_pos
	pitch = deg_to_rad(pitch_deg)
	yaw = 0.0
	cam.rotation = Vector3(pitch, yaw, 0.0)

func _reset_camera() -> void:
	_set_cam_preset(Vector3(0, 7.5, 20), 4.0)

func _capture_mouse(capture: bool) -> void:
	mouse_captured = capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

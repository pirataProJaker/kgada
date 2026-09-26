extends SceneTree

var _frames := 0
var _scene: Node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/79db2cc8-f315-455f-b908-b6920dd6fb96"

func _init() -> void:
	var scene_res: PackedScene = load("res://scenes/botanical_growth_showcase.tscn")
	_scene = scene_res.instantiate()
	root.add_child(_scene)
	print("✓ Botanical Showcase instanciado para captura.")

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()
	
	# Captura 1: Modo 0 - Árbol Interactivo Adulto (LOD 0)
	if _frames == 20:
		if _scene and _scene.has_method("_switch_mode"):
			_scene.rotating = false
			_scene._switch_mode(0)
	elif _frames == 35:
		if vp:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png(ARTIFACT_DIR + "/botanical_mature_interactive.png")
					print("✓ Captura 1: botanical_mature_interactive.png guardada.")
	
	# Captura 2: Modo 1 - Comparativa de 4 LODs Simultáneos
	elif _frames == 40:
		if _scene and _scene.has_method("_switch_mode"):
			_scene._switch_mode(1)
	elif _frames == 55:
		if vp:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png(ARTIFACT_DIR + "/botanical_lod_lineup.png")
					print("✓ Captura 2: botanical_lod_lineup.png guardada.")
	
	# Captura 3: Modo 2 - Línea de Tiempo de Crecimiento
	elif _frames == 60:
		if _scene and _scene.has_method("_switch_mode"):
			_scene._switch_mode(2)
	elif _frames == 75:
		if vp:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png(ARTIFACT_DIR + "/botanical_growth_timeline.png")
					print("✓ Captura 3: botanical_growth_timeline.png guardada.")
	
	# Captura 4: Poda Interactiva
	elif _frames == 80:
		if _scene and _scene.has_method("_switch_mode"):
			_scene._switch_mode(0)
			_scene._on_prune_pressed()
			_scene._on_prune_pressed()
	elif _frames == 95:
		if vp:
			var tex = vp.get_texture()
			if tex:
				var img = tex.get_image()
				if img:
					img.save_png(ARTIFACT_DIR + "/botanical_pruned_tree.png")
					print("✓ Captura 4: botanical_pruned_tree.png guardada.")
		quit(0)
		return true
		
	return false

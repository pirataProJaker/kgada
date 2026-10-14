extends SceneTree

var _frames := 0
var _showcase_node = null
const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d"

func _init() -> void:
	var scn = load("res://scenes/military_base_showcase.tscn")
	_showcase_node = scn.instantiate()
	root.add_child(_showcase_node)

func _process(_delta: float) -> bool:
	_frames += 1
	var vp = root.get_viewport()

	if _frames == 5:
		# Desactivar sombras de la luz direccional temporalmente para una vista limpia de la textura
		var sun: DirectionalLight3D = _showcase_node.get_node_or_null("MilitarySun")
		if sun:
			sun.shadow_enabled = false
			sun.light_energy = 1.3

		var compound = _showcase_node._compound
		var gate_pos = compound.checkpoint_gate_position
		var cam: Camera3D = _showcase_node._camera
		
		# Vista cenital elevada (ángulo de 70° hacia el suelo del portón)
		cam.look_at_from_position(
			gate_pos + Vector3(0.0, 5.5, -3.2),
			gate_pos + Vector3(0.0, 0.0, 0.2),
			Vector3.UP
		)

	elif _frames == 12:
		# Captura de Variante 1 (2 franjas gruesas actualmente instalada)
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/in_game_gate_hazard_2cycles.png")
				print("✓ Captura 3D guardada: in_game_gate_hazard_2cycles.png")

	elif _frames == 15:
		# Cambiar la textura a Variante 2 (3 franjas) para la siguiente foto
		var tex_3cycles := Image.load_from_file(ARTIFACT_DIR + "/hazard_road_6x3_variant_3cycles.png")
		# Extraer 1 baldosa de 256x256
		var tile_3c := tex_3cycles.get_region(Rect2i(0, 0, 256, 256))
		tile_3c.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
		
		# Regenerar la base para que recargue el Texture2DArray con la variante 2
		_showcase_node._regenerate_base()
		
		# Reubicar cámara cenital
		var compound = _showcase_node._compound
		var gate_pos = compound.checkpoint_gate_position
		var cam: Camera3D = _showcase_node._camera
		cam.look_at_from_position(
			gate_pos + Vector3(0.0, 5.5, -3.2),
			gate_pos + Vector3(0.0, 0.0, 0.2),
			Vector3.UP
		)

	elif _frames == 22:
		# Captura de Variante 2 (3 franjas medianas)
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/in_game_gate_hazard_3cycles.png")
				print("✓ Captura 3D guardada: in_game_gate_hazard_3cycles.png")

	elif _frames >= 25:
		# Restaurar variante 1 como default en el asset oficial
		var cal_tile := Image.load_from_file(ARTIFACT_DIR + "/master_hazard_tile_256.png")
		if cal_tile:
			cal_tile.save_png("res://assets/textures/military/military_tile_32_r3_c7.png")
		quit(0)

	return false

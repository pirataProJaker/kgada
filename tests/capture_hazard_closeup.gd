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

	if _frames == 10:
		# Closeup de las franjas de advertencia en el portón
		var compound = _showcase_node._compound
		var gate_pos = compound.checkpoint_gate_position
		var cam: Camera3D = _showcase_node._camera
		# Posición elevada en ángulo de 50° para apreciar la cuadrícula perfectamente
		cam.look_at_from_position(
			gate_pos + Vector3(0.0, 4.0, -4.5),
			gate_pos + Vector3(0.0, 0.0, 0.5),
			Vector3.UP
		)

	elif _frames == 18:
		if vp:
			var img = vp.get_texture().get_image()
			if img:
				img.save_png(ARTIFACT_DIR + "/hazard_gate_closeup_calibrated.png")
				print("✓ Captura guardada: hazard_gate_closeup_calibrated.png")

	elif _frames >= 22:
		quit(0)

	return false

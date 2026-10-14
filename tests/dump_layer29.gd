extends SceneTree

const FacilityCompoundControllerScript = preload("res://world/facility/facility_compound_controller.gd")

func _init() -> void:
	var controller := FacilityCompoundControllerScript.new()
	var tex_arr: Texture2DArray = controller.get_ground_texture_array()
	print("Texture2DArray layers count: ", tex_arr.get_layers())
	
	# Layer 29
	var layer29 := tex_arr.get_layer_data(29)
	if layer29:
		layer29.save_png("C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/ed0523d0-0f90-456b-8f6a-677d5418d15d/debug_layer29_dump.png")
		print("✓ Layer 29 guardada en debug_layer29_dump.png (size: %dx%d)" % [layer29.get_width(), layer29.get_height()])
	else:
		printerr("Layer 29 is null!")
	quit(0)

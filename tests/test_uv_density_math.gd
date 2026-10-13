extends SceneTree

func _init() -> void:
	print("--- Probando cálculo matemático de sub-regiones proporcionales ---")
	var cell_w := 0.25
	var cell_h := 0.25
	var world_sample := 0.60 # Cada celda representa 0.60m x 0.60m en el mundo real
	var density := cell_w / world_sample # ~0.4167 UV por metro

	# Cojín 0.54 x 0.54m
	var c_w := 0.54 * density
	var c_h := 0.54 * density
	print("Cushion UV size: ", c_w, " x ", c_h, " (Aspect ratio: ", c_w / c_h, ")")

	# Backrest 0.54 x 0.44m
	var b_w := 0.54 * density
	var b_h := 0.44 * density
	print("Backrest UV size: ", b_w, " x ", b_h, " (Aspect ratio: ", b_w / b_h, ", físico: ", 0.54 / 0.44, ")")

	# Apron panel 0.54 x 0.14m
	var a_w := 0.54 * density
	var a_h := 0.14 * density
	print("Apron UV size: ", a_w, " x ", a_h, " (Aspect ratio: ", a_w / a_h, ", físico: ", 0.54 / 0.14, ")")

	print("Densidad en X del Apron: ", a_w / 0.54, " UV/m")
	print("Densidad en Y del Apron: ", a_h / 0.14, " UV/m")
	print("Densidad en X del Cushion: ", c_w / 0.54, " UV/m")
	print("Densidad en Y del Backrest: ", b_h / 0.44, " UV/m")
	quit()

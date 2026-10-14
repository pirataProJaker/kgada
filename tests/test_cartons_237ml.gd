extends SceneTree

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")

func _init() -> void:
	print("=== VERIFICACIÓN DE CATÁLOGO DE 50 BEBIDAS EN CARTÓN 237ml ===")
	ObjectAtlasScript.ensure_initialized()

	var count := ObjectAtlasScript.CARTON_237ML_DATA.size()
	print("Total bebidas registradas: ", count)
	assert(count == 50, "Debe haber exactamente 50 bebidas registradas")

	for i in range(50):
		var d = ObjectAtlasScript.get_carton_237ml_data(i)
		var id_str: String = d["id"]
		var disp: String = d["display_name"]
		var front_r: Rect2 = d["front"]
		var side_r: Rect2 = d["side"]
		assert(front_r.size.x > 0.0 and front_r.size.y > 0.0, "UV front inválida para " + id_str)
		assert(side_r.size.x > 0.0 and side_r.size.y > 0.0, "UV side inválida para " + id_str)
		if i < 5 or i >= 45:
			print("[%02d] %s: %s | Front UV: %s" % [i + 1, id_str, disp, str(front_r)])

	# Probar aliases
	var test_manzana = ObjectAtlasScript.get_carton_237ml_data("manzana")
	print("Alias 'manzana' -> ", test_manzana["id"])
	assert(test_manzana["id"] == "frutalia_manzana")

	var test_voltik = ObjectAtlasScript.get_carton_237ml_data("voltik")
	print("Alias 'voltik' -> ", test_voltik["id"])
	assert(test_voltik["id"] == "voltik_energetica")

	var test_promax = ObjectAtlasScript.get_carton_237ml_data("proteina")
	print("Alias 'proteina' -> ", test_promax["id"])
	assert(test_promax["id"] == "promax_proteina")

	var test_curcuma = ObjectAtlasScript.get_carton_237ml_data("curcuma")
	print("Alias 'curcuma' -> ", test_curcuma["id"])
	assert(test_curcuma["id"] == "curcuma_curcuma")

	print("=== TODAS LAS 50 BEBIDAS Y ALIASES VERIFICADOS CON ÉXITO ===")
	quit(0)

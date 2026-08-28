extends SceneTree
## Verifica el contrato minimo del documento de mapa.
##   godot --headless --path . -s tests/map_editor_verify.gd

const MAP_DOCUMENT_SCRIPT := preload("res://map_editor/map_document.gd")
const TEST_PATH := "user://map_editor_verify.json"


func _initialize() -> void:
	var document = MAP_DOCUMENT_SCRIPT.new(Vector2i(4, 3))
	document.map_name = "Prueba editor"
	document.world_seed = 12345
	document.cell_size = 2.5
	document.sea_level = -1.0
	document.set_height(Vector2i(2, 1), 4.5)
	document.objects.append({
		"asset_id": "builtin/test_marker",
		"position": [1.0, 0.0, 2.0],
		"rotation_y": 0.0,
		"scale": 1.0,
	})

	if not document.save_to_file(TEST_PATH):
		print("[verify] FALLO: no se pudo guardar documento")
		quit(1)
		return

	var loaded = MAP_DOCUMENT_SCRIPT.load_from_file(TEST_PATH)
	if loaded == null:
		print("[verify] FALLO: no se pudo cargar documento")
		quit(1)
		return
	if loaded.map_name != "Prueba editor" or loaded.world_seed != 12345 or loaded.terrain_mode != "flat":
		print("[verify] FALLO: metadatos no coinciden")
		quit(1)
		return
	if absf(loaded.get_height(Vector2i(2, 1)) - 4.5) > 0.001:
		print("[verify] FALLO: altura no coincide")
		quit(1)
		return
	if loaded.objects.size() != 1 or loaded.objects[0].get("asset_id", "") != "builtin/test_marker":
		print("[verify] FALLO: objetos no coinciden")
		quit(1)
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("[verify] OK: MapDocument guarda y carga alturas, metadatos y objetos")
	quit(0)

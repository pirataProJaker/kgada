extends Node3D

const ARTIFACT_DIR := "C:/Users/Eduardo Contreras/.gemini/antigravity-ide/brain/6bf09c8b-03bf-4f0e-bca0-2fc0acc03730"
const ShowcaseScript = preload("res://tests/test_street_types_showcase.gd")

var _showcase: Node3D
var _camera: Camera3D

func _ready() -> void:
	_showcase = ShowcaseScript.new()
	_showcase.is_capture_mode = true
	add_child(_showcase)

	_camera = _showcase.get_node("ShowcaseCamera") as Camera3D
	if _camera == null:
		_camera = Camera3D.new()
		_camera.current = true
		add_child(_camera)

	_run_captures()

func _wait_frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame

func _capture_and_save(filename: String) -> void:
	await _wait_frames(8)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		var target_path := ARTIFACT_DIR + "/" + filename
		img.save_png(target_path)
		print("[ShowcaseCapture] Captura guardada: ", filename)

func _run_captures() -> void:
	await _wait_frames(12)

	# 1. Vista Panorámica Aérea de todo el Catálogo
	_camera.position = Vector3(0.0, 50.0, 85.0)
	_camera.look_at(Vector3(0.0, 0.0, -5.0), Vector3.UP)
	await _capture_and_save("streets_with_cars_panoramic.png")

	# 2. Bahía 1: Bulevar Dividido de 3 Carriles (X = -150.0)
	_camera.position = Vector3(-150.0, 32.0, 0.0)
	_camera.look_at(Vector3(-150.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
	await _capture_and_save("boulevard_crossing_topdown.png")

	_camera.position = Vector3(-150.0 - 10.0 + 4.5, 3.8, 14.0)
	_camera.look_at(Vector3(-150.0 - 10.0, 0.6, 0.0), Vector3.UP)
	await _capture_and_save("boulevard_3lane_with_car.png")

	# 3. Bahía 2: Bulevar con Arroyo Fluvial (X = -105.0)
	_camera.position = Vector3(-105.0, 6.0, 18.0)
	_camera.look_at(Vector3(-105.0 - 7.0, 0.6, 0.0), Vector3.UP)
	await _capture_and_save("parkway_stream_with_car.png")

	# 4. Bahía 3: Avenida de 6 Carriles con Camellón Arbolado (X = -65.0)
	_camera.position = Vector3(-65.0 + 14.0, 7.5, 28.0)
	_camera.look_at(Vector3(-65.0, 1.0, 0.0), Vector3.UP)
	await _capture_and_save("divided_median_3lane_perspective.png")

	_camera.position = Vector3(-65.0, 34.0, 0.0)
	_camera.look_at(Vector3(-65.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
	await _capture_and_save("divided_median_3lane_topdown.png")

	_camera.position = Vector3(-65.0 + 3.2, 2.2, 14.0)
	_camera.look_at(Vector3(-65.0, 1.5, 4.0), Vector3.UP)
	await _capture_and_save("divided_median_3lane_closeup.png")

	# 5. Bahía 4: Avenida de 6 Carriles con Macetas Cuadradas Adaptativas (X = -25.0)
	# A. Perspectiva
	_camera.position = Vector3(-25.0 + 14.0, 7.5, 28.0)
	_camera.look_at(Vector3(-25.0, 1.0, 0.0), Vector3.UP)
	await _capture_and_save("divided_median_planters_perspective.png")

	# B. Cenital (Top-Down)
	_camera.position = Vector3(-25.0, 34.0, 0.0)
	_camera.look_at(Vector3(-25.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0))
	await _capture_and_save("divided_median_planters_topdown.png")

	# C. Acercamiento macro a la maceta cuadrada de concreto y su vegetación
	_camera.position = Vector3(-25.0 + 2.8, 1.6, 12.0)
	_camera.look_at(Vector3(-25.0, 0.7, 4.0), Vector3.UP)
	await _capture_and_save("divided_median_planters_closeup.png")

	# 6. Bahía 5: Avenida Comercial 4 Carriles (X = +14.0)
	_camera.position = Vector3(14.0 + 5.0, 3.5, 18.0)
	_camera.look_at(Vector3(14.0 - 2.0, 0.7, 4.0), Vector3.UP)
	await _capture_and_save("commercial_4lane_with_cars.png")

	# 7. Bahía 6: Calle Residencial Estándar 2L (X = +42.0)
	_camera.position = Vector3(42.0 + 3.0, 3.2, 18.0)
	_camera.look_at(Vector3(42.0, 0.6, 4.0), Vector3.UP)
	await _capture_and_save("residential_2lane_with_cars.png")

	# 8. Bahía 7: Callejón / Privada Angosta de 1 Carril (X = +68.0)
	_camera.position = Vector3(68.0 + 2.5, 2.8, 12.0)
	_camera.look_at(Vector3(68.0, 0.6, 0.0), Vector3.UP)
	await _capture_and_save("alley_1lane_with_car_no_divider.png")

	# 9. Bahía 8: Carretera Rural Libre (X = +94.0)
	_camera.position = Vector3(94.0 + 3.0, 3.2, 14.0)
	_camera.look_at(Vector3(94.0, 0.6, 2.0), Vector3.UP)
	await _capture_and_save("rural_road_with_car.png")

	# 10. Demostrador de Manzana (X = +125.0)
	_camera.position = Vector3(125.0 + 4.0, 5.0, 15.0)
	_camera.look_at(Vector3(125.0, 0.6, 0.0), Vector3.UP)
	await _capture_and_save("interactive_manzana_with_car.png")

	# 11. Acercamiento específico a los postes de luz metálicos (Avenidas / Bulevares)
	_camera.position = Vector3(-65.0 + 2.2, 3.6, 15.2)
	_camera.look_at(Vector3(-65.0, 3.2, 12.0), Vector3.UP)
	await _capture_and_save("streetlight_metal_closeup.png")

	# 12. Acercamiento específico a los postes de luz amarillos (Calles medianas / residenciales)
	_camera.position = Vector3(37.65 + 1.1, 3.2, 25.5)
	_camera.look_at(Vector3(37.65, 3.0, 22.0), Vector3.UP)
	await _capture_and_save("streetlight_yellow_closeup.png")

	print("[ShowcaseCapture] ¡Todas las capturas visuales completadas exitosamente!")
	get_tree().quit(0)

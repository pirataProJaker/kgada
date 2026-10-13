extends SceneTree

func _init() -> void:
	print("--- Probando rotación de cojín de respaldo ---")
	# Rotación 90° en X con inclinación ergonómica hacia atrás de 7°:
	var basis := Basis(Vector3.RIGHT, deg_to_rad(90.0 - 7.0))
	
	# Normal de la cara frontal (+Y local):
	var face_normal := basis * Vector3.UP
	print("Normal de la cara frontal: ", face_normal) # Debe tener Z > 0 (mirando hacia adelante) e Y ligeramente > 0
	
	# Vector que va hacia la cabeza/arriba del respaldo (local Z = -0.5, donde v = 0):
	var top_vector := basis * Vector3(0.0, 0.0, -0.5)
	print("Posición de la parte superior (v=0): ", top_vector) # Debe tener Y > 0 (arriba)
	
	quit()

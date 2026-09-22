@tool
extends SceneTree

const PSXGrass = preload("res://world/vegetation/grass/psx_grass.gd")

func _init() -> void:
	print("--- TEST DE CLASE PSXGrass ---")
	var m = PSXGrass.create_mesh(0.45)
	if m:
		print("✓ PSXGrass creado con éxito, AABB: ", m.get_aabb())
		print("✓ Material: ", PSXGrass.get_material())
	else:
		print("✗ Error al crear PSXGrass")
	quit(0)

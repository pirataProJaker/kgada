extends Node3D
## Escena de prueba para DrainageDungeonGenerator: genera un nivel de
## drenaje procedural, agrega luz/ambiente basico y una camara libre para
## recorrerlo (WASD + mouse, ver tests/free_fly_camera.gd).
##
## Cambiar rng_seed en el DrainageDungeonGenerator (panel de Inspector, o
## en el script de esta escena) para probar distintos layouts.

const FREE_FLY_CAMERA_SCRIPT := preload("res://tests/free_fly_camera.gd")


func _ready() -> void:
	_add_lighting()
	_add_camera()


func _add_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.6, 0.65)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.9
	world_env.environment = environment
	add_child(world_env)


func _add_camera() -> void:
	var camera := Camera3D.new()
	camera.set_script(FREE_FLY_CAMERA_SCRIPT)
	camera.position = Vector3(-3.0, 6.0, 10.0)
	camera.rotation_degrees = Vector3(-25.0, -15.0, 0.0)
	add_child(camera)

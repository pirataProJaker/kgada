extends Node
class_name InteractController
## Interaccion generica con una tecla configurable (E por defecto, ver
## SettingsManager - accion "interact"): lanza un rayo corto desde la camara
## y, si golpea algo con un metodo `interact(interactor)`, lo llama. Pensado
## para puertas (InteractiveDoor) y, a futuro, cofres u otros objetos del
## mundo (ver el comentario "Punto de interaccion" en ChestBehavior).
##
## Mismo patron que PlacementController/MeleeController: un Node hijo del
## Player, activo solo para el dueño local (multiplayer authority), que
## revisa la tecla con deteccion de flanco manual - igual que el salto en
## player.gd, este proyecto evita registrar acciones nuevas en el Input Map
## (project.godot) a proposito, prefiriendo SettingsManager.get_key(...).

const INTERACT_RANGE := 3.0

var _player: Node3D = null
var _was_interact_pressed := false


func _ready() -> void:
	_player = get_parent()
	if not _player.is_multiplayer_authority():
		set_process(false)


func _process(_delta: float) -> void:
	var pressed := Input.is_physical_key_pressed(SettingsManager.get_key("interact"))
	var just_pressed := pressed and not _was_interact_pressed
	_was_interact_pressed = pressed
	if not just_pressed:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_try_interact()


func _try_interact() -> void:
	var camera: Camera3D = _player.camera
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * INTERACT_RANGE

	var space_state := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [_player.get_rid()]
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider = result["collider"]
	if collider != null and collider.has_method("interact"):
		collider.interact(_player)

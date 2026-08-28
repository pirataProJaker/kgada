extends Node3D
class_name FirstPersonArms
## Modelo de brazos en primera persona (assets/first-person/arms_rig.fbx).
## Vive bajo Head/Camera3D en player.tscn, siempre a transform identidad
## (asi viene armado el rig, pensado para colgar directo de la camara).
## Solo se muestra/anima para el dueño local del Player (mismo patron que
## HeldItemView).

const ARMS_SCENE := preload("res://assets/first-person/arms_rig.fbx")
## Pedido explicito del usuario: usar "relax" (brazos relajados/bajos) como
## pose default en vez de "guard_idle" (guardia de boxeo, puños arriba). Con
## el offset Y mas bajo (ver EXTRA_OFFSET) "relax" ya entra bien en cuadro.
## ("rest" tambien existe pero dura solo ~0.03s - practicamente un solo
## frame - no sirve como pose idle en loop).
const IDLE_ANIM := "ArmsRig|relax"

## Offset extra despues de alinear con el hueso "camera" (ver
## _align_to_camera_bone). Medido con un test headless reproduciendo la
## animacion real "guard_idle" (no la bind pose, que engaña porque el rig
## por defecto esta en una T-pose con los brazos extendidos): con solo el
## alineado del hueso "camera", las manos en guard_idle terminaban a apenas
## ~0.08-0.15m del lente (el "guard" de boxeo lleva los puños pegados a la
## cara) - eso es casi el near clip (0.05) y produce la distorsion/triangulos
## rotos que se ven en pantalla (perspectiva exagerada de lo pegado que esta
## el mesh a la camara). Se empuja hacia adelante (Z mas negativo) para que
## las manos queden a una distancia tipica de viewmodel FPS. -0.7 quedaba
## demasiado lejos (brazos chiquitos y se alcanzaba a ver de donde "nacen"
## los brazos, es decir el hombro/base del modelo entraba en cuadro) - se
## bajo a -0.35 para que los brazos entren mas grandes y su base quede fuera
## de la vista, como un viewmodel FPS tipico. Y en la componente Y, -0.12
## dejaba los brazos muy arriba en pantalla (casi a la altura de la mira) -
## se bajo a -0.32 y luego, a pedido del usuario, aun mas abajo a -0.5. En Z
## se acerco un poco mas (-0.35 -> -0.22) porque se veia todo el brazo
## (antebrazo + brazo superior/codo) y "estorbaba" - al acercarlo mas a la
## camara, la parte mas cercana (antebrazo/mano) se agranda y ocupa mas
## pantalla mientras el codo/brazo superior queda mas al borde/fuera.
const EXTRA_OFFSET := Vector3(0.0, -0.5, -0.22)

## Escala aplicada al modelo (alrededor de su propio origen, que ya quedo
## alineado con la Camera3D real por _align_to_camera_bone) para: 1) que se
## vea mas grande sin acercarlo mas a la camara (acercarlo de nuevo volveria
## a causar la distorsion/near-clip de antes), y 2) separar un poco los dos
## brazos entre si escalando mas fuerte en X que en Y/Z - como la pose
## "guard_idle" trae los puños casi juntos al centro, estirar en X los aleja
## simetricamente del centro (aproximacion simple, no una separacion real de
## huesos, pero da el efecto visual pedido sin tener que editar la animacion).
const MODEL_SCALE := Vector3(1.6, 1.3, 1.3)

var _anim_player: AnimationPlayer = null


func _ready() -> void:
	if not owner.is_multiplayer_authority():
		visible = false
		return

	var model := ARMS_SCENE.instantiate()
	add_child(model)
	_align_to_camera_bone(model)
	_anim_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim_player != null:
		play_animation(IDLE_ANIM)


## El rig trae un hueso llamado "camera" (bajo "root"), pensado por el autor
## del asset como referencia de donde deberia estar la camara real relativa
## al resto de los brazos. Sin esto, el modelo (autorado como un personaje
## completo de pie, con el origen en los pies) queda con las manos ~1.7m por
## encima y detras de la Camera3D real -> invisible en pantalla. Se centra
## el modelo restando la posicion de ese hueso (en espacio local de `model`)
## para que quede exactamente en el origen, que es donde cuelga la Camera3D
## real (este nodo vive bajo Head/Camera3D).
func _align_to_camera_bone(model: Node3D) -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skeleton == null:
		return
	var camera_bone_idx := skeleton.find_bone("camera")
	if camera_bone_idx == -1:
		return
	var armature: Node3D = skeleton.get_parent() as Node3D
	var to_model_space := armature.transform * skeleton.transform
	var camera_bone_pos: Vector3 = to_model_space * skeleton.get_bone_global_rest(camera_bone_idx).origin
	model.position = -camera_bone_pos + EXTRA_OFFSET
	# El rig mira hacia +Z (la camara "camera" en el rig apunta al reves de
	# como mira la Camera3D real, que mira hacia -Z) - sin este giro, los
	# brazos quedan invertidos: los puños/manos apuntando HACIA la camara en
	# vez de extendiendose hacia adelante, alejandose de ella.
	model.rotate_y(PI)
	model.scale = MODEL_SCALE


## Reproduce una animacion del rig por nombre (ver lista completa en
## arms_rig.fbx: finger_gun_*, grab_L/R, guard_*, jab_L/R, knife_*, push_L/R,
## relax, rest), en loop si `loop` es true. Pensado para que otros sistemas
## (inventario, ataques, etc.) la llamen mas adelante.
func play_animation(anim_name: String, loop: bool = true) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	var anim := _anim_player.get_animation(anim_name)
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	_anim_player.play(anim_name)


## Como play_animation, pero pensada para acciones de un solo golpe (ataque,
## etc.): la reproduce sin loop y, quede vuelve automaticamente a IDLE_ANIM
## cuando termina (via animation_finished), asi quien la llama (ej.
## MeleeController) no tiene que acordarse de restaurar la pose de reposo a
## mano ni llevar su propio timer de duracion.
func play_action_animation(anim_name: String) -> void:
	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return
	if _anim_player.animation_finished.is_connected(_on_action_animation_finished):
		_anim_player.animation_finished.disconnect(_on_action_animation_finished)
	_anim_player.animation_finished.connect(_on_action_animation_finished, CONNECT_ONE_SHOT)
	play_animation(anim_name, false)


func _on_action_animation_finished(_anim_name: String) -> void:
	play_animation(IDLE_ANIM)

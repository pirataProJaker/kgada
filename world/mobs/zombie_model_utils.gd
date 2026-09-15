extends RefCounted
class_name ZombieModelUtils
## Carga el modelo real del zombie (assets/zombie 1/, pack "AutopsyZombieItch"
## con animaciones estilo Mixamo) y lo agrega como hijo "Model" del mob.
##
## El pack trae el modelo base (AutopsyZombieItch.fbx, malla+esqueleto de 90
## huesos) y 5 archivos .fbx SEPARADOS, uno por animacion (zombie walk.fbx,
## zombie run.fbx, zombie idle.fbx, zombie death.fbx, zombie attack.fbx) -
## cada uno con el MISMO esqueleto (Armature_001/Skeleton3D, mismos huesos)
## pero una sola animacion llamada "mixamo_com" (patron tipico de
## Mixamo: descargas el modelo y cada animacion en archivos separados).
##
## build_model() carga el modelo base, le aplica la textura real
## (Material_Diffuse.png), y luego fusiona las 5 animaciones dentro del
## AnimationPlayer del modelo base, renombrandolas a "walk"/"run"/"idle"/
## "die"/"attack" para que Zombie.gd las pueda reproducir por nombre fijo
## (igual que el patron de Dog/Cat).

const ZOMBIE_MODEL_PATH := "res://assets/zombie 1/AutopsyZombieItch.fbx"
const ZOMBIE_DIFFUSE_PATH := "res://assets/zombie 1/zombie 1 original/AutopsyZombieItch.fbm/Material_Diffuse.png"
const ZOMBIE_NORMAL_PATH := "res://assets/zombie 1/zombie 1 original/AutopsyZombieItch.fbm/Material_Normal.png"
const ZOMBIE_TARGET_HEIGHT := 1.8 # altura aproximada de una persona, en metros

# Archivo .fbx de animacion -> nombre final dentro del AnimationPlayer fusionado.
const ANIM_SOURCES := {
	"res://assets/zombie 1/zombie walk.fbx": "walk",
	"res://assets/zombie 1/zombie run.fbx": "run",
	"res://assets/zombie 1/zombie idle.fbx": "idle",
	"res://assets/zombie 1/zombie death.fbx": "die",
	"res://assets/zombie 1/zombie attack.fbx": "attack",
}

# Nombre de la animacion dentro de cada .fbx de animacion (patron Mixamo:
# siempre se llama igual sin importar el movimiento real).
const SOURCE_ANIM_NAME := "mixamo_com"
const PROCESSED_ANIM_CACHE_META := "zombie_processed_animation"


## Carga el modelo del zombie, lo agrega como hijo de `parent` (nombrado
## "Model"), le aplica textura/escala, y fusiona las animaciones. Si el
## modelo base no se puede cargar, agrega un placeholder de bloques.
static func build_model(parent: Node3D) -> void:
	var model_scene: PackedScene = load(ZOMBIE_MODEL_PATH) as PackedScene
	if model_scene == null:
		push_warning("[mob] No se pudo cargar %s, usando modelo de bloques de respaldo." % ZOMBIE_MODEL_PATH)
		parent.add_child(build_placeholder_model())
		return

	var instanced: Node = model_scene.instantiate()
	if not (instanced is Node3D):
		push_warning("[mob] La raiz de %s no es un Node3D (es %s), usando modelo de bloques de respaldo." % [ZOMBIE_MODEL_PATH, instanced.get_class()])
		instanced.free()
		parent.add_child(build_placeholder_model())
		return

	var model: Node3D = instanced
	model.name = "Model"
	parent.add_child(model)

	_apply_material(model)
	_force_visible(model)
	_normalize_scale(model)
	_merge_animations(model)

	# El modelo mira hacia +Z (verificado via huesos: los dedos del pie
	# quedan mas adelante que el tobillo en +Z tras la conversion de ejes
	# FBX -> Godot - mismo caso que cat.fbx). Godot usa -Z como direccion de
	# avance, asi que se rota 180 grados en Y (si no, el zombie camina "de
	# espaldas": el cuerpo se mueve hacia donde apunta Zombie.gd pero el
	# modelo visualmente mira/camina para el otro lado).
	model.rotation.y = PI


## Escala `model` para que su altura real (AABB) sea ZOMBIE_TARGET_HEIGHT, y
## lo reposiciona en Y para que la parte mas baja quede en y=0.
static func _normalize_scale(model: Node3D) -> void:
	var aabb := _combined_aabb_local(model)
	if aabb.size.y <= 0.0001:
		push_warning("[mob] El zombie no tiene mallas visibles (AABB vacio), no se pudo normalizar escala.")
		return

	var scale_factor: float = ZOMBIE_TARGET_HEIGHT / aabb.size.y
	if scale_factor <= 0.0 or not is_finite(scale_factor):
		push_warning("[mob] scale_factor invalido (%s), se deja el zombie sin escalar." % scale_factor)
		return
	model.scale = Vector3.ONE * scale_factor
	model.position.y -= aabb.position.y * scale_factor


## Busca el AnimationPlayer del modelo base y, por cada entrada de
## ANIM_SOURCES, carga el .fbx correspondiente, extrae su animacion
## "mixamo_com", la duplica (para no compartir el recurso con la escena
## fuente) y la agrega al AnimationPlayer del modelo base con el nombre
## final ("walk", "run", etc).
static func _merge_animations(model: Node3D) -> void:
	var anim_player := _find_anim_player(model)
	if anim_player == null:
		push_warning("[mob] El zombie base no tiene AnimationPlayer, no se pueden fusionar animaciones.")
		return

	# Blend automatico entre animaciones (walk<->idle<->run, etc.) para que
	# el cambio no se vea brusco - AnimationPlayer interpola solo durante
	# este tiempo cada vez que se llama a play() con una animacion distinta.
	anim_player.playback_default_blend_time = 0.25

	if not anim_player.has_animation_library(""):
		anim_player.add_animation_library("", AnimationLibrary.new())
	var library: AnimationLibrary = anim_player.get_animation_library("")

	# Posicion de reposo del nodo raiz del esqueleto ANTES de aplicar
	# ninguna animacion (la que dejo _normalize_scale al parar el modelo en
	# y=0) - se usa como referencia fija para que ninguna animacion mueva el
	# esqueleto de ese punto (ver _strip_root_motion).
	var rest_position := _find_armature_rest_position(model)

	# Velocidad "natural" de cada animacion (metros/segundo que avanzaba de
	# verdad el root motion horneado original, antes de quitarlo) - se
	# expone como metadata para que Zombie.gd pueda sincronizar la velocidad
	# de reproduccion con la velocidad real de movimiento y los pies no se
	# arrastren/resbalen (ver _strip_root_motion).
	var natural_speeds := {}

	for source_path in ANIM_SOURCES:
		var final_name: String = ANIM_SOURCES[source_path]
		var processed := _load_processed_animation(source_path, rest_position)
		if processed.is_empty():
			push_warning("[mob] No se pudo extraer la animacion de %s." % source_path)
			continue
		var source_anim: Animation = processed["animation"]
		natural_speeds[final_name] = float(processed["natural_speed"])
		if library.has_animation(final_name):
			library.remove_animation(final_name)
		library.add_animation(final_name, source_anim)

	# Limpiar animaciones residuales del FBX base que no se usan y cargan cientos de tracks
	for anim_name in library.get_animation_list():
		if not anim_name in ANIM_SOURCES.values():
			library.remove_animation(anim_name)

	anim_player.set_meta("mob_natural_speeds", natural_speeds)


## Busca el nodo "Armature_001" dentro de `model` y devuelve su posicion
## local actual (antes de que se reproduzca ninguna animacion) - esta es la
## posicion de reposo que dejo _normalize_scale, y sirve como referencia
## fija para que _strip_root_motion no deje que las animaciones muevan al
## esqueleto de ahi (ni hacia adelante/atras ni metiendo los pies bajo
## tierra).
static func _find_armature_rest_position(model: Node3D) -> Vector3:
	var armature := model.get_node_or_null("Armature_001")
	if armature is Node3D:
		return (armature as Node3D).position
	return Vector3.ZERO


## Los .fbx de animacion (Mixamo) traen la traslacion del ciclo de caminata
## HORNEADA en un track de posicion del nodo "Armature_001" (no es un hueso,
## es el nodo raiz del esqueleto) - el personaje avanza de verdad dentro de
## la animacion (ej. de Z=-0.05 a Z=1.16 en 4s de "walk"). Como el
## movimiento REAL del mob ya lo controla Zombie.gd/ZombieAi (mueve el
## CharacterBody3D), esta traslacion horneada se suma aparte sobre el
## modelo visual: cada vuelta del loop el modelo se desliza hacia adelante
## un tramo y luego, al reiniciar la animacion, se "teletransporta" de
## vuelta a la posicion inicial (mientras el cuerpo fisico invisible sigue
## avanzando sin parar) - se ve como si el zombie caminara, se
## teletransportara hacia atras, y siguiera caminando adelante.
## Esta funcion fija la posicion (X, Y y Z) de ese track al valor de
## `rest_position` (la posicion de reposo del esqueleto antes de reproducir
## cualquier animacion) en TODOS los frames, asi la animacion camina "en el
## mismo lugar", con los pies siempre a la misma altura (sin hundirse ni
## flotar al cambiar de animacion), y el unico movimiento real lo hace el
## CharacterBody3D.
##
## Antes de borrar los keyframes originales, mide cuanto avanzaba "de
## verdad" el personaje en esta animacion (distancia horizontal entre el
## primer y el ultimo frame, dividida por la duracion) y devuelve esa
## velocidad "natural" en metros/segundo (0.0 si no hay track o esta
## degenerado). Zombie.gd usa este valor para escalar `speed_scale` del
## AnimationPlayer segun la velocidad real de movimiento - si no se hace
## esto, la velocidad real (fija por WANDER_SPEED) casi nunca coincide con
## el paso que la animacion "cree" que esta dando, y se ve como si el
## zombie arrastrara los pies (un pie queda plantado en el piso mientras el
## cuerpo ya avanzo mas o menos de lo que el paso animado recorre).
static func _strip_root_motion(anim: Animation, rest_position: Vector3) -> float:
	var natural_speed := 0.0
	for i in anim.get_track_count():
		if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
			continue
		var track_path := str(anim.track_get_path(i))
		if not track_path.ends_with("Armature_001"):
			continue
		var key_count := anim.track_get_key_count(i)
		if key_count == 0:
			continue
		var first_value: Vector3 = anim.track_get_key_value(i, 0)
		var last_value: Vector3 = anim.track_get_key_value(i, key_count - 1)
		var distance := Vector2(last_value.x - first_value.x, last_value.z - first_value.z).length()
		if anim.length > 0.001:
			natural_speed = distance / anim.length
		for k in key_count:
			anim.track_set_key_value(i, k, rest_position)
	return natural_speed


## Carga `path` (un .fbx de animacion suelta), instancia su escena
## temporalmente, busca su AnimationPlayer, duplica la animacion
## SOURCE_ANIM_NAME y libera la instancia temporal (ya no se necesita el
## resto del modelo/esqueleto, solo la animacion).
static func _load_processed_animation(path: String, rest_position: Vector3) -> Dictionary:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return {}
	if scene.has_meta(PROCESSED_ANIM_CACHE_META):
		var cached: Variant = scene.get_meta(PROCESSED_ANIM_CACHE_META)
		if cached is Dictionary:
			var cached_dictionary: Dictionary = cached as Dictionary
			var cached_animation: Variant = cached_dictionary.get("animation")
			if cached_animation is Animation:
				return cached_dictionary

	var instance: Node = scene.instantiate()
	var source_player := _find_anim_player(instance)
	var result: Animation = null
	if source_player != null and source_player.has_animation(SOURCE_ANIM_NAME):
		result = (source_player.get_animation(SOURCE_ANIM_NAME) as Animation).duplicate()
	instance.free()
	if result == null:
		return {}

	var natural_speed := _strip_root_motion(result, rest_position)
	var processed := {
		"animation": result,
		"natural_speed": natural_speed,
	}
	scene.set_meta(PROCESSED_ANIM_CACHE_META, processed)
	return processed


static func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found != null:
			return found
	return null


## Recorre `node` y le asigna un material propio (texturas del pack,
## culling desactivado) a cada superficie de cada MeshInstance3D.
static func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		var mesh: Mesh = mesh_instance.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				mesh_instance.set_surface_override_material(i, _build_zombie_material())
	for child in node.get_children():
		_apply_material(child)


static var _cached_zombie_material: StandardMaterial3D = null

static func _build_zombie_material() -> StandardMaterial3D:
	if _cached_zombie_material != null:
		return _cached_zombie_material
	var material := StandardMaterial3D.new()
	var albedo := load(ZOMBIE_DIFFUSE_PATH) as Texture2D
	if albedo != null:
		material.albedo_texture = albedo
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # look PSX pixelado
	else:
		push_warning("[mob] No se pudo cargar la textura %s." % ZOMBIE_DIFFUSE_PATH)
		material.albedo_color = Color(0.35, 0.4, 0.3)
	var normal := load(ZOMBIE_NORMAL_PATH) as Texture2D
	if normal != null:
		material.normal_enabled = true
		material.normal_texture = normal
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cached_zombie_material = material
	return _cached_zombie_material


static func _force_visible(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = true
	for child in node.get_children():
		_force_visible(child)


static func _combined_aabb_local(model: Node3D) -> AABB:
	var inv := model.global_transform.affine_inverse()
	var result := AABB()
	var first := true
	for vi in _find_visual_instances(model):
		var xform: Transform3D = inv * vi.global_transform
		var local_aabb: AABB = xform * vi.get_aabb()
		if first:
			result = local_aabb
			first = false
		else:
			result = result.merge(local_aabb)
	return result


static func _find_visual_instances(node: Node) -> Array:
	var found: Array = []
	if node is VisualInstance3D:
		found.append(node)
	for child in node.get_children():
		found += _find_visual_instances(child)
	return found


## Zombie de bloques simples (BoxMesh) usado unicamente como respaldo si el
## modelo real no se pudiera cargar - encaja con el estilo PSX/low-poly del
## resto del juego y no depende de ningun archivo externo.
static func build_placeholder_model() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.4, 0.3)

	_add_box(root, "Body", Vector3(0.4, 0.7, 0.25), Vector3(0.0, 1.05, 0.0), material)
	_add_box(root, "Head", Vector3(0.28, 0.28, 0.28), Vector3(0.0, 1.55, 0.0), material)
	_add_box(root, "ArmL", Vector3(0.14, 0.6, 0.14), Vector3(0.3, 1.1, 0.0), material)
	_add_box(root, "ArmR", Vector3(0.14, 0.6, 0.14), Vector3(-0.3, 1.1, 0.0), material)
	_add_box(root, "LegL", Vector3(0.16, 0.7, 0.16), Vector3(0.11, 0.35, 0.0), material)
	_add_box(root, "LegR", Vector3(0.16, 0.7, 0.16), Vector3(-0.11, 0.35, 0.0), material)

	return root


static func _add_box(parent: Node3D, box_name: String, size: Vector3, pos: Vector3, material: StandardMaterial3D) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = box_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	parent.add_child(mesh_instance)

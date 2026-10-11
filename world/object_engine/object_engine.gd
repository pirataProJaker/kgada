class_name ObjectEngine
extends Node3D

## Motor Central de Objetos, Mobiliario y Props (Play Sector X)
## Arquitectura de Renderizado Ultra-Optimizado a +0 Draw Calls:
## - Ensambla cualquier objeto a partir de una biblioteca de primitivas geométricas estándar.
## - Renderiza todos los objetos del juego en Hardware Instancing agrupados estrictamente por tipo de primitiva.
## - Costo de renderizado: Exactamente 1 Draw Call por tipo de primitiva presente en la escena (típicamente 2 a 4 en total).
## - Todo nuevo objeto/mueble añadido al juego consume +0 Draw Calls adicionales.
## - Integra el Atlas Inteligente (Texture2DArray) con recortes UV por instancia (INSTANCE_CUSTOM).

const ObjectPrimitivesScript = preload("res://world/object_engine/object_primitives.gd")
const ObjectBuilderScript = preload("res://world/object_engine/object_builder.gd")
const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")
const OBJECT_SHADER: Shader = preload("res://world/object_engine/object_engine.gdshader")

@export var generate_collisions: bool = true
@export var default_roughness: float = 0.55
@export var default_metallic: float = 0.02

var _builder: ObjectBuilder = null
var _shared_material: ShaderMaterial = null
var _multimesh_nodes: Dictionary = {} # primitive_type -> MultiMeshInstance3D
var _collision_body: StaticBody3D = null


func _init() -> void:
	_builder = ObjectBuilderScript.new()


func _ready() -> void:
	add_to_group("object_engine")
	_init_shared_material()


## Retorna el builder principal para comenzar a alimentar piezas y muebles
func get_builder() -> ObjectBuilder:
	if _builder == null:
		_builder = ObjectBuilderScript.new()
	return _builder


## Añade cualquier mueble o prop delegando al ObjectBuilder
## Compatible 100% con HouseFurniturePlanner y con FurnitureMultiMeshSystem.
func add_furniture_by_script(scr: Variant, t: Transform3D, extra_params: Dictionary = {}) -> void:
	if _builder == null:
		_builder = ObjectBuilderScript.new()
	_builder.add_furniture_by_script(scr, t, extra_params)


## Limpia todos los nodos y registros
func clear() -> void:
	if _builder != null:
		_builder.clear()

	for node in _multimesh_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_multimesh_nodes.clear()

	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
		_collision_body = null


## Construye y envía toda la geometría a la GPU y crea las colisiones consolidadas
func commit(external_builder: ObjectBuilder = null) -> void:
	if external_builder != null and external_builder != _builder:
		_builder.merge_from(external_builder)

	_init_shared_material()

	# Limpiar MultiMeshes y colisiones previas si las hubiera
	for node in _multimesh_nodes.values():
		if is_instance_valid(node):
			node.queue_free()
	_multimesh_nodes.clear()

	if is_instance_valid(_collision_body):
		_collision_body.queue_free()
		_collision_body = null

	var instances_map := _builder.get_instances_map()
	if instances_map.is_empty():
		return

	# 1. GENERACIÓN DE MULTIMESHES POR TIPO DE PRIMITIVA (1 Draw Call por tipo)
	for prim_type in instances_map:
		var items: Array = instances_map[prim_type]
		if items.is_empty():
			continue

		var mesh := ObjectPrimitivesScript.get_mesh(prim_type)
		if mesh == null:
			continue

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = items.size()

		for i in range(items.size()):
			var entry: Dictionary = items[i]
			var t: Transform3D = entry["transform"]
			var layer_idx: int = entry.get("layer", 0)
			var r: float = entry.get("roughness", default_roughness)
			var m: float = entry.get("metallic", default_metallic)
			var uv: Rect2 = entry.get("uv_rect", Rect2(0.0, 0.0, 1.0, 1.0))

			mm.set_instance_transform(i, t)
			# COLOR: r = capa del atlas, g = roughness, b = metallic, a = 1.0
			mm.set_instance_color(i, Color(float(layer_idx) / 255.0, r, m, 1.0))
			# INSTANCE_CUSTOM: (uv_min.x, uv_min.y, uv_size.x, uv_size.y)
			mm.set_instance_custom_data(i, Color(uv.position.x, uv.position.y, uv.size.x, uv.size.y))

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "ObjectEngine_%s_MultiMesh" % prim_type.capitalize()
		mmi.multimesh = mm
		mmi.material_override = _shared_material
		add_child(mmi)
		_multimesh_nodes[prim_type] = mmi

	# 2. GENERACIÓN DE COLISIONES CONSOLIDADAS EN 1 SOLO STATICBODY3D
	if generate_collisions:
		var col_list := _builder.get_collisions()
		if not col_list.is_empty():
			_collision_body = StaticBody3D.new()
			_collision_body.name = "ObjectEngine_ConsolidatedCollision"

			for col_data in col_list:
				var col_shape := CollisionShape3D.new()
				var type: String = col_data.get("type", "box")
				var t: Transform3D = col_data.get("transform", Transform3D.IDENTITY)

				match type:
					"box":
						var shape := BoxShape3D.new()
						shape.size = col_data.get("size", Vector3.ONE)
						col_shape.shape = shape
					"cylinder":
						var shape := CylinderShape3D.new()
						shape.radius = col_data.get("radius", 0.5)
						shape.height = col_data.get("height", 1.0)
						col_shape.shape = shape
					"sphere":
						var shape := SphereShape3D.new()
						shape.radius = col_data.get("radius", 0.5)
						col_shape.shape = shape
					"capsule":
						var shape := CapsuleShape3D.new()
						shape.radius = col_data.get("radius", 0.25)
						shape.height = col_data.get("height", 1.0)
						col_shape.shape = shape
					_:
						var shape := BoxShape3D.new()
						shape.size = col_data.get("size", Vector3.ONE)
						col_shape.shape = shape

				col_shape.transform = t
				_collision_body.add_child(col_shape)

			add_child(_collision_body)


## Retorna estadísticas de telemetría de rendimiento y draw calls
func get_stats() -> Dictionary:
	var total_instances := _builder.get_total_instances() if _builder != null else 0
	var active_draw_calls := _multimesh_nodes.size()
	var collision_shapes_count := 0
	if is_instance_valid(_collision_body):
		collision_shapes_count = _collision_body.get_child_count()

	var total_triangles := 0
	var total_vertices := 0
	for prim_type in _multimesh_nodes:
		var mm_node = _multimesh_nodes[prim_type]
		if is_instance_valid(mm_node) and is_instance_valid(mm_node.multimesh):
			var count: int = mm_node.multimesh.instance_count
			var mesh: Mesh = mm_node.multimesh.mesh
			if mesh:
				var faces: PackedVector3Array = mesh.get_faces()
				total_triangles += (faces.size() / 3) * count
				total_vertices += faces.size() * count

	return {
		"draw_calls": active_draw_calls,
		"total_instances": total_instances,
		"primitives_active": _multimesh_nodes.keys(),
		"collision_shapes": collision_shapes_count,
		"triangles": total_triangles,
		"vertices": total_vertices
	}


# =========================================================================
# GESTIÓN DEL MATERIAL COMPARTIDO
# =========================================================================

func _init_shared_material() -> void:
	if _shared_material != null:
		return

	# Asegurar que el FurnitureTextureManager tenga inicializado el Texture2DArray
	FurnitureTextureManagerScript.init_manager()

	_shared_material = ShaderMaterial.new()
	_shared_material.shader = OBJECT_SHADER
	_shared_material.set_shader_parameter("texture_array", FurnitureTextureManagerScript.get_texture_array())
	_shared_material.set_shader_parameter("default_roughness", default_roughness)
	_shared_material.set_shader_parameter("default_metallic", default_metallic)

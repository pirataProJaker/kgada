class_name VegetationScatter
extends MultiMeshInstance3D

## Nodo utilitario para dispersar y renderizar miles de instancias de vegetación
## mediante hardware instancing (MultiMeshInstance3D) en un solo draw call.

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

@export var scatter_radius: float = 15.0
@export var instance_amount: int = 120
@export var min_scale: float = 0.80
@export var max_scale: float = 1.25
@export var random_seed: int = 12345

var _shared_material: ShaderMaterial

func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # Máximo rendimiento en campo abierto

func get_default_material() -> ShaderMaterial:
	if not _shared_material:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = VEGETATION_SHADER
	return _shared_material

## Puebla el MultiMesh distribuyendo instancias aleatoriamente en un círculo o área dada
func populate_radial(
	prototype_mesh: Mesh,
	amount: int,
	radius: float,
	center: Vector3 = Vector3.ZERO,
	height_func: Callable = Callable(),
	seed_val: int = 0,
	density_func: Callable = Callable()
) -> void:
	if amount <= 0 or prototype_mesh == null:
		return
	
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else random_seed
	
	if material_override == null:
		material_override = get_default_material()
	
	var transforms: Array[Transform3D] = []
	var attempts: int = amount if not density_func.is_valid() else int(amount * 1.6)
	
	for i in range(attempts):
		if transforms.size() >= amount:
			break
			
		var angle: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * radius
		var x: float = center.x + cos(angle) * dist
		var z: float = center.z + sin(angle) * dist
		
		if density_func.is_valid():
			var prob = density_func.call(Vector2(x, z))
			if prob is float:
				if rng.randf() > prob:
					continue
		
		var y: float = center.y
		var normal := Vector3.UP
		if height_func.is_valid():
			var h_info = height_func.call(Vector2(x, z))
			if h_info is float:
				y = h_info
			elif h_info is Vector3:
				y = h_info.y
			elif h_info is Dictionary:
				y = h_info.get("height", 0.0)
				normal = h_info.get("normal", Vector3.UP)
		
		# Escala aleatoria y rotación de 360 grados
		var s: float = rng.randf_range(min_scale, max_scale)
		var yaw: float = rng.randf() * TAU
		
		# Ligera inclinación para que no todas estén perfectamente verticales
		var tilt_x: float = deg_to_rad(rng.randf_range(-6.0, 6.0))
		var tilt_z: float = deg_to_rad(rng.randf_range(-6.0, 6.0))
		
		var basis := Basis()
		basis = basis.rotated(Vector3.UP, yaw)
		basis = basis.rotated(Vector3.RIGHT, tilt_x)
		basis = basis.rotated(Vector3.FORWARD, tilt_z)
		basis = basis.scaled(Vector3(s, s, s))
		
		transforms.append(Transform3D(basis, Vector3(x, y, z)))
	
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = prototype_mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	
	multimesh = mm

## Puebla a partir de un arreglo directo de Transform3D (útil para clústers artesanales)
func populate_from_transforms(prototype_mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty() or prototype_mesh == null:
		return
	
	if material_override == null:
		material_override = get_default_material()
		
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = prototype_mesh
	mm.instance_count = transforms.size()
	
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
		
	multimesh = mm

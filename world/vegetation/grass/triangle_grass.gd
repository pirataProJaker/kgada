class_name TriangleGrass
extends Node3D

## Césped triangular genérico low-poly.
## Construido exclusivamente con triángulos delgados (1 triángulo por brizna de hierba).
## Cada mata agrupa de 4 a 6 briznas arqueadas radialmente con variación de altura,
## curvatura orgánica y gradiente de color botánico (raíz oscura -> verde vivo -> punta dorada).

const VEGETATION_SHADER = preload("res://world/vegetation/common/vegetation_shader.gdshader")

@export var grass_seed: int = 12345
@export var grass_scale: float = 1.0

var _mesh_instance: MeshInstance3D

func _ready() -> void:
	if get_child_count() == 0:
		generate()

func generate() -> void:
	if _mesh_instance:
		_mesh_instance.queue_free()
	
	var mesh = create_mesh(grass_seed, grass_scale)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	
	var mat = ShaderMaterial.new()
	mat.shader = VEGETATION_SHADER
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

## Genera un ArrayMesh procedural de una mata de césped triangular
static func create_mesh(seed_val: int = 0, scale_f: float = 1.0) -> ArrayMesh:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Paleta cromática natural
	var col_base := Color(0.08, 0.20, 0.05)      # Base sombreada en tierra
	var col_mid := Color(0.22, 0.52, 0.14)       # Verde césped natural brillante
	var col_tip := Color(0.46, 0.72, 0.22)       # Puntas iluminadas por la luz del atardecer
	
	var blade_count: int = rng.randi_range(6, 9)
	var root_spread: float = 0.035 * scale_f
	
	for i in range(blade_count):
		var base_angle: float = float(i) * TAU / float(blade_count) + rng.randf_range(-0.30, 0.30)
		
		# Altura y curvatura individual de la brizna (mezcla de briznas bajas y altas)
		var h: float = rng.randf_range(0.18, 0.42) * scale_f
		var arch_dist: float = rng.randf_range(0.08, 0.18) * scale_f
		var blade_w: float = rng.randf_range(0.032, 0.052) * scale_f
		
		# Base (2 vértices formando la raíz)
		var perp := Vector3(-sin(base_angle), 0, cos(base_angle)) * (blade_w * 0.5)
		var root_center := Vector3(cos(base_angle) * root_spread, 0, sin(base_angle) * root_spread)
		var v_base_l := root_center + perp
		var v_base_r := root_center - perp
		
		# Punta de la brizna (inclinada hacia afuera según el ángulo)
		var v_tip := root_center + Vector3(cos(base_angle) * arch_dist, h, sin(base_angle) * arch_dist)
		
		# 2 triángulos por brizna para curvatura arqueada orgánica
		var mid_h: float = h * 0.48
		var mid_arch: float = arch_dist * 0.42
		var v_mid := root_center + Vector3(cos(base_angle) * mid_arch, mid_h, sin(base_angle) * mid_arch)
		
		# Triángulo 1: Base izquierda -> Base derecha -> Punto medio
		st.set_color(col_base); st.add_vertex(v_base_l)
		st.set_color(col_base); st.add_vertex(v_base_r)
		st.set_color(col_mid);  st.add_vertex(v_mid)
		
		# Triángulo 2: Base izquierda -> Punto medio -> Punta
		st.set_color(col_base); st.add_vertex(v_base_l)
		st.set_color(col_mid);  st.add_vertex(v_mid)
		st.set_color(col_tip);  st.add_vertex(v_tip)
	
	st.generate_normals()
	return st.commit()

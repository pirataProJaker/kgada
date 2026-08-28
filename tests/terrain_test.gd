extends Node3D
## Fase 1 - primer generador de terreno: un chunk fijo generado en Rust
## (Marching Cubes, crate `mcubes`) y convertido a un ArrayMesh de Godot.
## Sin streaming/chunks multiples todavia - eso viene en una fase posterior.

const CHUNK_RESOLUTION := 64
const VOXEL_SIZE := 2.5
const TERRAIN_SEED := 1
const PSX_SHADER := preload("res://shaders/psx_vertex_snap.gdshader")

# Colores por altura: verde (llanura) -> gris (roca de montana) -> blanco (nieve).
const LOW_COLOR := Color(0.3, 0.5, 0.25)
const MID_COLOR := Color(0.45, 0.43, 0.4)
const HIGH_COLOR := Color(0.92, 0.94, 0.97)
const GRADIENT_LOW_HEIGHT := 14.0
const GRADIENT_MID_HEIGHT := 24.0
const GRADIENT_HIGH_HEIGHT := 32.0

# Mucho mas fino que el default (40) - una malla de terreno densa se ve muy
# rota/ruidosa con un wobble tan fuerte; esto lo suaviza muchisimo sin quitarle
# el wobble a las cajas/props que ya se ven bien con el valor por defecto.
const TERRAIN_GRID_PRECISION := 260

const WALL_HEIGHT := 80.0
const WALL_THICKNESS := 2.0


func _ready() -> void:
	if not ClassDB.class_exists("TerrainGenerator"):
		push_warning("[terrain_test] TerrainGenerator no esta disponible - compila rust_core (cargo build) y reabre el proyecto.")
		return

	var generator = ClassDB.instantiate("TerrainGenerator")
	var data: Dictionary = generator.generate_chunk(CHUNK_RESOLUTION, VOXEL_SIZE, TERRAIN_SEED)
	generator.free()

	if data.is_empty():
		push_warning("[terrain_test] El generador de terreno devolvio datos vacios.")
		return

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := ShaderMaterial.new()
	material.shader = PSX_SHADER
	material.set_shader_parameter("grid_precision", TERRAIN_GRID_PRECISION)
	material.set_shader_parameter("use_height_gradient", true)
	material.set_shader_parameter("low_color", LOW_COLOR)
	material.set_shader_parameter("mid_color", MID_COLOR)
	material.set_shader_parameter("high_color", HIGH_COLOR)
	material.set_shader_parameter("gradient_low_height", GRADIENT_LOW_HEIGHT)
	material.set_shader_parameter("gradient_mid_height", GRADIENT_MID_HEIGHT)
	material.set_shader_parameter("gradient_high_height", GRADIENT_HIGH_HEIGHT)
	# Para agregar una textura real: coloca la imagen en assets/textures/terrain/
	# y asignala al parametro "Albedo Texture" de este material (Inspector), o
	# hazlo por codigo con material.set_shader_parameter("albedo_texture", tex).

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = array_mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)
	mesh_instance.create_trimesh_collision()

	var vertex_count: int = (data["vertices"] as PackedVector3Array).size()
	print("[terrain_test] Chunk de terreno generado: ", vertex_count, " vertices")

	_create_boundary_walls(CHUNK_RESOLUTION * VOXEL_SIZE)


## Muros invisibles alrededor del chunk para que no se pueda caminar/caer
## fuera del borde (el chunk todavia es fijo y unico - sin streaming).
func _create_boundary_walls(map_size: float) -> void:
	var half := map_size * 0.5
	var outer := map_size + WALL_THICKNESS * 2.0
	var wall_configs := [
		{"pos": Vector3(half, WALL_HEIGHT * 0.5 - 10.0, -WALL_THICKNESS * 0.5), "size": Vector3(outer, WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(half, WALL_HEIGHT * 0.5 - 10.0, map_size + WALL_THICKNESS * 0.5), "size": Vector3(outer, WALL_HEIGHT, WALL_THICKNESS)},
		{"pos": Vector3(-WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5 - 10.0, half), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, outer)},
		{"pos": Vector3(map_size + WALL_THICKNESS * 0.5, WALL_HEIGHT * 0.5 - 10.0, half), "size": Vector3(WALL_THICKNESS, WALL_HEIGHT, outer)},
	]

	for config in wall_configs:
		var wall := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = config["size"]
		collision.shape = shape
		wall.add_child(collision)
		wall.position = config["pos"]
		add_child(wall)

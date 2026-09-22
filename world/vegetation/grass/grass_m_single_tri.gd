class_name GrassMSingleTri
extends Node3D

## Césped 2D ultra-optimizado de 1 solo triángulo con silueta de briznas "MMMM".
## Diseñado para reducir la geometría al mínimo físico absoluto en gráficos 3D:
## 1 solo triángulo (3 vértices) proyectando una mata completa de césped mediante pixel art.

const GRASS_SHADER = preload("res://world/vegetation/grass/grass_single_triangle.gdshader")

static var _cached_material: ShaderMaterial
static var _cached_texture: Texture2D

static func get_grass_texture() -> Texture2D:
	if _cached_texture != null:
		return _cached_texture
	
	if ResourceLoader.has_cached("res://world/vegetation/grass/grass_m_texture.png"):
		_cached_texture = load("res://world/vegetation/grass/grass_m_texture.png")
		return _cached_texture
		
	var img := Image.new()
	var err = img.load("res://world/vegetation/grass/grass_m_texture.png")
	if err == OK:
		_cached_texture = ImageTexture.create_from_image(img)
	elif FileAccess.file_exists("res://world/vegetation/grass/grass_m_texture.png"):
		var f_img = Image.load_from_file("res://world/vegetation/grass/grass_m_texture.png")
		if f_img:
			_cached_texture = ImageTexture.create_from_image(f_img)
	
	return _cached_texture

static func get_shared_material() -> ShaderMaterial:
	if not _cached_material:
		_cached_material = ShaderMaterial.new()
		_cached_material.shader = GRASS_SHADER
		_cached_material.set_shader_parameter("grass_texture", get_grass_texture())
		_cached_material.set_shader_parameter("alpha_scissor_threshold", 0.45)
	return _cached_material

## Genera una malla de EXACTAMENTE 1 triángulo (3 vértices)
static func create_single_triangle_mesh(width: float = 0.38, height: float = 0.38) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var half_w = width * 0.5
	var normal = Vector3.FORWARD
	
	# Vértice 0: Base izquierda (0.0, 1.0 en UV)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, 1.0))
	st.add_vertex(Vector3(-half_w, 0.0, 0.0))
	
	# Vértice 1: Base derecha (1.0, 1.0 en UV)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, 1.0))
	st.add_vertex(Vector3(half_w, 0.0, 0.0))
	
	# Vértice 2: Cúspide central (0.5, 0.0 en UV)
	st.set_normal(normal)
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(Vector3(0.0, height, 0.0))
	
	return st.commit()

## Genera una malla de 2 triángulos cruzados en "+" (volumen 3D con solo 2 triángulos)
static func create_cross_triangles_mesh(width: float = 0.38, height: float = 0.38) -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_w = width * 0.5
	
	# Triángulo 1 (plano X-Y)
	st.set_normal(Vector3.FORWARD)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-half_w, 0.0, 0.0))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(half_w, 0.0, 0.0))
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(Vector3(0.0, height, 0.0))
	
	# Triángulo 2 (plano Z-Y perpendicular)
	st.set_normal(Vector3.RIGHT)
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(0.0, 0.0, -half_w))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(0.0, 0.0, half_w))
	st.set_uv(Vector2(0.5, 0.0)); st.add_vertex(Vector3(0.0, height, 0.0))
	
	return st.commit()

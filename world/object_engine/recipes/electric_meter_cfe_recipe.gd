class_name ElectricMeterCFERecipe
extends ObjectRecipeBase

## Receta Oficial del Medidor Eléctrico CFE (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente ObjectAtlas)
## Descompuesto matemáticamente en:
## 1. Caja de montaje o gabinete de switch (Cubo unitario)
## 2. Collarín base del enchufe (Cilindro low-poly de 12 lados)
## 3. Cuerpo de policarbonato gris CFE (Cilindro low-poly de 12 lados)
## 4. Carátula circular con textura digital CFE (Cilindro low-poly de 12 lados con atlas "medidor_cfe")
## 5. Aro metálico perimetral de sellado (Cilindro low-poly de 12 lados)

const ROT_FACING_Z := Basis(Vector3(1.0, 0.0, 0.0), 1.57079632679) # 90 grados en X para mirar hacia +Z


static func build(builder: ObjectBuilder, base_transform: Transform3D, params: Dictionary = {}) -> void:
	var include_switch_box: bool = params.get("include_switch_box", false)
	var include_enclosure: bool = params.get("include_enclosure", false)
	var z_offset: float = 0.0

	# 1. GABINETE O CAJA TRASERA (Opcional si va montado en caja metálica Square D o switch)
	if include_enclosure:
		var box_size := Vector3(0.24, 0.32, 0.10)
		var box_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.05))
		builder.add_smart_box(box_t, box_size, "commercial_cooler", "black_enamel", 0.55, 0.40, true)
		z_offset += 0.10

	# Base de rotación para que los cilindros tengan su tapa frontal mirando hacia +Z
	var t_face := base_transform * Transform3D(ROT_FACING_Z, Vector3.ZERO)

	# 2. BASE / COLLARÍN METÁLICO DEL SOCKET (Donde se clava al muro o base)
	var collar_t := t_face * Transform3D(Basis.IDENTITY, Vector3(0.0, z_offset + 0.010, 0.0))
	builder.add_smart_cylinder(collar_t, 0.096, 0.020, "medidor_cfe", "socket", 0.40, 0.70, false)

	# 3. CUERPO DE POLICARBONATO GRIS CFE
	var body_t := t_face * Transform3D(Basis.IDENTITY, Vector3(0.0, z_offset + 0.045, 0.0))
	builder.add_smart_cylinder(body_t, 0.090, 0.065, "commercial_cooler", "white_enamel", 0.45, 0.05, true)

	# 4. CARÁTULA CIRCULAR DIGITAL CFE (La textura oficial del medidor CFE)
	var dial_t := t_face * Transform3D(Basis.IDENTITY, Vector3(0.0, z_offset + 0.076, 0.0))
	builder.add_smart_cylinder(dial_t, 0.088, 0.005, "medidor_cfe", "dial", 0.20, 0.05, false)

	# 5. ARO DE SEGURIDAD / CERROJO PERIMETRAL DE ACERO INOXIDABLE
	var rim_t := t_face * Transform3D(Basis.IDENTITY, Vector3(0.0, z_offset + 0.065, 0.0))
	builder.add_smart_cylinder(rim_t, 0.092, 0.012, "medidor_cfe", "rim", 0.30, 0.85, false)

	# 6. CAJA DE SWITCH DE SEGURIDAD LATERAL (Si se solicita)
	if include_switch_box:
		var switch_size := Vector3(0.18, 0.26, 0.08)
		var switch_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.24, 0.0, 0.04))
		builder.add_smart_box(switch_t, switch_size, "commercial_cooler", "black_enamel", 0.60, 0.50, true)


static func get_metadata() -> Dictionary:
	return {
		"name": "Medidor CFE Digital Low-Poly",
		"category": "electricity",
		"dimensions": Vector3(0.20, 0.20, 0.09),
		"primitives": ["cylinder_12", "cube"],
		"draw_calls": "+0 Draw Calls"
	}

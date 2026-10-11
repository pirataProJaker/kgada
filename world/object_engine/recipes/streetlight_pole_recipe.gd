class_name StreetlightPoleRecipe
extends ObjectRecipeBase

## Receta Oficial de Poste de Alumbrado Público / Poste de Luz (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente ObjectAtlas)
## Comparte al 100% las primitivas base del Medidor CFE:
## 1. Mástil estructural vertical (Cilindro low-poly de 12 lados idéntico al medidor CFE)
## 2. Placa base de anclaje a banqueta (Cubo)
## 3. Brazo horizontal voladizo hacia el arroyo vehicular (Cubo)
## 4. Carcasa de luminaria LED (Cubo)
## 5. Cuña o reflector de haz de luz (Cuña/Wedge)

static func build(builder: Variant, base_transform: Transform3D, params: Dictionary = {}) -> void:
	var height: float = params.get("height", 6.8)
	var double_arm: bool = params.get("double_arm", false)
	var arm_reach: float = params.get("arm_reach", 1.4)
	var texture_key: String = params.get("texture_key", "commercial_cooler")

	# 1. PLACA BASE DE ANCLAJE A BANQUETA (Cubo)
	var base_plate_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0))
	builder.add_smart_box(base_plate_t, Vector3(0.38, 0.08, 0.38), texture_key, "black_enamel", 0.45, 0.65, true)

	# 2. MÁSTIL TUBULAR ESTRUCTURAL (Cilindro low-poly de 12 lados del medidor CFE)
	var mast_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))
	builder.add_smart_cylinder(mast_t, 0.10, height, texture_key, "aluminum_frame", 0.40, 0.70, true)

	# 3. ANILLO DE REFUERZO DE MÁSTIL A 1/3 DE ALTURA (Cilindro de 12 lados)
	var ring_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 2.2, 0.0))
	builder.add_smart_cylinder(ring_t, 0.12, 0.15, texture_key, "aluminum_frame", 0.35, 0.80, false)

	# 4. BRAZO HORIZONTAL VOLADIZO (Cubo)
	if double_arm:
		var arm_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height - 0.05, 0.0))
		builder.add_smart_box(arm_t, Vector3(arm_reach * 2.0, 0.09, 0.09), texture_key, "aluminum_frame", 0.45, 0.65, false)
		_build_luminaire(builder, base_transform * Transform3D(Basis.IDENTITY, Vector3(-arm_reach, height - 0.12, 0.0)), texture_key)
		_build_luminaire(builder, base_transform * Transform3D(Basis.IDENTITY, Vector3( arm_reach, height - 0.12, 0.0)), texture_key)
	else:
		var arm_center_x := arm_reach * 0.5
		var arm_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(arm_center_x, height - 0.05, 0.0))
		builder.add_smart_box(arm_t, Vector3(arm_reach, 0.09, 0.09), texture_key, "aluminum_frame", 0.45, 0.65, false)

		var brace_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(arm_center_x * 0.6, height - 0.35, 0.0))
		builder.add_smart_box(brace_t, Vector3(arm_reach * 0.5, 0.05, 0.05), texture_key, "aluminum_frame", 0.45, 0.65, false)
		_build_luminaire(builder, base_transform * Transform3D(Basis.IDENTITY, Vector3(arm_reach, height - 0.12, 0.0)), texture_key)


## Construye la cabeza de la luminaria LED usando cajas y cuñas
static func _build_luminaire(builder: ObjectBuilder, mount_t: Transform3D, texture_key: String) -> void:
	# Carcasa superior de la lámpara (Cubo)
	builder.add_smart_box(mount_t, Vector3(0.48, 0.10, 0.22), texture_key, "aluminum_frame", 0.40, 0.75, false)

	# Bisel aerodinámico trasero de la lámpara (Cuña)
	var bevel_t := mount_t * Transform3D(Basis(Vector3.UP, 3.14159265), Vector3(-0.28, 0.0, 0.0))
	builder.add_smart_wedge(bevel_t, Vector3(0.12, 0.10, 0.22), texture_key, "aluminum_frame", 0.40, 0.75, false)

	# Panel difusor LED inferior emisor de luz blanca (Caja plana hacia abajo)
	var lens_t := mount_t * Transform3D(Basis.IDENTITY, Vector3(0.04, -0.051, 0.0))
	builder.add_smart_box(lens_t, Vector3(0.36, 0.005, 0.18), texture_key, "white_enamel", 0.10, 0.05, false)


static func get_metadata() -> Dictionary:
	return {
		"name": "Poste de Alumbrado Público Urbano",
		"category": "urban",
		"dimensions": Vector3(1.60, 6.80, 0.40),
		"primitives": ["cylinder_12", "cube", "wedge"],
		"draw_calls": "+0 Draw Calls"
	}

class_name BarrierGateRecipe
extends ObjectRecipeBase

## Receta Oficial de Pluma de Acceso Vehicular / Barrera de Control (Play Sector X)
## Arquitectura: +0 Draw Calls (Vinculado 100% al Atlas Inteligente barrier_gate_atlas)
##
## Características:
## 1. Gabinete de control electromecánico (naranja vial, amarillo, blanco o gris).
## 2. Brazo / asta con franjas diagonales reflectivas rojas y blancas (o amarillas y negras).
## 3. Estado dinámico: Abierta (rotación ~85° hacia arriba) o Cerrada (horizontal bloqueando paso).
## 4. Poste receptor de apoyo en el extremo opuesto (catch post).
## 5. Colisión física ajustada según esté abierta o cerrada.

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


static func build(builder: Variant, base_transform: Transform3D, params: Dictionary = {}) -> void:
	# Parámetros configurables directos y sencillos
	var arm_length: float = float(params.get("arm_length", params.get("length", 3.2)))       # Longitud de la barra (3.2m estándar)
	var is_open: bool = bool(params.get("is_open", params.get("open", false)))               # Estado: abierta o cerrada
	var open_angle_deg: float = float(params.get("open_angle", 85.0))                        # Ángulo de apertura vertical (85° estándar)
	var cabinet_color: String = str(params.get("color", params.get("cabinet", "orange"))).to_lower() # "orange", "yellow", "white", "gray"
	var stripe_type: String = str(params.get("stripes", "red_white")).to_lower()            # "red_white" o "yellow_black"
	var has_catch_post: bool = bool(params.get("catch_post", true))                          # Poste de descanso en el otro extremo
	var has_collision: bool = bool(params.get("collision", true))
	var flip_side: bool = bool(params.get("flip", false))                                    # Invertir sentido de apertura (+X o -X)

	var atlas_key := "barrier_gate_atlas"

	# Región del gabinete
	var housing_region := "housing_orange"
	match cabinet_color:
		"yellow", "amarillo":
			housing_region = "housing_yellow"
		"white", "blanco":
			housing_region = "housing_white"
		"gray", "gris", "metal":
			housing_region = "housing_gray"
		_:
			housing_region = "housing_orange"

	# Región de las franjas de la pluma
	var arm_region := "arm_stripes_red_white"
	if stripe_type.contains("yellow") or stripe_type.contains("black") or stripe_type.contains("negro"):
		arm_region = "arm_stripes_yellow_black"

	var dir_x: float = -1.0 if flip_side else 1.0

	# =========================================================================
	# 1. GABINETE DE CONTROL / PEDESTAL (Altura estándar: 1.05m)
	# =========================================================================
	# Placa base de anclaje de acero
	var base_plate_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.025, 0.0))
	builder.add_smart_box(
		base_plate_t,
		Vector3(0.38, 0.05, 0.38),
		atlas_key,
		"pivot_metal",
		0.45,
		0.60,
		has_collision
	)

	# Cuerpo vertical del gabinete (32cm x 96cm x 30cm)
	var cabinet_h: float = 0.98
	var cabinet_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05 + cabinet_h * 0.5, 0.0))
	builder.add_smart_box(
		cabinet_t,
		Vector3(0.32, cabinet_h, 0.30),
		atlas_key,
		housing_region,
		0.35,
		0.15,
		has_collision
	)

	# Tapa superior biselada del gabinete (protección de lluvia)
	var top_cap_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05 + cabinet_h + 0.025, 0.0))
	builder.add_smart_box(
		top_cap_t,
		Vector3(0.34, 0.05, 0.32),
		atlas_key,
		"pivot_metal",
		0.40,
		0.50,
		false
	)

	# Indicador de estado LED (Rojo si está cerrada, Verde si está abierta)
	var led_region := "led_green" if is_open else "led_red"
	var led_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.88, 0.155))
	builder.add_smart_box(
		led_t,
		Vector3(0.08, 0.08, 0.015),
		atlas_key,
		led_region,
		0.10,
		0.05,
		false
	)

	# =========================================================================
	# 2. MECANISMO DE PIVOTE Y TAMBOR GIRATORIO
	# =========================================================================
	var pivot_y: float = 0.88 # Altura del eje de rotación de la pluma
	var pivot_x: float = (0.16 + 0.04) * dir_x

	# Tambor cilíndrico del motor de rotación
	var drum_t := base_transform * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(pivot_x, pivot_y, 0.0))
	builder.add_smart_cylinder(
		drum_t,
		0.075, # Radio de 7.5 cm
		0.08,  # Espesor
		atlas_key,
		"pivot_metal",
		0.35,
		0.70,
		false
	)

	# Brida / Mordaza de sujeción de la barra (abrazadera de acero)
	var clamp_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(pivot_x + 0.03 * dir_x, pivot_y, 0.0))
	builder.add_smart_box(
		clamp_t,
		Vector3(0.06, 0.12, 0.08),
		atlas_key,
		"aluminum",
		0.35,
		0.80,
		false
	)

	# =========================================================================
	# 3. BRAZO / ASTA DE LA PLUMA (BOOM ARM CON FRANJAS REFLECTIVAS)
	# =========================================================================
	var arm_angle: float = open_angle_deg if is_open else 0.0
	# Si flip_side es verdadero, la rotación hacia arriba se invierte
	var final_rot_deg := -arm_angle * dir_x

	# Centro de rotación ubicado en el pivote
	var pivot_basis := Basis(Vector3.FORWARD, deg_to_rad(final_rot_deg))
	var arm_half_len := arm_length * 0.5
	# Desplazamiento desde el centro del pivote hasta el centro de la barra
	var local_arm_center := Vector3(arm_half_len * dir_x, 0.0, 0.0)
	var arm_center_in_world := Vector3(pivot_x, pivot_y, 0.0) + pivot_basis * local_arm_center

	var arm_transform := base_transform * Transform3D(pivot_basis, arm_center_in_world)

	# Barra principal con franjas de seguridad reflectivas
	var arm_height: float = 0.085 # 8.5 cm de altura de barra
	var arm_thickness: float = 0.035 # 3.5 cm de perfil
	builder.add_smart_box(
		arm_transform,
		Vector3(arm_length, arm_height, arm_thickness),
		atlas_key,
		arm_region,
		0.25, # Reflejo de plástico reflectivo 3M
		0.08,
		has_collision
	)

	# Tapa de goma protectora en la punta de la pluma
	var tip_pos := Vector3(pivot_x, pivot_y, 0.0) + pivot_basis * Vector3((arm_length + 0.01) * dir_x, 0.0, 0.0)
	var tip_t := base_transform * Transform3D(pivot_basis, tip_pos)
	builder.add_smart_box(
		tip_t,
		Vector3(0.02, arm_height + 0.005, arm_thickness + 0.005),
		atlas_key,
		"pivot_metal",
		0.80,
		0.0,
		false
	)

	# =========================================================================
	# 4. POSTE RECEPTOR DE DESCANSO (CATCH POST EN EXTREMO OPUESTO)
	# =========================================================================
	if has_catch_post:
		var catch_x := (pivot_x + arm_length * dir_x)
		var catch_base_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(catch_x, 0.02, 0.0))

		# Placa base del poste
		builder.add_smart_box(
			catch_base_t,
			Vector3(0.20, 0.04, 0.20),
			atlas_key,
			"pivot_metal",
			0.45,
			0.60,
			has_collision
		)

		# Mástil vertical del soporte (Tubo de acero)
		var catch_h: float = pivot_y - (arm_height * 0.5) - 0.02
		var catch_post_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(catch_x, catch_h * 0.5 + 0.04, 0.0))
		builder.add_smart_cylinder(
			catch_post_t,
			0.04, # 4 cm de radio
			catch_h,
			atlas_key,
			"aluminum",
			0.35,
			0.80,
			has_collision
		)

		# Horquilla en 'U' receptora donde descansa la barra
		var fork_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(catch_x, catch_h + 0.04, 0.0))
		builder.add_smart_box(
			fork_t,
			Vector3(0.08, 0.02, 0.12),
			atlas_key,
			"pivot_metal",
			0.40,
			0.60,
			false
		)
		# Aletas laterales de la horquilla
		for side_z in [-0.05, 0.05]:
			var flap_t := base_transform * Transform3D(Basis.IDENTITY, Vector3(catch_x, catch_h + 0.06, side_z))
			builder.add_smart_box(
				flap_t,
				Vector3(0.08, 0.06, 0.015),
				atlas_key,
				"pivot_metal",
				0.40,
				0.60,
				false
			)

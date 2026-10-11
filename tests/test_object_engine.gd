@tool
extends SceneTree

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")
const ObjectRecipeBaseScript = preload("res://world/object_engine/object_recipe_base.gd")
const ObjectBuilderScript = preload("res://world/object_engine/object_builder.gd")


# Receta de prueba: Una máquina expendedora retro (Vending Machine) compuesta por:
# - 1 Caja principal para el cuerpo
# - 1 Caja frontal para el panel de selección
# - 4 Cilindros para las patas
# - 1 Cuña para la marquesina inclinada
class RetroVendingMachineRecipe extends ObjectRecipeBaseScript:
	static func build(builder: ObjectBuilderScript, base_t: Transform3D, _params: Dictionary = {}) -> void:
		# Cuerpo principal (Caja)
		builder.add_box(
			base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, 0.0)),
			Vector3(0.9, 1.8, 0.8),
			"commercial_cooler",
			Rect2(0.0, 0.5, 0.5, 0.5), # Esmalte negro
			0.35, 0.15, true
		)

		# Display / Marquesina superior inclinada (Cuña)
		builder.add_wedge(
			base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 1.95, 0.05)),
			Vector3(0.85, 0.20, 0.30),
			"commercial_cooler",
			Rect2(0.5, 0.0, 0.5, 0.25), # Logo
			0.20, 0.05, true
		)

		# 4 Patas cilíndricas
		var leg_offsets := [
			Vector3(-0.35, 0.05, -0.30),
			Vector3( 0.35, 0.05, -0.30),
			Vector3(-0.35, 0.05,  0.30),
			Vector3( 0.35, 0.05,  0.30)
		]
		for offset in leg_offsets:
			builder.add_cylinder(
				base_t * Transform3D(Basis.IDENTITY, offset),
				0.04, 0.10,
				"commercial_cooler",
				Rect2(0.0, 0.5, 0.1, 0.1),
				0.40, 0.80, true
			)


func _init() -> void:
	print("--- INICIANDO TEST DEL MOTOR DE OBJETOS (+0 DRAW CALLS) ---")

	var engine := ObjectEngineScript.new()
	var root := Node3D.new()
	root.add_child(engine)

	var builder := engine.get_builder()

	# Construir 20 máquinas expendedoras en distintas posiciones del mundo
	for i in range(20):
		var t := Transform3D(Basis.IDENTITY, Vector3(float(i) * 1.5, 0.0, 0.0))
		RetroVendingMachineRecipe.build(builder, t)

	print("Total de piezas geométricas encoladas: %d" % builder.get_total_instances())
	print("Total de colisiones registradas: %d" % builder.get_collisions().size())

	# Ejecutar el commit del motor
	engine.commit()

	var stats := engine.get_stats()
	print("ESTADÍSTICAS DEL MOTOR DE OBJETOS:")
	print("- Total instancias procesadas en GPU: %d" % stats["total_instances"])
	print("- Draw Calls totales consumidos: %d" % stats["draw_calls"])
	print("- Primitivas activas en escena: %s" % str(stats["primitives_active"]))
	print("- Formas de colisión consolidadas: %d" % stats["collision_shapes"])

	# Verificación de la ley fundamental de PSX
	# 20 máquinas expendedoras = 20 cuerpos + 20 marquesinas + 80 patas = 120 piezas
	# Pero solo usan 3 tipos de primitivas (cube, wedge, cylinder).
	# Por lo tanto, el número total de draw calls DEBE ser exactamente 3.
	assert(stats["draw_calls"] == 3, "ERROR: Los draw calls deben ser exactamente 3 (1 por primitiva).")
	assert(stats["total_instances"] == 120, "ERROR: Deben haber 120 instancias en total.")
	print("--> RESULTADO: TEST SUPERADO CON ÉXITO (+0 DRAW CALLS COMPROBADO).")

	root.free()
	quit(0)

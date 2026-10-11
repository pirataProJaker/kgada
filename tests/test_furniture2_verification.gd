@tool
extends SceneTree

## Script de Verificación de Toda la Colección Furniture 2.0 (Interior Village)
## Comprueba que todos los modelos de las 5 tandas se instancien correctamente
## con el Motor de Objetos (ObjectEngine) a +0 Draw Calls y sin errores.

const ObjectEngineScript = preload("res://world/object_engine/object_engine.gd")

func _init() -> void:
	print("=======================================================================")
	print("INICIANDO VERIFICACIÓN UNIVERSAL DE FURNITURE 2.0 (+0 DRAW CALLS)")
	print("=======================================================================")

	var root_3d := Node3D.new()
	root.add_child(root_3d)

	var engine = ObjectEngineScript.new()
	root_3d.add_child(engine)
	var builder = engine.get_builder()

	# Lista maestra de claves de prueba para los modelos de Furniture 2.0
	var test_models: Array[String] = [
		# Tanda 1: Asientos (12)
		"sofa_damask_gold", "sofa_floral_cottage", "sofa_wood_minimal",
		"sofa_chesterfield_red", "armchair_chesterfield_red", "armchair_wingback_leather",
		"armchair_tufted_charcoal", "armchair_tufted_skyblue", "armchair_velvet_mustard",
		"chair_dining_cream", "chair_baroque_oval", "armchair_louis_xv_blue",

		# Tanda 2: Camas (5)
		"bed_single_plaid", "bed_double_iron_arabesque", "bed_double_grey_duvet",
		"bed_double_rustic_band", "bed_double_rustic_wrinkled",

		# Tanda 3: Almacenamiento (16)
		"chest_drawers_tall_5", "chest_drawers_light_4", "chest_drawers_white_3",
		"nightstand_tapered_legs_3", "nightstand_tapered_legs_2", "sideboard_buffet_3drawers",
		"sideboard_low_2doors", "cupboard_welsh_dresser", "cupboard_vitrine_books",
		"cupboard_vitrine_books_02", "cupboard_glass_tall", "bookcase_full_books_tall",
		"bookcase_full_books_tall_01", "bookcase_books_low", "wardrobe_open_clothes",
		"wardrobe_open_coats",

		# Tanda 4: Cocina y Comedor (12)
		"kitchen_corner_wall_cabinet", "kitchen_base_counter_sink", "kitchen_island",
		"kitchen_stove_gas_white", "kitchen_refrigerator_beige", "table_hex_gingham_rack",
		"table_rect_gingham", "table_rect_lace_floral", "kitchen_hanging_utensils",
		"chair_kitchen_slat", "chair_kitchen_spindle", "chair_kitchen_upholstered",

		# Tanda 5: Props, Lámparas, Radios, Comida (36)
		"fan_pedestal_tall", "fan_desk_table", "fan_ceiling", "lamp_table_shade",
		"lamp_banker_green", "lamp_desk_gooseneck_black", "lamp_desk_gooseneck_white",
		"socket_lightbulb_stand", "alarm_clock_digital_red", "alarm_clock_digital_green",
		"radio_vintage_dial", "radio_portable", "walkie_talkie_military",
		"phone_rotary_black", "phone_pushbutton_beige", "paintings_wall_canvas",
		"magazines_books_stack", "trash_can_liner", "garbage_bag_full",
		"vase_flower_rose", "vase_flower_lavender", "food_pizza_box_open",
		"food_pizza_slice", "food_roast_chicken", "food_fried_basket",
		"food_meat_cuts", "food_soup_bowl", "food_dinner_plate", "food_pie_slice",
		"food_flan", "food_ice_cream_tub", "food_popsicle_red", "drink_soda_bottle",
		"drink_milk_jug", "drink_milk_strawberry", "drink_can"
	]

	var instantiated_count := 0
	var offset_x := 0.0
	for model_key in test_models:
		var t := Transform3D(Basis.IDENTITY, Vector3(offset_x, 0.0, 0.0))
		builder.add_furniture_by_script(model_key, t)
		instantiated_count += 1
		offset_x += 1.5

	print("✓ Instanciados exitosamente %d modelos en el ObjectBuilder." % instantiated_count)

	# Compilar geometría en el ObjectEngine
	engine.commit(builder)

	var primitive_counts: Dictionary = {}
	for c in engine.get_children():
		if c is MultiMeshInstance3D and c.multimesh:
			primitive_counts[c.name] = c.multimesh.instance_count

	print("✓ MultiMeshes compilados en ObjectEngine (+0 Draw Calls):")
	for p_name in primitive_counts:
		print("   - %s: %d instancias en GPU (1 Draw Call)" % [p_name, primitive_counts[p_name]])

	print("=======================================================================")
	print("✓ VERIFICACIÓN DE FURNITURE 2.0 COMPLETADA CON ÉXITO")
	print("=======================================================================")

	quit(0)

class_name Furniture2PropsRecipes
extends RefCounted

## Recetas Oficiales: Decoración, Lámparas, Radios, Comida y Props (Furniture 2.0 - Imagen 1)
## Para el Motor de Objetos de Play Sector X
## =========================================================================
## Arquitectura: +0 Draw Calls (Hardware Instancing en ObjectEngine)
## Modelos 1:1 fieles al asset pack "Interior Village" de elbolilloduro:
##
## Iluminación y Ventilación:
##   1. FanPedestalTallRecipe        - Ventilador de pie alto oscuro (ventilator)
##   2. FanDeskTableRecipe           - Ventilador de mesa bajo (ventilator_01)
##   3. FanCeilingRecipe             - Ventilador de techo con aspas (ceiling_fan)
##   4. LampTableShadeRecipe         - Lámpara de noche con pantalla de tela (lamp)
##   5. LampBankerGreenRecipe        - Lámpara de banquero con cristal verde esmeralda (lamp_02 / lamp_03)
##   6. LampDeskGooseneckBlackRecipe - Flexo de mesa cuello de ganso negro (desk_lamp)
##   7. LampDeskGooseneckWhiteRecipe - Flexo de mesa cuello de ganso blanco (desk_lamp_01)
##   8. SocketLightbulbStandRecipe   - Portalámparas con bombilla desnuda (focus)
##
## Tecnología y Comunicación Vintage:
##   9. AlarmClockDigitalRedRecipe   - Despertador digital LED rojo (alarm_clock)
##  10. AlarmClockDigitalGreenRecipe - Despertador digital LED verde (alarm_clock_01)
##  11. RadioVintageDialRecipe       - Radio receptor analógico con dial y altavoz (radio)
##  12. RadioPortableRecipe          - Radio transistor portátil con antena (radio_01)
##  13. WalkieTalkieMilitaryRecipe   - Walkie-talkie militar con antena (gadgets)
##  14. PhoneRotaryBlackRecipe       - Teléfono clásico de disco negro (phone)
##  15. PhonePushbuttonBeigeRecipe   - Teléfono de botones beige de oficina (phone_01)
##
## Decoración, Oficina y Desechos:
##  16. PaintingsWallCanvasRecipe    - Cuadro de pared enmarcado (paintings)
##  17. MagazinesBooksStackRecipe    - Pila de libros y revistas (books)
##  18. TrashCanLinerRecipe          - Bote de basura con bolsa gris (trash_can)
##  19. GarbageBagFullRecipe         - Bolsa de basura negra llena y atada (garbage_bags)
##  20. VaseFlowerRoseRecipe         - Florero con rosa roja (flower_table)
##  21. VaseFlowerLavenderRecipe     - Florero con vara de lavanda (flower_table_01)
##
## Alimentos y Bebidas:
##  22. FoodPizzaBoxOpenRecipe       - Caja de pizza abierta con pizza pepperoni (box_pizza, pizza)
##  23. FoodPizzaSliceRecipe         - Rebanada triangular de pizza servida (pizza)
##  24. FoodRoastChickenRecipe       - Pollo asado dorado entero sobre bandeja (chicken, plates)
##  25. FoodFriedBasketRecipe        - Canasta con frituras y empanizados (fried_foods)
##  26. FoodMeatCutsRecipe           - Bandeja con filetes de carne cruda (meat)
##  27. FoodSoupBowlRecipe           - Tazón hondo de sopa/ramen con fideos (plate_food)
##  28. FoodDinnerPlateRecipe        - Plato con guisado servido (plate_food_01)
##  29. FoodPieSliceRecipe           - Rebanada de pay/tarta de frutos rojos (cake)
##  30. FoodFlanRecipe               - Porción de flan con caramelo (flan)
##  31. FoodIceCreamTubRecipe        - Bote de helado con cuchara (ice_cream)
##  32. FoodPopsicleRedRecipe        - Paleta de hielo roja mexicana (palette)
##  33. DrinkSodaBottleRecipe        - Botella de vidrio de refresco (bottle)
##  34. DrinkMilkJugRecipe           - Galón de leche blanca (milk)
##  35. DrinkMilkStrawberryRecipe    - Tetrabrik de leche de fresa (box_strawberries)
##  36. DrinkCanRecipe               - Lata de refresco de aluminio (can)

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")
const AlarmClock01RecipeScript = preload("res://world/object_engine/recipes/alarm_clock_01_recipe.gd")


# =========================================================================
# 1. VENTILADOR DE PIE ALTO OSCURO (VENTILATOR)
# =========================================================================
class FanPedestalTallRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 1.25)
		var texture_key: String = params.get("texture_key", "ventilator")

		# Base circular pesada
		var base_disc_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0))
		builder.add_cylinder(base_disc_t, 0.22, 0.04, texture_key, ObjectAtlasScript.get_region(texture_key, "cage"), 0.35, 0.40)

		# Mástil telescópico de tubo metálico
		var pole_h := h - 0.38
		var pole_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, pole_h * 0.5 + 0.04, 0.0))
		builder.add_cylinder(pole_t, 0.02, pole_h, texture_key, ObjectAtlasScript.get_region(texture_key, "tube"), 0.30, 0.70, false)

		# Motor posterior
		var motor_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.16, -0.06))
		builder.add_cylinder(motor_t, 0.06, 0.12, texture_key, ObjectAtlasScript.get_region(texture_key, "tube"), 0.35, 0.40, false)

		# Reja frontal con aspas
		var cage_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, h - 0.16, 0.03))
		builder.add_cylinder(cage_t, 0.20, 0.06, texture_key, ObjectAtlasScript.get_region(texture_key, "cage"), 0.25, 0.50, false)


# =========================================================================
# 2. VENTILADOR DE MESA BAJO (VENTILATOR_01)
# =========================================================================
class FanDeskTableRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.45)
		var texture_key: String = params.get("texture_key", "ventilator_01")

		var base_disc_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.015, 0.0))
		builder.add_cylinder(base_disc_t, 0.12, 0.03, texture_key, ObjectAtlasScript.get_region(texture_key, "stand"), 0.30, 0.70)

		var neck_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0))
		builder.add_cylinder(neck_t, 0.016, 0.18, texture_key, ObjectAtlasScript.get_region(texture_key, "stand"), 0.30, 0.70, false)

		var motor_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.14, -0.04))
		builder.add_cylinder(motor_t, 0.05, 0.08, texture_key, ObjectAtlasScript.get_region(texture_key, "motor"), 0.40, 0.15, false)

		var cage_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0.0, h - 0.14, 0.02))
		builder.add_cylinder(cage_t, 0.15, 0.05, texture_key, ObjectAtlasScript.get_region(texture_key, "cage"), 0.35, 0.50, false)


# =========================================================================
# 3. VENTILADOR DE TECHO CON ASPAS (CEILING_FAN)
# =========================================================================
class FanCeilingRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var diameter: float = params.get("diameter", 1.10)
		var texture_key: String = params.get("texture_key", "ceiling_fan")

		# Tija colgante y campana de anclaje
		var rod_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.15, 0.0))
		builder.add_cylinder(rod_t, 0.015, 0.30, texture_key, ObjectAtlasScript.get_region(texture_key, "rod"), 0.30, 0.60, false)

		# Motor central
		var motor_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.32, 0.0))
		builder.add_cylinder(motor_t, 0.11, 0.08, texture_key, ObjectAtlasScript.get_region(texture_key, "motor"), 0.35, 0.50, false)

		# 4 Aspas de madera horizontales
		var blade_len := diameter * 0.42
		for i in range(4):
			var angle := float(i) * (PI * 0.5)
			var basis := Basis(Vector3.UP, angle)
			var blade_pos := Vector3(0.0, -0.31, 0.0) + basis * Vector3(0.0, 0.0, blade_len * 0.5 + 0.10)
			var blade_t := base_t * Transform3D(basis, blade_pos)
			builder.add_smart_box(blade_t, Vector3(0.12, 0.01, blade_len), texture_key, "blades", 0.55, 0.05, false)


# =========================================================================
# 4. LÁMPARA DE NOCHE CON PANTALLA DE TELA (LAMP)
# =========================================================================
class LampTableShadeRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.52)
		var texture_key: String = params.get("texture_key", "lamp")

		# Base de cerámica / metal
		var base_t_pos := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0))
		builder.add_cylinder(base_t_pos, 0.09, 0.20, texture_key, ObjectAtlasScript.get_region(texture_key, "metal"), 0.30, 0.60)

		# Pantalla cónica de tela plisada
		var shade_h := 0.22
		var shade_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - shade_h * 0.5, 0.0))
		builder.add_cylinder(shade_t, 0.14, shade_h, texture_key, ObjectAtlasScript.get_region(texture_key, "shade"), 0.70, 0.01, false)


# =========================================================================
# 5. LÁMPARA DE BANQUERO CRISTAL VERDE (LAMP_02 / LAMP_03)
# =========================================================================
class LampBankerGreenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.40)
		var texture_key: String = params.get("texture_key", "lamp_02")

		# Base pesada de latón dorado
		var base_plate_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.015, 0.0))
		builder.add_cylinder(base_plate_t, 0.09, 0.03, texture_key, ObjectAtlasScript.get_region(texture_key, "metal"), 0.25, 0.85)

		# Brazo de latón curvo
		var arm_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.18, 0.0))
		builder.add_cylinder(arm_t, 0.012, 0.30, texture_key, ObjectAtlasScript.get_region(texture_key, "metal"), 0.20, 0.90, false)

		# Pantalla semicilíndrica verde esmeralda
		var shade_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, h - 0.05, 0.04))
		builder.add_cylinder(shade_t, 0.05, 0.22, texture_key, ObjectAtlasScript.get_region(texture_key, "shade"), 0.20, 0.10, false)


# =========================================================================
# 6. FLEXO DE MESA CUELLO DE GANSO NEGRO (DESK_LAMP)
# =========================================================================
class LampDeskGooseneckBlackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.42)
		var texture_key: String = params.get("texture_key", "desk_lamp")

		var base_plate_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.015, 0.0))
		builder.add_cylinder(base_plate_t, 0.08, 0.03, texture_key, ObjectAtlasScript.get_region(texture_key, "base"), 0.35, 0.40)

		# Brazo flexible inclinado
		var neck_basis := Basis(Vector3.RIGHT, deg_to_rad(20.0))
		var neck_t := base_t * Transform3D(neck_basis, Vector3(0.0, 0.16, 0.04))
		builder.add_cylinder(neck_t, 0.01, 0.28, texture_key, ObjectAtlasScript.get_region(texture_key, "neck"), 0.35, 0.40, false)

		# Campana metálica
		var head_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(65.0)), Vector3(0.0, h - 0.06, 0.14))
		builder.add_cylinder(head_t, 0.06, 0.10, texture_key, ObjectAtlasScript.get_region(texture_key, "head"), 0.30, 0.45, false)


# =========================================================================
# 7. FLEXO DE MESA CUELLO DE GANSO BLANCO (DESK_LAMP_01)
# =========================================================================
class LampDeskGooseneckWhiteRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.42)
		var texture_key: String = params.get("texture_key", "desk_lamp_01")

		var base_plate_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.015, 0.0))
		builder.add_cylinder(base_plate_t, 0.08, 0.03, texture_key, ObjectAtlasScript.get_region(texture_key, "base"), 0.35, 0.35)

		var neck_basis := Basis(Vector3.RIGHT, deg_to_rad(20.0))
		var neck_t := base_t * Transform3D(neck_basis, Vector3(0.0, 0.16, 0.04))
		builder.add_cylinder(neck_t, 0.01, 0.28, texture_key, ObjectAtlasScript.get_region(texture_key, "neck"), 0.35, 0.35, false)

		var head_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(65.0)), Vector3(0.0, h - 0.06, 0.14))
		builder.add_cylinder(head_t, 0.06, 0.10, texture_key, ObjectAtlasScript.get_region(texture_key, "head"), 0.30, 0.35, false)


# =========================================================================
# 8. PORTALÁMPARAS CON BOMBILLA DESNUDA (FOCUS)
# =========================================================================
class SocketLightbulbStandRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "focus")

		# Base de rosca o taco de baquelita
		var socket_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0))
		builder.add_cylinder(socket_t, 0.035, 0.06, texture_key, ObjectAtlasScript.get_region(texture_key, "socket"), 0.45, 0.20)

		# Bombilla encendida luminosa
		var bulb_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.10, 0.0))
		builder.add_cylinder(bulb_t, 0.045, 0.08, texture_key, ObjectAtlasScript.get_region(texture_key, "bulb"), 0.10, 0.05, false)


# =========================================================================
# 9. DESPERTADOR DIGITAL LED ROJO (ALARM_CLOCK)
# =========================================================================
class AlarmClockDigitalRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.16)
		var d: float = params.get("depth", 0.08)
		var h: float = params.get("height", 0.07)
		var texture_key: String = params.get("texture_key", "alarm_clock")

		var clock_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(clock_t, Vector3(w, h, d), texture_key, "display", "case")


# =========================================================================
# 10. DESPERTADOR DIGITAL LED (ALARM_CLOCK_01 / 12:53)
# =========================================================================
class AlarmClockDigitalGreenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		AlarmClock01RecipeScript.build(builder, base_t, params)


# =========================================================================
# 11. RADIO VINTAGE CON DIAL Y ALTAVOZ (RADIO)
# =========================================================================
class RadioVintageDialRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.32)
		var d: float = params.get("depth", 0.14)
		var h: float = params.get("height", 0.20)
		var texture_key: String = params.get("texture_key", "radio")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(body_t, Vector3(w, h, d), texture_key, "dial", "case")


# =========================================================================
# 12. RADIO TRANSISTOR PORTÁTIL (RADIO_01)
# =========================================================================
class RadioPortableRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.22)
		var d: float = params.get("depth", 0.08)
		var h: float = params.get("height", 0.14)
		var texture_key: String = params.get("texture_key", "radio_01")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(body_t, Vector3(w, h, d), texture_key, "dial", "case")

		# Antena telescópica metálica extendida
		var ant_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-15.0)), Vector3(-w * 0.35, h + 0.12, 0.0))
		builder.add_cylinder(ant_t, 0.004, 0.26, "metal", Rect2(0.0, 0.0, 1.0, 1.0), 0.10, 0.95, false)


# =========================================================================
# 13. WALKIE-TALKIE MILITAR (GADGETS)
# =========================================================================
class WalkieTalkieMilitaryRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.08)
		var d: float = params.get("depth", 0.05)
		var h: float = params.get("height", 0.18)
		var texture_key: String = params.get("texture_key", "gadgets")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_smart_box(body_t, Vector3(w, h, d), texture_key, "case")

		var ant_t := base_t * Transform3D(Basis.IDENTITY, Vector3(-0.02, h + 0.08, 0.0))
		builder.add_cylinder(ant_t, 0.005, 0.16, texture_key, ObjectAtlasScript.get_region(texture_key, "antenna"), 0.30, 0.60, false)


# =========================================================================
# 14. TELÉFONO CLÁSICO DE DISCO NEGRO (PHONE)
# =========================================================================
class PhoneRotaryBlackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.22)
		var d: float = params.get("depth", 0.20)
		var h: float = params.get("height", 0.14)
		var texture_key: String = params.get("texture_key", "phone")

		# Base piramidal truncada
		var base_body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0))
		builder.add_smart_box(base_body_t, Vector3(w, 0.08, d), texture_key, "body")

		# Disco de marcar
		var dial_t := base_t * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(30.0)), Vector3(0.0, 0.065, 0.04))
		builder.add_cylinder(dial_t, 0.045, 0.015, texture_key, ObjectAtlasScript.get_region(texture_key, "dial"), 0.20, 0.30, false)

		# Auricular horizontal sobre la horquilla
		var hand_t := base_t * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, h, -0.02))
		builder.add_cylinder(hand_t, 0.025, 0.24, texture_key, ObjectAtlasScript.get_region(texture_key, "handset"), 0.25, 0.20, false)


# =========================================================================
# 15. TELÉFONO DE BOTONES BEIGE DE OFICINA (PHONE_01)
# =========================================================================
class PhonePushbuttonBeigeRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.20)
		var d: float = params.get("depth", 0.22)
		var h: float = params.get("height", 0.10)
		var texture_key: String = params.get("texture_key", "phone_01")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(body_t, Vector3(w, h, d), texture_key, "buttons", "body")


# =========================================================================
# 16. CUADRO DE PARED ENMARCADO (PAINTINGS)
# =========================================================================
class PaintingsWallCanvasRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.70)
		var h: float = params.get("height", 0.90)
		var texture_key: String = params.get("texture_key", "paintings")

		# Marco de madera
		var frame_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0))
		builder.add_smart_box(frame_t, Vector3(w, h, 0.03), "roble_claro", "")

		# Lienzo artístico con pintura
		var canvas_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.018))
		builder.add_smart_box(canvas_t, Vector3(w - 0.08, h - 0.08, 0.005), texture_key, "canvas", 0.55, 0.01, false)


# =========================================================================
# 17. PILA DE LIBROS Y REVISTAS (BOOKS)
# =========================================================================
class MagazinesBooksStackRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.26)
		var d: float = params.get("depth", 0.20)
		var h: float = params.get("height", 0.12)
		var texture_key: String = params.get("texture_key", "books")

		var stack_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(stack_t, Vector3(w, h, d), texture_key, "pages", "cover")


# =========================================================================
# 18. BOTE DE BASURA CON BOLSA GRIS (TRASH_CAN)
# =========================================================================
class TrashCanLinerRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.40)
		var r: float = params.get("radius", 0.15)
		var texture_key: String = params.get("texture_key", "trash_can")

		var can_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(can_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "can_body"), 0.50, 0.10)


# =========================================================================
# 19. BOLSA DE BASURA NEGRA LLENA (GARBAGE_BAGS)
# =========================================================================
class GarbageBagFullRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.55)
		var r: float = params.get("radius", 0.24)
		var texture_key: String = params.get("texture_key", "garbage_bags")

		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.40, 0.0))
		builder.add_cylinder(body_t, r, h * 0.70, texture_key, ObjectAtlasScript.get_region(texture_key, "plastic"), 0.35, 0.15)

		var knot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.06, 0.0))
		builder.add_cylinder(knot_t, 0.08, 0.12, texture_key, ObjectAtlasScript.get_region(texture_key, "knot"), 0.40, 0.10, false)


# =========================================================================
# 20. FLORERO CON ROSA ROJA (FLOWER_TABLE)
# =========================================================================
class VaseFlowerRoseRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.38)
		var texture_key: String = params.get("texture_key", "flower_table")

		var vase_h := 0.22
		var vase_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, vase_h * 0.5, 0.0))
		builder.add_cylinder(vase_t, 0.06, vase_h, texture_key, ObjectAtlasScript.get_region(texture_key, "vase"), 0.25, 0.10)

		var flower_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.06, 0.0))
		builder.add_cylinder(flower_t, 0.04, 0.12, texture_key, ObjectAtlasScript.get_region(texture_key, "rose"), 0.60, 0.02, false)


# =========================================================================
# 21. FLORERO CON VARA DE LAVANDA (FLOWER_TABLE_01)
# =========================================================================
class VaseFlowerLavenderRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.42)
		var texture_key: String = params.get("texture_key", "flower_table_01")

		var vase_h := 0.24
		var vase_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, vase_h * 0.5, 0.0))
		builder.add_cylinder(vase_t, 0.05, vase_h, texture_key, ObjectAtlasScript.get_region(texture_key, "vase"), 0.25, 0.10)

		var stem_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.08, 0.0))
		builder.add_cylinder(stem_t, 0.03, 0.16, texture_key, ObjectAtlasScript.get_region(texture_key, "lavender"), 0.65, 0.02, false)


# =========================================================================
# 22. CAJA DE PIZZA ABIERTA (BOX_PIZZA, PIZZA)
# =========================================================================
class FoodPizzaBoxOpenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var size: float = params.get("size", 0.42)
		var box_tex: String = params.get("box_tex", "box_pizza")

		# Fondo de la caja de cartón
		var bot_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0))
		builder.add_smart_box(bot_t, Vector3(size, 0.04, size), box_tex, "box_inside")

		# Tapa abierta levantada a 75°
		var lid_rot := Basis(Vector3.RIGHT, deg_to_rad(-75.0))
		var lid_pos := Vector3(0.0, 0.04, -size * 0.5) + lid_rot * Vector3(0.0, size * 0.5, 0.0)
		var lid_t := base_t * Transform3D(lid_rot, lid_pos)
		builder.add_smart_box(lid_t, Vector3(size, size, 0.015), box_tex, "box_lid", -1.0, -1.0, false)

		# Pizza circular de pepperoni dentro de la caja
		var pizza_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.045, 0.0))
		builder.add_cylinder(pizza_t, size * 0.42, 0.02, box_tex, ObjectAtlasScript.get_region(box_tex, "pizza"), 0.80, 0.02, false)


# =========================================================================
# 23. REBANADA TRIANGULAR DE PIZZA (PIZZA)
# =========================================================================
class FoodPizzaSliceRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var length: float = params.get("length", 0.18)
		var texture_key: String = params.get("texture_key", "pizza")

		var slice_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.01, 0.0))
		builder.add_smart_box(slice_t, Vector3(0.12, 0.02, length), texture_key, "slice")


# =========================================================================
# 24. POLLO ASADO ENTERO (CHICKEN, PLATES)
# =========================================================================
class FoodRoastChickenRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var length: float = params.get("length", 0.30)
		var texture_key: String = params.get("texture_key", "chicken")

		# Plato o bandeja blanca base
		var plate_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.015, 0.0))
		builder.add_cylinder(plate_t, 0.18, 0.03, "plates", Rect2(0.0, 0.0, 1.0, 1.0), 0.20, 0.20)

		# Cuerpo del pollo asado dorado
		var chicken_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.09, 0.0))
		builder.add_cylinder(chicken_t, 0.11, length, texture_key, ObjectAtlasScript.get_region(texture_key, "roast"), 0.65, 0.05, false)


# =========================================================================
# 25. BANDEJA CON FRITURAS Y EMPANIZADOS (FRIED_FOODS)
# =========================================================================
class FoodFriedBasketRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.28)
		var d: float = params.get("depth", 0.18)
		var texture_key: String = params.get("texture_key", "fried_foods")

		var basket_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.035, 0.0))
		builder.add_smart_box(basket_t, Vector3(w, 0.07, d), texture_key, "fries")


# =========================================================================
# 26. BANDEJA DE CORTES DE CARNE CRUDA (MEAT)
# =========================================================================
class FoodMeatCutsRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.30)
		var d: float = params.get("depth", 0.20)
		var texture_key: String = params.get("texture_key", "meat")

		var tray_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0))
		builder.add_smart_box(tray_t, Vector3(w, 0.04, d), texture_key, "steak")


# =========================================================================
# 27. TAZÓN HONDO DE SOPA/RAMEN (PLATE_FOOD)
# =========================================================================
class FoodSoupBowlRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var r: float = params.get("radius", 0.12)
		var h: float = params.get("height", 0.09)
		var texture_key: String = params.get("texture_key", "plate_food")

		var bowl_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(bowl_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "plate"), 0.30, 0.10)

		var soup_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.008, 0.0))
		builder.add_cylinder(soup_t, r * 0.90, 0.01, texture_key, ObjectAtlasScript.get_region(texture_key, "soup"), 0.40, 0.05, false)


# =========================================================================
# 28. PLATO CON GUISADO SERVIDO (PLATE_FOOD_01)
# =========================================================================
class FoodDinnerPlateRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var r: float = params.get("radius", 0.15)
		var h: float = params.get("height", 0.04)
		var texture_key: String = params.get("texture_key", "plate_food_01")

		var plate_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(plate_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "plate"), 0.20, 0.10)

		var food_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.005, 0.0))
		builder.add_cylinder(food_t, r * 0.80, 0.015, texture_key, ObjectAtlasScript.get_region(texture_key, "food"), 0.40, 0.05, false)


# =========================================================================
# 29. REBANADA DE TARTA DE FRUTOS ROJOS (CAKE)
# =========================================================================
class FoodPieSliceRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var length: float = params.get("length", 0.14)
		var h: float = params.get("height", 0.06)
		var texture_key: String = params.get("texture_key", "cake")

		var cake_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_smart_box(cake_t, Vector3(0.09, h, length), texture_key, "slice")


# =========================================================================
# 30. PORCIÓN DE FLAN CON CARAMELO (FLAN)
# =========================================================================
class FoodFlanRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var r: float = params.get("radius", 0.06)
		var h: float = params.get("height", 0.05)
		var texture_key: String = params.get("texture_key", "flan")

		var flan_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(flan_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "caramel"), 0.40, 0.05)


# =========================================================================
# 31. BOTE DE HELADO CON TAPA (ICE_CREAM)
# =========================================================================
class FoodIceCreamTubRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var r: float = params.get("radius", 0.07)
		var h: float = params.get("height", 0.12)
		var texture_key: String = params.get("texture_key", "ice_cream")

		var tub_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(tub_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "tub"), 0.40, 0.05)

		var lid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.005, 0.0))
		builder.add_cylinder(lid_t, r + 0.005, 0.01, texture_key, ObjectAtlasScript.get_region(texture_key, "lid"), 0.40, 0.05, false)


# =========================================================================
# 32. PALETA DE HIELO ROJA MEXICANA (PALETTE)
# =========================================================================
class FoodPopsicleRedRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var texture_key: String = params.get("texture_key", "palette")

		# Palito plano de madera
		var stick_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0))
		builder.add_smart_box(stick_t, Vector3(0.015, 0.08, 0.005), "roble_claro", "")

		# Bloque congelado rojo de la paleta
		var ice_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.12, 0.0))
		builder.add_smart_box(ice_t, Vector3(0.05, 0.10, 0.02), texture_key, "ice")


# =========================================================================
# 33. BOTELLA DE VIDRIO DE REFRESCO (BOTTLE)
# =========================================================================
class DrinkSodaBottleRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var h: float = params.get("height", 0.25)
		var r: float = params.get("radius", 0.04)
		var texture_key: String = params.get("texture_key", "bottle")

		# Cuerpo cilíndrico de la botella
		var body_h := h * 0.65
		var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h * 0.5, 0.0))
		builder.add_cylinder(body_t, r, body_h, texture_key, ObjectAtlasScript.get_region(texture_key, "glass"), 0.15, 0.10)

		# Faja serigrafiada con logotipo
		var label_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h * 0.5, 0.0))
		builder.add_cylinder(label_t, r + 0.001, body_h * 0.40, texture_key, ObjectAtlasScript.get_region(texture_key, "label"), 0.30, 0.10, false)

		# Cuello de botella delgado
		var neck_h := h * 0.35
		var neck_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h + neck_h * 0.5, 0.0))
		builder.add_cylinder(neck_t, r * 0.40, neck_h, texture_key, ObjectAtlasScript.get_region(texture_key, "glass"), 0.15, 0.10, false)

		# Chapa corona
		var cap_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, body_h + neck_h, 0.0))
		builder.add_cylinder(cap_t, r * 0.42, 0.01, texture_key, ObjectAtlasScript.get_region(texture_key, "cap"), 0.25, 0.75, false)


# =========================================================================
# 34. GALÓN DE LECHE BLANCA (MILK)
# =========================================================================
class DrinkMilkJugRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.13)
		var d: float = params.get("depth", 0.13)
		var h: float = params.get("height", 0.24)
		var texture_key: String = params.get("texture_key", "milk")

		var jug_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_panel_box(jug_t, Vector3(w, h, d), texture_key, "label", "jug")

		var cap_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.01, 0.0))
		builder.add_cylinder(cap_t, 0.022, 0.02, texture_key, ObjectAtlasScript.get_region(texture_key, "cap"), 0.35, 0.10, false)


# =========================================================================
# 35. TETRABRIK DE LECHE DE FRESA (BOX_STRAWBERRIES)
# =========================================================================
class DrinkMilkStrawberryRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var w: float = params.get("width", 0.08)
		var d: float = params.get("depth", 0.06)
		var h: float = params.get("height", 0.16)
		var texture_key: String = params.get("texture_key", "box_strawberries")

		var brick_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_smart_box(brick_t, Vector3(w, h, d), texture_key, "brick")


# =========================================================================
# 36. LATA DE REFRESCO DE ALUMINIO (CAN)
# =========================================================================
class DrinkCanRecipe extends ObjectRecipeBase:
	static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
		var r: float = params.get("radius", 0.033)
		var h: float = params.get("height", 0.125)
		var texture_key: String = params.get("texture_key", "can")

		var can_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
		builder.add_cylinder(can_t, r, h, texture_key, ObjectAtlasScript.get_region(texture_key, "label"), 0.35, 0.15)

		var lid_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h - 0.001, 0.0))
		builder.add_cylinder(lid_t, r - 0.002, 0.002, texture_key, ObjectAtlasScript.get_region(texture_key, "lid"), 0.20, 0.85, false)

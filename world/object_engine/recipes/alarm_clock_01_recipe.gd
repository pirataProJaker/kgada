class_name AlarmClock01Recipe
extends ObjectRecipeBase

## Receta Oficial del Despertador Digital Vintage (Alarm_clock_01.png) - Play Sector X
## Construido de forma limpia y ultra-optimizada utilizando la figura base 'chamfer_box'
## del Motor de Objetos (ObjectEngine), reduciendo la geometría de 20 piezas a solo 3:
## 1. Carcasa completa achaflanada (chamfer_box) con sus cantos suavizados a 45°.
## 2. Pantalla digital activa LCD/LED ámbar "12:53".
## 3. Botón Snooze superior circular.
## Costo: +0 Draw Calls adicionales.

const ObjectAtlasScript = preload("res://world/object_engine/object_atlas.gd")


static func build(builder: Variant, base_t: Transform3D, params: Dictionary = {}) -> void:
	var w: float = params.get("width", 0.16)
	var d: float = params.get("depth", 0.09)
	var h: float = params.get("height", 0.07)
	var texture_key: String = params.get("texture_key", "alarm_clock_01")
	var has_collision: bool = params.get("collision", true)

	# 1. Carcasa Principal Achaflanada (chamfer_box: 1 sola figura base para todo el cuerpo)
	var body_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))
	builder.add_smart_chamfer_box(body_t, Vector3(w, h, d), texture_key, "case", 0.45, 0.05, has_collision)

	# 2. Pantalla Digital Frontal Activa ("12:53")
	var disp_w := w * 0.72  # ~0.115 m
	var disp_h := h * 0.62  # ~0.043 m
	var disp_thick := 0.002
	var disp_basis := base_t.basis * Basis(Vector3.FORWARD, deg_to_rad(90.0))
	var disp_pos := base_t * Vector3(0.0, h * 0.5, (d * 0.5) + disp_thick * 0.5)
	var disp_t := Transform3D(disp_basis, disp_pos)
	builder.add_box(disp_t, Vector3(disp_h, disp_w, disp_thick), texture_key, ObjectAtlasScript.get_region(texture_key, "display"), 0.12, 0.15, false)

	# 3. Botón Snooze superior circular
	var snooze_t := base_t * Transform3D(Basis.IDENTITY, Vector3(0.0, h + 0.0025, 0.0))
	var snooze_region := ObjectAtlasScript.get_region(texture_key, "button_snooze")
	builder.add_cylinder(snooze_t, 0.014, 0.005, texture_key, snooze_region, 0.30, 0.15, false)


static func get_metadata() -> Dictionary:
	return {
		"name": "Despertador Digital Retro",
		"category": "prop",
		"texture_source": "Alarm_clock_01.png",
		"dimensions": Vector3(0.16, 0.07, 0.09),
		"draw_calls": 0
	}

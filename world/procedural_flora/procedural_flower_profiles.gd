class_name ProceduralFlowerProfiles
extends RefCounted

## Catálogo de perfiles y especies para el sistema botánico procedural.
## Todas las dimensiones están en metros (1.0 = 1 metro).

const MORPHOLOGY_SHRUB = "shrub"       # Arbusto leñoso ramificado con múltiples flores (Rosal)
const MORPHOLOGY_CLUSTER = "cluster"   # Manto/parche rastrero con roseta basal y abanico de flores (Margaritas)
const MORPHOLOGY_SPIKE = "spike"       # Espiga vertical con inflorescencias apiladas (Lavanda)
const MORPHOLOGY_SOLITARY = "solitary" # Tallo esbelto con una sola flor en copa (Amapola, Tulipán)
const MORPHOLOGY_FOCAL = "focal"       # Tallo robusto y alto con flor gigante orientada (Girasol)

const PROFILES: Dictionary = {
	"shrub_rose": {
		"name": "Rosal Silvestre",
		"latin_name": "Rosa canina / Rosa rubiginosa",
		"morphology": MORPHOLOGY_SHRUB,
		"min_height": 0.75,
		"max_height": 1.15,
		"stem_radius": 0.012,
		"stem_color": Color(0.24, 0.31, 0.16),
		"stem_woody_color": Color(0.35, 0.28, 0.20),
		"leaf_color": Color(0.18, 0.42, 0.14),
		"leaf_count_per_node": 3,
		"leaf_size": Vector2(0.045, 0.028),
		"has_thorns": true,
		"thorn_color": Color(0.45, 0.22, 0.18),
		"flower_count_min": 3,
		"flower_count_max": 7,
		"flower_radius": 0.055, # 11 cm de diámetro
		"petal_layers": 3,
		"petal_count": 5,
		"color_palettes": [
			Color(0.85, 0.12, 0.22), # Rosa clásica carmesí
			Color(0.95, 0.65, 0.75), # Rosa pastel
			Color(0.96, 0.94, 0.88), # Rosa blanca marfil
			Color(0.95, 0.82, 0.18), # Rosa amarilla silvestre
		],
		"center_color": Color(0.92, 0.78, 0.15),
		"growth_stages": {
			"sprout_end": 0.20,
			"veg_end": 0.50,
			"bud_end": 0.78,
			"bloom_end": 1.00
		}
	},
	"meadow_daisy": {
		"name": "Margarita Silvestre",
		"latin_name": "Bellis perennis",
		"morphology": MORPHOLOGY_CLUSTER,
		"min_height": 0.14,
		"max_height": 0.24,
		"stem_radius": 0.004,
		"stem_color": Color(0.28, 0.48, 0.20),
		"stem_woody_color": Color(0.28, 0.48, 0.20),
		"leaf_color": Color(0.22, 0.45, 0.16),
		"leaf_count_per_node": 1,
		"leaf_size": Vector2(0.035, 0.015),
		"has_thorns": false,
		"flower_count_min": 5,
		"flower_count_max": 12,
		"flower_radius": 0.026, # 5.2 cm de diámetro
		"petal_layers": 2,
		"petal_count": 8,
		"color_palettes": [
			Color(0.98, 0.98, 0.96), # Blanco puro
			Color(0.95, 0.85, 0.90), # Blanco con puntas rosadas
			Color(0.96, 0.92, 0.70), # Amarillo suave campestre
		],
		"center_color": Color(0.96, 0.78, 0.08), # Ojo amarillo brillante
		"growth_stages": {
			"sprout_end": 0.18,
			"veg_end": 0.45,
			"bud_end": 0.75,
			"bloom_end": 1.00
		}
	},
	"field_lavender": {
		"name": "Lavanda de Campo",
		"latin_name": "Lavandula angustifolia",
		"morphology": MORPHOLOGY_SPIKE,
		"min_height": 0.42,
		"max_height": 0.65,
		"stem_radius": 0.005,
		"stem_color": Color(0.35, 0.46, 0.32),
		"stem_woody_color": Color(0.40, 0.36, 0.28),
		"leaf_color": Color(0.32, 0.48, 0.35), # Hojas plateadas/grisáceas
		"leaf_count_per_node": 2,
		"leaf_size": Vector2(0.040, 0.008),
		"has_thorns": false,
		"flower_count_min": 4,
		"flower_count_max": 9,
		"flower_radius": 0.018,
		"spike_length": 0.14, # 14 cm de espiga de flores
		"petal_layers": 1,
		"petal_count": 6,
		"color_palettes": [
			Color(0.55, 0.38, 0.78), # Púrpura lavanda clásico
			Color(0.42, 0.30, 0.68), # Violeta oscuro profundo
			Color(0.68, 0.58, 0.85), # Lila pálido
		],
		"center_color": Color(0.45, 0.30, 0.60),
		"growth_stages": {
			"sprout_end": 0.20,
			"veg_end": 0.50,
			"bud_end": 0.78,
			"bloom_end": 1.00
		}
	},
	"wild_poppy": {
		"name": "Amapola Silvestre",
		"latin_name": "Papaver rhoeas",
		"morphology": MORPHOLOGY_SOLITARY,
		"min_height": 0.45,
		"max_height": 0.72,
		"stem_radius": 0.005,
		"stem_color": Color(0.28, 0.44, 0.18),
		"stem_woody_color": Color(0.28, 0.44, 0.18),
		"leaf_color": Color(0.24, 0.42, 0.16),
		"leaf_count_per_node": 1,
		"leaf_size": Vector2(0.055, 0.022),
		"has_thorns": false,
		"flower_count_min": 1,
		"flower_count_max": 2,
		"flower_radius": 0.050, # 10 cm de diámetro
		"petal_layers": 2,
		"petal_count": 4, # 4 grandes pétalos sedosos
		"color_palettes": [
			Color(0.92, 0.15, 0.12), # Rojo escarlata intenso
			Color(0.96, 0.45, 0.18), # Naranja brillante
			Color(0.90, 0.25, 0.35), # Rosa carmesí
		],
		"center_color": Color(0.12, 0.12, 0.12), # Cápsula central negra/púrpura
		"growth_stages": {
			"sprout_end": 0.22,
			"veg_end": 0.52,
			"bud_end": 0.80,
			"bloom_end": 1.00
		}
	},
	"sunflower_focal": {
		"name": "Girasol Silvestre",
		"latin_name": "Helianthus annuus",
		"morphology": MORPHOLOGY_FOCAL,
		"min_height": 1.45,
		"max_height": 1.95,
		"stem_radius": 0.024, # Tallo grueso y robusto
		"stem_color": Color(0.32, 0.46, 0.18),
		"stem_woody_color": Color(0.34, 0.44, 0.20),
		"leaf_color": Color(0.22, 0.42, 0.14),
		"leaf_count_per_node": 2,
		"leaf_size": Vector2(0.18, 0.12), # Hojas anchas acorazonadas
		"has_thorns": false,
		"flower_count_min": 1,
		"flower_count_max": 2,
		"flower_radius": 0.15, # 30 cm de diámetro total
		"petal_layers": 2,
		"petal_count": 12,
		"color_palettes": [
			Color(0.98, 0.78, 0.06), # Amarillo solar dorado
			Color(0.95, 0.62, 0.08), # Naranja ámbar
		],
		"center_color": Color(0.22, 0.14, 0.08), # Ojo discoide marrón oscuro
		"growth_stages": {
			"sprout_end": 0.20,
			"veg_end": 0.55,
			"bud_end": 0.82,
			"bloom_end": 1.00
		}
	}
}

static func get_profile(profile_id: String) -> Dictionary:
	if PROFILES.has(profile_id):
		return PROFILES[profile_id]
	return PROFILES["shrub_rose"]

static func get_all_profile_ids() -> Array:
	return PROFILES.keys()

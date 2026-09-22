class_name ProceduralFlowerProfiles
extends RefCounted

## Catálogo de perfiles y especies para el sistema botánico procedural.
## Todas las dimensiones están en metros (1.0 = 1 metro).

const MORPHOLOGY_SHRUB = "shrub"       # Arbusto leñoso ramificado con múltiples flores (Rosal)
const MORPHOLOGY_CLUSTER = "cluster"   # Manto/parche rastrero con roseta basal y abanico de flores (Margaritas)
const MORPHOLOGY_SPIKE = "spike"       # Espiga vertical con inflorescencias apiladas (Lavanda)
const MORPHOLOGY_SOLITARY = "solitary" # Tallo esbelto con una sola flor en copa (Amapola, Tulipán)
const MORPHOLOGY_FOCAL = "focal"       # Tallo robusto y alto con flor gigante orientada (Girasol)

const ROSE_COLOR_NAMES := [
	"Rojo Carmesí",
	"Rosa Coral / Salmón (Foto Referencia)",
	"Rosa Pastel Delicado",
	"Blanco Marfil",
	"Amarillo Dorado",
	"Naranja Atardecer",
	"Negro Gótico"
]

const ROSE_PALETTES: Array[Color] = [
	Color(0.72, 0.04, 0.08), # Rojo carmesí profundo aterciopelado
	Color(0.92, 0.32, 0.30), # Rosa coral / salmón idéntico a la foto de referencia
	Color(0.92, 0.48, 0.58), # Rosa suave delicado
	Color(0.96, 0.95, 0.90), # Blanco marfil elegante
	Color(0.96, 0.80, 0.14), # Amarillo dorado imperial
	Color(0.95, 0.42, 0.12), # Naranja atardecer coral
	Color(0.18, 0.04, 0.08), # Negro gótico aterciopelado (Black Baccara)
]

const PROFILES: Dictionary = {
	"solitary_rose": {
		"name": "Rosa de Corte",
		"latin_name": "Rosa gallica / Rosa hybrid",
		"morphology": MORPHOLOGY_SOLITARY,
		"is_rose": true,
		"min_height": 0.42,
		"max_height": 0.50,
		"stem_radius": 0.0055,
		"stem_color": Color(0.035, 0.18, 0.045),
		"stem_woody_color": Color(0.14, 0.07, 0.04),
		"leaf_color": Color(0.038, 0.22, 0.055),
		"leaf_count_per_node": 3,
		"leaf_size": Vector2(0.092, 0.055),
		"has_thorns": true,
		"thorn_color": Color(0.48, 0.12, 0.10),
		"flower_count_min": 1,
		"flower_count_max": 1,
		"flower_radius": 0.068, # 13.6 cm de diámetro y 8.5 cm de altura (flor voluptuosa real)
		"petal_layers": 5,
		"petal_count": 8,
		"color_palettes": ROSE_PALETTES,
		"center_color": Color(0.14, 0.01, 0.02), # Corazón carmesí oscuro aterciopelado
		"growth_stages": {
			"sprout_end": 0.18,
			"veg_end": 0.48,
			"bud_end": 0.76,
			"bloom_end": 1.00
		}
	},
	"shrub_rose": {
		"name": "Rosal Silvestre / Arbustivo",
		"latin_name": "Rosa floribunda / Rosa canina",
		"morphology": MORPHOLOGY_SHRUB,
		"is_rose": true,
		"min_height": 0.76,
		"max_height": 1.00,
		"stem_radius": 0.0075,
		"stem_color": Color(0.035, 0.18, 0.045),
		"stem_woody_color": Color(0.12, 0.06, 0.03),
		"leaf_color": Color(0.038, 0.22, 0.055),
		"leaf_count_per_node": 3,
		"leaf_size": Vector2(0.086, 0.054),
		"has_thorns": true,
		"thorn_color": Color(0.44, 0.10, 0.08),
		"flower_count_min": 10,
		"flower_count_max": 16,
		"flower_radius": 0.060, # 12 cm de diámetro (escala ideal para flores múltiples en arbusto)
		"petal_layers": 5,
		"petal_count": 8,
		"color_palettes": ROSE_PALETTES,
		"center_color": Color(0.16, 0.01, 0.02),
		"growth_stages": {
			"sprout_end": 0.18,
			"veg_end": 0.48,
			"bud_end": 0.76,
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

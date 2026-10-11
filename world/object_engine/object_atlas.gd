class_name ObjectAtlas
extends RefCounted

## Atlas Inteligente del Motor de Objetos (Play Sector X)
## Sistema Centralizado y Semántico de Texturas y Regiones UV
## =========================================================================
## Responsabilidades:
## 1. Conoce la ubicación exacta (UV Rect2), rugosidad y acabado metálico de cada
##    componente de cada objeto del juego (puertas de congelador, copetes de estufa,
##    quemadores, perillas, granito, fajas de cajón, sábanas, displays de cooler, etc.).
## 2. Elimina por completo las coordenadas mágicas manuales ("a lo pendejo") en los modelos.
## 3. Mapea hacia el Texture2DArray universal unificado sin romper el hardware instancing
##    garantizando +0 Draw Calls adicionales.
## 4. Proporciona fallbacks resilientes con sugerencias semánticas en caso de errores de tipeo.

const FurnitureTextureManagerScript = preload("res://world/furniture/furniture_texture_manager.gd")

## Diccionario Maestro de Regiones Semánticas del Atlas Inteligente
## Formato por clave de textura:
## region_name -> { "rect": Rect2, "roughness": float, "metallic": float, "desc": String }
static var _REGIONS: Dictionary = {
	# =========================================================================
	# 1. REFRIGERADOR DOMÉSTICO (refrigerador.png - 256x256)
	# =========================================================================
	"refrigerador": {
		"freezer_door": {
			"rect": Rect2(0.005, 0.005, 0.320, 0.497),
			"roughness": 0.30,
			"metallic": 0.15,
			"desc": "Puerta superior del congelador con logo y bisel"
		},
		"main_door": {
			"rect": Rect2(0.005, 0.510, 0.320, 0.435),
			"roughness": 0.30,
			"metallic": 0.15,
			"desc": "Puerta inferior principal con manija empotrada y relieve"
		},
		"metal_body": {
			"rect": Rect2(0.350, 0.100, 0.600, 0.800),
			"roughness": 0.35,
			"metallic": 0.10,
			"desc": "Esmalte metálico liso blanco/marfil para laterales, techo y dorso"
		},
		"grille": {
			"rect": Rect2(0.010, 0.949, 0.315, 0.049),
			"roughness": 0.70,
			"metallic": 0.05,
			"desc": "Rejilla inferior frontal de ventilación y compresor"
		},
		"shelves": {
			"rect": Rect2(0.350, 0.100, 0.600, 0.800),
			"roughness": 0.15,
			"metallic": 0.20,
			"desc": "Repisas y gavetas interiores de cristal y plástico blanco"
		},
		"handle": {
			"rect": Rect2(0.350, 0.100, 0.100, 0.100),
			"roughness": 0.20,
			"metallic": 0.85,
			"desc": "Acabado de aluminio pulido / cromo para manijas externas"
		}
	},

	# =========================================================================
	# 2. ESTUFA DE COCINA (estufa.png - 256x256)
	# =========================================================================
	"estufa": {
		"burners": {
			"rect": Rect2(0.495, 0.005, 0.500, 0.375),
			"roughness": 0.85,
			"metallic": 0.10,
			"desc": "Cubierta superior con los 4 quemadores de hierro forjado y parrillas"
		},
		"backguard": {
			"rect": Rect2(0.005, 0.005, 0.480, 0.375),
			"roughness": 0.35,
			"metallic": 0.15,
			"desc": "Copete trasero con reloj digital, display y perillas serigrafiadas"
		},
		"oven_door": {
			"rect": Rect2(0.468, 0.388, 0.527, 0.390),
			"roughness": 0.25,
			"metallic": 0.20,
			"desc": "Puerta del horno con ventana de cristal ahumado y manija horizontal"
		},
		"drawer": {
			"rect": Rect2(0.468, 0.781, 0.527, 0.215),
			"roughness": 0.35,
			"metallic": 0.10,
			"desc": "Cajón inferior calientaplatos con manija inferior"
		},
		"side": {
			"rect": Rect2(0.005, 0.390, 0.455, 0.605),
			"roughness": 0.40,
			"metallic": 0.10,
			"desc": "Laterales de lámina esmaltada blanca y marco exterior"
		},
		"body": {
			"rect": Rect2(0.005, 0.390, 0.455, 0.605),
			"roughness": 0.40,
			"metallic": 0.10,
			"desc": "Alias de laterales de lámina esmaltada"
		},
		"knobs": {
			"rect": Rect2(0.005, 0.005, 0.100, 0.100),
			"roughness": 0.25,
			"metallic": 0.80,
			"desc": "Perillas de control frontales en cromo brillante"
		}
	},

	# =========================================================================
	# 3. GABINETES Y ALACENAS DE COCINA (cabinets.png - 256x256)
	# =========================================================================
	"cabinets": {
		"granite": {
			"rect": Rect2(0.08203, 0.00781, 0.55469, 0.32813),
			"roughness": 0.40,
			"metallic": 0.02,
			"desc": "Cubierta superior de granito jaspeado gris/negro con brillo pétreo (sin sangrado blanco)"
		},
		"wood_side": {
			"rect": Rect2(0.00781, 0.35938, 0.32813, 0.62891),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Vetas de madera natural clara para costados, piso interior y repisas"
		},
		"wood_body": {
			"rect": Rect2(0.00781, 0.35938, 0.32813, 0.62891),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Alias de laterales de madera clara"
		},
		"drawer": {
			"rect": Rect2(0.35938, 0.36719, 0.25000, 0.08594),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Frente de cajón superior de madera con ranura biselada"
		},
		"door_front": {
			"rect": Rect2(0.35938, 0.47656, 0.25000, 0.35938),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Hoja de puerta estilo shaker con marco perimetral y panel hundido"
		},
		"door": {
			"rect": Rect2(0.35938, 0.47656, 0.25000, 0.35938),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Alias de puerta estilo shaker"
		},
		"kick": {
			"rect": Rect2(0.35938, 0.85938, 0.25000, 0.12891),
			"roughness": 0.75,
			"metallic": 0.02,
			"desc": "Zócalo o rodapié inferior retranqueado para pies"
		},
		"kickplate": {
			"rect": Rect2(0.35938, 0.85938, 0.25000, 0.12891),
			"roughness": 0.75,
			"metallic": 0.02,
			"desc": "Alias de zócalo rodapié"
		},
		"sink_basin": {
			"rect": Rect2(0.64063, 0.62500, 0.35547, 0.36719),
			"roughness": 0.35,
			"metallic": 0.40,
			"desc": "Poceta o tarja de fregadero de acero inoxidable satinado"
		},
		"sink_rim": {
			"rect": Rect2(0.65625, 0.41000, 0.32000, 0.20000),
			"roughness": 0.30,
			"metallic": 0.45,
			"desc": "Bisel y pestaña perimetral de acero inoxidable para tarja"
		}
	},

	# =========================================================================
	# 4. HORNO DE MICROONDAS (microondas.png - 128x128)
	# =========================================================================
	"microondas": {
		"metal": {
			"rect": Rect2(0.005, 0.005, 0.385, 0.323),
			"roughness": 0.35,
			"metallic": 0.40,
			"desc": "Carcasa exterior lisa de metal esmaltado / acero satinado"
		},
		"body": {
			"rect": Rect2(0.005, 0.005, 0.385, 0.323),
			"roughness": 0.35,
			"metallic": 0.40,
			"desc": "Alias de carcasa exterior metálica"
		},
		"vent": {
			"rect": Rect2(0.005, 0.336, 0.385, 0.352),
			"roughness": 0.55,
			"metallic": 0.30,
			"desc": "Ranuras de ventilación louver para lateral izquierdo"
		},
		"panel": {
			"rect": Rect2(0.844, 0.336, 0.148, 0.352),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Teclado numérico de membrana, display LED verde y botones de cocción"
		},
		"control_panel": {
			"rect": Rect2(0.844, 0.336, 0.148, 0.352),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Alias de panel de control"
		},
		"door_window": {
			"rect": Rect2(0.398, 0.336, 0.446, 0.352),
			"roughness": 0.20,
			"metallic": 0.15,
			"desc": "Ventana frontal de puerta con malla metálica microperforada y jaladera"
		},
		"door": {
			"rect": Rect2(0.398, 0.336, 0.446, 0.352),
			"roughness": 0.20,
			"metallic": 0.15,
			"desc": "Alias de ventana frontal de puerta"
		},
		"cavity": {
			"rect": Rect2(0.469, 0.726, 0.492, 0.242),
			"roughness": 0.60,
			"metallic": 0.10,
			"desc": "Cavidad interior oscura de cocción"
		},
		"plate": {
			"rect": Rect2(0.469, 0.726, 0.492, 0.242),
			"roughness": 0.20,
			"metallic": 0.05,
			"desc": "Plato giratorio de vidrio"
		}
	},

	# =========================================================================
	# 5. LAVADORA Y SECADORA AUTOMÁTICA (washer.png / dryer.png - 128x128)
	# =========================================================================
	"washer": {
		"white_body": {
			"rect": Rect2(0.008, 0.008, 0.250, 0.150),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Esmalte blanco puro de electrodoméstico"
		},
		"body": {
			"rect": Rect2(0.008, 0.008, 0.250, 0.150),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Alias de cuerpo esmaltado blanco"
		},
		"control_panel": {
			"rect": Rect2(0.38281, 0.21094, 0.28125, 0.06250),
			"roughness": 0.28,
			"metallic": 0.15,
			"desc": "Copete trasero con 4 perillas y display LED azul digital"
		},
		"panel": {
			"rect": Rect2(0.38281, 0.21094, 0.28125, 0.06250),
			"roughness": 0.28,
			"metallic": 0.15,
			"desc": "Alias de panel de control de lavadora"
		},
		"lid": {
			"rect": Rect2(0.39063, 0.29688, 0.26563, 0.22656),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Tapa superior rectangular con marco y borde negro biselado"
		},
		"door": {
			"rect": Rect2(0.39063, 0.29688, 0.26563, 0.22656),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Alias de tapa superior de lavadora"
		},
		"front_seam": {
			"rect": Rect2(0.0, 0.57422, 1.0, 0.01172),
			"roughness": 0.50,
			"metallic": 0.05,
			"desc": "Línea de costura negra horizontal superior"
		},
		"steel_drum": {
			"rect": Rect2(0.01, 0.90625, 0.98, 0.08594),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Tambor interior de acero inoxidable pulido"
		},
		"drum": {
			"rect": Rect2(0.01, 0.90625, 0.98, 0.08594),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Alias de tambor interior de acero"
		}
	},
	"dryer": {
		"white_body": {
			"rect": Rect2(0.008, 0.008, 0.250, 0.150),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Esmalte blanco puro para secadora"
		},
		"body": {
			"rect": Rect2(0.008, 0.008, 0.250, 0.150),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Alias de esmalte blanco secadora"
		},
		"control_panel": {
			"rect": Rect2(0.38281, 0.21094, 0.28125, 0.06250),
			"roughness": 0.28,
			"metallic": 0.15,
			"desc": "Panel superior con temporizador y display LED azul"
		},
		"panel": {
			"rect": Rect2(0.38281, 0.21094, 0.28125, 0.06250),
			"roughness": 0.28,
			"metallic": 0.15,
			"desc": "Alias de panel de control de secadora"
		},
		"door": {
			"rect": Rect2(0.39063, 0.61719, 0.26563, 0.22656),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Puerta frontal cuadrada con esquinas biseladas y manija negra"
		},
		"front_seam": {
			"rect": Rect2(0.0, 0.57422, 1.0, 0.01172),
			"roughness": 0.50,
			"metallic": 0.05,
			"desc": "Línea de costura negra horizontal superior"
		},
		"steel_drum": {
			"rect": Rect2(0.01, 0.90625, 0.98, 0.08594),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Tambor interior de acero inoxidable para secadora"
		},
		"drum": {
			"rect": Rect2(0.01, 0.90625, 0.98, 0.08594),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Alias de tambor interior secadora"
		}
	},

	# =========================================================================
	# 6. TOSTADORA DE PAN (toaster.png - 128x128)
	# =========================================================================
	"toaster": {
		"slots": {
			"rect": Rect2(0.703, 0.500, 0.266, 0.469),
			"roughness": 0.30,
			"metallic": 0.85,
			"desc": "Placa superior cromada con ranuras dobles para rebanadas"
		},
		"steel_sides": {
			"rect": Rect2(0.005, 0.500, 0.479, 0.484),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Laterales de acero inoxidable brillante"
		},
		"body": {
			"rect": Rect2(0.005, 0.500, 0.479, 0.484),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Alias de laterales de acero inoxidable"
		},
		"lever_track": {
			"rect": Rect2(0.281, 0.125, 0.407, 0.344),
			"roughness": 0.40,
			"metallic": 0.70,
			"desc": "Canal vertical lateral con ranura de palanca eyectora"
		},
		"plain_metal": {
			"rect": Rect2(0.005, 0.005, 0.276, 0.479),
			"roughness": 0.30,
			"metallic": 0.80,
			"desc": "Acabado de aluminio satinado plano"
		},
		"toast_bread": {
			"rect": Rect2(0.080, 0.550, 0.320, 0.300),
			"roughness": 0.85,
			"metallic": 0.01,
			"desc": "Corteza dorada de pan tostado"
		},
		"rubber_feet": {
			"rect": Rect2(0.850, 0.850, 0.130, 0.130),
			"roughness": 0.90,
			"metallic": 0.02,
			"desc": "Patitas de goma negra antideslizantes"
		}
	},

	# =========================================================================
	# 7. REFRIGERADOR COMERCIAL MODULAR OXXO (commercial_cooler.png - 512x512)
	# =========================================================================
	"commercial_cooler": {
		"canopy_logo": {
			"rect": Rect2(0.50, 0.00, 0.50, 0.25),
			"roughness": 0.30,
			"metallic": 0.02,
			"desc": "Marquesina superior iluminada con logotipo y banner de refrescos"
		},
		"canopy_wings": {
			"rect": Rect2(0.75, 0.25, 0.25, 0.25),
			"roughness": 0.30,
			"metallic": 0.02,
			"desc": "Extensiones laterales blancas retroiluminadas para vitrinas anchas"
		},
		"stripes": {
			"rect": Rect2(0.00, 0.25, 0.50, 0.25),
			"roughness": 0.50,
			"metallic": 0.15,
			"desc": "Rejilla louver negra de condensador inferior"
		},
		"grille": {
			"rect": Rect2(0.00, 0.25, 0.50, 0.25),
			"roughness": 0.50,
			"metallic": 0.15,
			"desc": "Alias de rejilla inferior louver"
		},
		"thermostat": {
			"rect": Rect2(0.50, 0.25, 0.25, 0.25),
			"roughness": 0.25,
			"metallic": 0.10,
			"desc": "Termostato digital con pantalla LED roja de temperatura"
		},
		"white_enamel": {
			"rect": Rect2(0.50, 0.50, 0.50, 0.50),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Acabado exterior blanco industrial"
		},
		"white_body": {
			"rect": Rect2(0.50, 0.50, 0.50, 0.50),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Alias de acabado blanco industrial"
		},
		"black_enamel": {
			"rect": Rect2(0.00, 0.50, 0.50, 0.50),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Acabado exterior negro mate comercial"
		},
		"black_body": {
			"rect": Rect2(0.00, 0.50, 0.50, 0.50),
			"roughness": 0.35,
			"metallic": 0.05,
			"desc": "Alias de acabado negro comercial"
		},
		"glass": {
			"rect": Rect2(0.35, 0.15, 0.10, 0.10),
			"roughness": 0.05,
			"metallic": 0.10,
			"desc": "Vidrio templado reflectante de exhibición"
		},
		"aluminum_frame": {
			"rect": Rect2(0.65, 0.65, 0.10, 0.10),
			"roughness": 0.30,
			"metallic": 0.85,
			"desc": "Marco perimetral de puerta en aluminio anodizado"
		},
		"wire_shelf": {
			"rect": Rect2(0.65, 0.65, 0.10, 0.10),
			"roughness": 0.30,
			"metallic": 0.80,
			"desc": "Parrilla interna de alambre galvanizado"
		}
	},

	# =========================================================================
	# 8. ESTANTERÍA COMERCIAL MODULAR GÓNDOLA (commercial_shelf.png - 256x256)
	# =========================================================================
	"commercial_shelf": {
		"shelf_surface": {
			"rect": Rect2(0.0, 0.0, 1.0, 0.50),
			"roughness": 0.55,
			"metallic": 0.40,
			"desc": "Bandeja horizontal de chapa de acero con orificios porta-precios"
		},
		"upright_post": {
			"rect": Rect2(0.0, 0.50, 0.50, 0.50),
			"roughness": 0.50,
			"metallic": 0.60,
			"desc": "Poste ranurado vertical con ranuras de encastre para ménsulas"
		},
		"bracket": {
			"rect": Rect2(0.50, 0.50, 0.50, 0.50),
			"roughness": 0.50,
			"metallic": 0.60,
			"desc": "Ménsula angular de soporte para bandejas"
		}
	},

	# =========================================================================
	# 9. MESA DE CENTRO DE SALA (coffee_table.png - 128x128)
	# =========================================================================
	"coffee_table": {
		"tabletop": {
			"rect": Rect2(2.0 / 128.0, 26.0 / 128.0, 90.0 / 128.0, 57.0 / 128.0),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Cubierta superior de listones de madera machihembrada con nudos"
		},
		"drawer_front": {
			"rect": Rect2(0.008, 0.625, 0.711, 0.359),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Frente de cajón deslizante con marco tallado y tirador"
		},
		"legs": {
			"rect": Rect2(0.734, 0.078, 0.258, 0.391),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Patas cuadradas de madera maciza"
		},
		"wood_frame": {
			"rect": Rect2(0.734, 0.484, 0.258, 0.500),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Faldones y estructura perimetral del bastidor"
		}
	},

	# =========================================================================
	# 10. SILLÓN OREJERO Y SOFÁ DE CUERO (sofa_leather.png - 128x128)
	# =========================================================================
	"sofa_leather": {
		"capitone": {
			"rect": Rect2(87.0 / 128.0, 2.0 / 128.0, 38.0 / 128.0, 40.0 / 128.0),
			"roughness": 0.60,
			"metallic": 0.05,
			"desc": "Respaldo con acolchado capitoné en rombos con botones profundos"
		},
		"tufted": {
			"rect": Rect2(87.0 / 128.0, 2.0 / 128.0, 38.0 / 128.0, 40.0 / 128.0),
			"roughness": 0.60,
			"metallic": 0.05,
			"desc": "Alias de respaldo capitoné"
		},
		"smooth": {
			"rect": Rect2(87.0 / 128.0, 44.0 / 128.0, 38.0 / 128.0, 41.0 / 128.0),
			"roughness": 0.55,
			"metallic": 0.05,
			"desc": "Cuero liso marrón oscuro para dorso y vivos"
		},
		"plain": {
			"rect": Rect2(87.0 / 128.0, 44.0 / 128.0, 38.0 / 128.0, 41.0 / 128.0),
			"roughness": 0.55,
			"metallic": 0.05,
			"desc": "Alias de cuero liso"
		},
		"cushion": {
			"rect": Rect2(21.0 / 128.0, 34.0 / 128.0, 47.0 / 128.0, 46.0 / 128.0),
			"roughness": 0.60,
			"metallic": 0.05,
			"desc": "Cojín de asiento con costuras perimetrales dobles"
		},
		"side": {
			"rect": Rect2(12.0 / 128.0, 82.0 / 128.0, 90.0 / 128.0, 44.0 / 128.0),
			"roughness": 0.58,
			"metallic": 0.05,
			"desc": "Orejeras laterales y faldón inferior del sillón"
		},
		"armrest": {
			"rect": Rect2(5.0 / 128.0, 43.0 / 128.0, 15.0 / 128.0, 37.0 / 128.0),
			"roughness": 0.58,
			"metallic": 0.05,
			"desc": "Brazos redondos acolchados"
		},
		"wood_leg": {
			"rect": Rect2(68.0 / 128.0, 2.0 / 128.0, 17.0 / 128.0, 40.0 / 128.0),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Patas de madera oscura torneada con remaches de latón"
		}
	},

	# =========================================================================
	# 11. MEDIDOR ELÉCTRICO CFE (medidor_cfe.png - 512x512)
	# =========================================================================
	"medidor_cfe": {
		"dial": {
			"rect": Rect2(0.0, 0.0, 1.0, 1.0),
			"roughness": 0.20,
			"metallic": 0.05,
			"desc": "Carátula circular digital oficial CFE con display LCD de kWh y logotipo"
		},
		"rim": {
			"rect": Rect2(0.0, 0.5, 0.1, 0.1),
			"roughness": 0.30,
			"metallic": 0.85,
			"desc": "Aro de acero perimetral con precinto de seguridad"
		},
		"socket": {
			"rect": Rect2(0.0, 0.5, 0.2, 0.2),
			"roughness": 0.40,
			"metallic": 0.70,
			"desc": "Base o collarín de sujeción al muro en aluminio fundido"
		}
	},

	# =========================================================================
	# 12. ROPA DE CAMA MAESTRA (bed_linens_master_atlas.png - Cuadrícula 8x8)
	# =========================================================================
	"bed_linens_atlas": {
		"bare_mattress": {
			"rect": Rect2(0.0, 5.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
			"roughness": 0.80,
			"metallic": 0.01,
			"desc": "Colchón vintage rayado desnudo (Fila 5, Columna 0)"
		},
		"pillow": {
			"rect": Rect2(2.0 / 8.0, 5.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0),
			"roughness": 0.85,
			"metallic": 0.01,
			"desc": "Almohada con funda de algodón suave (Fila 5, Columna 2)"
		}
	},

	# =========================================================================
	# 13. ACABADOS DE MADERA REFINADA (pared_madera.png / pared_madera2.png)
	# =========================================================================
	"roble_claro": {
		"surface": {
			"rect": Rect2(0.0, 0.0, 1.0, 1.0),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Vetas de roble claro escandinavo para muebles y pisos"
		}
	},
	"nogal_oscuro": {
		"surface": {
			"rect": Rect2(0.0, 0.0, 1.0, 1.0),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Nogal oscuro señorial para comedores y armarios"
		}
	},
	"caoba_rojiza": {
		"surface": {
			"rect": Rect2(0.0, 0.0, 1.0, 1.0),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Caoba rojiza cálida para camas y mesas de noche"
		}
	},
	"pino_natural": {
		"surface": {
			"rect": Rect2(0.0, 0.0, 1.0, 1.0),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Pino miel dorado rústico"
		}
	},

	# =========================================================================
	# 14. SILLÓN DE OFICINA VERDE (chair01 - 256x256)
	# =========================================================================
	"chair01": {
		"cushion": {
			"rect": Rect2(0.65, 0.45, 0.33, 0.30),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Tapizado de tela verde para asiento y respaldo ergonómico"
		},
		"plastic_black": {
			"rect": Rect2(0.02, 0.02, 0.30, 0.30),
			"roughness": 0.45,
			"metallic": 0.10,
			"desc": "Carcasa posterior plástica negra, soporte de columna y base de 5 radios"
		},
		"stem": {
			"rect": Rect2(0.05, 0.05, 0.15, 0.15),
			"roughness": 0.35,
			"metallic": 0.50,
			"desc": "Cilindro neumático y soporte bajo el asiento"
		},
		"casters": {
			"rect": Rect2(0.01, 0.01, 0.10, 0.10),
			"roughness": 0.40,
			"metallic": 0.10,
			"desc": "Ruedas giratorias dobles de nylon negro"
		}
	},

	# =========================================================================
	# 15. SILLA DE OFICINA ROJA VINTAGE (chair02 - 256x256)
	# =========================================================================
	"chair02": {
		"cushion": {
			"rect": Rect2(0.05, 0.45, 0.45, 0.45),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Tapizado rojo/granate para asiento curvo y respaldo"
		},
		"metal_pipe": {
			"rect": Rect2(0.60, 0.55, 0.35, 0.35),
			"roughness": 0.30,
			"metallic": 0.75,
			"desc": "Estructura tubular metálica gris/cromo para soporte trasero"
		},
		"base_grey": {
			"rect": Rect2(0.65, 0.60, 0.30, 0.30),
			"roughness": 0.40,
			"metallic": 0.40,
			"desc": "Base estrellada gris y mecanismo giratorio"
		}
	},

	# =========================================================================
	# 16. LIBRERO ABIERTO DE OFICINA (cupboard01 - 256x256)
	# =========================================================================
	"cupboard01": {
		"wood_frame": {
			"rect": Rect2(0.00, 0.00, 0.45, 0.50),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Madera de roble claro para paredes laterales, techo y marco exterior"
		},
		"shelf": {
			"rect": Rect2(0.50, 0.00, 0.48, 0.50),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Superficie de baldas y repisas horizontales interiores"
		},
		"back_panel": {
			"rect": Rect2(0.02, 0.68, 0.25, 0.25),
			"roughness": 0.70,
			"metallic": 0.01,
			"desc": "Panel de fondo trasero de madera contrachapada"
		}
	},

	# =========================================================================
	# 17. ARMARIO Y GABINETE DE OFICINA CON PUERTAS (cupboard02 - 256x256)
	# =========================================================================
	"cupboard02": {
		"wood_frame": {
			"rect": Rect2(0.00, 0.00, 0.45, 0.30),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Cuerpo exterior de madera de roble/miel para costados y techo"
		},
		"door_panel": {
			"rect": Rect2(0.00, 0.30, 0.30, 0.35),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Hojas de puerta batiente estilo shaker con marco y moldura"
		},
		"shelf": {
			"rect": Rect2(0.35, 0.30, 0.40, 0.35),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Repisas y piso interior del mueble"
		},
		"knob": {
			"rect": Rect2(0.02, 0.65, 0.10, 0.10),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Pomos redondos de metal cromado para puertas"
		},
		"plinth": {
			"rect": Rect2(0.00, 0.75, 0.40, 0.20),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Zócalo o rodapié inferior de apoyo"
		}
	},

	# =========================================================================
	# 18. ESCRITORIO EJECUTIVO DOBLE PEDESTAL (desk01 - 256x256)
	# =========================================================================
	"desk01": {
		"wood_top": {
			"rect": Rect2(0.00, 0.00, 0.50, 0.40),
			"roughness": 0.50,
			"metallic": 0.02,
			"desc": "Cubierta superior de madera noble con barniz satinado"
		},
		"wood_body": {
			"rect": Rect2(0.00, 0.40, 0.50, 0.35),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Laterales de los pedestales y faldón de modestia central"
		},
		"drawer": {
			"rect": Rect2(0.00, 0.45, 0.45, 0.20),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Frentes de cajón de madera a juego"
		},
		"handle": {
			"rect": Rect2(0.25, 0.68, 0.15, 0.08),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Tiradores horizontales plateados de aluminio pulido"
		},
		"foot": {
			"rect": Rect2(0.50, 0.75, 0.25, 0.20),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Patas cúbicas de madera que elevan los pedestales"
		}
	},

	# =========================================================================
	# 19. ESCRITORIO METÁLICO TANKER (desk02 - 256x256)
	# =========================================================================
	"desk02": {
		"top_linoleum": {
			"rect": Rect2(0.08, 0.08, 0.55, 0.55),
			"roughness": 0.45,
			"metallic": 0.05,
			"desc": "Cubierta superior de linóleo/madera oscura con reborde metálico"
		},
		"metal_grey": {
			"rect": Rect2(0.75, 0.15, 0.24, 0.55),
			"roughness": 0.35,
			"metallic": 0.25,
			"desc": "Chapa de acero esmaltada en gris clásico de oficina"
		},
		"drawer": {
			"rect": Rect2(0.75, 0.15, 0.24, 0.25),
			"roughness": 0.35,
			"metallic": 0.25,
			"desc": "Frente de cajones metálicos grises"
		},
		"handle": {
			"rect": Rect2(0.75, 0.85, 0.20, 0.10),
			"roughness": 0.20,
			"metallic": 0.85,
			"desc": "Jaladeras cromadas redondeadas tipo tanker"
		},
		"leg": {
			"rect": Rect2(0.75, 0.75, 0.22, 0.20),
			"roughness": 0.30,
			"metallic": 0.75,
			"desc": "Patas cilíndricas de acero tubular"
		}
	},

	# =========================================================================
	# 20. ESCRITORIO EN L MODULAR (desk03 - 256x256)
	# =========================================================================
	"desk03": {
		"wood_top": {
			"rect": Rect2(0.00, 0.00, 0.45, 0.45),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cubierta de melamina madera clara para configuración en L"
		},
		"wood_body": {
			"rect": Rect2(0.00, 0.75, 0.45, 0.25),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Cuerpo del pedestal cajonero derecho"
		},
		"drawer": {
			"rect": Rect2(0.00, 0.45, 0.40, 0.25),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Frentes de cajón con textura de veta de madera"
		},
		"handle": {
			"rect": Rect2(0.30, 0.68, 0.12, 0.06),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Tiradores de cajón metálicos"
		}
	},

	# =========================================================================
	# 21. ESCRITORIO CON PATAS AZULES / SENCILLO (desk04 - 256x256)
	# =========================================================================
	"desk04": {
		"wood_top": {
			"rect": Rect2(0.00, 0.00, 0.45, 0.45),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cubierta de madera clara para escritorio individual"
		},
		"wood_body": {
			"rect": Rect2(0.00, 0.45, 0.45, 0.35),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Laterales de pedestal y patas de madera"
		},
		"drawer": {
			"rect": Rect2(0.00, 0.45, 0.40, 0.20),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajonera simple de madera"
		},
		"handle": {
			"rect": Rect2(0.20, 0.65, 0.15, 0.08),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Tirador de cajón plateado"
		},
		"blue_metal": {
			"rect": Rect2(0.6367, 0.1094, 0.3398, 0.1797),
			"roughness": 0.35,
			"metallic": 0.50,
			"desc": "Tubo de acero esmaltado en azul para patas en T y patines del escritorio en L"
		}
	},

	# =========================================================================
	# 22. ARCHIVERO VERTICAL METÁLICO (file_cabinet - 256x256)
	# =========================================================================
	"file_cabinet": {
		"metal_body": {
			"rect": Rect2(0.18, 0.20, 0.80, 0.35),
			"roughness": 0.40,
			"metallic": 0.25,
			"desc": "Chapa de acero gris carbón para paredes, techo y fondo del archivero"
		},
		"drawer_front": {
			"rect": Rect2(0.18, 0.00, 0.32, 0.18),
			"roughness": 0.35,
			"metallic": 0.30,
			"desc": "Frente de cajón con marco de etiqueta y jaladera empotrada"
		},
		"handle": {
			"rect": Rect2(0.18, 0.00, 0.15, 0.08),
			"roughness": 0.20,
			"metallic": 0.85,
			"desc": "Jaladera metálica y portatarjetas para rótulo"
		},
		"folders": {
			"rect": Rect2(0.504, 0.00, 0.250, 0.168),
			"roughness": 0.85,
			"metallic": 0.01,
			"desc": "Carpetas colgantes manila con pestañas indicadoras en cajón abierto"
		},
		"kickplate": {
			"rect": Rect2(0.18, 0.56, 0.32, 0.16),
			"roughness": 0.45,
			"metallic": 0.20,
			"desc": "Zócalo base inferior del archivero"
		}
	}
}

static var _is_initialized: bool = false


## Inicializa el Atlas Inteligente y sincroniza sus capas en el Texture2DArray
static func ensure_initialized() -> void:
	if _is_initialized:
		return
	FurnitureTextureManagerScript.ensure_initialized()
	_scan_folders_for_json_regions("res://assets/textures/furniture/")
	_scan_folders_for_json_regions("res://assets/textures/house/")
	_scan_folders_for_json_regions("res://assets/textures/office pack/")
	_is_initialized = true


## Escanea carpetas de texturas buscando archivos descriptores de regiones (.json)
static func _scan_folders_for_json_regions(folder_path: String) -> void:
	var gpath := ProjectSettings.globalize_path(folder_path)
	if not DirAccess.dir_exists_absolute(gpath):
		return
	var dir := DirAccess.open(gpath)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".json"):
			var full_path := folder_path.path_join(file_name)
			_load_regions_from_json(full_path, file_name.get_basename().to_lower())
		file_name = dir.get_next()
	dir.list_dir_end()


## Carga y registra dinámicamente regiones semánticas desde un descriptor JSON
static func _load_regions_from_json(json_path: String, texture_key: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for region_name in parsed:
			var entry: Dictionary = parsed[region_name]
			var rect := Rect2(0.0, 0.0, 1.0, 1.0)
			if entry.has("rect") and entry["rect"] is Array and entry["rect"].size() >= 4:
				var r_arr: Array = entry["rect"]
				rect = Rect2(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]), float(r_arr[3]))
			var roughness := float(entry.get("roughness", 0.55))
			var metallic := float(entry.get("metallic", 0.02))
			var desc := str(entry.get("desc", ""))
			register_region(texture_key, region_name, rect, roughness, metallic, desc)


## Resuelve de forma inteligente y unificada cualquier identificador semántico.
## Elimina por completo desincronizaciones entre capas y sub-regiones.
## Admite:
## - Clave compuesta: "cabinets/granite", "estufa/burners"
const _GLOBAL_ALIASES: Dictionary = {
	"granito": "cabinets/granite",
	"granite": "cabinets/granite",
	"tarja": "cabinets/sink_basin",
	"tarja_borde": "cabinets/sink_rim",
	"sink": "cabinets/sink_basin",
	"fregadero": "cabinets/sink_basin",
	"acero": "cabinets/sink_rim",
	"acero_inoxidable": "cabinets/sink_rim",
	"aluminio": "cabinets/sink_rim",
	"madera": "roble_claro",
	"madera_clara": "roble_claro",
	"madera_oscura": "nogal",
	"roble": "roble_claro",
	"vidrio": "commercial_cooler/glass",
	"cristal": "commercial_cooler/glass",
	"esmalte_blanco": "commercial_cooler/white_enamel",
	"metal_negro": "commercial_cooler/black_metal",
	"rejilla": "commercial_cooler/grill",
	"display": "commercial_cooler/display",
	"quemadores": "estufa/burners",
	"estufa_panel": "estufa/control_panel",
	"horno_puerta": "estufa/oven_door",
	"microondas_panel": "microondas/panel",
	"microondas_puerta": "microondas/door",
	"lavadora_panel": "washer/panel",
	"lavadora_puerta": "washer/door",
	"secadora_panel": "dryer/panel",
	"secadora_puerta": "dryer/door",
	"archivero": "file_cabinet/drawer_front",
	"carpetas": "file_cabinet/folders",
	"silla_oficina_verde": "chair01/cushion",
	"silla_oficina_roja": "chair02/cushion",
	"patas_azules": "desk04/blue_metal",
}


## - Dos argumentos: ("cabinets", "granite")
## - Solo nombre de región: ("granite") -> auto-detecta textura "cabinets"
## - Alias semántico universal: ("granito") -> auto-resuelve "cabinets/granite"
## - Textura directa: ("roble_claro") -> capa roble_claro, rect [0,0,1,1]
## Retorna Dictionary { "texture_key": String, "region_name": String, "layer": int, "uv_rect": Rect2, "roughness": float, "metallic": float }
static func resolve_semantic_texture(key_or_region: String, opt_region: String = "") -> Dictionary:
	ensure_initialized()
	var t_key := key_or_region.strip_edges().to_lower()
	var r_name := opt_region.strip_edges().to_lower()

	# 1. Alias global semántico (e.g. "granito" -> "cabinets/granite")
	if r_name.is_empty() and _GLOBAL_ALIASES.has(t_key):
		t_key = _GLOBAL_ALIASES[t_key]

	# 2. Soporte para paths semánticos "texture/region"
	if t_key.contains("/"):
		var parts := t_key.split("/", false)
		if parts.size() >= 2:
			t_key = parts[0]
			r_name = parts[1]

	# Si no se pasó región explícita, checamos si t_key es una región dentro de alguna textura
	if r_name.is_empty():
		var is_known_texture: bool = _REGIONS.has(t_key) or FurnitureTextureManagerScript.get_all_keys().has(t_key)
		if not is_known_texture:
			# Búsqueda inversa: ¿es t_key un nombre de región en _REGIONS?
			for parent_tex in _REGIONS:
				var regions_in_tex: Dictionary = _REGIONS[parent_tex]
				if regions_in_tex.has(t_key):
					r_name = t_key
					t_key = parent_tex
					break

	var final_layer := FurnitureTextureManagerScript.get_texture_layer(t_key)
	var final_rect := get_region(t_key, r_name)
	var final_props := get_material_properties(t_key, r_name)

	return {
		"texture_key": t_key,
		"region_name": r_name,
		"layer": final_layer,
		"uv_rect": final_rect,
		"roughness": final_props.get("roughness", 0.55),
		"metallic": final_props.get("metallic", 0.02)
	}


## Obtiene la sub-región UV Rect2 correspondiente a la textura y región semántica
static func get_region(texture_key: String, region_name: String = "") -> Rect2:
	ensure_initialized()
	var t_key := texture_key.to_lower()
	var r_name := region_name.to_lower()

	if r_name.is_empty():
		return Rect2(0.0, 0.0, 1.0, 1.0)

	if _REGIONS.has(t_key):
		var regions_dict: Dictionary = _REGIONS[t_key]
		if regions_dict.has(r_name):
			return regions_dict[r_name]["rect"]

	# Intento de búsqueda cruzada si el usuario pasó e.g. "dial" directamente
	for k in _REGIONS:
		var d: Dictionary = _REGIONS[k]
		if d.has(r_name):
			return d[r_name]["rect"]

	push_warning("[ObjectAtlas] Advertencia: Región '%s' no encontrada para textura '%s'. Usando [0, 0, 1, 1]." % [r_name, t_key])
	return Rect2(0.0, 0.0, 1.0, 1.0)


## Obtiene las propiedades de material (roughness y metallic) de una región
static func get_material_properties(texture_key: String, region_name: String = "") -> Dictionary:
	ensure_initialized()
	var t_key := texture_key.to_lower()
	var r_name := region_name.to_lower()

	if not r_name.is_empty() and _REGIONS.has(t_key):
		var regions_dict: Dictionary = _REGIONS[t_key]
		if regions_dict.has(r_name):
			var entry: Dictionary = regions_dict[r_name]
			return {
				"roughness": entry.get("roughness", 0.55),
				"metallic": entry.get("metallic", 0.02)
			}

	return {
		"roughness": 0.55,
		"metallic": 0.02
	}


## Verifica si una textura tiene registrada una región semántica
static func has_region(texture_key: String, region_name: String) -> bool:
	var t_key := texture_key.to_lower()
	var r_name := region_name.to_lower()
	if _REGIONS.has(t_key):
		return (_REGIONS[t_key] as Dictionary).has(r_name)
	return false


## Retorna el índice de capa del Texture2DArray para una clave dada
static func get_texture_layer(texture_key: String) -> int:
	ensure_initialized()
	return FurnitureTextureManagerScript.get_texture_layer(texture_key)


## Retorna el Texture2DArray universal compilado del Atlas Inteligente
static func get_texture_array() -> Texture2DArray:
	ensure_initialized()
	return FurnitureTextureManagerScript.get_texture_array()


## Permite registrar dinámicamente una nueva región semántica en el Atlas
static func register_region(texture_key: String, region_name: String, rect: Rect2, roughness: float = 0.55, metallic: float = 0.02, desc: String = "") -> void:
	var t_key := texture_key.to_lower()
	var r_name := region_name.to_lower()
	if not _REGIONS.has(t_key):
		_REGIONS[t_key] = {}
	_REGIONS[t_key][r_name] = {
		"rect": rect,
		"roughness": roughness,
		"metallic": metallic,
		"desc": desc
	}


## Retorna la sub-región UV exacta para una sábana del atlas 8x8 (patrones 0 a 15)
static func get_sheet_region(pattern_id: int) -> Rect2:
	var sid := clampi(pattern_id, 0, 15)
	var col := sid % 8
	var row := sid / 8
	return Rect2(float(col) / 8.0, float(row) / 8.0, 1.0 / 8.0, 1.0 / 8.0)


## Retorna la sub-región UV exacta para una cobija del atlas 8x8 (patrones 0 a 23)
static func get_blanket_region(pattern_id: int) -> Rect2:
	var bid := clampi(pattern_id, 0, 23)
	var col := bid % 8
	var row := 2 + (bid / 8)
	return Rect2(float(col) / 8.0, float(row) / 8.0, 1.0 / 8.0, 1.0 / 8.0)


## Retorna la sub-región UV del colchón desnudo rayado (Fila 5, Col 0)
static func get_bare_mattress_region() -> Rect2:
	return Rect2(0.0, 5.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0)


## Retorna la sub-región UV de la almohada con funda blanca (Fila 5, Col 2)
static func get_pillow_region() -> Rect2:
	return Rect2(2.0 / 8.0, 5.0 / 8.0, 1.0 / 8.0, 1.0 / 8.0)


## Retorna la lista de nombres de regiones disponibles para una textura
static func get_available_regions(texture_key: String) -> Array[String]:
	var t_key := texture_key.to_lower()
	if _REGIONS.has(t_key):
		var keys: Array[String] = []
		for k in _REGIONS[t_key]:
			keys.append(str(k))
		return keys
	return []


## Retorna todas las claves de texturas registradas en el atlas
static func get_all_texture_keys() -> Array[String]:
	ensure_initialized()
	var keys: Array[String] = []
	for k in _REGIONS:
		keys.append(str(k))
	return keys

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
		"cushion_seat": {
			"rect": Rect2(0.570, 0.406, 0.422, 0.426),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Cojín acolchado verde oliva para asiento con bordes redondeados"
		},
		"cushion_back": {
			"rect": Rect2(0.441, 0.070, 0.176, 0.313),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Cojín acolchado verde oliva para respaldo lumbar"
		},
		"cushion": {
			"rect": Rect2(0.570, 0.406, 0.422, 0.426),
			"roughness": 0.70,
			"metallic": 0.02,
			"desc": "Alias de cojín verde"
		},
		"shell_back": {
			"rect": Rect2(0.125, 0.063, 0.313, 0.328),
			"roughness": 0.45,
			"metallic": 0.10,
			"desc": "Carcasa plástica negra trasera del respaldo"
		},
		"shell_bottom": {
			"rect": Rect2(0.078, 0.406, 0.484, 0.414),
			"roughness": 0.45,
			"metallic": 0.10,
			"desc": "Carcasa plástica negra inferior del asiento"
		},
		"plastic_black": {
			"rect": Rect2(0.125, 0.063, 0.313, 0.328),
			"roughness": 0.45,
			"metallic": 0.10,
			"desc": "Plástico negro estructural"
		},
		"accordion": {
			"rect": Rect2(0.625, 0.141, 0.133, 0.215),
			"roughness": 0.50,
			"metallic": 0.10,
			"desc": "Fuelle de goma estriado para el cilindro de gas"
		},
		"stem": {
			"rect": Rect2(0.625, 0.141, 0.133, 0.215),
			"roughness": 0.50,
			"metallic": 0.10,
			"desc": "Columna neumática"
		},
		"base_arms": {
			"rect": Rect2(0.008, 0.867, 0.281, 0.078),
			"roughness": 0.45,
			"metallic": 0.10,
			"desc": "Radios de la base estrellada de 5 apoyos"
		},
		"casters": {
			"rect": Rect2(0.008, 0.781, 0.086, 0.086),
			"roughness": 0.40,
			"metallic": 0.10,
			"desc": "Ruedas dobles de nylon negro"
		}
	},

	# =========================================================================
	# 15. SILLA DE OFICINA ROJA VINTAGE (chair02 - 256x256)
	# =========================================================================
	"chair02": {
		"cushion_seat": {
			"rect": Rect2(0.008, 0.406, 0.586, 0.586),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Cojín circular rojo/borgoña para asiento con desgaste"
		},
		"cushion_back": {
			"rect": Rect2(0.512, 0.008, 0.398, 0.200),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Cojín ovalado rojo para respaldo"
		},
		"cushion": {
			"rect": Rect2(0.008, 0.406, 0.586, 0.586),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Alias de cojín rojo"
		},
		"metal_pipe": {
			"rect": Rect2(0.922, 0.008, 0.070, 0.602),
			"roughness": 0.20,
			"metallic": 0.15,
			"desc": "Tubo cromado vertical continuo para soporte del respaldo"
		},
		"accordion": {
			"rect": Rect2(0.594, 0.414, 0.121, 0.188),
			"roughness": 0.45,
			"metallic": 0.15,
			"desc": "Fuelle de columna estriado"
		},
		"base_grey": {
			"rect": Rect2(0.602, 0.609, 0.281, 0.305),
			"roughness": 0.35,
			"metallic": 0.50,
			"desc": "Radios metálicos esmaltados en gris para base de 4 apoyos"
		},
		"base_hub": {
			"rect": Rect2(0.723, 0.422, 0.168, 0.180),
			"roughness": 0.35,
			"metallic": 0.50,
			"desc": "Tapa central del mecanismo giratorio"
		}
	},

	# =========================================================================
	# 16. LIBRERO ABIERTO DE OFICINA (cupboard01 - 256x256)
	# =========================================================================
	"cupboard01": {
		"wood_frame": {
			"rect": Rect2(0.000, 0.000, 0.195, 0.664),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Tablero de roble con veta vertical para laterales y marco"
		},
		"shelf": {
			"rect": Rect2(0.203, 0.684, 0.375, 0.305),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Balda interior horizontal con veta horizontal"
		},
		"back_panel": {
			"rect": Rect2(0.586, 0.027, 0.180, 0.739),
			"roughness": 0.70,
			"metallic": 0.01,
			"desc": "Panel de fondo trasero con listones verticales"
		},
		"plinth": {
			"rect": Rect2(0.000, 0.672, 0.195, 0.141),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Zócalo inferior de madera oscura"
		}
	},

	# =========================================================================
	# 17. ARMARIO Y GABINETE DE OFICINA CON PUERTAS (cupboard02 - 256x256)
	# =========================================================================
	"cupboard02": {
		"doors_tall_pair": {
			"rect": Rect2(0.000, 0.293, 0.289, 0.398),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Par frontal completo de 2 puertas altas shaker con pomos integrados"
		},
		"door_tall_left": {
			"rect": Rect2(0.000, 0.293, 0.145, 0.398),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Hoja izquierda de puerta alta shaker con pomo"
		},
		"door_tall_right": {
			"rect": Rect2(0.145, 0.293, 0.145, 0.398),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Hoja derecha de puerta alta shaker con pomo"
		},
		"doors_low_pair": {
			"rect": Rect2(0.000, 0.700, 0.289, 0.180),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Par frontal completo de 2 puertas bajas con pomos integrados"
		},
		"door_low_left": {
			"rect": Rect2(0.000, 0.700, 0.145, 0.180),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Hoja izquierda de puerta baja con pomo"
		},
		"door_low_right": {
			"rect": Rect2(0.145, 0.700, 0.145, 0.180),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Hoja derecha de puerta baja con pomo"
		},
		"door_panel": {
			"rect": Rect2(0.000, 0.293, 0.289, 0.398),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Alias de puertas altas"
		},
		"wood_frame": {
			"rect": Rect2(0.414, 0.293, 0.289, 0.398),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Laterales de madera de roble con veta vertical"
		},
		"top_panel": {
			"rect": Rect2(0.414, 0.293, 0.289, 0.398),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cubierta superior del armario"
		},
		"shelf": {
			"rect": Rect2(0.414, 0.293, 0.289, 0.398),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Repisas interiores"
		},
		"plinth": {
			"rect": Rect2(0.301, 0.703, 0.109, 0.293),
			"roughness": 0.65,
			"metallic": 0.02,
			"desc": "Zócalo inferior de madera oscura"
		},
		"knob": {
			"rect": Rect2(0.133, 0.550, 0.025, 0.025),
			"roughness": 0.25,
			"metallic": 0.85,
			"desc": "Pomo metálico cromado"
		}
	},

	# =========================================================================
	# 18. ESCRITORIO EJECUTIVO DOBLE PEDESTAL (desk01 - 256x256)
	# =========================================================================
	"desk01": {
		"wood_top": {
			"rect": Rect2(0.000, 0.000, 0.328, 0.640),
			"roughness": 0.50,
			"metallic": 0.02,
			"desc": "Cubierta superior de nogal con veta orientada a lo largo del escritorio"
		},
		"wood_body": {
			"rect": Rect2(0.773, 0.086, 0.227, 0.609),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Costados y faldón de modestia con veta vertical"
		},
		"drawer": {
			"rect": Rect2(0.000, 0.648, 0.316, 0.074),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Frente de cajón de madera con veta horizontal"
		},
		"drawer_mid": {
			"rect": Rect2(0.000, 0.820, 0.191, 0.082),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajón intermedio con veta horizontal"
		},
		"drawer_bot": {
			"rect": Rect2(0.000, 0.906, 0.191, 0.082),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajón inferior con veta horizontal"
		},
		"handle": {
			"rect": Rect2(0.000, 0.727, 0.130, 0.074),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Tirador horizontal plateado de aluminio pulido"
		},
		"foot": {
			"rect": Rect2(0.773, 0.086, 0.227, 0.200),
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
			"rect": Rect2(0.000, 0.000, 0.328, 0.640),
			"roughness": 0.45,
			"metallic": 0.05,
			"desc": "Cubierta de linóleo oscuro continua sin costura central"
		},
		"metal_grey": {
			"rect": Rect2(0.773, 0.086, 0.227, 0.609),
			"roughness": 0.35,
			"metallic": 0.25,
			"desc": "Chapa de acero esmaltada en gris para costados y cuerpo"
		},
		"drawer": {
			"rect": Rect2(0.000, 0.648, 0.312, 0.078),
			"roughness": 0.35,
			"metallic": 0.25,
			"desc": "Frente de cajón metálico gris con sombreado perimetral"
		},
		"handle": {
			"rect": Rect2(0.000, 0.730, 0.125, 0.074),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Jaladera cromada redondeada estilo tanker"
		},
		"leg": {
			"rect": Rect2(0.773, 0.700, 0.227, 0.290),
			"roughness": 0.30,
			"metallic": 0.75,
			"desc": "Patas cilíndricas de acero tubular"
		}
	},

	# =========================================================================
	# 20. ESCRITORIO INDIVIDUAL CON CAJONERA Y PATAS ABIERTAS (desk03 - 256x256)
	# =========================================================================
	"desk03": {
		"wood_top": {
			"rect": Rect2(0.000, 0.000, 0.375, 0.656),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cubierta de madera con nudo y veta que corre a lo largo del escritorio al rotarse 90°"
		},
		"wood_body": {
			"rect": Rect2(0.508, 0.324, 0.215, 0.316),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Cuerpo del pedestal y patas con veta vertical"
		},
		"modesty": {
			"rect": Rect2(0.390, 0.000, 0.610, 0.250),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Faldón de modestia trasero con listones horizontales"
		},
		"drawer": {
			"rect": Rect2(0.000, 0.664, 0.188, 0.082),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Frente de cajón con veta horizontal"
		},
		"drawer_deep": {
			"rect": Rect2(0.000, 0.762, 0.188, 0.133),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajón inferior profundo"
		},
		"handle": {
			"rect": Rect2(0.203, 0.676, 0.133, 0.063),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Tiradores de cajón metálicos plateados"
		},
		"leg": {
			"rect": Rect2(0.390, 0.324, 0.094, 0.316),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Pata abierta de madera"
		}
	},

	# =========================================================================
	# 21. ESCRITORIO MODULAR EN L CON ESTRUCTURA AZUL (desk04 - 256x256)
	# =========================================================================
	"desk04": {
		"wood_top_main": {
			"rect": Rect2(0.000, 0.000, 0.610, 0.300),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Ala principal del escritorio en L con veta orientada a lo largo del ala al rotarse 90°"
		},
		"wood_top_return": {
			"rect": Rect2(0.000, 0.000, 0.300, 0.830),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Ala de retorno lateral con veta a lo largo del ala"
		},
		"wood_top": {
			"rect": Rect2(0.000, 0.000, 0.610, 0.300),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cubierta de melamina roble claro"
		},
		"wood_body": {
			"rect": Rect2(0.645, 0.490, 0.335, 0.330),
			"roughness": 0.60,
			"metallic": 0.02,
			"desc": "Pedestal cajonero de madera clara"
		},
		"drawer": {
			"rect": Rect2(0.309, 0.547, 0.191, 0.074),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajón de madera clara con veta horizontal"
		},
		"drawer_deep": {
			"rect": Rect2(0.309, 0.629, 0.191, 0.164),
			"roughness": 0.55,
			"metallic": 0.02,
			"desc": "Cajón inferior de gran capacidad"
		},
		"handle": {
			"rect": Rect2(0.527, 0.559, 0.032, 0.097),
			"roughness": 0.30,
			"metallic": 0.10,
			"desc": "Tirador metálico vertical/horizontal plateado"
		},
		"blue_metal": {
			"rect": Rect2(0.640, 0.115, 0.300, 0.165),
			"roughness": 0.35,
			"metallic": 0.50,
			"desc": "Tubo de acero esmaltado en azul para patas en T y patín"
		}
	},

	# =========================================================================
	# 22. ARCHIVERO VERTICAL METÁLICO (file_cabinet - 256x256)
	# =========================================================================
	"file_cabinet": {
		"metal_body": {
			"rect": Rect2(0.172, 0.172, 0.828, 0.375),
			"roughness": 0.40,
			"metallic": 0.25,
			"desc": "Chapa de acero gris carbón para laterales y fondo"
		},
		"top_surface": {
			"rect": Rect2(0.172, 0.000, 0.328, 0.168),
			"roughness": 0.40,
			"metallic": 0.25,
			"desc": "Cubierta superior del archivero"
		},
		"drawer_front": {
			"rect": Rect2(0.000, 0.172, 0.168, 0.129),
			"roughness": 0.35,
			"metallic": 0.30,
			"desc": "Frente de gaveta con jaladera cromada y marco de etiqueta integrado"
		},
		"handle": {
			"rect": Rect2(0.000, 0.172, 0.168, 0.129),
			"roughness": 0.20,
			"metallic": 0.85,
			"desc": "Jaladera metálica con portaetiquetas"
		},
		"folders": {
			"rect": Rect2(0.504, 0.000, 0.320, 0.168),
			"roughness": 0.85,
			"metallic": 0.01,
			"desc": "Carpetas colgantes manila con pestañas indicadoras"
		},
		"kickplate": {
			"rect": Rect2(0.172, 0.551, 0.328, 0.188),
			"roughness": 0.45,
			"metallic": 0.20,
			"desc": "Zócalo base inferior del archivero"
		}
	},

	# =========================================================================
	# 23. COLECCIÓN FURNITURE 2.0 (INTERIOR VILLAGE)
	# =========================================================================
	"bed": {
		"wood": { "rect": Rect2(0.005, 0.495, 0.555, 0.500), "roughness": 0.65, "metallic": 0.02, "desc": "Paneles de madera oscura lisa" },
		"wood_headboard": { "rect": Rect2(0.005, 0.220, 0.185, 0.270), "roughness": 0.65, "metallic": 0.02, "desc": "Cabecero de madera oscura con listones" },
		"wood_post": { "rect": Rect2(0.420, 0.055, 0.140, 0.435), "roughness": 0.60, "metallic": 0.02, "desc": "Postes esquineros y largueros de madera" },
		"duvet": { "rect": Rect2(0.566, 0.620, 0.380, 0.375), "roughness": 0.80, "metallic": 0.01, "desc": "Edredón rayado acolchado" },
		"plaid": { "rect": Rect2(0.566, 0.498, 0.380, 0.120), "roughness": 0.75, "metallic": 0.01, "desc": "Cenefa de cobija escocesa roja a cuadros" },
		"pillow": { "rect": Rect2(0.566, 0.498, 0.380, 0.120), "roughness": 0.80, "metallic": 0.01, "desc": "Almohada escocesa a juego" }
	},
	"bed_01": {
		"wood": { "rect": Rect2(0.005, 0.605, 0.590, 0.390), "roughness": 0.70, "metallic": 0.02, "desc": "Tablones de pino rústico dorado" },
		"wood_post": { "rect": Rect2(0.300, 0.605, 0.300, 0.390), "roughness": 0.70, "metallic": 0.02, "desc": "Postes y largueros de pino rústico" },
		"duvet": { "rect": Rect2(0.005, 0.250, 0.285, 0.260), "roughness": 0.80, "metallic": 0.01, "desc": "Sábana superior gris claro" },
		"band": { "rect": Rect2(0.005, 0.510, 0.285, 0.090), "roughness": 0.85, "metallic": 0.01, "desc": "Cenefa tejida artesanal con figuras decorativas" },
		"pillow": { "rect": Rect2(0.005, 0.250, 0.285, 0.260), "roughness": 0.80, "metallic": 0.01, "desc": "Almohada suave a juego" }
	},
	"bed_02": {
		"iron_white": { "rect": Rect2(0.350, 0.020, 0.300, 0.450), "roughness": 0.35, "metallic": 0.40, "desc": "Tubos de hierro forjado blanco" },
		"iron_arabesque": { "rect": Rect2(0.300, 0.005, 0.380, 0.480), "roughness": 0.35, "metallic": 0.40, "desc": "Filigrana y arabescos de hierro blanco" },
		"duvet": { "rect": Rect2(0.005, 0.495, 0.335, 0.500), "roughness": 0.80, "metallic": 0.01, "desc": "Edredón gris liso acolchado" },
		"sheet": { "rect": Rect2(0.345, 0.495, 0.335, 0.500), "roughness": 0.80, "metallic": 0.01, "desc": "Sábana bajera crema" },
		"pillow": { "rect": Rect2(0.005, 0.005, 0.300, 0.480), "roughness": 0.75, "metallic": 0.01, "desc": "Almohada con malla tejida y cenefa oscura" }
	},
	"bed_03": {
		"wood": { "rect": Rect2(0.005, 0.612, 0.560, 0.385), "roughness": 0.65, "metallic": 0.02, "desc": "Tablones de roble cálido" },
		"wood_headboard": { "rect": Rect2(0.565, 0.280, 0.195, 0.285), "roughness": 0.65, "metallic": 0.02, "desc": "Cabecero y piecero de madera" },
		"duvet": { "rect": Rect2(0.005, 0.225, 0.268, 0.380), "roughness": 0.80, "metallic": 0.01, "desc": "Edredón bicolor gris topo y beige" },
		"pillow": { "rect": Rect2(0.005, 0.080, 0.185, 0.140), "roughness": 0.80, "metallic": 0.01, "desc": "Almohadas oscuras carbón" }
	},
	"bed_04": {
		"wood": { "rect": Rect2(0.005, 0.525, 0.305, 0.470), "roughness": 0.65, "metallic": 0.02, "desc": "Tablas de nogal oscuro rústico" },
		"duvet": { "rect": Rect2(0.312, 0.556, 0.300, 0.350), "roughness": 0.85, "metallic": 0.01, "desc": "Sábanas arrugadas acogedoras grisáceas" },
		"pillow": { "rect": Rect2(0.100, 0.268, 0.130, 0.200), "roughness": 0.85, "metallic": 0.01, "desc": "Almohada blanca arrugada" }
	},
	"armchair_08": {
		"damask": { "rect": Rect2(0.461, 0.461, 0.359, 0.523), "roughness": 0.88, "metallic": 0.0, "desc": "Brocado de damasco floral dorado refinado" },
		"trim_gold": { "rect": Rect2(0.883, 0.391, 0.109, 0.547), "roughness": 0.65, "metallic": 0.0, "desc": "Moldura perimetral barroca dorada tallada" },
		"satin_base": { "rect": Rect2(0.016, 0.367, 0.219, 0.617), "roughness": 0.85, "metallic": 0.0, "desc": "Satén mate para base y laterales" },
		"wood_leg": { "rect": Rect2(0.312, 0.117, 0.117, 0.234), "roughness": 0.70, "metallic": 0.0, "desc": "Pata tallada dorada mate" }
	},
	"armchair_06": {
		"floral": { "rect": Rect2(0.609, 0.438, 0.188, 0.547), "roughness": 0.88, "metallic": 0.0, "desc": "Estampado floral cottage estilo provenzal" },
		"cushion": { "rect": Rect2(0.609, 0.438, 0.188, 0.547), "roughness": 0.88, "metallic": 0.0, "desc": "Cojín acolchado floral" },
		"wood_base": { "rect": Rect2(0.016, 0.453, 0.195, 0.531), "roughness": 0.70, "metallic": 0.0, "desc": "Zócalo base de madera oscura tallada" },
		"wood_leg": { "rect": Rect2(0.016, 0.453, 0.195, 0.531), "roughness": 0.70, "metallic": 0.0, "desc": "Patas de madera oscura" },
		"arm_roll": { "rect": Rect2(0.430, 0.438, 0.070, 0.547), "roughness": 0.88, "metallic": 0.0, "desc": "Rollo de reposabrazos floral" }
	},
	"armchair_07": {
		"cushion": { "rect": Rect2(0.781, 0.516, 0.195, 0.469), "roughness": 0.90, "metallic": 0.0, "desc": "Tapizado de lino marfil texturizado mate" },
		"fabric_linen": { "rect": Rect2(0.781, 0.516, 0.195, 0.469), "roughness": 0.90, "metallic": 0.0, "desc": "Lino marfil de asiento y respaldo" },
		"wood_frame": { "rect": Rect2(0.078, 0.492, 0.344, 0.492), "roughness": 0.70, "metallic": 0.0, "desc": "Estructura vista de madera de roble claro" },
		"wood_back": { "rect": Rect2(0.547, 0.508, 0.195, 0.477), "roughness": 0.70, "metallic": 0.0, "desc": "Tablero trasero de roble" },
		"wood_leg": { "rect": Rect2(0.078, 0.492, 0.150, 0.492), "roughness": 0.70, "metallic": 0.0, "desc": "Patas cuadradas de roble" }
	},
	"armchair_03": {
		"cushion": { "rect": Rect2(0.242, 0.297, 0.258, 0.305), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero granate suave para cojín de asiento" },
		"tufted_back": { "rect": Rect2(0.750, 0.760, 0.133, 0.225), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero capitoné con botones en rombo" },
		"arm_scroll": { "rect": Rect2(0.008, 0.227, 0.219, 0.375), "roughness": 0.78, "metallic": 0.0, "desc": "Brazo curvo enrollado Chesterfield" },
		"smooth_leather": { "rect": Rect2(0.516, 0.391, 0.188, 0.219), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero granate liso para cuerpo y laterales" },
		"bun_foot": { "rect": Rect2(0.352, 0.195, 0.078, 0.094), "roughness": 0.70, "metallic": 0.0, "desc": "Pata redonda de madera oscura torneada" },
		"wood_leg": { "rect": Rect2(0.352, 0.195, 0.078, 0.094), "roughness": 0.70, "metallic": 0.0, "desc": "Pata redonda torneada" }
	},
	"armchair_04": {
		"cushion": { "rect": Rect2(0.010, 0.260, 0.200, 0.230), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero marrón cognac suave para asiento" },
		"tufted_back": { "rect": Rect2(0.205, 0.285, 0.210, 0.210), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero cognac capitoné puro" },
		"arm_scroll": { "rect": Rect2(0.641, 0.461, 0.188, 0.516), "roughness": 0.78, "metallic": 0.0, "desc": "Brazo enrollado en espiral" },
		"smooth_leather": { "rect": Rect2(0.453, 0.508, 0.172, 0.477), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero cognac liso para cuerpo y laterales" },
		"bun_foot": { "rect": Rect2(0.080, 0.080, 0.060, 0.080), "roughness": 0.70, "metallic": 0.0, "desc": "Pata torneada" },
		"wood_leg": { "rect": Rect2(0.080, 0.080, 0.060, 0.080), "roughness": 0.70, "metallic": 0.0, "desc": "Pata torneada" }
	},
	"armchair": {
		"tufted_back": { "rect": Rect2(0.020, 0.300, 0.220, 0.260), "roughness": 0.78, "metallic": 0.0, "desc": "Respaldo capitoné central sin esquinas negras" },
		"cushion": { "rect": Rect2(0.016, 0.594, 0.296, 0.390), "roughness": 0.78, "metallic": 0.0, "desc": "Cojín de cuero grueso envejecido" },
		"arm_scroll": { "rect": Rect2(0.712, 0.140, 0.108, 0.230), "roughness": 0.78, "metallic": 0.0, "desc": "Frontal de reposabrazos con tachuelas sin bordes negros" },
		"arm_roll": { "rect": Rect2(0.712, 0.140, 0.108, 0.230), "roughness": 0.78, "metallic": 0.0, "desc": "Frontal de reposabrazos sin bordes negros" },
		"smooth_leather": { "rect": Rect2(0.641, 0.438, 0.344, 0.234), "roughness": 0.78, "metallic": 0.0, "desc": "Cuero marrón liso para cuerpo y respaldo" },
		"wood_leg": { "rect": Rect2(0.094, 0.118, 0.125, 0.136), "roughness": 0.70, "metallic": 0.0, "desc": "Patas cónicas de madera oscura" }
	},
	"armchair_01": {
		"tufted_back": { "rect": Rect2(0.675, 0.730, 0.230, 0.205), "roughness": 0.88, "metallic": 0.0, "desc": "Respaldo capitoné gris marengo puro sin bordes negros" },
		"cushion": { "rect": Rect2(0.656, 0.047, 0.297, 0.258), "roughness": 0.88, "metallic": 0.0, "desc": "Cojín suave gris marengo" },
		"studded_arm": { "rect": Rect2(0.738, 0.352, 0.095, 0.250), "roughness": 0.60, "metallic": 0.15, "desc": "Línea de tachuelas plateadas sin borde negro" },
		"smooth_fabric": { "rect": Rect2(0.039, 0.293, 0.273, 0.684), "roughness": 0.88, "metallic": 0.0, "desc": "Tela marengo para cuerpo, laterales y respaldo" },
		"arm": { "rect": Rect2(0.039, 0.293, 0.273, 0.684), "roughness": 0.88, "metallic": 0.0, "desc": "Laterales acolchados" },
		"wood_leg": { "rect": Rect2(0.391, 0.109, 0.102, 0.125), "roughness": 0.70, "metallic": 0.0, "desc": "Patas cónicas de madera" }
	},
	"armchair_02": {
		"tufted_back": { "rect": Rect2(0.675, 0.775, 0.230, 0.195), "roughness": 0.88, "metallic": 0.0, "desc": "Respaldo capitoné azul cielo puro sin bordes negros" },
		"cushion": { "rect": Rect2(0.656, 0.047, 0.297, 0.258), "roughness": 0.88, "metallic": 0.0, "desc": "Cojín azul cielo pastel" },
		"studded_arm": { "rect": Rect2(0.735, 0.352, 0.095, 0.250), "roughness": 0.60, "metallic": 0.15, "desc": "Línea de tachuelas plateadas sin borde negro" },
		"smooth_fabric": { "rect": Rect2(0.039, 0.260, 0.273, 0.720), "roughness": 0.88, "metallic": 0.0, "desc": "Tela azul cielo para cuerpo y respaldo" },
		"arm": { "rect": Rect2(0.039, 0.260, 0.273, 0.720), "roughness": 0.88, "metallic": 0.0, "desc": "Laterales acolchados" },
		"wood_leg": { "rect": Rect2(0.391, 0.109, 0.102, 0.125), "roughness": 0.70, "metallic": 0.0, "desc": "Patas cónicas de madera" }
	},
	"armchair_05": {
		"tufted_back": { "rect": Rect2(0.023, 0.295, 0.250, 0.195), "roughness": 0.92, "metallic": 0.0, "desc": "Respaldo capitoné terciopelo mostaza puro" },
		"cushion": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.92, "metallic": 0.0, "desc": "Terciopelo mostaza puro continuo sin recortes" },
		"arm_side": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.92, "metallic": 0.0, "desc": "Terciopelo mostaza puro para laterales y brazos" },
		"arm": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.92, "metallic": 0.0, "desc": "Brazos de terciopelo" },
		"smooth_velvet": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.92, "metallic": 0.0, "desc": "Terciopelo liso amarillo" },
		"wood_leg": { "rect": Rect2(0.289, 0.258, 0.100, 0.100), "roughness": 0.70, "metallic": 0.0, "desc": "Patas de madera oscura" }
	},
	"chair": {
		"toile_back": { "rect": Rect2(0.380, 0.770, 0.120, 0.180), "roughness": 0.88, "metallic": 0.0, "desc": "Tela Toile de Jouy azul pura para medallón sin esquinas negras" },
		"toile_seat": { "rect": Rect2(0.530, 0.770, 0.210, 0.210), "roughness": 0.88, "metallic": 0.0, "desc": "Asiento acolchado Toile de Jouy azul" },
		"carved_wood": { "rect": Rect2(0.098, 0.801, 0.078, 0.156), "roughness": 0.70, "metallic": 0.0, "desc": "Madera tallada estilo Luis XV pura sin esquinas negras" },
		"wood_leg": { "rect": Rect2(0.098, 0.801, 0.078, 0.156), "roughness": 0.70, "metallic": 0.0, "desc": "Pata cabriolé tallada" },
		"arm_pad": { "rect": Rect2(0.760, 0.770, 0.065, 0.210), "roughness": 0.88, "metallic": 0.0, "desc": "Codera acolchada azul" }
	},
	"chair_01": {
		"damask_back": { "rect": Rect2(0.330, 0.670, 0.180, 0.280), "roughness": 0.88, "metallic": 0.0, "desc": "Tela brocada crema/dorada pura para medallón sin esquinas negras" },
		"damask_seat": { "rect": Rect2(0.620, 0.290, 0.250, 0.260), "roughness": 0.88, "metallic": 0.0, "desc": "Asiento adamascado" },
		"carved_wood": { "rect": Rect2(0.078, 0.664, 0.117, 0.176), "roughness": 0.65, "metallic": 0.0, "desc": "Madera dorada tallada pura sin esquinas negras" },
		"wood_leg": { "rect": Rect2(0.078, 0.664, 0.117, 0.176), "roughness": 0.65, "metallic": 0.0, "desc": "Patas doradas talladas" }
	},
	"chair_02": {
		"polka_seat": { "rect": Rect2(0.620, 0.400, 0.260, 0.260), "roughness": 0.88, "metallic": 0.0, "desc": "Tapizado de lunares / jacquard crema para asiento" },
		"polka_back": { "rect": Rect2(0.045, 0.660, 0.210, 0.300), "roughness": 0.88, "metallic": 0.0, "desc": "Respaldo tapizado crema con marco de caoba" },
		"wood_frame": { "rect": Rect2(0.620, 0.690, 0.280, 0.300), "roughness": 0.70, "metallic": 0.0, "desc": "Madera de caoba pulida para marco y faldón" },
		"wood_leg": { "rect": Rect2(0.620, 0.690, 0.100, 0.300), "roughness": 0.70, "metallic": 0.0, "desc": "Patas cuadradas de caoba" }
	},
	"chair_03": {
		"slat_back": { "rect": Rect2(0.005, 0.570, 0.380, 0.425), "roughness": 0.65, "metallic": 0.02, "desc": "Listones verticales de pino" },
		"wood_seat": { "rect": Rect2(0.380, 0.100, 0.230, 0.890), "roughness": 0.60, "metallic": 0.02, "desc": "Asiento de madera sólida de pino" },
		"wood_leg": { "rect": Rect2(0.380, 0.100, 0.230, 0.890), "roughness": 0.60, "metallic": 0.02, "desc": "Patas cuadradas de pino" }
	},
	"chair_04": {
		"wood_seat": { "rect": Rect2(0.005, 0.680, 0.320, 0.315), "roughness": 0.60, "metallic": 0.02, "desc": "Asiento moldeado redondeado de madera" },
		"spindles": { "rect": Rect2(0.600, 0.360, 0.300, 0.300), "roughness": 0.55, "metallic": 0.02, "desc": "Husillos y barrotes torneados" }
	},
	"chair_05": {
		"boucle_seat": { "rect": Rect2(0.005, 0.250, 0.250, 0.270), "roughness": 0.80, "metallic": 0.01, "desc": "Tapizado bouclé texturizado de asiento" },
		"boucle_back": { "rect": Rect2(0.520, 0.030, 0.230, 0.250), "roughness": 0.80, "metallic": 0.01, "desc": "Respaldo semicircular bouclé" },
		"wood_legs": { "rect": Rect2(0.005, 0.510, 0.500, 0.485), "roughness": 0.60, "metallic": 0.02, "desc": "Patas cónicas de nogal oscuro" }
	},
	"chest_drawers_01": {
		"drawers": { "rect": Rect2(0.005, 0.580, 0.360, 0.360), "roughness": 0.60, "metallic": 0.05, "desc": "Frente de 3 cajones con jaladeras metálicas" },
		"drawer_top": { "rect": Rect2(0.020, 0.590, 0.330, 0.110), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón superior" },
		"drawer_mid": { "rect": Rect2(0.020, 0.700, 0.330, 0.110), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón central" },
		"drawer_bot": { "rect": Rect2(0.020, 0.810, 0.330, 0.110), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón inferior" },
		"wood_body": { "rect": Rect2(0.380, 0.570, 0.370, 0.420), "roughness": 0.60, "metallic": 0.02, "desc": "Cuerpo y laterales de madera clara" },
		"wood_top": { "rect": Rect2(0.270, 0.160, 0.270, 0.400), "roughness": 0.60, "metallic": 0.02, "desc": "Cubierta superior de madera" }
	},
	"chest_drawers_02": {
		"drawers": { "rect": Rect2(0.265, 0.510, 0.255, 0.485), "roughness": 0.35, "metallic": 0.15, "desc": "Frentes de cajón blancos con anillas de latón" },
		"white_body": { "rect": Rect2(0.005, 0.510, 0.250, 0.485), "roughness": 0.35, "metallic": 0.10, "desc": "Laterales y tapa esmaltados en blanco" }
	},
	"chest_drawers_03": {
		"drawers": { "rect": Rect2(0.005, 0.505, 0.490, 0.490), "roughness": 0.60, "metallic": 0.05, "desc": "3 cajones de pino con pomos oscuros" },
		"drawer_top": { "rect": Rect2(0.015, 0.525, 0.470, 0.150), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón superior de pino" },
		"drawer_mid": { "rect": Rect2(0.015, 0.680, 0.470, 0.150), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón central de pino" },
		"drawer_bot": { "rect": Rect2(0.015, 0.835, 0.470, 0.150), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón inferior de pino" },
		"pine_top": { "rect": Rect2(0.005, 0.005, 0.495, 0.495), "roughness": 0.60, "metallic": 0.02, "desc": "Cubierta superior de pino" },
		"pine_body": { "rect": Rect2(0.505, 0.505, 0.490, 0.490), "roughness": 0.60, "metallic": 0.02, "desc": "Laterales de pino con veta cálida" }
	},
	"chest_drawers_04": {
		"nightstand_drawers": { "rect": Rect2(0.030, 0.450, 0.360, 0.240), "roughness": 0.60, "metallic": 0.05, "desc": "2 cajones para mesita de noche con pomos" },
		"nightstand_drawer_top": { "rect": Rect2(0.030, 0.450, 0.360, 0.120), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón superior de mesita" },
		"nightstand_drawer_bot": { "rect": Rect2(0.030, 0.570, 0.360, 0.120), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón inferior de mesita" },
		"chest_drawers": { "rect": Rect2(0.460, 0.040, 0.510, 0.440), "roughness": 0.60, "metallic": 0.05, "desc": "Cajones anchos para cómoda alta" },
		"chest_drawer_top": { "rect": Rect2(0.460, 0.040, 0.510, 0.220), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón ancho superior" },
		"chest_drawer_bot": { "rect": Rect2(0.460, 0.260, 0.510, 0.220), "roughness": 0.60, "metallic": 0.05, "desc": "Cajón ancho inferior" },
		"oak_body": { "rect": Rect2(0.400, 0.450, 0.410, 0.540), "roughness": 0.60, "metallic": 0.02, "desc": "Tablero de roble limpio para laterales y tapa" },
		"wood_leg": { "rect": Rect2(0.810, 0.450, 0.180, 0.540), "roughness": 0.60, "metallic": 0.02, "desc": "Patas cónicas de roble" }
	},
	"chest_drawers_05": {
		"drawer_panels": { "rect": Rect2(0.245, 0.065, 0.230, 0.925), "roughness": 0.60, "metallic": 0.02, "desc": "Columna de frentes biselados y cajones" },
		"drawer_top": { "rect": Rect2(0.245, 0.065, 0.230, 0.285), "roughness": 0.60, "metallic": 0.02, "desc": "Cajón superior enmarcado" },
		"drawer_mid": { "rect": Rect2(0.245, 0.355, 0.230, 0.340), "roughness": 0.60, "metallic": 0.02, "desc": "Franja media de cajones" },
		"drawer_bot": { "rect": Rect2(0.245, 0.695, 0.230, 0.285), "roughness": 0.60, "metallic": 0.02, "desc": "Cajón inferior enmarcado" },
		"wood_body": { "rect": Rect2(0.005, 0.055, 0.235, 0.935), "roughness": 0.60, "metallic": 0.02, "desc": "Laterales de madera cálida" }
	},
	"chest_drawers_06": {
		"doors": { "rect": Rect2(0.510, 0.495, 0.465, 0.495), "roughness": 0.60, "metallic": 0.05, "desc": "Puertas dobles y cajones con pomos de metal" },
		"door_left": { "rect": Rect2(0.510, 0.495, 0.230, 0.495), "roughness": 0.60, "metallic": 0.05, "desc": "Puerta izquierda con pomo" },
		"door_right": { "rect": Rect2(0.740, 0.495, 0.235, 0.495), "roughness": 0.60, "metallic": 0.05, "desc": "Puerta derecha con pomo" },
		"wood_body": { "rect": Rect2(0.015, 0.490, 0.480, 0.505), "roughness": 0.60, "metallic": 0.02, "desc": "Tablero de madera natural para laterales y tapa" }
	},
	"fitment": {
		"vitrine_glass": { "rect": Rect2(0.005, 0.700, 0.490, 0.295), "roughness": 0.20, "metallic": 0.10, "desc": "Puertas vitrina con cristal cuarteado y vajilla interior" },
		"drawers_strip": { "rect": Rect2(0.005, 0.638, 0.490, 0.055), "roughness": 0.60, "metallic": 0.05, "desc": "Hilera de 5 cajoncitos con tiradores" },
		"top_cabinets": { "rect": Rect2(0.005, 0.505, 0.490, 0.130), "roughness": 0.60, "metallic": 0.02, "desc": "Alacenas superiores de roble tallado" },
		"wood_body": { "rect": Rect2(0.505, 0.525, 0.490, 0.470), "roughness": 0.60, "metallic": 0.02, "desc": "Vetas de roble horizontal para cubierta y laterales" }
	},
	"bookcase": {
		"books_shelves": { "rect": Rect2(0.015, 0.495, 0.335, 0.500), "roughness": 0.70, "metallic": 0.01, "desc": "Estantes repletos de lomos de libros antiguos" },
		"wood_body": { "rect": Rect2(0.355, 0.495, 0.355, 0.500), "roughness": 0.60, "metallic": 0.02, "desc": "Madera de caoba pulida para laterales y repisas" }
	},
	"bookcase_01": {
		"vitrine_books": { "rect": Rect2(0.230, 0.225, 0.285, 0.290), "roughness": 0.25, "metallic": 0.15, "desc": "Vitrina con cristales y encuadernaciones de lujo" },
		"wood_cabinet": { "rect": Rect2(0.518, 0.315, 0.285, 0.195), "roughness": 0.60, "metallic": 0.02, "desc": "Armario inferior de nogal con molduras" },
		"wood_body": { "rect": Rect2(0.005, 0.520, 0.620, 0.475), "roughness": 0.60, "metallic": 0.02, "desc": "Panel lateral de nogal lustroso" }
	},
	"wardrobe": {
		"clothes_hanging": { "rect": Rect2(0.005, 0.130, 0.230, 0.350), "roughness": 0.75, "metallic": 0.01, "desc": "Ropa colgada en perchas dentro del armario" },
		"wood_body": { "rect": Rect2(0.235, 0.130, 0.230, 0.350), "roughness": 0.60, "metallic": 0.02, "desc": "Madera para costados y techo de ropero" }
	},
	"stove": {
		"burners": { "rect": Rect2(0.0, 0.0, 1.0, 0.36), "roughness": 0.85, "metallic": 0.15, "desc": "6 quemadores de gas con parrillas de hierro forjado" },
		"knobs": { "rect": Rect2(0.0, 0.36, 1.0, 0.15), "roughness": 0.30, "metallic": 0.50, "desc": "Panel frontal de acero con perillas redondas" },
		"oven_door": { "rect": Rect2(0.0, 0.51, 1.0, 0.49), "roughness": 0.25, "metallic": 0.20, "desc": "Puerta del horno con cristal negro y logo Viking" },
		"white_side": { "rect": Rect2(0.02, 0.85, 0.10, 0.10), "roughness": 0.35, "metallic": 0.10, "desc": "Esmalte blanco pulido para laterales" }
	},
	"refrigerator": {
		"main_door": { "rect": Rect2(0.24, 0.64, 0.23, 0.35), "roughness": 0.30, "metallic": 0.15, "desc": "Puerta inferior con nota adhesiva y magnetos" },
		"freezer_door": { "rect": Rect2(0.36, 0.40, 0.15, 0.23), "roughness": 0.30, "metallic": 0.15, "desc": "Puerta superior congelador con dispensador" },
		"enamel_body": { "rect": Rect2(0.005, 0.65, 0.20, 0.30), "roughness": 0.35, "metallic": 0.10, "desc": "Lámina beige marfil para costados y techo" }
	},
	"cupboard": {
		"drawer": { "rect": Rect2(0.0, 0.0, 1.0, 0.22), "roughness": 0.45, "metallic": 0.05, "desc": "Frente de cajón blanco shaker con tirador" },
		"doors": { "rect": Rect2(0.0, 0.22, 1.0, 0.78), "roughness": 0.45, "metallic": 0.05, "desc": "Puertas dobles shaker blancas con tiradores" },
		"door_left": { "rect": Rect2(0.0, 0.22, 0.50, 0.78), "roughness": 0.45, "metallic": 0.05, "desc": "Puerta izquierda shaker" },
		"door_right": { "rect": Rect2(0.50, 0.22, 0.50, 0.78), "roughness": 0.45, "metallic": 0.05, "desc": "Puerta derecha shaker" },
		"white_body": { "rect": Rect2(0.05, 0.85, 0.15, 0.10), "roughness": 0.45, "metallic": 0.05, "desc": "Laterales blancos limpios" }
	},
	"cupboard_01": {
		"doors": { "rect": Rect2(0.0, 0.0, 1.0, 1.0), "roughness": 0.45, "metallic": 0.05, "desc": "Puertas dobles altas de alacena blanca con tiradores" },
		"door_left": { "rect": Rect2(0.0, 0.0, 0.50, 1.0), "roughness": 0.45, "metallic": 0.05, "desc": "Puerta izquierda alta" },
		"door_right": { "rect": Rect2(0.50, 0.0, 0.50, 1.0), "roughness": 0.45, "metallic": 0.05, "desc": "Puerta derecha alta" },
		"white_body": { "rect": Rect2(0.10, 0.10, 0.20, 0.20), "roughness": 0.45, "metallic": 0.05, "desc": "Blanco puro para laterales y base" }
	},
	"cupboard_02": {
		"drawer": { "rect": Rect2(0.0, 0.0, 1.0, 0.25), "roughness": 0.45, "metallic": 0.05, "desc": "Cajón gris shaker con jaladera" },
		"doors": { "rect": Rect2(0.0, 0.25, 1.0, 0.75), "roughness": 0.45, "metallic": 0.05, "desc": "Puertas dobles gris shaker" },
		"grey_body": { "rect": Rect2(0.10, 0.35, 0.20, 0.20), "roughness": 0.45, "metallic": 0.05, "desc": "Gris suave para estructura" }
	},
	"table": {
		"gingham_cloth": { "rect": Rect2(0.005, 0.495, 0.350, 0.500), "roughness": 0.70, "metallic": 0.01, "desc": "Mantel a cuadros rojos y blancos estilo picnic" },
		"gingham_skirt": { "rect": Rect2(0.705, 0.495, 0.260, 0.500), "roughness": 0.70, "metallic": 0.01, "desc": "Faldón colgante de mantel vichy" },
		"pine_wood": { "rect": Rect2(0.360, 0.510, 0.340, 0.485), "roughness": 0.60, "metallic": 0.02, "desc": "Tablones de madera clara para repisas y tablero" },
		"wood_leg": { "rect": Rect2(0.595, 0.020, 0.065, 0.490), "roughness": 0.60, "metallic": 0.02, "desc": "Patas cilíndricas/cuadradas de madera" }
	},
	"table_01": {
		"gingham_top": { "rect": Rect2(0.005, 0.520, 0.470, 0.460), "roughness": 0.70, "metallic": 0.01, "desc": "Mantel octagonal de cuadros rojos" },
		"lace_trim": { "rect": Rect2(0.520, 0.350, 0.410, 0.170), "roughness": 0.75, "metallic": 0.01, "desc": "Borde de encaje blanco troquelado" },
		"wood": { "rect": Rect2(0.520, 0.550, 0.410, 0.400), "roughness": 0.60, "metallic": 0.02, "desc": "Madera para patas y bastidor" }
	},
	"table_02": {
		"lace_cloth": { "rect": Rect2(0.005, 0.480, 0.300, 0.515), "roughness": 0.75, "metallic": 0.01, "desc": "Mantel de encaje blanco con filigrana bordada" },
		"dark_walnut": { "rect": Rect2(0.300, 0.490, 0.290, 0.505), "roughness": 0.60, "metallic": 0.02, "desc": "Nogal oscuro para patas y base" }
	},
	"box_pizza": {
		"pizza": { "rect": Rect2(0.360, 0.675, 0.335, 0.325), "roughness": 0.80, "metallic": 0.02, "desc": "Pizza entera de pepperoni con queso gratinado" },
		"box_lid": { "rect": Rect2(0.360, 0.315, 0.270, 0.365), "roughness": 0.85, "metallic": 0.01, "desc": "Tapa de caja con logo de porción de pizza" },
		"box_inside": { "rect": Rect2(0.005, 0.265, 0.355, 0.365), "roughness": 0.85, "metallic": 0.01, "desc": "Interior de la caja de pizza con manchas de aceite" },
		"cardboard": { "rect": Rect2(0.630, 0.315, 0.255, 0.365), "roughness": 0.85, "metallic": 0.01, "desc": "Cartón corrugado kraft limpio" }
	},
	"pizza": {
		"slice": { "rect": Rect2(0.450, 0.365, 0.445, 0.635), "roughness": 0.80, "metallic": 0.02, "desc": "Porción triangular de pizza con pepperoni" },
		"crust": { "rect": Rect2(0.005, 0.365, 0.445, 0.635), "roughness": 0.85, "metallic": 0.01, "desc": "Corteza horneada de la masa de pizza" }
	},
	"chicken": {
		"roast": { "rect": Rect2(0.005, 0.520, 0.330, 0.475), "roughness": 0.65, "metallic": 0.05, "desc": "Pollo entero asado dorado crujiente" }
	},
	"fried_foods": {
		"fries": { "rect": Rect2(0.500, 0.240, 0.495, 0.755), "roughness": 0.80, "metallic": 0.02, "desc": "Bolsa de patatas fritas / frituras crujientes" }
	},
	"meat": {
		"steak": { "rect": Rect2(0.005, 0.400, 0.410, 0.595), "roughness": 0.50, "metallic": 0.05, "desc": "Corte de carne roja fresca marmoleada" }
	},
	"cereal_bowl": {
		"cereal": { "rect": Rect2(0.490, 0.520, 0.460, 0.475), "roughness": 0.75, "metallic": 0.01, "desc": "Aros de cereal de colores en tazón con leche" },
		"bowl": { "rect": Rect2(0.005, 0.520, 0.460, 0.475), "roughness": 0.30, "metallic": 0.10, "desc": "Tazón de cerámica azul pastel" }
	},
	"plate_food": {
		"soup": { "rect": Rect2(0.480, 0.520, 0.495, 0.460), "roughness": 0.40, "metallic": 0.05, "desc": "Ramen caliente con huevo cocido y chashu" },
		"plate": { "rect": Rect2(0.005, 0.520, 0.460, 0.460), "roughness": 0.30, "metallic": 0.10, "desc": "Plato hondo de porcelana" }
	},
	"cake": {
		"slice": { "rect": Rect2(0.410, 0.460, 0.410, 0.520), "roughness": 0.70, "metallic": 0.02, "desc": "Porción de tarta de cerezas enrejada" }
	},
	"flan": {
		"caramel": { "rect": Rect2(0.400, 0.580, 0.350, 0.415), "roughness": 0.40, "metallic": 0.05, "desc": "Flan de huevo con caramelo líquido" },
		"lid": { "rect": Rect2(0.005, 0.580, 0.395, 0.415), "roughness": 0.25, "metallic": 0.50, "desc": "Tapa de aluminio azul sellada" }
	},
	"can": {
		"lid": { "rect": Rect2(0.005, 0.005, 0.250, 0.285), "roughness": 0.20, "metallic": 0.85, "desc": "Tapa metálica con anilla abrefácil" },
		"label": { "rect": Rect2(0.005, 0.320, 0.805, 0.675), "roughness": 0.35, "metallic": 0.15, "desc": "Etiqueta serigrafiada de leche de fresa" }
	},
	"bottle": {
		"label": { "rect": Rect2(0.005, 0.450, 0.745, 0.160), "roughness": 0.30, "metallic": 0.10, "desc": "Faja con logo rojo de refresco de cola" },
		"glass": { "rect": Rect2(0.005, 0.005, 0.250, 0.450), "roughness": 0.15, "metallic": 0.10, "desc": "Vidrio tintado con líquido oscuro de cola" },
		"cap": { "rect": Rect2(0.750, 0.620, 0.120, 0.140), "roughness": 0.25, "metallic": 0.75, "desc": "Chapa corona de metal estriada" }
	},
	"milk": {
		"label": { "rect": Rect2(0.380, 0.110, 0.170, 0.170), "roughness": 0.35, "metallic": 0.05, "desc": "Logo azul de vaca pasteurizada" },
		"cap": { "rect": Rect2(0.710, 0.610, 0.100, 0.110), "roughness": 0.35, "metallic": 0.10, "desc": "Tapón de rosca azul" },
		"jug": { "rect": Rect2(0.360, 0.560, 0.350, 0.420), "roughness": 0.45, "metallic": 0.02, "desc": "Envase de plástico semitranslúcido blanco" }
	},
	"alarm_clock": {
		"display": { "rect": Rect2(0.530, 0.490, 0.215, 0.505), "roughness": 0.20, "metallic": 0.20, "desc": "Display LED digital rojo (16:20)" },
		"case": { "rect": Rect2(0.005, 0.215, 0.250, 0.265), "roughness": 0.45, "metallic": 0.10, "desc": "Carcasa plástica negra mate" }
	},
	"radio": {
		"dial": { "rect": Rect2(0.330, 0.475, 0.300, 0.515), "roughness": 0.30, "metallic": 0.20, "desc": "Dial de frecuencias AM/FM con altavoz frontal" },
		"case": { "rect": Rect2(0.005, 0.475, 0.300, 0.515), "roughness": 0.45, "metallic": 0.15, "desc": "Gabinete de radio militar verde oliva" }
	},
	"ventilator": {
		"cage": { "rect": Rect2(0.005, 0.350, 0.300, 0.300), "roughness": 0.35, "metallic": 0.50, "desc": "Rejilla frontal protectora de alambre con logo" },
		"tube": { "rect": Rect2(0.305, 0.200, 0.035, 0.450), "roughness": 0.30, "metallic": 0.70, "desc": "Tubo metálico cromado del mástil" }
	},
	"ventilator_01": {
		"cage": { "rect": Rect2(0.005, 0.575, 0.420, 0.420), "roughness": 0.35, "metallic": 0.50, "desc": "Rejilla circular con aspas internas" },
		"motor": { "rect": Rect2(0.420, 0.220, 0.190, 0.210), "roughness": 0.40, "metallic": 0.15, "desc": "Carcasa trasera del motor eléctrico" },
		"stand": { "rect": Rect2(0.005, 0.250, 0.160, 0.320), "roughness": 0.30, "metallic": 0.70, "desc": "Brazo curvo de soporte de mesa" }
	},
	"lamp": {
		"shade": { "rect": Rect2(0.005, 0.005, 0.480, 0.480), "roughness": 0.70, "metallic": 0.01, "desc": "Pantalla textil plisada de lámpara de mesa" },
		"metal": { "rect": Rect2(0.485, 0.315, 0.340, 0.340), "roughness": 0.30, "metallic": 0.60, "desc": "Metal cepillado para base y campana" }
	},
	"lamp_02": {
		"shade": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.20, "metallic": 0.10, "desc": "Tulipa de cristal verde esmeralda de banquero" },
		"metal": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.25, "metallic": 0.85, "desc": "Base y brazos de latón dorado" }
	},
	"lamp_03": {
		"shade": { "rect": Rect2(0.555, 0.350, 0.205, 0.640), "roughness": 0.20, "metallic": 0.10, "desc": "Tulipa de cristal verde esmeralda de banquero" },
		"metal": { "rect": Rect2(0.005, 0.740, 0.255, 0.255), "roughness": 0.25, "metallic": 0.85, "desc": "Base y brazos de latón dorado brillante" }
	},
	"ceiling_fan": {
		"blades": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.55, "metallic": 0.05, "desc": "Aspas de madera oscura para ventilador de techo" },
		"motor": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.35, "metallic": 0.50, "desc": "Carcasa del motor central" },
		"rod": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.30, "metallic": 0.60, "desc": "Tija colgante de soporte" }
	},
	"desk_lamp": {
		"head": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.30, "metallic": 0.45, "desc": "Campana reflectora orientable negra" },
		"neck": { "rect": Rect2(0.5, 0.0, 0.5, 0.5), "roughness": 0.35, "metallic": 0.40, "desc": "Brazo flexible de cuello de ganso" },
		"base": { "rect": Rect2(0.0, 0.08, 0.5, 0.42), "roughness": 0.35, "metallic": 0.40, "desc": "Base redonda lastrada negra" }
	},
	"desk_lamp_01": {
		"head": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.30, "metallic": 0.35, "desc": "Campana reflectora orientable blanca" },
		"neck": { "rect": Rect2(0.5, 0.0, 0.5, 0.5), "roughness": 0.35, "metallic": 0.35, "desc": "Brazo flexible blanco" },
		"base": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.35, "metallic": 0.35, "desc": "Base redonda blanca" }
	},
	"focus": {
		"bulb": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.10, "metallic": 0.05, "desc": "Bombilla incandescente encendida" },
		"socket": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.45, "metallic": 0.20, "desc": "Portalámparas de baquelita" }
	},
	"alarm_clock_01": {
		"display": { "rect": Rect2(0.53125, 0.44531, 0.20312, 0.46094), "roughness": 0.15, "metallic": 0.10, "desc": "Display LED digital ámbar con números 12:53 e indicadores" },
		"display_digits": { "rect": Rect2(0.56250, 0.46094, 0.15625, 0.42188), "roughness": 0.15, "metallic": 0.10, "desc": "Recorte estrecho de los dígitos 12:53" },
		"case": { "rect": Rect2(0.01562, 0.25000, 0.21875, 0.70312), "roughness": 0.45, "metallic": 0.05, "desc": "Carcasa plástica negra mate con textura PSX" },
		"body": { "rect": Rect2(0.01562, 0.25000, 0.21875, 0.70312), "roughness": 0.45, "metallic": 0.05, "desc": "Alias de carcasa plástica negra" },
		"front_panel": { "rect": Rect2(0.50000, 0.34375, 0.26562, 0.64062), "roughness": 0.40, "metallic": 0.08, "desc": "Frontal biselado con marco de pantalla" },
		"buttons_strip": { "rect": Rect2(0.28125, 0.42969, 0.13281, 0.32812), "roughness": 0.30, "metallic": 0.15, "desc": "Franja superior de botonera circular" },
		"button_snooze": { "rect": Rect2(0.31250, 0.60547, 0.07031, 0.07031), "roughness": 0.30, "metallic": 0.15, "desc": "Botón circular grande de Snooze / Repetición" },
		"button_small": { "rect": Rect2(0.32422, 0.43359, 0.04688, 0.04688), "roughness": 0.30, "metallic": 0.15, "desc": "Botón circular secundario (Time / Alarm / Hour)" },
		"battery_cover": { "rect": Rect2(0.77344, 0.70312, 0.10156, 0.18750), "roughness": 0.45, "metallic": 0.05, "desc": "Tapa trasera del compartimento de baterías" },
		"back_face": { "rect": Rect2(0.75781, 0.34375, 0.23438, 0.64062), "roughness": 0.45, "metallic": 0.05, "desc": "Panel posterior de la carcasa" }
	},
	"radio_01": {
		"dial": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.30, "metallic": 0.20, "desc": "Dial sintonizador con rejilla de altavoz" },
		"case": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.40, "metallic": 0.10, "desc": "Carcasa de radio portátil" }
	},
	"gadgets": {
		"case": { "rect": Rect2(0.043, 0.500, 0.457, 0.444), "roughness": 0.50, "metallic": 0.10, "desc": "Cuerpo de walkie-talkie con botonera" },
		"antenna": { "rect": Rect2(0.043, 0.019, 0.457, 0.481), "roughness": 0.30, "metallic": 0.60, "desc": "Antena flexible de goma" }
	},
	"phone": {
		"dial": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.20, "metallic": 0.30, "desc": "Disco rotatorio con números" },
		"body": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.25, "metallic": 0.20, "desc": "Cuerpo del teléfono negro de baquelita" },
		"handset": { "rect": Rect2(0.5, 0.0, 0.5, 0.5), "roughness": 0.25, "metallic": 0.20, "desc": "Auricular ergonómico clásico" }
	},
	"phone_01": {
		"buttons": { "rect": Rect2(0.0, 0.039, 0.5, 0.461), "roughness": 0.30, "metallic": 0.10, "desc": "Teclado numérico beige de oficina" },
		"body": { "rect": Rect2(0.0, 0.500, 0.5, 0.500), "roughness": 0.40, "metallic": 0.05, "desc": "Carcasa beige de teléfono de escritorio" }
	},
	"paintings": {
		"canvas": { "rect": Rect2(0.0, 0.0, 1.0, 1.0), "roughness": 0.55, "metallic": 0.01, "desc": "Lienzo al óleo" },
		"frame": { "rect": Rect2(0.0, 0.0, 0.1, 0.1), "roughness": 0.50, "metallic": 0.05, "desc": "Moldura de marco" }
	},
	"books": {
		"pages": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.70, "metallic": 0.01, "desc": "Canto de páginas de libros y papel" },
		"cover": { "rect": Rect2(0.5, 0.0, 0.5, 0.5), "roughness": 0.50, "metallic": 0.02, "desc": "Cubiertas y lomos de libros encuadernados" }
	},
	"trash_can": {
		"can_body": { "rect": Rect2(0.0, 0.0, 1.0, 1.0), "roughness": 0.50, "metallic": 0.10, "desc": "Bote de basura con bolsa gris arrugada" }
	},
	"garbage_bags": {
		"plastic": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.35, "metallic": 0.15, "desc": "Plástico de bolsa de basura arrugado" },
		"knot": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.40, "metallic": 0.10, "desc": "Nudo superior de bolsa atada" }
	},
	"flower_table": {
		"rose": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.60, "metallic": 0.02, "desc": "Rosa roja fresca y hojas verdes" },
		"vase": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.25, "metallic": 0.10, "desc": "Florero cerámico oscuro" }
	},
	"flower_table_01": {
		"lavender": { "rect": Rect2(0.5, 0.0, 0.5, 0.5), "roughness": 0.65, "metallic": 0.02, "desc": "Espigas de flor de lavanda morada" },
		"vase": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.25, "metallic": 0.10, "desc": "Florero cilíndrico" }
	},
	"plate_food_01": {
		"food": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.40, "metallic": 0.05, "desc": "Guisado casero servido en plato" },
		"plate": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.20, "metallic": 0.10, "desc": "Plato llano blanco de porcelana" }
	},
	"ice_cream": {
		"tub": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.40, "metallic": 0.05, "desc": "Tarrina cilíndrica de helado artesanal" },
		"lid": { "rect": Rect2(0.5, 0.5, 0.5, 0.5), "roughness": 0.40, "metallic": 0.05, "desc": "Tapa y etiqueta del bote de helado" }
	},
	"palette": {
		"ice": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.25, "metallic": 0.10, "desc": "Hielo cristalizado de paleta roja de fresa" }
	},
	"box_strawberries": {
		"brick": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.40, "metallic": 0.05, "desc": "Envase tetrabrik de leche con fresas" }
	},

	# =========================================================================
	# COLECCIÓN DE TELAS DE SOFÁ (sofa_fabrics_atlas.png - Cuadrícula 4x4)
	# 8 Telas Mexicanas Vintage + 8 Telas Modernas Minimalistas
	# =========================================================================
	"sofa_fabrics_atlas": {
		"vintage_01_jacquard_gold": { "rect": Rect2(0.00, 0.00, 0.25, 0.25), "roughness": 0.88, "metallic": 0.0, "desc": "Jacquard floral café y oro viejo" },
		"vintage_02_velvet_burgundy": { "rect": Rect2(0.25, 0.00, 0.25, 0.25), "roughness": 0.85, "metallic": 0.0, "desc": "Terciopelo labrado burdeos guinda" },
		"vintage_03_corduroy_orange": { "rect": Rect2(0.50, 0.00, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Pana gruesa acanalada naranja óxido" },
		"vintage_04_brocade_green": { "rect": Rect2(0.75, 0.00, 0.25, 0.25), "roughness": 0.88, "metallic": 0.0, "desc": "Brocado colonial verde y beige" },
		"vintage_05_stripes_tan": { "rect": Rect2(0.00, 0.25, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Rayas verticales beige, crema y marrón" },
		"vintage_06_tapestry_mustard": { "rect": Rect2(0.25, 0.25, 0.25, 0.25), "roughness": 0.88, "metallic": 0.0, "desc": "Tapiz mostaza floral retro" },
		"vintage_07_tweed_rustic": { "rect": Rect2(0.50, 0.25, 0.25, 0.25), "roughness": 0.92, "metallic": 0.0, "desc": "Telar rústico artesanal jaspeado tierra" },
		"vintage_08_diamonds_70s": { "rect": Rect2(0.75, 0.25, 0.25, 0.25), "roughness": 0.88, "metallic": 0.0, "desc": "Geométrico retro de rombos setenteros" },
		"modern_01_charcoal": { "rect": Rect2(0.00, 0.50, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Lino contemporáneo gris carbón uniforme" },
		"modern_02_boucle_oat": { "rect": Rect2(0.25, 0.50, 0.25, 0.25), "roughness": 0.92, "metallic": 0.0, "desc": "Bouclé texturizado beige avena" },
		"modern_03_offwhite": { "rect": Rect2(0.50, 0.50, 0.25, 0.25), "roughness": 0.88, "metallic": 0.0, "desc": "Algodón/lino liso blanco marfil off-white" },
		"modern_04_olive": { "rect": Rect2(0.75, 0.50, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Lino moderno verde olivo apagado" },
		"modern_05_navy": { "rect": Rect2(0.00, 0.75, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Azul marino profundo liso" },
		"modern_06_terracotta": { "rect": Rect2(0.25, 0.75, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Tejido contemporáneo terracota mate" },
		"modern_07_mustard": { "rect": Rect2(0.50, 0.75, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Lino liso mostaza cálido" },
		"modern_08_graphite": { "rect": Rect2(0.75, 0.75, 0.25, 0.25), "roughness": 0.90, "metallic": 0.0, "desc": "Microfibra lisa negro grafito" }
	}
}

static var _is_initialized: bool = false


## Inicializa el Atlas Inteligente y sincroniza sus capas en el Texture2DArray
static func ensure_initialized() -> void:
	if _is_initialized:
		return
	FurnitureTextureManagerScript.ensure_initialized()
	_register_sofa_fabric_kit()
	_register_carton_drinks_kit()
	_register_soda_cans_kit()
	_register_cereal_boxes_kit()
	_register_candy_bags_kit()
	_register_cigarette_packs_kit()
	_register_cookie_packs_kit()
	_register_snack_bags_kit()
	_scan_folders_for_json_regions("res://assets/textures/furniture/")
	_scan_folders_for_json_regions("res://assets/textures/house/")
	_scan_folders_for_json_regions("res://assets/textures/office pack/")
	_scan_folders_for_json_regions("res://assets/textures/furniture 2.0/")
	_is_initialized = true


## Registra semánticamente el kit de las 16 familias de telas de sofá con densidad uniforme y dirección congruente
static func _register_sofa_fabric_kit() -> void:
	for idx in range(16):
		var key_name: String = SOFA_FABRIC_NAMES[idx]
		var col := idx % 4
		var row := idx / 4
		var u0 := float(col) * 0.25
		var v0 := float(row) * 0.25

		# Densidad métrica uniforme universal: 0.25 en UV = 0.60m en el mundo real (0.4167 UV/m)
		# 1. Asiento: 0.54 x 0.54m (cuadrado 1:1, textura sin distorsión)
		var cushion_rect := Rect2(u0 + 0.0125, v0 + 0.0125, 0.225, 0.225)
		# 2. Respaldo: 0.54 x 0.59m (cuadrado 1:1 vertical congruente)
		var back_rect := Rect2(u0 + 0.0125, v0 + 0.0125, 0.225, 0.225)
		# 3. Faldón frontal (1 panel por cojín): 0.54 x 0.14m (caída vertical proporcional, orla inferior)
		var apron_rect := Rect2(u0 + 0.0125, v0 + 0.167, 0.225, 0.058)
		# 4. Frente vertical del reposabrazos: 0.17 x 0.44m (vertical proporcional 1:2.58)
		var arm_front_rect := Rect2(u0 + 0.089, v0 + 0.033, 0.071, 0.183)
		# 5. Rollo del reposabrazos: semicilindro 0.28m desarrollo x 0.42m longitud modular
		var arm_roll_rect := Rect2(u0 + 0.066, v0 + 0.037, 0.117, 0.175)
		# 6. Lateral exterior del reposabrazos: panel modular 0.42m largo x 0.45m alto
		var arm_side_rect := Rect2(u0 + 0.037, v0 + 0.031, 0.175, 0.187)
		# 7. Remate circular frontal del reposabrazos: disco 0.18m diámetro (cuadrado 1:1)
		var arm_cap_rect := Rect2(u0 + 0.087, v0 + 0.087, 0.075, 0.075)
		# 8. Pata de madera torneada oscura
		var wood_rect := Rect2(0.312, 0.117, 0.117, 0.234)

		var sofa_dict := {
			"cushion": { "rect": cushion_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Cojín de asiento mullido 1:1" },
			"back": { "rect": back_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Cojín de respaldo vertical proporcional 1:1" },
			"apron": { "rect": apron_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Faldón frontal proporcional con caída vertical" },
			"arm_front": { "rect": arm_front_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Frente vertical del reposabrazos" },
			"arm_roll": { "rect": arm_roll_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Rollo cilíndrico del reposabrazos modular" },
			"arm_side": { "rect": arm_side_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Costado exterior del reposabrazos modular" },
			"arm_cap": { "rect": arm_cap_rect, "roughness": 0.88, "metallic": 0.0, "desc": "Remate circular frontal del reposabrazos 1:1" },
			"wood_leg": { "rect": wood_rect, "roughness": 0.70, "metallic": 0.02, "desc": "Pata de madera torneada" }
		}

		_REGIONS[key_name] = sofa_dict
		_REGIONS["sofa_" + key_name] = sofa_dict
		if idx < 8:
			_REGIONS["sofa_vintage_0%d" % (idx + 1)] = sofa_dict
			_REGIONS["vintage_0%d" % (idx + 1)] = sofa_dict
		else:
			_REGIONS["sofa_modern_0%d" % (idx - 7)] = sofa_dict
			_REGIONS["modern_0%d" % (idx - 7)] = sofa_dict


## Registra semánticamente el catálogo oficial de las 18 Bebidas en Cartón 1L (carton_drinks_atlas.png)
static func _register_carton_drinks_kit() -> void:
	for idx in range(18):
		var data: Dictionary = CARTON_DRINK_DATA[idx]
		var key_name: String = data["id"]
		var c_idx: int = data["col"]
		var r_idx: int = data["row"]

		var u0: float = float(c_idx) / 6.0
		var v0: float = float(r_idx) / 3.0
		var cell_w: float = 1.0 / 6.0
		var cell_h: float = 1.0 / 3.0

		var front_w: float = (176.0 / 256.0) * cell_w
		var side_w: float = (80.0 / 256.0) * cell_w
		var left_w: float = (50.0 / 256.0) * cell_w

		var front_rect := Rect2(u0, v0, front_w, cell_h)
		var side_rect := Rect2(u0 + front_w, v0, side_w, cell_h)
		var left_rect := Rect2(u0, v0, left_w, cell_h)
		var top_rect := Rect2(u0, v0, front_w, cell_h * 0.15)
		var full_rect := Rect2(u0, v0, cell_w, cell_h)

		var drink_dict := {
			"front": { "rect": front_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Frente)" },
			"side": { "rect": side_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Información Nutricional)" },
			"left": { "rect": left_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Lateral color)" },
			"top": { "rect": top_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Tapa superior)" },
			"full": { "rect": full_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Celda completa)" }
		}

		_REGIONS[key_name] = drink_dict
		_REGIONS["drink_" + key_name] = drink_dict
		_REGIONS["carton_" + key_name] = drink_dict


## Registra semánticamente el catálogo oficial de las 19 Latas de Refresco / Cerveza / Bebidas (soda_cans_atlas.png)
static func _register_soda_cans_kit() -> void:
	var w: float = 1024.0
	var h: float = 765.0

	var lid_u := 830.0 / w
	var lid_v := 579.0 / h
	var lid_w := 180.0 / w
	var lid_h := 180.0 / h
	var lid_dict := {
		"lid": { "rect": Rect2(lid_u, lid_v, lid_w, lid_h), "roughness": 0.22, "metallic": 0.88, "desc": "Tapa superior circular de aluminio con Pull-Tab" },
		"top": { "rect": Rect2(lid_u, lid_v, lid_w, lid_h), "roughness": 0.22, "metallic": 0.88, "desc": "Alias de tapa superior" },
		"pull_tab": { "rect": Rect2(lid_u, lid_v, lid_w, lid_h), "roughness": 0.22, "metallic": 0.88, "desc": "Alias de anilla de apertura" },
		"rim": { "rect": Rect2(lid_u, lid_v, lid_w, lid_h * 0.15), "roughness": 0.18, "metallic": 0.90, "desc": "Aro biselado de aluminio" }
	}
	_REGIONS["soda_cans_atlas"] = lid_dict
	_REGIONS["can_lid"] = lid_dict

	for idx in range(SODA_CAN_DATA.size()):
		var data: Dictionary = SODA_CAN_DATA[idx]
		var key_name: String = data["id"]
		var px: float = float(data["x"])
		var py: float = float(data["y"])
		var pw: float = float(data["w"])
		var ph: float = float(data["h"])

		var u0 := px / w
		var v0 := py / h
		var su := pw / w
		var sv := ph / h

		var full_rect := Rect2(u0, v0, su, sv)
		var front_rect := Rect2(u0 + su * 0.16, v0, su * 0.62, sv)
		var barcode_rect := Rect2(u0, v0, su * 0.16, sv)
		var nut_rect := Rect2(u0 + su * 0.78, v0, su * 0.22, sv)

		var can_dict := {
			"full": { "rect": full_rect, "roughness": 0.30, "metallic": 0.65, "desc": data["name"] + " (Cilindro 360°)" },
			"label": { "rect": full_rect, "roughness": 0.30, "metallic": 0.65, "desc": data["name"] + " (Envoltorio)" },
			"front": { "rect": front_rect, "roughness": 0.30, "metallic": 0.65, "desc": data["name"] + " (Frente)" },
			"barcode": { "rect": barcode_rect, "roughness": 0.35, "metallic": 0.50, "desc": data["name"] + " (Código de barras)" },
			"nutrition": { "rect": nut_rect, "roughness": 0.35, "metallic": 0.50, "desc": data["name"] + " (Tabla nutricional)" },
			"lid": { "rect": Rect2(lid_u, lid_v, lid_w, lid_h), "roughness": 0.22, "metallic": 0.88, "desc": "Tapa superior circular de aluminio" }
		}

		_REGIONS[key_name] = can_dict
		_REGIONS["can_" + key_name] = can_dict
		_REGIONS["soda_" + key_name] = can_dict

## Registra semánticamente el catálogo oficial de las 20 Cajas de Cereal 375g (cereal_boxes_atlas.png)
static func _register_cereal_boxes_kit() -> void:
	var w: float = 1024.0
	var h: float = 682.0

	var kit_dict := {}
	for idx in range(CEREAL_BOX_DATA.size()):
		var data: Dictionary = CEREAL_BOX_DATA[idx]
		var key_name: String = data["id"]
		var px: float = float(data["x"])
		var py: float = float(data["y"])
		var pw: float = float(data["w"])
		var ph: float = float(data["h"])

		var front_w := float(int(pw * 0.70))
		var side_w := pw - front_w
		var side_x := px + front_w

		var full_rect := Rect2(px / w, py / h, pw / w, ph / h)
		var front_rect := Rect2(px / w, py / h, front_w / w, ph / h)
		var side_rect := Rect2(side_x / w, py / h, side_w / w, ph / h)
		var color_rect := Rect2((px + 8.0) / w, (py + 8.0) / h, 24.0 / w, 24.0 / h)

		var item_dict := {
			"full": { "rect": full_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Caja completa)" },
			"front": { "rect": front_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Portada frontal: logo y tazón)" },
			"side": { "rect": side_rect, "roughness": 0.50, "metallic": 0.02, "desc": data["name"] + " (Panel lateral: nutricional y código)" },
			"color": { "rect": color_rect, "roughness": 0.50, "metallic": 0.02, "desc": data["name"] + " (Color sólido para lomo y tapas)" }
		}

		kit_dict[key_name] = item_dict["full"]
		kit_dict[key_name + "_front"] = item_dict["front"]
		kit_dict[key_name + "_side"] = item_dict["side"]
		kit_dict[key_name + "_color"] = item_dict["color"]

		_REGIONS[key_name] = item_dict
		_REGIONS["cereal_" + key_name] = item_dict

	if not _REGIONS.has("cereal_boxes_atlas"):
		_REGIONS["cereal_boxes_atlas"] = {}
	for k in kit_dict:
		_REGIONS["cereal_boxes_atlas"][k] = kit_dict[k]


## Registra semánticamente el catálogo oficial de los 20 Paquetes de Dulces y Chocolates (candy_bags_atlas.png)
static func _register_candy_bags_kit() -> void:
	var w: float = 1024.0
	var h: float = 682.0

	var kit_dict := {}
	for idx in range(CANDY_BAG_DATA.size()):
		var data: Dictionary = CANDY_BAG_DATA[idx]
		var key_name: String = data["id"]
		var px: float = float(data["x"])
		var py: float = float(data["y"])
		var pw: float = float(data["w"])
		var ph: float = float(data["h"])

		var crimp_w := float(clampi(int(round(pw * 0.082)), 13, 17))
		var body_w := pw - crimp_w * 2.0
		var crimp_r_x := px + pw - crimp_w

		var full_rect := Rect2(px / w, py / h, pw / w, ph / h)
		var body_rect := Rect2((px + crimp_w) / w, py / h, body_w / w, ph / h)
		var crimp_l_rect := Rect2(px / w, py / h, crimp_w / w, ph / h)
		var crimp_r_rect := Rect2(crimp_r_x / w, py / h, crimp_w / w, ph / h)
		var color_rect := Rect2((px + crimp_w + 10.0) / w, (py + 12.0) / h, 14.0 / w, 14.0 / h)

		var item_dict := {
			"full": { "rect": full_rect, "roughness": 0.40, "metallic": 0.04, "desc": data["name"] + " (Paquete completo)" },
			"body": { "rect": body_rect, "roughness": 0.40, "metallic": 0.04, "desc": data["name"] + " (Cuerpo frontal hinchado)" },
			"crimp_left": { "rect": crimp_l_rect, "roughness": 0.35, "metallic": 0.08, "desc": data["name"] + " (Sellado dentado izquierdo)" },
			"crimp_right": { "rect": crimp_r_rect, "roughness": 0.35, "metallic": 0.08, "desc": data["name"] + " (Sellado dentado derecho)" },
			"color": { "rect": color_rect, "roughness": 0.45, "metallic": 0.02, "desc": data["name"] + " (Color sólido de envoltura)" }
		}

		kit_dict[key_name] = item_dict["full"]
		kit_dict[key_name + "_full"] = item_dict["full"]
		kit_dict[key_name + "_body"] = item_dict["body"]
		kit_dict[key_name + "_crimp_left"] = item_dict["crimp_left"]
		kit_dict[key_name + "_crimp_right"] = item_dict["crimp_right"]
		kit_dict[key_name + "_color"] = item_dict["color"]

		_REGIONS[key_name] = item_dict
		_REGIONS["candy_" + key_name] = item_dict
		_REGIONS["dulce_" + key_name] = item_dict

	if not _REGIONS.has("candy_bags_atlas"):
		_REGIONS["candy_bags_atlas"] = {}
	for k in kit_dict:
		_REGIONS["candy_bags_atlas"][k] = kit_dict[k]


## Registra semánticamente el catálogo oficial de las 20 Cajetillas de Cigarros (cigarette_packs_atlas.png)
static func _register_cigarette_packs_kit() -> void:
	var w: float = 1024.0
	var h: float = 682.0

	var kit_dict := {}
	for idx in range(CIGARETTE_PACK_DATA.size()):
		var data: Dictionary = CIGARETTE_PACK_DATA[idx]
		var key_name: String = data["id"]
		var fx: float = float(data["fx"])
		var fy: float = float(data["fy"])
		var fw: float = float(data["fw"])
		var fh: float = float(data["fh"])

		var sx: float = float(data["sx"])
		var sy: float = float(data["sy"])
		var sw: float = float(data["sw"])
		var sh: float = float(data["sh"])

		var front_rect := Rect2(fx / w, fy / h, fw / w, fh / h)
		var side_rect := Rect2(sx / w, sy / h, sw / w, sh / h)
		var full_rect := Rect2(fx / w, fy / h, (sx + sw - fx) / w, maxf(fh, sh) / h)
		var color_rect := Rect2((sx + 6.0) / w, (sy + 10.0) / h, 14.0 / w, 14.0 / h)

		var item_dict := {
			"front": { "rect": front_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Portada frontal: logo y aviso)" },
			"side": { "rect": side_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Lateral derecho: marca y 20 cigarros)" },
			"color": { "rect": color_rect, "roughness": 0.48, "metallic": 0.02, "desc": data["name"] + " (Color sólido para tapas y lomo)" },
			"full": { "rect": full_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Frente y lateral combinados)" }
		}

		kit_dict[key_name] = item_dict["front"]
		kit_dict[key_name + "_front"] = item_dict["front"]
		kit_dict[key_name + "_side"] = item_dict["side"]
		kit_dict[key_name + "_color"] = item_dict["color"]
		kit_dict[key_name + "_full"] = item_dict["full"]

		_REGIONS[key_name] = item_dict
		_REGIONS["cigar_" + key_name] = item_dict
		_REGIONS["cigarro_" + key_name] = item_dict
		_REGIONS["cajetilla_" + key_name] = item_dict

	if not _REGIONS.has("cigarette_packs_atlas"):
		_REGIONS["cigarette_packs_atlas"] = {}
	for k in kit_dict:
		_REGIONS["cigarette_packs_atlas"][k] = kit_dict[k]


## Registra semánticamente el catálogo oficial de los 18 paquetes de Galletas Rizko (cookie_packs_atlas.png)
static func _register_cookie_packs_kit() -> void:
	var w: float = 1024.0
	var h: float = 682.0

	var kit_dict := {}
	for idx in range(COOKIE_PACK_DATA.size()):
		var data: Dictionary = COOKIE_PACK_DATA[idx]
		var key_name: String = data["id"]
		var fx: float = float(data["fx"])
		var fe: float = float(data["fe"])
		var bx: float = float(data["bx"])
		var be: float = float(data["be"])
		var sx: float = float(data["sx"])
		var se: float = float(data["se"])
		var ys: float = float(data["ys"])
		var ye: float = float(data["ye"])

		var front_rect := Rect2(fx / w, ys / h, (fe - fx + 1.0) / w, (ye - ys + 1.0) / h)
		var back_rect := Rect2(bx / w, ys / h, (be - bx + 1.0) / w, (ye - ys + 1.0) / h)
		var side_rect := Rect2(sx / w, ys / h, (se - sx + 1.0) / w, (ye - ys + 1.0) / h)
		var color_rect := Rect2((14.0 + float(idx) * 56.0 + 2.0) / w, (640.0 + 2.0) / h, 36.0 / w, 20.0 / h)
		var full_rect := Rect2(fx / w, ys / h, (se - fx + 1.0) / w, (ye - ys + 1.0) / h)

		var item_dict := {
			"front": { "rect": front_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Frente: Logo Rizko, variedad y galletas)" },
			"back": { "rect": back_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Atrás: Información nutrimental y código de barras)" },
			"side": { "rect": side_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Lateral: Tira vertical con logotipo oficial)" },
			"color": { "rect": color_rect, "roughness": 0.48, "metallic": 0.02, "desc": data["name"] + " (Color sólido para tapas y sellado)" },
			"full": { "rect": full_rect, "roughness": 0.45, "metallic": 0.05, "desc": data["name"] + " (Envoltura completa desplegada)" }
		}

		kit_dict[key_name] = item_dict["front"]
		kit_dict[key_name + "_front"] = item_dict["front"]
		kit_dict[key_name + "_back"] = item_dict["back"]
		kit_dict[key_name + "_side"] = item_dict["side"]
		kit_dict[key_name + "_color"] = item_dict["color"]
		kit_dict[key_name + "_full"] = item_dict["full"]

		_REGIONS[key_name] = item_dict
		_REGIONS["cookie_" + key_name] = item_dict
		_REGIONS["galleta_" + key_name] = item_dict
		_REGIONS["rizko_" + key_name] = item_dict

	if not _REGIONS.has("cookie_packs_atlas"):
		_REGIONS["cookie_packs_atlas"] = {}
	for k in kit_dict:
		_REGIONS["cookie_packs_atlas"][k] = kit_dict[k]


## Registra semánticamente el catálogo oficial de las 20 Bolsas de Papitas / Sabritas (snack_bags_atlas.png)
static func _register_snack_bags_kit() -> void:
	var w: float = 1024.0
	var h: float = 682.0

	var kit_dict := {}
	for idx in range(SNACK_BAG_DATA.size()):
		var data: Dictionary = SNACK_BAG_DATA[idx]
		var key_name: String = data["id"]
		var fx: float = float(data["fx"])
		var fe: float = float(data["fe"])
		var sx: float = float(data["sx"])
		var se: float = float(data["se"])
		var ys: float = float(data["ys"])
		var ye: float = float(data["ye"])

		var front_rect := Rect2(fx / w, ys / h, (fe - fx + 1.0) / w, (ye - ys + 1.0) / h)
		var side_rect := Rect2(sx / w, ys / h, (se - sx + 1.0) / w, (ye - ys + 1.0) / h)
		var color_rect := Rect2(3.0 / w, (24.0 + float(idx) * 31.0 + 1.0) / h, 13.0 / w, 20.0 / h)
		var full_rect := Rect2(fx / w, ys / h, (se - fx + 1.0) / w, (ye - ys + 1.0) / h)

		var item_dict := {
			"front": { "rect": front_rect, "roughness": 0.35, "metallic": 0.08, "desc": data["name"] + " (Frente: Logo de marca, botana y 60g)" },
			"side": { "rect": side_rect, "roughness": 0.35, "metallic": 0.08, "desc": data["name"] + " (Lateral: Franja vertical con icono oficial)" },
			"color": { "rect": color_rect, "roughness": 0.40, "metallic": 0.05, "desc": data["name"] + " (Color sólido para sellos y reverso)" },
			"full": { "rect": full_rect, "roughness": 0.35, "metallic": 0.08, "desc": data["name"] + " (Envoltura completa)" }
		}

		kit_dict[key_name] = item_dict["front"]
		kit_dict[key_name + "_front"] = item_dict["front"]
		kit_dict[key_name + "_side"] = item_dict["side"]
		kit_dict[key_name + "_color"] = item_dict["color"]
		kit_dict[key_name + "_full"] = item_dict["full"]

		_REGIONS[key_name] = item_dict
		_REGIONS["snack_" + key_name] = item_dict
		_REGIONS["sabrita_" + key_name] = item_dict
		_REGIONS["papa_" + key_name] = item_dict
		_REGIONS["papita_" + key_name] = item_dict
		_REGIONS["botana_" + key_name] = item_dict

	if not _REGIONS.has("snack_bags_atlas"):
		_REGIONS["snack_bags_atlas"] = {}
	for k in kit_dict:
		_REGIONS["snack_bags_atlas"][k] = kit_dict[k]



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
		var regions_map: Dictionary = parsed.get("regions", parsed)
		for region_name in regions_map:
			if not (regions_map[region_name] is Dictionary):
				continue
			var entry: Dictionary = regions_map[region_name]
			var rect := Rect2(0.0, 0.0, 1.0, 1.0)
			if entry.has("rect") and entry["rect"] is Array and entry["rect"].size() >= 4:
				var r_arr: Array = entry["rect"]
				rect = Rect2(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]), float(r_arr[3]))
			elif entry.has("uv_rect") and entry["uv_rect"] is Array and entry["uv_rect"].size() >= 4:
				var r_arr: Array = entry["uv_rect"]
				rect = Rect2(float(r_arr[0]), float(r_arr[1]), float(r_arr[2]), float(r_arr[3]))
			var roughness := float(entry.get("roughness", 0.55))
			var metallic := float(entry.get("metallic", 0.02))
			var desc := str(entry.get("desc", ""))
			register_region(texture_key, str(region_name), rect, roughness, metallic, desc)


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


## Nombres canónicos de las 16 telas de sofá (4x4)
const SOFA_FABRIC_NAMES: Array[String] = [
	"vintage_01_jacquard_gold",
	"vintage_02_velvet_burgundy",
	"vintage_03_corduroy_orange",
	"vintage_04_brocade_green",
	"vintage_05_stripes_tan",
	"vintage_06_tapestry_mustard",
	"vintage_07_tweed_rustic",
	"vintage_08_diamonds_70s",
	"modern_01_charcoal",
	"modern_02_boucle_oat",
	"modern_03_offwhite",
	"modern_04_olive",
	"modern_05_navy",
	"modern_06_terracotta",
	"modern_07_mustard",
	"modern_08_graphite"
]


## Nombres canónicos de las 18 bebidas en cartón de 1L (mosaico 6x3)
const CARTON_DRINK_NAMES: Array[String] = [
	"leche_entera",
	"leche_descremada",
	"leche_chocolate",
	"jugo_naranja",
	"jugo_manzana",
	"jugo_mango",
	"nectar_fresa",
	"nectar_naranja",
	"te_limon",
	"agua_coco",
	"bebida_platano",
	"cafe_con_leche",
	"rayo_energy",
	"koka_plus",
	"spritea",
	"jumexito_mango",
	"narizona_durazno",
	"aquapura_agua"
]

## Datos completos de las 18 bebidas en cartón de 1L (marca, nombre, categoría, color de tapón)
const CARTON_DRINK_DATA: Array[Dictionary] = [
	# Fila 0: Lácteos y Jugos Básicos
	{ "id": "leche_entera", "name": "Lácteos del Valle - Leche Entera 1L", "brand": "Lácteos del Valle", "category": "leche", "col": 0, "row": 0, "cap_color": Color(0.10, 0.40, 0.85) },
	{ "id": "leche_descremada", "name": "Lácteos del Valle - Leche Descremada 1L", "brand": "Lácteos del Valle", "category": "leche", "col": 1, "row": 0, "cap_color": Color(0.85, 0.12, 0.12) },
	{ "id": "leche_chocolate", "name": "ChocoVida - Leche Chocolate 1L", "brand": "ChocoVida", "category": "leche", "col": 2, "row": 0, "cap_color": Color(0.35, 0.18, 0.10) },
	{ "id": "jugo_naranja", "name": "SolVida - Jugo de Naranja 1L", "brand": "SolVida", "category": "jugo", "col": 3, "row": 0, "cap_color": Color(0.95, 0.50, 0.05) },
	{ "id": "jugo_manzana", "name": "SolVida - Jugo de Manzana 1L", "brand": "SolVida", "category": "jugo", "col": 4, "row": 0, "cap_color": Color(0.40, 0.75, 0.20) },
	{ "id": "jugo_mango", "name": "SolVida - Jugo de Mango 1L", "brand": "SolVida", "category": "jugo", "col": 5, "row": 0, "cap_color": Color(0.95, 0.70, 0.05) },

	# Fila 1: Néctares, Tés y Bebidas Especiales
	{ "id": "nectar_fresa", "name": "Valle Frutal - Néctar de Fresa 1L", "brand": "Valle Frutal", "category": "nectar", "col": 0, "row": 1, "cap_color": Color(0.85, 0.10, 0.20) },
	{ "id": "nectar_naranja", "name": "Valle Frutal - Néctar de Naranja 1L", "brand": "Valle Frutal", "category": "nectar", "col": 1, "row": 1, "cap_color": Color(0.95, 0.50, 0.05) },
	{ "id": "te_limon", "name": "Tezá - Té Helado Limón 1L", "brand": "Tezá", "category": "te", "col": 2, "row": 1, "cap_color": Color(0.90, 0.80, 0.10) },
	{ "id": "agua_coco", "name": "Vida - Agua de Coco 1L", "brand": "Vida", "category": "agua", "col": 3, "row": 1, "cap_color": Color(0.10, 0.70, 0.80) },
	{ "id": "bebida_platano", "name": "Plátano Fresco - Bebida de Plátano 1L", "brand": "Plátano Fresco", "category": "jugo", "col": 4, "row": 1, "cap_color": Color(0.95, 0.85, 0.10) },
	{ "id": "cafe_con_leche", "name": "Café del Valle - Café con Leche 1L", "brand": "Café del Valle", "category": "cafe", "col": 5, "row": 1, "cap_color": Color(0.35, 0.20, 0.15) },

	# Fila 2: Energizantes, Refrescos y Aguas
	{ "id": "rayo_energy", "name": "Rayo - Energy Drink 1L", "brand": "Rayo", "category": "energia", "col": 0, "row": 2, "cap_color": Color(0.10, 0.85, 0.10) },
	{ "id": "koka_plus", "name": "Koka Plus - Sabor Original 1L", "brand": "Koka Plus", "category": "refresco", "col": 1, "row": 2, "cap_color": Color(0.85, 0.05, 0.05) },
	{ "id": "spritea", "name": "Spritea - Sabor Lima-Limón 1L", "brand": "Spritea", "category": "refresco", "col": 2, "row": 2, "cap_color": Color(0.10, 0.70, 0.30) },
	{ "id": "jumexito_mango", "name": "Jumexito - Néctar de Mango 1L", "brand": "Jumexito", "category": "nectar", "col": 3, "row": 2, "cap_color": Color(0.05, 0.20, 0.55) },
	{ "id": "narizona_durazno", "name": "NariZona - Té Helado Durazno 1L", "brand": "NariZona", "category": "te", "col": 4, "row": 2, "cap_color": Color(0.10, 0.65, 0.65) },
	{ "id": "aquapura_agua", "name": "AquaPura - Agua Purificada 1L", "brand": "AquaPura", "category": "agua", "col": 5, "row": 2, "cap_color": Color(0.20, 0.50, 0.90) }
]

## Retorna los metadatos completos de una bebida por ID o índice
static func get_carton_drink_data(drink_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if drink_key_or_idx is int or drink_key_or_idx is float:
		var idx := clampi(int(drink_key_or_idx), 0, CARTON_DRINK_DATA.size() - 1)
		return CARTON_DRINK_DATA[idx]
	var s := str(drink_key_or_idx).strip_edges().to_lower()
	if s.begins_with("drink_"):
		s = s.trim_prefix("drink_")
	elif s.begins_with("carton_"):
		s = s.trim_prefix("carton_")
	for d in CARTON_DRINK_DATA:
		if d["id"] == s:
			return d

	# Aliases comunes
	var aliases := {
		"solvida_naranja": "jugo_naranja",
		"solvida_manzana": "jugo_manzana",
		"solvida_mango": "jugo_mango",
		"leche": "leche_entera",
		"chocolate": "leche_chocolate",
		"chocovida": "leche_chocolate",
		"descremada": "leche_descremada",
		"platano": "bebida_platano",
		"banana": "bebida_platano",
		"teza": "te_limon",
		"limon": "te_limon",
		"fresa": "nectar_fresa",
		"coco": "agua_coco",
		"vida": "agua_coco",
		"cafe": "cafe_con_leche",
		"rayo": "rayo_energy",
		"energy": "rayo_energy",
		"monster": "rayo_energy",
		"koka": "koka_plus",
		"coca": "koka_plus",
		"sprite": "spritea",
		"jumexito": "jumexito_mango",
		"arizona": "narizona_durazno",
		"durazno": "narizona_durazno",
		"narizona": "narizona_durazno",
		"agua": "aquapura_agua",
		"aquapura": "aquapura_agua"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in CARTON_DRINK_DATA:
			if d["id"] == target_id:
				return d

	for d in CARTON_DRINK_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d

	return CARTON_DRINK_DATA[0]

## Catálogo canónico de las 19 latas de bebidas (355ml)
const SODA_CAN_NAMES: Array[String] = [
	"kola_plus",
	"pepzi_maxx",
	"spritz_up",
	"fantatx",
	"seven_spark",
	"dr_pepperon",
	"mont_dew",
	"crushy",
	"squirtle_citrus",
	"mirindaz",
	"jarriton",
	"manzanita_solis",
	"freskita",
	"inka_schweppz",
	"canada_dry",
	"red_buller",
	"mounstro_energy",
	"aw_root_beer",
	"muggy_float"
]

const SODA_CAN_DATA: Array[Dictionary] = [
	# Fila 0: Colas y Cítricos Principales (y=7, h=188 -> bot=195, borde de aluminio estirado)
	{ "id": "kola_plus", "name": "Kola Plus 355ml", "brand": "Kola Plus", "flavor": "Cola", "col": 0, "row": 0, "x": 0, "y": 7, "w": 204, "h": 188 },
	{ "id": "pepzi_maxx", "name": "Pepzi Maxx 355ml", "brand": "Pepzi", "flavor": "Cola Sin Azúcar", "col": 1, "row": 0, "x": 205, "y": 7, "w": 204, "h": 188 },
	{ "id": "spritz_up", "name": "Spritz Up 355ml", "brand": "Spritz Up", "flavor": "Lima-Limón", "col": 2, "row": 0, "x": 410, "y": 7, "w": 204, "h": 188 },
	{ "id": "fantatx", "name": "Fantatx Naranja 355ml", "brand": "Fantatx", "flavor": "Naranja", "col": 3, "row": 0, "x": 615, "y": 7, "w": 204, "h": 188 },
	{ "id": "seven_spark", "name": "Seven Spark 355ml", "brand": "Seven Spark", "flavor": "Lima", "col": 4, "row": 0, "x": 820, "y": 7, "w": 204, "h": 188 },

	# Fila 1: Especiales y Frutales (y=201, h=182 -> bot=383, borde de aluminio estirado)
	{ "id": "dr_pepperon", "name": "Dr Pepperón 355ml", "brand": "Dr Pepperón", "flavor": "Mora / Especial", "col": 0, "row": 1, "x": 0, "y": 201, "w": 204, "h": 182 },
	{ "id": "mont_dew", "name": "Mont Dew 355ml", "brand": "Mont Dew", "flavor": "Citrus Energético", "col": 1, "row": 1, "x": 205, "y": 201, "w": 204, "h": 182 },
	{ "id": "crushy", "name": "Crushy Naranja 355ml", "brand": "Crushy", "flavor": "Naranja", "col": 2, "row": 1, "x": 410, "y": 201, "w": 204, "h": 182 },
	{ "id": "squirtle_citrus", "name": "Squirtle Citrus 355ml", "brand": "Squirtle", "flavor": "Toronja-Limón", "col": 3, "row": 1, "x": 615, "y": 201, "w": 204, "h": 182 },
	{ "id": "mirindaz", "name": "Mirindaz Naranja 355ml", "brand": "Mirindaz", "flavor": "Naranja", "col": 4, "row": 1, "x": 820, "y": 201, "w": 204, "h": 182 },

	# Fila 2: Mexicanos y Clásicos (y=388, h=178 -> bot=566, borde de aluminio estirado)
	{ "id": "jarriton", "name": "Jarriton Tutti Frutti 355ml", "brand": "Jarriton", "flavor": "Tutti Frutti", "col": 0, "row": 2, "x": 0, "y": 388, "w": 204, "h": 178 },
	{ "id": "manzanita_solis", "name": "Manzanita Solís 355ml", "brand": "Manzanita Solís", "flavor": "Manzana", "col": 1, "row": 2, "x": 205, "y": 388, "w": 204, "h": 178 },
	{ "id": "freskita", "name": "Freskita Agua Mineral 355ml", "brand": "Freskita", "flavor": "Agua Mineral", "col": 2, "row": 2, "x": 410, "y": 388, "w": 204, "h": 178 },
	{ "id": "inka_schweppz", "name": "Inka Cola-Real / Schweppz Tonic 355ml", "brand": "Inka / Schweppz", "flavor": "Tónica / Cola Real", "col": 3, "row": 2, "x": 615, "y": 388, "w": 204, "h": 178 },
	{ "id": "canada_dry", "name": "Canada Dry Ginger Ale 355ml", "brand": "Canada Dry", "flavor": "Ginger Ale", "col": 4, "row": 2, "x": 820, "y": 388, "w": 204, "h": 178 },

	# Fila 3: Energizantes y Bebidas Oscuras (y=570, h=182 -> bot=752, borde de aluminio estirado)
	{ "id": "red_buller", "name": "Red Buller Energy Drink 355ml", "brand": "Red Buller", "flavor": "Energy", "col": 0, "row": 3, "x": 0, "y": 570, "w": 204, "h": 182 },
	{ "id": "mounstro_energy", "name": "Mounstro Energy 355ml", "brand": "Mounstro", "flavor": "Energy", "col": 1, "row": 3, "x": 205, "y": 570, "w": 204, "h": 182 },
	{ "id": "aw_root_beer", "name": "A&W Root Beer 355ml", "brand": "A&W", "flavor": "Root Beer", "col": 2, "row": 3, "x": 410, "y": 570, "w": 204, "h": 182 },
	{ "id": "muggy_float", "name": "Muggy Float Chocolate 355ml", "brand": "Muggy Float", "flavor": "Float Chocolate", "col": 3, "row": 3, "x": 615, "y": 570, "w": 204, "h": 182 }
]

## Retorna los metadatos completos de una lata de refresco por ID o índice
static func get_soda_can_data(can_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if can_key_or_idx is int or can_key_or_idx is float:
		var idx := clampi(int(can_key_or_idx), 0, SODA_CAN_DATA.size() - 1)
		return SODA_CAN_DATA[idx]
	var s := str(can_key_or_idx).strip_edges().to_lower()
	if s.begins_with("can_"):
		s = s.trim_prefix("can_")
	elif s.begins_with("soda_"):
		s = s.trim_prefix("soda_")
	for d in SODA_CAN_DATA:
		if d["id"] == s:
			return d

	# Aliases comunes
	var aliases := {
		"cola": "kola_plus",
		"coca": "kola_plus",
		"pepsi": "pepzi_maxx",
		"pepzi": "pepzi_maxx",
		"sprite": "spritz_up",
		"spritz": "spritz_up",
		"fanta": "fantatx",
		"seven": "seven_spark",
		"7up": "seven_spark",
		"pepper": "dr_pepperon",
		"mountain_dew": "mont_dew",
		"dew": "mont_dew",
		"crush": "crushy",
		"squirt": "squirtle_citrus",
		"mirinda": "mirindaz",
		"jarritos": "jarriton",
		"jarrito": "jarriton",
		"manzanita": "manzanita_solis",
		"solis": "manzanita_solis",
		"mineral": "freskita",
		"inka": "inka_schweppz",
		"schweppes": "inka_schweppz",
		"tonic": "inka_schweppz",
		"ginger": "canada_dry",
		"ginger_ale": "canada_dry",
		"redbull": "red_buller",
		"red_bull": "red_buller",
		"monster": "mounstro_energy",
		"mounstro": "mounstro_energy",
		"root_beer": "aw_root_beer",
		"aw": "aw_root_beer",
		"mug": "muggy_float",
		"chocolate": "muggy_float"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in SODA_CAN_DATA:
			if d["id"] == target_id:
				return d

	for d in SODA_CAN_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d

	return SODA_CAN_DATA[0]

## Catálogo canónico de las 20 cajas de cereal (375g)
const CEREAL_BOX_NAMES: Array[String] = [
	"krisp_max",
	"zucarinix",
	"corny_bits",
	"choco_bites",
	"fruti_loops",
	"choco_krunch",
	"miel_dorada",
	"estrella_flakes",
	"granola_mix",
	"avena_crunch",
	"tornado_flakes",
	"frosty_crunch",
	"rayo_cereal",
	"selva_crunch",
	"sol_nativo",
	"campo_feliz",
	"dulce_maiz",
	"choco_rizos",
	"nube_crispy",
	"bosque_crunch"
]

const CEREAL_BOX_DATA: Array[Dictionary] = [
	# Fila 0: Maíz y Tradicionales
	{ "id": "krisp_max",       "name": "Krisp Max 375g",       "brand": "Krisp Max",       "flavor": "Corn Flakes",           "color": "Rojo",             "col": 0, "row": 0, "x": 6,   "y": 5,   "w": 195, "h": 170 },
	{ "id": "zucarinix",       "name": "Zucarinix 375g",       "brand": "Zucarinix",       "flavor": "Azucarados de Maíz",    "color": "Azul",             "col": 1, "row": 0, "x": 209, "y": 5,   "w": 202, "h": 170 },
	{ "id": "corny_bits",      "name": "Corny Bits 375g",      "brand": "Corny Bits",      "flavor": "Cereal de Maíz",        "color": "Verde",            "col": 2, "row": 0, "x": 419, "y": 5,   "w": 190, "h": 170 },
	{ "id": "choco_bites",     "name": "Choco Bites 375g",     "brand": "Choco Bites",     "flavor": "Cereal con Chocolate",  "color": "Naranja",          "col": 3, "row": 0, "x": 617, "y": 5,   "w": 200, "h": 170 },
	{ "id": "fruti_loops",     "name": "Fruti Loops 375g",     "brand": "Fruti Loops",     "flavor": "Aros Frutales",         "color": "Morado",           "col": 4, "row": 0, "x": 824, "y": 5,   "w": 195, "h": 170 },

	# Fila 1: Especialidades y Fibras
	{ "id": "choco_krunch",    "name": "Choco Krunch 375g",    "brand": "Choco Krunch",    "flavor": "Cereal de Chocolate",   "color": "Café",             "col": 0, "row": 1, "x": 6,   "y": 180, "w": 195, "h": 162 },
	{ "id": "miel_dorada",     "name": "Miel Dorada 375g",     "brand": "Miel Dorada",     "flavor": "Cereal con Miel",       "color": "Amarillo",         "col": 1, "row": 1, "x": 209, "y": 180, "w": 202, "h": 162 },
	{ "id": "estrella_flakes", "name": "Estrella Flakes 375g", "brand": "Estrella Flakes", "flavor": "Estrellitas de Maíz",   "color": "Azul Oscuro",      "col": 2, "row": 1, "x": 419, "y": 180, "w": 190, "h": 162 },
	{ "id": "granola_mix",     "name": "Granola Mix 375g",     "brand": "Granola Mix",     "flavor": "Granola con Frutas",    "color": "Verde Lima",       "col": 3, "row": 1, "x": 617, "y": 180, "w": 200, "h": 162 },
	{ "id": "avena_crunch",    "name": "Avena Crunch 375g",    "brand": "Avena Crunch",    "flavor": "Cereal de Avena",       "color": "Beige Trigo",      "col": 4, "row": 1, "x": 824, "y": 180, "w": 195, "h": 162 },

	# Fila 2: Glaseados y Temáticos
	{ "id": "tornado_flakes",  "name": "Tornado Flakes 375g",  "brand": "Tornado Flakes",  "flavor": "Hojuelas y Leche",      "color": "Azul Cobalto",     "col": 0, "row": 2, "x": 6,   "y": 347, "w": 195, "h": 160 },
	{ "id": "frosty_crunch",   "name": "Frosty Crunch 375g",   "brand": "Frosty Crunch",   "flavor": "Glaseado con Oso",      "color": "Celeste",          "col": 1, "row": 2, "x": 209, "y": 347, "w": 202, "h": 160 },
	{ "id": "rayo_cereal",     "name": "Rayo Cereal 375g",     "brand": "Rayo Cereal",     "flavor": "Almohaditas Crujientes","color": "Rojo Fuego",       "col": 2, "row": 2, "x": 419, "y": 347, "w": 190, "h": 160 },
	{ "id": "selva_crunch",    "name": "Selva Crunch 375g",    "brand": "Selva Crunch",    "flavor": "Aros con Tucán",        "color": "Verde Selva",      "col": 3, "row": 2, "x": 617, "y": 347, "w": 200, "h": 160 },
	{ "id": "sol_nativo",      "name": "Sol Nativo 375g",      "brand": "Sol Nativo",      "flavor": "Hojuelas Tostadas",     "color": "Naranja Dorado",   "col": 4, "row": 2, "x": 824, "y": 347, "w": 195, "h": 160 },

	# Fila 3: Infantiles y Chocolate
	{ "id": "campo_feliz",     "name": "Campo Feliz 375g",     "brand": "Campo Feliz",     "flavor": "Bolitas con Vaquita",   "color": "Verde Campo",      "col": 0, "row": 3, "x": 6,   "y": 513, "w": 195, "h": 160 },
	{ "id": "dulce_maiz",      "name": "Dulce Maíz 375g",      "brand": "Dulce Maíz",      "flavor": "Multicolor con Conejo", "color": "Rosa Magenta",     "col": 1, "row": 3, "x": 209, "y": 513, "w": 202, "h": 160 },
	{ "id": "choco_rizos",     "name": "Choco Rizos 375g",     "brand": "Choco Rizos",     "flavor": "Rizos de Chocolate",    "color": "Chocolate Oscuro", "col": 2, "row": 3, "x": 419, "y": 513, "w": 190, "h": 160 },
	{ "id": "nube_crispy",     "name": "Nube Crispy 375g",     "brand": "Nube Crispy",     "flavor": "Arroz con Nubecita",    "color": "Azul Cielo",       "col": 3, "row": 3, "x": 617, "y": 513, "w": 200, "h": 160 },
	{ "id": "bosque_crunch",   "name": "Bosque Crunch 375g",   "brand": "Bosque Crunch",   "flavor": "Aros con Oso",          "color": "Verde Bosque",     "col": 4, "row": 3, "x": 824, "y": 513, "w": 195, "h": 160 }
]

## Retorna los metadatos completos de una caja de cereal por ID o índice
static func get_cereal_box_data(cereal_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if cereal_key_or_idx is int or cereal_key_or_idx is float:
		var idx := clampi(int(cereal_key_or_idx), 0, CEREAL_BOX_DATA.size() - 1)
		return CEREAL_BOX_DATA[idx]
	var s := str(cereal_key_or_idx).strip_edges().to_lower()
	if s.is_valid_int():
		var idx := clampi(s.to_int(), 0, CEREAL_BOX_DATA.size() - 1)
		return CEREAL_BOX_DATA[idx]
	s = s.replace("cereal_", "").replace("box_", "")
	for d in CEREAL_BOX_DATA:
		if d["id"] == s:
			return d
	# Aliases semánticos y de sabores
	var aliases := {
		"corn_flakes": "krisp_max",
		"krisp": "krisp_max",
		"kelloggs": "krisp_max",
		"zucaritas": "zucarinix",
		"tigre": "zucarinix",
		"corny": "corny_bits",
		"choco": "choco_bites",
		"froot_loops": "fruti_loops",
		"fruit_loops": "fruti_loops",
		"loops": "fruti_loops",
		"krunch": "choco_krunch",
		"oso": "choco_krunch",
		"miel": "miel_dorada",
		"abeja": "miel_dorada",
		"estrella": "estrella_flakes",
		"granola": "granola_mix",
		"avena": "avena_crunch",
		"tornado": "tornado_flakes",
		"frosty": "frosty_crunch",
		"polar": "frosty_crunch",
		"rayo": "rayo_cereal",
		"selva": "selva_crunch",
		"tucan": "selva_crunch",
		"sol": "sol_nativo",
		"vaca": "campo_feliz",
		"vaquita": "campo_feliz",
		"conejo": "dulce_maiz",
		"rizos": "choco_rizos",
		"nube": "nube_crispy",
		"bosque": "bosque_crunch"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in CEREAL_BOX_DATA:
			if d["id"] == target_id:
				return d
	for d in CEREAL_BOX_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d
	return CEREAL_BOX_DATA[0]

## Catálogo canónico de los 20 Paquetes de Dulces, Chocolates y Golosinas (candy_bags_atlas.png)
const CANDY_BAG_NAMES: Array[String] = [
	"chocorix",
	"krix",
	"mellos",
	"dulcitos",
	"nuxi",
	"vitagom",
	"cacaoz",
	"rebotes",
	"freskito",
	"brrrt",
	"chispy",
	"frutix",
	"zelta",
	"lunetas",
	"tornado",
	"pipocas",
	"nubez",
	"aqualis",
	"trufino",
	"rollox"
]

const CANDY_BAG_DATA: Array[Dictionary] = [
	# Fila 0: Chocolates y Obleas Crujientes
	{ "id": "chocorix", "name": "Chocorix Chocolate con Leche", "brand": "Chocorix", "flavor": "Chocolate con Leche", "color": "Marrón Cacao", "col": 0, "row": 0, "x": 13, "y": 25, "w": 198, "h": 145 },
	{ "id": "krix", "name": "Krix Oblea con Chocolate", "brand": "Krix", "flavor": "Oblea con Chocolate", "color": "Rojo Escarlata", "col": 1, "row": 0, "x": 223, "y": 25, "w": 186, "h": 146 },
	{ "id": "mellos", "name": "Mellos Chocolate con Relleno", "brand": "Mellos", "flavor": "Chocolate Relleno", "color": "Marrón Oscuro", "col": 2, "row": 0, "x": 420, "y": 26, "w": 188, "h": 145 },
	{ "id": "dulcitos", "name": "Dulcitos Cacahuate Cubierto", "brand": "Dulcitos", "flavor": "Cacahuate Confite", "color": "Amarillo Dorado", "col": 3, "row": 0, "x": 618, "y": 25, "w": 188, "h": 147 },
	{ "id": "nuxi", "name": "Nuxi Chocolate con Avellana", "brand": "Nuxi", "flavor": "Avellana Premium", "color": "Oro Bronce", "col": 4, "row": 0, "x": 817, "y": 25, "w": 192, "h": 147 },

	# Fila 1: Menta, Cacao Puro y Caramelos Árticos
	{ "id": "vitagom", "name": "VitaGom Sabor Menta", "brand": "VitaGom", "flavor": "Menta Verde", "color": "Verde Esmeralda", "col": 0, "row": 1, "x": 13, "y": 186, "w": 198, "h": 146 },
	{ "id": "cacaoz", "name": "Cacaoz Chocolate Puro", "brand": "Cacaoz", "flavor": "Cacao Amargo", "color": "Café Tostado", "col": 1, "row": 1, "x": 224, "y": 187, "w": 184, "h": 145 },
	{ "id": "rebotes", "name": "Rebotes Caramelos de Fruta", "brand": "Rebotes", "flavor": "Gomitas Frutales", "color": "Naranja Cítrico", "col": 2, "row": 1, "x": 419, "y": 187, "w": 188, "h": 146 },
	{ "id": "freskito", "name": "Freskito Chicle sin Azúcar Menta", "brand": "Freskito", "flavor": "Menta Glacial", "color": "Azul Cobalto", "col": 3, "row": 1, "x": 618, "y": 187, "w": 189, "h": 146 },
	{ "id": "brrrt", "name": "Brrrt Caramelo Menta", "brand": "Brrrt", "flavor": "Menta Fuerte", "color": "Plata Metálico", "col": 4, "row": 1, "x": 817, "y": 188, "w": 192, "h": 144 },

	# Fila 2: Confitados, Gomitas y Ácidos
	{ "id": "chispy", "name": "Chispy Caramelos Surtidos", "brand": "Chispy", "flavor": "Caramelos Frutales", "color": "Fucsia Magenta", "col": 0, "row": 2, "x": 12, "y": 347, "w": 199, "h": 146 },
	{ "id": "frutix", "name": "Frutix Gomitas de Fruta", "brand": "Frutix", "flavor": "Panditas Gomita", "color": "Amarillo Sol", "col": 1, "row": 2, "x": 223, "y": 349, "w": 185, "h": 144 },
	{ "id": "zelta", "name": "Zelta Caramelo Ácido", "brand": "Zelta", "flavor": "Tiras Ácidas", "color": "Negro Carbón", "col": 2, "row": 2, "x": 421, "y": 349, "w": 184, "h": 143 },
	{ "id": "lunetas", "name": "Lunetas Chocolate Confitado", "brand": "Lunetas", "flavor": "Lentejas Chocolate", "color": "Púrpura Violeta", "col": 3, "row": 2, "x": 617, "y": 348, "w": 190, "h": 145 },
	{ "id": "tornado", "name": "Tornado Chicle Sabor Frutas", "brand": "Tornado", "flavor": "Tutti Frutti Chicle", "color": "Rojo Fuego", "col": 4, "row": 2, "x": 817, "y": 347, "w": 194, "h": 146 },

	# Fila 3: Palomitas, Malvaviscos y Golosinas Especiales
	{ "id": "pipocas", "name": "Pipocas Caramelo Crujiente", "brand": "Pipocas", "flavor": "Palomitas Dulces", "color": "Azul Marino", "col": 0, "row": 3, "x": 13, "y": 507, "w": 198, "h": 148 },
	{ "id": "nubez", "name": "Nubez Malvavisco con Chocolate", "brand": "Nubez", "flavor": "Bombón de Chocolate", "color": "Rosa Pastel", "col": 1, "row": 3, "x": 224, "y": 508, "w": 183, "h": 148 },
	{ "id": "aqualis", "name": "Aqualis Gomitas de Cola", "brand": "Aqualis", "flavor": "Botellitas Cola", "color": "Cian Turquesa", "col": 2, "row": 3, "x": 420, "y": 507, "w": 185, "h": 149 },
	{ "id": "trufino", "name": "Trufino Chocolate Extra Fino", "brand": "Trufino", "flavor": "Trufa Bombón", "color": "Negro Chocolate", "col": 3, "row": 3, "x": 619, "y": 508, "w": 187, "h": 147 },
	{ "id": "rollox", "name": "Rollox Caramelo Tutti Frutti", "brand": "Rollox", "flavor": "Rollos Arcoíris", "color": "Arcoíris Rayas", "col": 4, "row": 3, "x": 818, "y": 507, "w": 193, "h": 149 }
]

## Retorna los metadatos completos de un dulce/golosina por ID o índice
static func get_candy_bag_data(candy_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if candy_key_or_idx is int or candy_key_or_idx is float:
		var idx := clampi(int(candy_key_or_idx), 0, CANDY_BAG_DATA.size() - 1)
		return CANDY_BAG_DATA[idx]
	var s := str(candy_key_or_idx).strip_edges().to_lower()
	if s.is_valid_int():
		var idx := clampi(s.to_int(), 0, CANDY_BAG_DATA.size() - 1)
		return CANDY_BAG_DATA[idx]
	s = s.replace("candy_", "").replace("dulce_", "").replace("bag_", "")
	for d in CANDY_BAG_DATA:
		if d["id"] == s:
			return d
	# Aliases semánticos y de golosinas
	var aliases := {
		"chocolate": "chocorix",
		"wafer": "krix",
		"oblea": "krix",
		"m&ms": "mellos",
		"skittles": "chispy",
		"cacahuate": "dulcitos",
		"mani": "dulcitos",
		"nuez": "nuxi",
		"avellana": "nuxi",
		"menta": "vitagom",
		"chicle_menta": "vitagom",
		"cacao": "cacaoz",
		"chocolate_puro": "cacaoz",
		"gomitas": "frutix",
		"panditas": "frutix",
		"acido": "zelta",
		"sour": "zelta",
		"lentejas": "lunetas",
		"chicle": "tornado",
		"bubblegum": "tornado",
		"popcorn": "pipocas",
		"palomitas": "pipocas",
		"malvavisco": "nubez",
		"marshmallow": "nubez",
		"bombon": "nubez",
		"cola": "aqualis",
		"botellitas": "aqualis",
		"trufa": "trufino",
		"trufas": "trufino",
		"arcoiris": "rollox",
		"rainbow": "rollox"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in CANDY_BAG_DATA:
			if d["id"] == target_id:
				return d
	for d in CANDY_BAG_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d
	return CANDY_BAG_DATA[0]

## Catálogo canónico de las 20 Cajetillas de Cigarros (cigarette_packs_atlas.png)
const CIGARETTE_PACK_NAMES: Array[String] = [
	"ambar",
	"nordico",
	"cielo",
	"sable",
	"rio",
	"fenix",
	"valor",
	"tormenta",
	"duna",
	"boreal",
	"zafiro",
	"lider",
	"solsticio",
	"eclipse",
	"trento",
	"alba",
	"vertice",
	"caleo",
	"marfil",
	"lumen"
]

const CIGARETTE_PACK_DATA: Array[Dictionary] = [
	# Fila 0:
	{ "id": "ambar", "name": "Ámbar Classic (Tabaco Rubio 20)", "brand": "Ámbar", "type": "Classic", "col": 0, "row": 0, "fx": 19, "fy": 15, "fw": 122, "fh": 148, "sx": 153, "sy": 15, "sw": 36, "sh": 148 },
	{ "id": "nordico", "name": "Nórdico Suave (Tabaco Rubio 20)", "brand": "Nórdico", "type": "Suave", "col": 1, "row": 0, "fx": 221, "fy": 15, "fw": 122, "fh": 148, "sx": 355, "sy": 15, "sw": 36, "sh": 148 },
	{ "id": "cielo", "name": "Cielo Lights (Tabaco Rubio 20)", "brand": "Cielo", "type": "Lights", "col": 2, "row": 0, "fx": 426, "fy": 15, "fw": 122, "fh": 148, "sx": 559, "sy": 15, "sw": 36, "sh": 148 },
	{ "id": "sable", "name": "Sable Negro (Tabaco Negro 20)", "brand": "Sable", "type": "Negro", "col": 3, "row": 0, "fx": 630, "fy": 15, "fw": 122, "fh": 148, "sx": 765, "sy": 15, "sw": 35, "sh": 148 },
	{ "id": "rio", "name": "Río Mentol (Tabaco Rubio 20)", "brand": "Río", "type": "Mentol", "col": 4, "row": 0, "fx": 836, "fy": 15, "fw": 123, "fh": 148, "sx": 970, "sy": 16, "sw": 35, "sh": 147 },

	# Fila 1:
	{ "id": "fenix", "name": "Fénix Fuerte (Tabaco Rubio 20)", "brand": "Fénix", "type": "Fuerte", "col": 0, "row": 1, "fx": 20, "fy": 181, "fw": 120, "fh": 149, "sx": 154, "sy": 181, "sw": 34, "sh": 149 },
	{ "id": "valor", "name": "Valor Original (Tabaco Rubio 20)", "brand": "Valor", "type": "Original", "col": 1, "row": 1, "fx": 221, "fy": 181, "fw": 122, "fh": 149, "sx": 355, "sy": 181, "sw": 36, "sh": 149 },
	{ "id": "tormenta", "name": "Tormenta Mentol (Tabaco Rubio 20)", "brand": "Tormenta", "type": "Mentol", "col": 2, "row": 1, "fx": 426, "fy": 181, "fw": 122, "fh": 149, "sx": 559, "sy": 181, "sw": 36, "sh": 150 },
	{ "id": "duna", "name": "Duna Suave (Tabaco Rubio 20)", "brand": "Duna", "type": "Suave", "col": 3, "row": 1, "fx": 629, "fy": 181, "fw": 124, "fh": 150, "sx": 764, "sy": 181, "sw": 36, "sh": 150 },
	{ "id": "boreal", "name": "Boreal Mentol (Tabaco Rubio 20)", "brand": "Boreal", "type": "Mentol", "col": 4, "row": 1, "fx": 836, "fy": 181, "fw": 122, "fh": 149, "sx": 970, "sy": 181, "sw": 36, "sh": 149 },

	# Fila 2:
	{ "id": "zafiro", "name": "Zafiro Original (Tabaco Rubio 20)", "brand": "Zafiro", "type": "Original", "col": 0, "row": 2, "fx": 19, "fy": 347, "fw": 122, "fh": 151, "sx": 153, "sy": 347, "sw": 36, "sh": 152 },
	{ "id": "lider", "name": "Líder Fuerte (Tabaco Rubio 20)", "brand": "Líder", "type": "Fuerte", "col": 1, "row": 2, "fx": 221, "fy": 347, "fw": 122, "fh": 150, "sx": 355, "sy": 347, "sw": 36, "sh": 151 },
	{ "id": "solsticio", "name": "Solsticio Amarillo (Tabaco Rubio 20)", "brand": "Solsticio", "type": "Amarillo", "col": 2, "row": 2, "fx": 425, "fy": 347, "fw": 123, "fh": 151, "sx": 559, "sy": 347, "sw": 36, "sh": 151 },
	{ "id": "eclipse", "name": "Eclipse Negro (Tabaco Negro 20)", "brand": "Eclipse", "type": "Negro", "col": 3, "row": 2, "fx": 630, "fy": 348, "fw": 121, "fh": 150, "sx": 765, "sy": 349, "sw": 35, "sh": 149 },
	{ "id": "trento", "name": "Trento Original (Tabaco Rubio 20)", "brand": "Trento", "type": "Original", "col": 4, "row": 2, "fx": 836, "fy": 349, "fw": 122, "fh": 149, "sx": 969, "sy": 347, "sw": 38, "sh": 152 },

	# Fila 3:
	{ "id": "alba", "name": "Alba Suave (Tabaco Rubio 20)", "brand": "Alba", "type": "Suave", "col": 0, "row": 3, "fx": 20, "fy": 516, "fw": 120, "fh": 150, "sx": 153, "sy": 516, "sw": 36, "sh": 150 },
	{ "id": "vertice", "name": "Vértice Mentol (Tabaco Rubio 20)", "brand": "Vértice", "type": "Mentol", "col": 1, "row": 3, "fx": 222, "fy": 516, "fw": 120, "fh": 150, "sx": 356, "sy": 516, "sw": 34, "sh": 149 },
	{ "id": "caleo", "name": "Caleo Classic (Tabaco Rubio 20)", "brand": "Caleo", "type": "Classic", "col": 2, "row": 3, "fx": 425, "fy": 515, "fw": 122, "fh": 151, "sx": 558, "sy": 515, "sw": 37, "sh": 152 },
	{ "id": "marfil", "name": "Marfil Original (Tabaco Rubio 20)", "brand": "Marfil", "type": "Original", "col": 3, "row": 3, "fx": 630, "fy": 516, "fw": 121, "fh": 150, "sx": 765, "sy": 516, "sw": 35, "sh": 150 },
	{ "id": "lumen", "name": "Lumen Violeta (Tabaco Rubio 20)", "brand": "Lumen", "type": "Violeta", "col": 4, "row": 3, "fx": 836, "fy": 515, "fw": 122, "fh": 151, "sx": 970, "sy": 515, "sw": 36, "sh": 151 }
]

## Retorna los metadatos completos de una cajetilla de cigarros por ID o índice
static func get_cigarette_pack_data(cigar_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if cigar_key_or_idx is int or cigar_key_or_idx is float:
		var idx := clampi(int(cigar_key_or_idx), 0, CIGARETTE_PACK_DATA.size() - 1)
		return CIGARETTE_PACK_DATA[idx]
	var s := str(cigar_key_or_idx).strip_edges().to_lower()
	if s.is_valid_int():
		var idx := clampi(s.to_int(), 0, CIGARETTE_PACK_DATA.size() - 1)
		return CIGARETTE_PACK_DATA[idx]
	s = s.replace("cigar_", "").replace("cigarro_", "").replace("cajetilla_", "").replace("pack_", "")
	for d in CIGARETTE_PACK_DATA:
		if d["id"] == s:
			return d
	# Aliases semánticos y marcas
	var aliases := {
		"marlboro": "valor",
		"camel": "duna",
		"luckies": "ambar",
		"lucky_strike": "ambar",
		"pall_mall": "caleo",
		"benson": "marfil",
		"winston": "trento",
		"chesterfield": "lider",
		"kool": "rio",
		"newport": "boreal",
		"salem": "tormenta",
		"dunhill": "sable",
		"black_devil": "eclipse",
		"sobranie": "lumen",
		"davidoff": "alba",
		"mentol": "rio",
		"mentolado": "rio",
		"lights": "cielo",
		"suave": "nordico",
		"fuerte": "fenix",
		"rubio": "valor",
		"negro": "sable",
		"oro": "solsticio",
		"azul": "zafiro"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in CIGARETTE_PACK_DATA:
			if d["id"] == target_id:
				return d
	for d in CIGARETTE_PACK_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d
	return CIGARETTE_PACK_DATA[0]


## Catálogo canónico de los 18 paquetes de Galletas Rizko (cookie_packs_atlas.png)
const COOKIE_PACK_NAMES: Array[String] = [
	# Fila 0:
	"clasicas",
	"chocolate",
	"vainilla",
	"fresa",
	"crema",
	"limon",
	"arandano",
	"naranja",
	"frutos_rojos",
	# Fila 1:
	"platano",
	"chispas",
	"integrales",
	"doble_choco",
	"menta",
	"canela",
	"avena",
	"festival",
	"cookies_cream"
]

const COOKIE_PACK_DATA: Array[Dictionary] = [
	# Fila 0: ys=35, ye=273
	{ "id": "clasicas", "name": "Rizko Clásicas (120g)", "flavor": "Clásicas", "color": "0b4ea2", "fx": 11, "fe": 49, "bx": 55, "be": 83, "sx": 90, "se": 106, "ys": 35, "ye": 273 },
	{ "id": "chocolate", "name": "Rizko Chocolate (120g)", "flavor": "Chocolate", "color": "391b10", "fx": 123, "fe": 162, "bx": 169, "be": 196, "sx": 203, "se": 217, "ys": 35, "ye": 273 },
	{ "id": "vainilla", "name": "Rizko Vainilla (120g)", "flavor": "Vainilla", "color": "ded1b1", "fx": 235, "fe": 273, "bx": 278, "be": 306, "sx": 313, "se": 328, "ys": 35, "ye": 273 },
	{ "id": "fresa", "name": "Rizko Fresa (120g)", "flavor": "Fresa", "color": "ba121c", "fx": 343, "fe": 383, "bx": 388, "be": 418, "sx": 426, "se": 442, "ys": 35, "ye": 273 },
	{ "id": "crema", "name": "Rizko Crema (120g)", "flavor": "Crema", "color": "191817", "fx": 462, "fe": 498, "bx": 506, "be": 533, "sx": 541, "se": 555, "ys": 35, "ye": 273 },
	{ "id": "limon", "name": "Rizko Limón (120g)", "flavor": "Limón", "color": "1f8e28", "fx": 573, "fe": 612, "bx": 618, "be": 644, "sx": 651, "se": 666, "ys": 35, "ye": 273 },
	{ "id": "arandano", "name": "Rizko Arándano (120g)", "flavor": "Arándano", "color": "5a2777", "fx": 686, "fe": 725, "bx": 732, "be": 762, "sx": 768, "se": 784, "ys": 35, "ye": 273 },
	{ "id": "naranja", "name": "Rizko Naranja (120g)", "flavor": "Naranja", "color": "d45e14", "fx": 803, "fe": 841, "bx": 846, "be": 875, "sx": 880, "se": 896, "ys": 35, "ye": 273 },
	{ "id": "frutos_rojos", "name": "Rizko Frutos Rojos (120g)", "flavor": "Frutos Rojos", "color": "c11a56", "fx": 918, "fe": 957, "bx": 962, "be": 989, "sx": 994, "se": 1010, "ys": 35, "ye": 273 },

	# Fila 1: ys=345, ye=588
	{ "id": "platano", "name": "Rizko Plátano (120g)", "flavor": "Plátano", "color": "e19c11", "fx": 12, "fe": 50, "bx": 55, "be": 85, "sx": 90, "se": 106, "ys": 345, "ye": 588 },
	{ "id": "chispas", "name": "Rizko Chispas (120g)", "flavor": "Chispas", "color": "0b8c9c", "fx": 127, "fe": 164, "bx": 169, "be": 197, "sx": 202, "se": 218, "ys": 345, "ye": 588 },
	{ "id": "integrales", "name": "Rizko Integrales (120g)", "flavor": "Integrales", "color": "193d7c", "fx": 235, "fe": 272, "bx": 279, "be": 307, "sx": 314, "se": 328, "ys": 345, "ye": 588 },
	{ "id": "doble_choco", "name": "Rizko Doble Chocolate (120g)", "flavor": "Doble Chocolate", "color": "dfd5cb", "fx": 346, "fe": 383, "bx": 388, "be": 419, "sx": 424, "se": 440, "ys": 345, "ye": 588 },
	{ "id": "menta", "name": "Rizko Menta (120g)", "flavor": "Menta", "color": "399478", "fx": 459, "fe": 497, "bx": 502, "be": 531, "sx": 537, "se": 552, "ys": 345, "ye": 588 },
	{ "id": "canela", "name": "Rizko Canela (120g)", "flavor": "Canela", "color": "b5221b", "fx": 572, "fe": 609, "bx": 615, "be": 644, "sx": 650, "se": 666, "ys": 345, "ye": 588 },
	{ "id": "avena", "name": "Rizko Avena (120g)", "flavor": "Avena", "color": "82659e", "fx": 684, "fe": 723, "bx": 729, "be": 759, "sx": 765, "se": 781, "ys": 345, "ye": 588 },
	{ "id": "festival", "name": "Rizko Festival (120g)", "flavor": "Festival", "color": "282627", "fx": 802, "fe": 838, "bx": 845, "be": 873, "sx": 880, "se": 894, "ys": 345, "ye": 588 },
	{ "id": "cookies_cream", "name": "Rizko Cookies & Cream (120g)", "flavor": "Cookies & Cream", "color": "379ad9", "fx": 915, "fe": 953, "bx": 959, "be": 987, "sx": 992, "se": 1008, "ys": 345, "ye": 588 }
]

## Retorna los metadatos completos de un paquete de galletas por ID o índice
static func get_cookie_pack_data(cookie_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if cookie_key_or_idx is int or cookie_key_or_idx is float:
		var idx := clampi(int(cookie_key_or_idx), 0, COOKIE_PACK_DATA.size() - 1)
		return COOKIE_PACK_DATA[idx]
	var s := str(cookie_key_or_idx).strip_edges().to_lower()
	if s.is_valid_int():
		var idx := clampi(s.to_int(), 0, COOKIE_PACK_DATA.size() - 1)
		return COOKIE_PACK_DATA[idx]
	s = s.replace("cookie_", "").replace("galleta_", "").replace("rizko_", "").replace("pack_", "")
	for d in COOKIE_PACK_DATA:
		if d["id"] == s:
			return d
	# Aliases semánticos de sabores
	var aliases := {
		"clasica": "clasicas",
		"classic": "clasicas",
		"choco": "chocolate",
		"vanilla": "vainilla",
		"strawberry": "fresa",
		"cream": "crema",
		"sandwich": "crema",
		"lemon": "limon",
		"lime": "limon",
		"blueberry": "arandano",
		"moras": "arandano",
		"mora": "arandano",
		"orange": "naranja",
		"citrico": "naranja",
		"berries": "frutos_rojos",
		"frambuesa": "frutos_rojos",
		"banana": "platano",
		"chips": "chispas",
		"chocochips": "chispas",
		"wheat": "integrales",
		"integral": "integrales",
		"doble": "doble_choco",
		"double_chocolate": "doble_choco",
		"mint": "menta",
		"cinnamon": "canela",
		"oat": "avena",
		"oatmeal": "avena",
		"confetti": "festival",
		"chispitas": "festival",
		"cookies_and_cream": "cookies_cream",
		"oreo": "cookies_cream"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in COOKIE_PACK_DATA:
			if d["id"] == target_id:
				return d
	for d in COOKIE_PACK_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d
	return COOKIE_PACK_DATA[0]


## Catálogo canónico de las 20 Bolsas de Papitas / Sabritas (snack_bags_atlas.png)
const SNACK_BAG_NAMES: Array[String] = [
	# Fila 0:
	"tostiks",
	"crujitos",
	"rizitas",
	"chispas",
	"puffys",
	# Fila 1:
	"krachitos",
	"fuegorix",
	"maizmax",
	"bolitas",
	"ondulin",
	# Fila 2:
	"crokis",
	"papasol",
	"rinrin",
	"crujix",
	"megapik",
	# Fila 3:
	"saladitas",
	"paprizas",
	"chipan",
	"gomitas",
	"verdix"
]

const SNACK_BAG_DATA: Array[Dictionary] = [
	# Fila 0: ys=12, ye=173
	{ "id": "tostiks",   "name": "Tostik's Original (60g)", "type": "Totopos", "color": "c6131c", "fx": 19, "fe": 168, "sx": 169, "se": 200, "ys": 12, "ye": 173 },
	{ "id": "crujitos",  "name": "Crujitos Queso (60g)", "type": "Queso", "color": "ebaa11", "fx": 224, "fe": 369, "sx": 370, "se": 397, "ys": 12, "ye": 173 },
	{ "id": "rizitas",   "name": "Rizitas Crema y Cebolla (60g)", "type": "Papas", "color": "259247", "fx": 424, "fe": 569, "sx": 570, "se": 598, "ys": 12, "ye": 173 },
	{ "id": "chispas",   "name": "Chispas Picante (60g)", "type": "Picante", "color": "d44c15", "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 12, "ye": 173 },
	{ "id": "puffys",    "name": "Puffys BBQ (60g)", "type": "Aros", "color": "60238e", "fx": 825, "fe": 972, "sx": 973, "se": 1004, "ys": 12, "ye": 173 },

	# Fila 1: ys=183, ye=338
	{ "id": "krachitos", "name": "Krachitos Sal Marina (60g)", "type": "Papas", "color": "105eb0", "fx": 19, "fe": 168, "sx": 169, "se": 199, "ys": 183, "ye": 338 },
	{ "id": "fuegorix",  "name": "FuegoRix Extra Picante (60g)", "type": "Rollitos", "color": "1c191a", "fx": 225, "fe": 370, "sx": 371, "se": 397, "ys": 183, "ye": 338 },
	{ "id": "maizmax",   "name": "MaízMax Natural (60g)", "type": "Totopos", "color": "ded5b8", "fx": 425, "fe": 568, "sx": 569, "se": 597, "ys": 183, "ye": 338 },
	{ "id": "bolitas",   "name": "Bolitas Queso (60g)", "type": "Queso", "color": "ba1f22", "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 183, "ye": 338 },
	{ "id": "ondulin",   "name": "Ondulín Vinagreta (60g)", "type": "Papas", "color": "17949a", "fx": 825, "fe": 971, "sx": 972, "se": 1004, "ys": 183, "ye": 338 },

	# Fila 2: ys=347, ye=504
	{ "id": "crokis",    "name": "Crokis Barbacoa (60g)", "type": "Aros", "color": "d44b15", "fx": 19, "fe": 167, "sx": 168, "se": 200, "ys": 347, "ye": 504 },
	{ "id": "papasol",   "name": "Papasol Limón y Sal (60g)", "type": "Papas", "color": "449c2a", "fx": 225, "fe": 368, "sx": 369, "se": 398, "ys": 347, "ye": 504 },
	{ "id": "rinrin",    "name": "RinRin Jamón (60g)", "type": "Jamón", "color": "652485", "fx": 425, "fe": 569, "sx": 570, "se": 599, "ys": 347, "ye": 504 },
	{ "id": "crujix",    "name": "Crujix Carnitas (60g)", "type": "Carnitas", "color": "177bba", "fx": 625, "fe": 768, "sx": 769, "se": 800, "ys": 347, "ye": 504 },
	{ "id": "megapik",   "name": "MegaPik Queso Intenso (60g)", "type": "Totopos", "color": "242223", "fx": 826, "fe": 971, "sx": 972, "se": 1003, "ys": 347, "ye": 504 },

	# Fila 3: ys=515, ye=668
	{ "id": "saladitas", "name": "Saladitas Clásicas (60g)", "type": "Galletas", "color": "0d54a2", "fx": 19, "fe": 168, "sx": 169, "se": 199, "ys": 515, "ye": 668 },
	{ "id": "paprizas",  "name": "Paprizas Jalapeño (60g)", "type": "Totopos", "color": "b91f24", "fx": 224, "fe": 368, "sx": 369, "se": 398, "ys": 515, "ye": 668 },
	{ "id": "chipan",    "name": "Chipán Tocino (60g)", "type": "Tocino", "color": "ccb18f", "fx": 426, "fe": 568, "sx": 569, "se": 599, "ys": 515, "ye": 668 },
	{ "id": "gomitas",   "name": "Gomitas Frutas (60g)", "type": "Gomitas", "color": "c8307b", "fx": 626, "fe": 768, "sx": 769, "se": 800, "ys": 515, "ye": 668 },
	{ "id": "verdix",    "name": "Verdix Vegetales (60g)", "type": "Vegetales", "color": "276b39", "fx": 826, "fe": 970, "sx": 971, "se": 1001, "ys": 515, "ye": 668 }
]

## Retorna los metadatos completos de una bolsa de papitas / botanas por ID o índice
static func get_snack_bag_data(snack_key_or_idx: Variant) -> Dictionary:
	ensure_initialized()
	if snack_key_or_idx is int or snack_key_or_idx is float:
		var idx := clampi(int(snack_key_or_idx), 0, SNACK_BAG_DATA.size() - 1)
		return SNACK_BAG_DATA[idx]
	var s := str(snack_key_or_idx).strip_edges().to_lower()
	if s.is_valid_int():
		var idx := clampi(s.to_int(), 0, SNACK_BAG_DATA.size() - 1)
		return SNACK_BAG_DATA[idx]
	s = s.replace("snack_", "").replace("sabrita_", "").replace("papa_", "").replace("papita_", "").replace("botana_", "").replace("bolsa_", "")
	for d in SNACK_BAG_DATA:
		if d["id"] == s:
			return d
	# Aliases semánticos y de marcas equivalentes
	var aliases := {
		"doritos": "tostiks",
		"tostitos": "tostiks",
		"cheetos": "crujitos",
		"ruffles": "rizitas",
		"crema_cebolla": "rizitas",
		"sabritones": "chispas",
		"takis": "fuegorix",
		"fuego": "fuegorix",
		"lay": "krachitos",
		"lays": "krachitos",
		"chips": "papasol",
		"rancheritos": "crokis",
		"chicharron": "crujix",
		"chicharrones": "crujix",
		"carnitas": "crujix",
		"panditas": "gomitas",
		"gummy": "gomitas",
		"crackers": "saladitas",
		"galletitas": "saladitas",
		"veggie": "verdix",
		"bacon": "chipan",
		"tocino": "chipan",
		"jalapeno": "paprizas"
	}
	if aliases.has(s):
		var target_id: String = aliases[s]
		for d in SNACK_BAG_DATA:
			if d["id"] == target_id:
				return d
	for d in SNACK_BAG_DATA:
		if s in d["id"] or d["id"] in s or s in d["name"].to_lower():
			return d
	return SNACK_BAG_DATA[0]

## Retorna la sub-región UV exacta para una de las 16 telas de sofá (por ID 0..15 o por nombre)
static func get_sofa_fabric_region(fabric_key_or_id: Variant) -> Rect2:
	if fabric_key_or_id is int or fabric_key_or_id is float:
		var idx := clampi(int(fabric_key_or_id), 0, 15)
		var col := idx % 4
		var row := idx / 4
		return Rect2(float(col) * 0.25, float(row) * 0.25, 0.25, 0.25)
	var s := str(fabric_key_or_id).to_lower()
	var found_idx := SOFA_FABRIC_NAMES.find(s)
	if found_idx >= 0:
		var col := found_idx % 4
		var row := found_idx / 4
		return Rect2(float(col) * 0.25, float(row) * 0.25, 0.25, 0.25)
	if has_region("sofa_fabrics_atlas", s):
		return get_region("sofa_fabrics_atlas", s)
	return Rect2(0.0, 0.0, 0.25, 0.25)


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

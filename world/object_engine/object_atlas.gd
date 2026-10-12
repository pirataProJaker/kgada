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
		"damask": { "rect": Rect2(0.461, 0.461, 0.359, 0.523), "roughness": 0.65, "metallic": 0.05, "desc": "Brocado de damasco floral dorado refinado" },
		"trim_gold": { "rect": Rect2(0.883, 0.391, 0.109, 0.547), "roughness": 0.40, "metallic": 0.30, "desc": "Moldura perimetral barroca dorada tallada" },
		"satin_base": { "rect": Rect2(0.016, 0.367, 0.219, 0.617), "roughness": 0.65, "metallic": 0.05, "desc": "Satén para base y laterales" },
		"wood_leg": { "rect": Rect2(0.312, 0.117, 0.117, 0.234), "roughness": 0.40, "metallic": 0.30, "desc": "Pata tallada dorada" }
	},
	"armchair_06": {
		"floral": { "rect": Rect2(0.609, 0.438, 0.188, 0.547), "roughness": 0.65, "metallic": 0.01, "desc": "Estampado floral cottage estilo provenzal" },
		"cushion": { "rect": Rect2(0.609, 0.438, 0.188, 0.547), "roughness": 0.65, "metallic": 0.01, "desc": "Cojín acolchado floral" },
		"wood_base": { "rect": Rect2(0.016, 0.453, 0.195, 0.531), "roughness": 0.60, "metallic": 0.02, "desc": "Zócalo base de madera oscura tallada" },
		"wood_leg": { "rect": Rect2(0.016, 0.453, 0.195, 0.531), "roughness": 0.60, "metallic": 0.02, "desc": "Patas de madera oscura" },
		"arm_roll": { "rect": Rect2(0.430, 0.438, 0.070, 0.547), "roughness": 0.65, "metallic": 0.01, "desc": "Rollo de reposabrazos floral" }
	},
	"armchair_07": {
		"cushion": { "rect": Rect2(0.781, 0.516, 0.195, 0.469), "roughness": 0.70, "metallic": 0.01, "desc": "Tapizado de lino marfil texturizado" },
		"fabric_linen": { "rect": Rect2(0.781, 0.516, 0.195, 0.469), "roughness": 0.70, "metallic": 0.01, "desc": "Lino marfil de asiento y respaldo" },
		"wood_frame": { "rect": Rect2(0.078, 0.492, 0.344, 0.492), "roughness": 0.60, "metallic": 0.02, "desc": "Estructura vista de madera de roble claro" },
		"wood_back": { "rect": Rect2(0.547, 0.508, 0.195, 0.477), "roughness": 0.60, "metallic": 0.02, "desc": "Tablero trasero de roble" },
		"wood_leg": { "rect": Rect2(0.078, 0.492, 0.150, 0.492), "roughness": 0.60, "metallic": 0.02, "desc": "Patas cuadradas de roble" }
	},
	"armchair_03": {
		"cushion": { "rect": Rect2(0.242, 0.297, 0.258, 0.305), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero granate suave para cojín de asiento" },
		"tufted_back": { "rect": Rect2(0.750, 0.760, 0.133, 0.225), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero capitoné con botones en rombo" },
		"arm_scroll": { "rect": Rect2(0.008, 0.227, 0.219, 0.375), "roughness": 0.45, "metallic": 0.08, "desc": "Brazo curvo enrollado Chesterfield" },
		"smooth_leather": { "rect": Rect2(0.516, 0.391, 0.188, 0.219), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero granate liso para cuerpo y laterales" },
		"bun_foot": { "rect": Rect2(0.352, 0.195, 0.078, 0.094), "roughness": 0.50, "metallic": 0.05, "desc": "Pata redonda de madera oscura torneada" },
		"wood_leg": { "rect": Rect2(0.352, 0.195, 0.078, 0.094), "roughness": 0.50, "metallic": 0.05, "desc": "Pata redonda torneada" }
	},
	"armchair_04": {
		"cushion": { "rect": Rect2(0.016, 0.258, 0.180, 0.195), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero marrón cognac suave para asiento" },
		"tufted_back": { "rect": Rect2(0.211, 0.234, 0.188, 0.219), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero cognac capitoné" },
		"arm_scroll": { "rect": Rect2(0.641, 0.461, 0.188, 0.516), "roughness": 0.45, "metallic": 0.08, "desc": "Brazo enrollado en espiral" },
		"smooth_leather": { "rect": Rect2(0.453, 0.508, 0.172, 0.477), "roughness": 0.45, "metallic": 0.08, "desc": "Cuero cognac liso para cuerpo y laterales" },
		"bun_foot": { "rect": Rect2(0.080, 0.080, 0.060, 0.080), "roughness": 0.50, "metallic": 0.05, "desc": "Pata torneada" },
		"wood_leg": { "rect": Rect2(0.080, 0.080, 0.060, 0.080), "roughness": 0.50, "metallic": 0.05, "desc": "Pata torneada" }
	},
	"armchair": {
		"tufted_back": { "rect": Rect2(0.024, 0.328, 0.280, 0.250), "roughness": 0.50, "metallic": 0.08, "desc": "Respaldo capitoné central sin esquinas negras" },
		"cushion": { "rect": Rect2(0.016, 0.594, 0.296, 0.390), "roughness": 0.45, "metallic": 0.08, "desc": "Cojín de cuero grueso envejecido" },
		"arm_scroll": { "rect": Rect2(0.712, 0.140, 0.108, 0.230), "roughness": 0.45, "metallic": 0.08, "desc": "Frontal de reposabrazos con tachuelas sin bordes negros" },
		"arm_roll": { "rect": Rect2(0.712, 0.140, 0.108, 0.230), "roughness": 0.45, "metallic": 0.08, "desc": "Frontal de reposabrazos sin bordes negros" },
		"smooth_leather": { "rect": Rect2(0.641, 0.438, 0.344, 0.234), "roughness": 0.50, "metallic": 0.08, "desc": "Cuero marrón liso para cuerpo y respaldo" },
		"wood_leg": { "rect": Rect2(0.094, 0.118, 0.125, 0.136), "roughness": 0.55, "metallic": 0.02, "desc": "Patas cónicas de madera oscura" }
	},
	"armchair_01": {
		"tufted_back": { "rect": Rect2(0.672, 0.734, 0.242, 0.242), "roughness": 0.60, "metallic": 0.02, "desc": "Respaldo capitoné gris marengo puro sin bordes negros" },
		"cushion": { "rect": Rect2(0.656, 0.047, 0.297, 0.258), "roughness": 0.55, "metallic": 0.02, "desc": "Cojín suave gris marengo" },
		"studded_arm": { "rect": Rect2(0.738, 0.352, 0.095, 0.250), "roughness": 0.40, "metallic": 0.20, "desc": "Línea de tachuelas plateadas sin borde negro" },
		"smooth_fabric": { "rect": Rect2(0.039, 0.293, 0.273, 0.684), "roughness": 0.60, "metallic": 0.02, "desc": "Tela marengo para cuerpo, laterales y respaldo" },
		"arm": { "rect": Rect2(0.039, 0.293, 0.273, 0.684), "roughness": 0.60, "metallic": 0.02, "desc": "Laterales acolchados" },
		"wood_leg": { "rect": Rect2(0.391, 0.109, 0.102, 0.125), "roughness": 0.55, "metallic": 0.02, "desc": "Patas cónicas de madera" }
	},
	"armchair_02": {
		"tufted_back": { "rect": Rect2(0.672, 0.740, 0.230, 0.220), "roughness": 0.55, "metallic": 0.05, "desc": "Respaldo capitoné azul cielo puro sin bordes negros" },
		"cushion": { "rect": Rect2(0.656, 0.047, 0.297, 0.258), "roughness": 0.50, "metallic": 0.05, "desc": "Cojín azul cielo pastel" },
		"studded_arm": { "rect": Rect2(0.735, 0.352, 0.095, 0.250), "roughness": 0.40, "metallic": 0.20, "desc": "Línea de tachuelas plateadas sin borde negro" },
		"smooth_fabric": { "rect": Rect2(0.039, 0.260, 0.273, 0.720), "roughness": 0.55, "metallic": 0.05, "desc": "Tela azul cielo para cuerpo y respaldo" },
		"arm": { "rect": Rect2(0.039, 0.260, 0.273, 0.720), "roughness": 0.55, "metallic": 0.05, "desc": "Laterales acolchados" },
		"wood_leg": { "rect": Rect2(0.391, 0.109, 0.102, 0.125), "roughness": 0.55, "metallic": 0.02, "desc": "Patas cónicas de madera" }
	},
	"armchair_05": {
		"tufted_back": { "rect": Rect2(0.020, 0.290, 0.250, 0.230), "roughness": 0.70, "metallic": 0.02, "desc": "Respaldo capitoné terciopelo mostaza puro" },
		"cushion": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.70, "metallic": 0.02, "desc": "Terciopelo mostaza puro continuo sin recortes" },
		"arm_side": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.70, "metallic": 0.02, "desc": "Terciopelo mostaza puro para laterales y brazos" },
		"arm": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.70, "metallic": 0.02, "desc": "Brazos de terciopelo" },
		"smooth_velvet": { "rect": Rect2(0.040, 0.620, 0.550, 0.350), "roughness": 0.70, "metallic": 0.02, "desc": "Terciopelo liso amarillo" },
		"wood_leg": { "rect": Rect2(0.289, 0.258, 0.100, 0.100), "roughness": 0.55, "metallic": 0.02, "desc": "Patas de madera oscura" }
	},
	"chair": {
		"toile_back": { "rect": Rect2(0.380, 0.770, 0.120, 0.180), "roughness": 0.60, "metallic": 0.02, "desc": "Tela Toile de Jouy azul pura para medallón sin esquinas negras" },
		"toile_seat": { "rect": Rect2(0.530, 0.770, 0.210, 0.210), "roughness": 0.60, "metallic": 0.02, "desc": "Asiento acolchado Toile de Jouy azul" },
		"carved_wood": { "rect": Rect2(0.098, 0.801, 0.078, 0.156), "roughness": 0.55, "metallic": 0.05, "desc": "Madera tallada estilo Luis XV pura sin esquinas negras" },
		"wood_leg": { "rect": Rect2(0.098, 0.801, 0.078, 0.156), "roughness": 0.55, "metallic": 0.05, "desc": "Pata cabriolé tallada" },
		"arm_pad": { "rect": Rect2(0.760, 0.770, 0.065, 0.210), "roughness": 0.60, "metallic": 0.02, "desc": "Codera acolchada azul" }
	},
	"chair_01": {
		"damask_back": { "rect": Rect2(0.330, 0.670, 0.180, 0.280), "roughness": 0.55, "metallic": 0.05, "desc": "Tela brocada crema/dorada pura para medallón sin esquinas negras" },
		"damask_seat": { "rect": Rect2(0.620, 0.290, 0.250, 0.260), "roughness": 0.55, "metallic": 0.05, "desc": "Asiento adamascado" },
		"carved_wood": { "rect": Rect2(0.078, 0.664, 0.117, 0.176), "roughness": 0.50, "metallic": 0.05, "desc": "Madera dorada tallada pura sin esquinas negras" },
		"wood_leg": { "rect": Rect2(0.078, 0.664, 0.117, 0.176), "roughness": 0.50, "metallic": 0.05, "desc": "Patas doradas talladas" }
	},
	"chair_02": {
		"polka_seat": { "rect": Rect2(0.620, 0.400, 0.260, 0.260), "roughness": 0.60, "metallic": 0.02, "desc": "Tapizado de lunares / jacquard crema para asiento" },
		"polka_back": { "rect": Rect2(0.045, 0.660, 0.210, 0.300), "roughness": 0.60, "metallic": 0.02, "desc": "Respaldo tapizado crema con marco de caoba" },
		"wood_frame": { "rect": Rect2(0.620, 0.690, 0.280, 0.300), "roughness": 0.55, "metallic": 0.02, "desc": "Madera de caoba pulida para marco y faldón" },
		"wood_leg": { "rect": Rect2(0.620, 0.690, 0.100, 0.300), "roughness": 0.55, "metallic": 0.02, "desc": "Patas cuadradas de caoba" }
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
		"display": { "rect": Rect2(0.0, 0.0, 0.5, 0.5), "roughness": 0.20, "metallic": 0.20, "desc": "Display LED digital verde" },
		"case": { "rect": Rect2(0.0, 0.5, 0.5, 0.5), "roughness": 0.45, "metallic": 0.10, "desc": "Carcasa plástica negra" }
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
	_scan_folders_for_json_regions("res://assets/textures/furniture 2.0/")
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

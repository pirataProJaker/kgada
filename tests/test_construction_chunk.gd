extends Node3D

const STICK_RES = preload("res://content/building/stick_tool.tres")
const STAKE_RES = preload("res://content/building/stake_rope_tool.tres")
const BLUEPRINT_RES = preload("res://content/building/blueprint_tool.tres")
const WOOD_RES = preload("res://content/building/wood_material.tres")
const STONE_RES = preload("res://content/building/stone_material.tres")
const PROCEDURAL_TREE_SCRIPT = preload("res://world/procedural_trees/procedural_tree.gd")

@onready var player: CharacterBody3D = $Player
@onready var help_label: Label = $CanvasLayer/HelpPanel/MarginContainer/VBoxContainer/HelpText

func _ready() -> void:
	# 1. Asegurar ConstructionEngine en la escena
	var engine = get_node_or_null("ConstructionEngine")
	if engine == null and ClassDB.class_exists("ConstructionEngine"):
		engine = ClassDB.instantiate("ConstructionEngine")
		add_child(engine)
		print("[TestConstructionChunk] ConstructionEngine (Rust) inicializado.")

	# 2. Desbloquear recetas para la prueba
	BuildingManager.unlock_book("book_masonry_volume_1")
	BuildingManager.unlock_book("book_architecture_brickwork")
	BuildingManager.unlock_book("book_carpentry_advanced")

	# 3. Equipar herramientas y materiales al jugador
	if player:
		var inv: Inventory = player.get_node_or_null("Inventory")
		if inv:
			inv.set_slot(0, STICK_RES, 1)
			inv.set_slot(1, STAKE_RES, 1)
			inv.set_slot(2, BLUEPRINT_RES, 1)
			inv.set_slot(3, WOOD_RES, 64)
			inv.set_slot(4, STONE_RES, 64)
			inv.select_hotbar_slot(0)
			print("[TestConstructionChunk] Herramientas equipadas en slots 1-3 y Materiales (Madera/Piedra) en slots 4-5.")

	if help_label:
		help_label.text = "• Teclas [1], [2], [3]: Palo (Rasca tierra) / Estacas / Cal
• Teclas [4], [5]: Madera / Piedra de Construcción
• [Clic Izq con Palo]: P0 -> Mover -> P1 (Rasca la orilla de tierra, no pone piso)
• [Clic Izq con Madera/Piedra]: Clic en el trazado de tierra -> ¡Edifica el piso!
• [Clic Der]: Rueda radial / Cancelar punto
• [WASD + Ratón]: Moverse / Mirar libremente"

	# 4. Generar árboles de ambientación en las esquinas respetando AGENTS.md (ProceduralTree)
	_spawn_procedural_trees()

	# 5. Generar tramo de pared estándar con marco de puerta en (0, 0, -4)
	# para enmarcar la puerta interactiva de madera (1.30m ancho x 2.10m alto).
	if engine:
		var p0 := Vector3(-2.5, 0.0, -4.0)
		var p1 := Vector3(2.5, 0.0, -4.0)
		var door_openings: Array[Dictionary] = [
			{
				"type": 3,
				"t_min": 1.85, # Centrada en t=2.50, ancho=1.30m, alto=2.10m
				"t_max": 3.15,
				"y_bottom": 0.0,
				"y_top": 2.10
			}
		]
		engine.call("add_wall_span_with_openings", p0, p1, 3.0, 0, door_openings)

	print("[TestConstructionChunk] Escena de prueba de 1 Chunk lista para construir.")

func _spawn_procedural_trees() -> void:
	var tree_container := Node3D.new()
	tree_container.name = "Vegetation"
	add_child(tree_container)

	var tree_spawns := [
		{"pos": Vector3(-16, 0, -16), "profile": "classic_oak", "seed": 101},
		{"pos": Vector3(16, 0, -16), "profile": "pine_boreal", "seed": 202},
		{"pos": Vector3(-16, 0, 16), "profile": "autumn_birch", "seed": 303},
		{"pos": Vector3(16, 0, 16), "profile": "weeping_willow", "seed": 404}
	]

	for data in tree_spawns:
		var tree = PROCEDURAL_TREE_SCRIPT.new()
		tree.profile_id = data["profile"]
		tree.tree_seed = data["seed"]
		tree_container.add_child(tree)
		tree.global_position = data["pos"]

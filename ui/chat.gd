extends CanvasLayer
## Chat en-juego estilo Minecraft: se abre con T, los mensajes se
## desvanecen solos 5s despues de escribirse (si el chat esta cerrado); al
## abrirlo se ve el historial completo sin desvanecer. Autocompletado: "/"
## sugiere los comandos disponibles, y "/give <parcial>" sugiere objetos
## reales de ObjectRegistry - nada hardcodeado, un objeto/comando nuevo
## aparece solo.
##
## Comandos disponibles: "/give <objeto>" agrega CUALQUIER objeto que
## exista en ObjectRegistry al inventario del jugador local; "/summon
## <entidad>" invoca esa entidad (ver content/entity_types.gd) justo frente
## al jugador local; "/kill" elimina y reaparece al jugador local.

const MESSAGE_LIFETIME := 5.0
const COMMANDS := ["give", "summon", "kill"]

@onready var panel: Control = $Panel
@onready var log_background: ColorRect = $Panel/LogBackground
@onready var log_label: RichTextLabel = $Panel/Log
@onready var input_line: LineEdit = $Panel/Input
@onready var suggestions_list: ItemList = $Panel/Suggestions
@onready var fade_timer: Timer = $FadeTimer

var _is_open := false
var _messages: Array = [] # {text: String, time: float}
var _current_suggestions: Array = []
var _tab_cycle_index := -1
var _suppress_text_changed := false


func _ready() -> void:
	panel.visible = false
	log_background.visible = false
	suggestions_list.visible = false
	input_line.text_submitted.connect(_on_submitted)
	input_line.text_changed.connect(_on_text_changed)
	input_line.gui_input.connect(_on_input_gui_event)
	suggestions_list.item_selected.connect(_on_suggestion_selected)
	fade_timer.timeout.connect(_refresh_visible_messages)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_T and not _is_open:
		if get_tree().get_nodes_in_group("local_player").is_empty():
			return # sin jugador local (ej. estamos en un menu) - no abrir el chat
		_open()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _is_open:
		_close()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_is_open = true
	panel.visible = true
	log_background.visible = true
	input_line.text = ""
	input_line.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_visible_messages()


func _close() -> void:
	_is_open = false
	panel.visible = false
	log_background.visible = false
	suggestions_list.visible = false
	input_line.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_refresh_visible_messages()


func _on_submitted(text: String) -> void:
	_close()
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return

	_log(trimmed)
	if trimmed.begins_with("/"):
		_run_command(trimmed.substr(1))


func _run_command(command_text: String) -> void:
	var parts := command_text.split(" ", false)
	if parts.is_empty():
		return

	var command_name: String = parts[0].to_lower()
	var args := parts.slice(1)

	match command_name:
		"give":
			_cmd_give(args)
		"summon":
			_cmd_summon(args)
		"kill":
			_cmd_kill(args)
		_:
			_log("[color=orange]Comando desconocido: /%s[/color]" % command_name)


func _cmd_kill(args: PackedStringArray) -> void:
	if not args.is_empty():
		_log("[color=orange]Uso: /kill[/color]")
		return

	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty():
		_log("[color=red]No hay un jugador local activo para eliminar.[/color]")
		return

	var player: Node = players[0]
	if not player.has_method("kill"):
		_log("[color=red]El jugador activo no admite /kill.[/color]")
		return

	player.kill()
	_log("[color=red]Te has eliminado. Has reaparecido en el punto inicial.[/color]")


func _cmd_give(args: PackedStringArray) -> void:
	if args.is_empty():
		_log("[color=orange]Uso: /give <objeto> o /give egg:<entidad>[/color]")
		return

	var query := " ".join(args)

	if query.to_lower().begins_with("egg:"):
		_cmd_give_egg(query.substr(4))
		return

	var definition: ObjectDefinition = ObjectRegistry.find(query)
	if definition == null:
		_log("[color=red]No existe ningun objeto llamado '%s'.[/color]" % query)
		return

	var inventories := get_tree().get_nodes_in_group("local_inventory")
	if inventories.is_empty():
		_log("[color=red]No hay un jugador activo para recibir el objeto.[/color]")
		return

	inventories[0].add_item(definition, 1)
	_log("[color=green]+1 %s agregado a tu inventario.[/color]" % definition.display_name)


## "Huevo de invocacion" (estilo Minecraft): un item que se sostiene y se ve
## como la entidad real (usa la escena visual de EntityTypes), y al
## colocarlo con click (PlacementController) invoca la entidad de verdad en
## vez de un objeto estatico. No pasa por ObjectRegistry - se arma en
## memoria porque no necesita guardarse como .tres, cualquier entidad
## registrada en EntityTypes ya funciona sola.
func _cmd_give_egg(entity_query: String) -> void:
	var key := EntityTypes.find_key(entity_query)
	if key.is_empty():
		_log("[color=red]No existe ninguna entidad llamada '%s'.[/color]" % entity_query)
		return

	var inventories := get_tree().get_nodes_in_group("local_inventory")
	if inventories.is_empty():
		_log("[color=red]No hay un jugador activo para recibir el objeto.[/color]")
		return

	var entity_data: Dictionary = EntityTypes.TYPES[key]
	var egg := SpawnEggDefinition.new()
	egg.id = "egg:" + key
	egg.display_name = "Huevo de " + entity_data["display_name"]
	egg.model_path = entity_data["visual_scene"]
	egg.entity_key = key

	inventories[0].add_item(egg, 1)
	_log("[color=green]+1 %s agregado a tu inventario.[/color]" % egg.display_name)


func _cmd_summon(args: PackedStringArray) -> void:
	if args.is_empty():
		_log("[color=orange]Uso: /summon <entidad>[/color]")
		return

	var query := " ".join(args)
	var key := EntityTypes.find_key(query)
	if key.is_empty():
		_log("[color=red]No existe ninguna entidad llamada '%s'.[/color]" % query)
		return

	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty():
		_log("[color=red]No hay un jugador activo para invocar la entidad.[/color]")
		return

	var scene: PackedScene = load(EntityTypes.TYPES[key]["scene"])
	if scene == null:
		_log("[color=red]No se pudo cargar la escena de '%s'.[/color]" % key)
		return

	var player: Node3D = players[0]
	# Frente al jugador (segun hacia donde mira), un poco separado para no
	# aparecer encimado con el.
	var forward_pos: Vector3 = player.global_position - player.global_transform.basis.z * 2.0
	# El terreno del juego no es plano (hay pendientes/montañas) - sin este
	# ajuste la entidad podia aparecer flotando en el aire o incrustada bajo
	# el suelo segun la inclinacion, y terminaba invisible/cayendose fuera de
	# vista. Se lanza un rayo hacia abajo desde bien arriba para pararla
	# justo sobre la superficie real, igual que hace el spawn del jugador.
	var spawn_pos := _snap_to_ground(forward_pos, player.global_position)

	var instance: Node3D = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_pos
	_log("[color=green]%s invocado en (%.1f, %.1f, %.1f).[/color]" % [key, spawn_pos.x, spawn_pos.y, spawn_pos.z])


## Lanza un rayo hacia abajo desde bien arriba de `pos` para encontrar el
## suelo real y parar la entidad justo encima. Si no encuentra nada (fuera
## del terreno cargado), cae de vuelta a la posicion del jugador para no
## dejar la entidad en el vacio.
func _snap_to_ground(pos: Vector3, fallback: Vector3) -> Vector3:
	var space_state := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, pos.y + 50.0, pos.z), Vector3(pos.x, pos.y - 50.0, pos.z)
	)
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return (result["position"] as Vector3) + Vector3(0.0, 0.1, 0.0)
	return fallback


func _log(text: String) -> void:
	_messages.append({"text": text, "time": Time.get_ticks_msec() / 1000.0})
	_refresh_visible_messages()


## Mientras el chat esta cerrado solo se muestran mensajes de los ultimos
## MESSAGE_LIFETIME segundos (estilo Minecraft); abierto, se ve todo el
## historial sin desvanecer.
func _refresh_visible_messages() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	log_label.clear()
	var any_visible := false
	for entry in _messages:
		if _is_open or (now - entry.time) < MESSAGE_LIFETIME:
			log_label.append_text(entry.text + "\n")
			any_visible = true
	log_label.visible = any_visible


func _on_text_changed(new_text: String) -> void:
	if _suppress_text_changed:
		return
	_tab_cycle_index = -1
	_update_suggestions(new_text)


## Arma la lista de autocompletado: si todavia se esta escribiendo el
## nombre del comando ("/gi..."), sugiere comandos; si ya hay un espacio
## ("/give cof..."), sugiere objetos reales que existen en ObjectRegistry.
func _update_suggestions(text: String) -> void:
	suggestions_list.clear()
	_current_suggestions.clear()
	suggestions_list.visible = false

	if not text.begins_with("/"):
		return

	var body := text.substr(1)

	if not text.contains(" "):
		var matches: Array = []
		for cmd in COMMANDS:
			if cmd.begins_with(body.to_lower()):
				matches.append("/" + cmd)
		_show_suggestions(matches)
		return

	var parts := body.split(" ", false)
	var command_name: String = parts[0].to_lower() if parts.size() > 0 else ""
	var partial: String = parts[1] if parts.size() > 1 else ""
	var partial_lower := partial.to_lower()

	if command_name == "give":
		var matches: Array = []
		for def in ObjectRegistry.get_all():
			if partial.is_empty() or def.id.to_lower().contains(partial_lower) or def.display_name.to_lower().contains(partial_lower):
				matches.append(def.id)
		# Sugerencias de "huevos de invocacion" (egg:<entidad>) junto con los
		# objetos normales - asi Tab tambien las completa.
		for key in EntityTypes.TYPES.keys():
			var egg_id: String = "egg:" + str(key)
			if partial.is_empty() or egg_id.contains(partial_lower) or key.contains(partial_lower):
				matches.append(egg_id)
		_show_suggestions(matches)
	elif command_name == "summon":
		var matches: Array = []
		for key in EntityTypes.TYPES.keys():
			if partial.is_empty() or key.contains(partial_lower):
				matches.append(key)
		_show_suggestions(matches)


func _show_suggestions(matches: Array) -> void:
	_current_suggestions = matches
	if matches.is_empty():
		suggestions_list.visible = false
		return
	for match_text in matches:
		suggestions_list.add_item(match_text)
	suggestions_list.visible = true


func _on_suggestion_selected(index: int) -> void:
	_tab_cycle_index = index
	_apply_suggestion(_current_suggestions[index])


func _on_input_gui_event(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		_cycle_tab_suggestion()
		get_viewport().set_input_as_handled()


## Igual que en Minecraft: la primera vez que se presiona Tab se completa
## con la primera sugerencia; si se sigue presionando Tab, va rotando entre
## TODAS las sugerencias disponibles (sin recalcular la lista, gracias a
## _suppress_text_changed) hasta volver a la primera.
func _cycle_tab_suggestion() -> void:
	if _current_suggestions.is_empty():
		return
	_tab_cycle_index = wrapi(_tab_cycle_index + 1, 0, _current_suggestions.size())
	suggestions_list.select(_tab_cycle_index)
	_apply_suggestion(_current_suggestions[_tab_cycle_index])


## Reemplaza el comando o el ultimo argumento por la sugerencia elegida
## (con Tab o con click), dejando el cursor listo para seguir escribiendo.
## _suppress_text_changed evita que este cambio de texto programado borre
## la lista de sugerencias activa (para poder seguir rotando con Tab).
func _apply_suggestion(chosen: String) -> void:
	_suppress_text_changed = true
	var text := input_line.text
	if not text.contains(" "):
		input_line.text = chosen + " "
	else:
		var space_index := text.find(" ")
		input_line.text = text.substr(0, space_index + 1) + chosen + " "
	input_line.caret_column = input_line.text.length()
	input_line.grab_focus()
	_suppress_text_changed = false

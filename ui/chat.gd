extends CanvasLayer
## Chat y consola de comandos en-juego estilo Minecraft.
## - Se abre con 'T' (mensaje o comando) o con '/' (comando prellenado).
## - Mientras el chat está cerrado, los mensajes recientes flotan en pantalla y se desvanecen tras 7s.
## - Al abrirlo, se despliega el fondo translúcido y el historial completo.
## - Historial de comandos enviados con flechas Arriba/Abajo.
## - Autocompletado contextual con tecla TAB o selección con clic.
## - Comandos integrados: /help, /give, /summon, /tp, /time, /kill, /clear.

const MESSAGE_LIFETIME := 7.0
const COMMANDS := ["help", "give", "summon", "tp", "time", "kill", "clear"]

@onready var panel: Control = $Panel
@onready var log_background: ColorRect = $Panel/LogBackground
@onready var log_label: RichTextLabel = $Panel/Log
@onready var input_line: LineEdit = $Panel/Input
@onready var suggestions_list: ItemList = $Panel/Suggestions
@onready var fade_timer: Timer = $FadeTimer

var _is_open := false
var _messages: Array = [] # {text: String, time: float}
var _history: Array[String] = []
var _history_index := -1
var _current_suggestions: Array = []
var _tab_cycle_index := -1
var _suppress_text_changed := false


func _ready() -> void:
	panel.visible = true
	log_background.visible = false
	input_line.visible = false
	suggestions_list.visible = false
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	input_line.text_submitted.connect(_on_submitted)
	input_line.text_changed.connect(_on_text_changed)
	input_line.gui_input.connect(_on_input_gui_event)
	suggestions_list.item_selected.connect(_on_suggestion_selected)
	fade_timer.timeout.connect(_refresh_visible_messages)

	_log("[color=#70c0ff][b]Play Sector X[/b] - Pulsa [color=#ffee55]T[/color] para chatear o [color=#ffee55]/[/color] para comandos.[/color]")


func is_open() -> bool:
	return _is_open


func log_message(text: String) -> void:
	_log(text)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode

	if (code == KEY_T or code == KEY_SLASH) and not _is_open:
		# No abrir si estamos en pausa o no hay jugador en mundo
		if get_tree().paused:
			return
		if get_tree().get_nodes_in_group("local_player").is_empty():
			return

		get_viewport().set_input_as_handled()
		var init_text := "/" if code == KEY_SLASH else ""
		# Usar call_deferred para garantizar que el evento de teclado actual termine de procesarse
		# y no se inserte 'T' accidentalmente dentro de la caja de texto
		call_deferred("_open", init_text)
	elif code == KEY_ESCAPE and _is_open:
		_close()
		get_viewport().set_input_as_handled()


func _open(initial_text := "") -> void:
	_is_open = true
	log_background.visible = true
	input_line.visible = true
	suggestions_list.visible = false
	log_label.mouse_filter = Control.MOUSE_FILTER_PASS

	_suppress_text_changed = true
	input_line.text = initial_text
	_suppress_text_changed = false

	input_line.grab_focus()
	input_line.caret_column = initial_text.length()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_history_index = _history.size()

	_refresh_visible_messages()

	if not initial_text.is_empty():
		_update_suggestions(initial_text)


func _close() -> void:
	_is_open = false
	log_background.visible = false
	input_line.visible = false
	suggestions_list.visible = false
	input_line.release_focus()
	log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	_refresh_visible_messages()


func _on_input_gui_event(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return

	var code: Key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode

	if code == KEY_ESCAPE:
		_close()
		input_line.accept_event()
		get_viewport().set_input_as_handled()
	elif code == KEY_TAB:
		_cycle_tab_suggestion()
		input_line.accept_event()
		get_viewport().set_input_as_handled()
	elif code == KEY_UP:
		_history_prev()
		input_line.accept_event()
		get_viewport().set_input_as_handled()
	elif code == KEY_DOWN:
		_history_next()
		input_line.accept_event()
		get_viewport().set_input_as_handled()


func _history_prev() -> void:
	if _history.is_empty():
		return
	if _history_index > 0:
		_history_index -= 1
	else:
		_history_index = 0

	_suppress_text_changed = true
	input_line.text = _history[_history_index]
	input_line.caret_column = input_line.text.length()
	_suppress_text_changed = false
	suggestions_list.visible = false


func _history_next() -> void:
	if _history.is_empty():
		return
	if _history_index < _history.size() - 1:
		_history_index += 1
		_suppress_text_changed = true
		input_line.text = _history[_history_index]
		input_line.caret_column = input_line.text.length()
		_suppress_text_changed = false
		suggestions_list.visible = false
	else:
		_history_index = _history.size()
		_suppress_text_changed = true
		input_line.text = ""
		_suppress_text_changed = false
		suggestions_list.visible = false


func _on_submitted(text: String) -> void:
	_close()
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return

	# Guardar en historial
	if _history.is_empty() or _history[-1] != trimmed:
		_history.append(trimmed)
		if _history.size() > 50:
			_history.pop_front()
	_history_index = _history.size()

	if trimmed.begins_with("/"):
		_log("[color=#a0a8b0]> %s[/color]" % trimmed)
		_run_command(trimmed.substr(1))
	else:
		_send_chat_message(trimmed)


func _send_chat_message(text: String) -> void:
	var sender_name := "Tú"
	var nm = get_tree().root.get_node_or_null("NetworkManager")
	if nm != null and nm.has_method("get_player_name"):
		var n: String = nm.get_player_name()
		if not n.is_empty():
			sender_name = n

	var formatted := "[color=#88ccff]<%s>[/color] %s" % [sender_name, text]
	_log(formatted)

	if multiplayer.has_multiplayer_peer() and multiplayer.get_peers().size() > 0:
		rpc("_rpc_receive_chat", sender_name, text)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_receive_chat(sender: String, text: String) -> void:
	_log("[color=#88ccff]<%s>[/color] %s" % [sender, text])


func _run_command(command_text: String) -> void:
	var parts := command_text.split(" ", false)
	if parts.is_empty():
		return

	var command_name: String = parts[0].to_lower()
	var args := parts.slice(1)

	match command_name:
		"help", "?":
			_cmd_help(args)
		"give":
			_cmd_give(args)
		"summon":
			_cmd_summon(args)
		"tp", "teleport":
			_cmd_tp(args)
		"time":
			_cmd_time(args)
		"kill":
			_cmd_kill(args)
		"clear":
			_cmd_clear(args)
		_:
			_log("[color=orange]Comando desconocido: /%s. Escribe [color=#ffee55]/help[/color] para ver la lista.[/color]" % command_name)


func _cmd_help(_args: PackedStringArray) -> void:
	_log("[color=#44d0fe][b]--- COMANDOS DISPONIBLES ---[/b][/color]")
	_log("[color=white][color=#ffee55]/help[/color] - Muestra esta lista de ayuda[/color]")
	_log("[color=white][color=#ffee55]/give <objeto|egg:entidad> [cantidad][/color] - Agrega objetos al inventario[/color]")
	_log("[color=white][color=#ffee55]/summon <perro|gato|zombi> [cantidad][/color] - Invoca una entidad[/color]")
	_log("[color=white][color=#ffee55]/tp <x> <z>  o  /tp <x> <y> <z>[/color] - Teletransporte de posición[/color]")
	_log("[color=white][color=#ffee55]/time <day|noon|sunset|night|sunrise>[/color] - Cambia la hora del día[/color]")
	_log("[color=white][color=#ffee55]/kill[/color] - Reaparece en el punto de spawn inicial[/color]")
	_log("[color=white][color=#ffee55]/clear[/color] - Limpia los mensajes en pantalla[/color]")


func _cmd_clear(_args: PackedStringArray) -> void:
	_messages.clear()
	_refresh_visible_messages()


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
		_log("[color=orange]Uso: /give <objeto|egg:entidad> [cantidad][/color]")
		return

	var amount := 1
	var last_idx := args.size() - 1
	if last_idx >= 1 and args[last_idx].is_valid_int():
		amount = maxi(1, args[last_idx].to_int())
		args = args.slice(0, last_idx)

	var query := " ".join(args).strip_edges()

	if query.to_lower().begins_with("egg:"):
		_cmd_give_egg(query.substr(4), amount)
		return

	var definition: ObjectDefinition = ObjectRegistry.find(query)
	if definition == null:
		_log("[color=red]No existe ningún objeto llamado '%s'.[/color]" % query)
		return

	var inventories := get_tree().get_nodes_in_group("local_inventory")
	if inventories.is_empty():
		_log("[color=red]No hay un jugador activo para recibir el objeto.[/color]")
		return

	inventories[0].add_item(definition, amount)
	_log("[color=green]+%d %s agregado(s) a tu inventario.[/color]" % [amount, definition.display_name])


func _cmd_give_egg(entity_query: String, amount: int = 1) -> void:
	var key := EntityTypes.find_key(entity_query)
	if key.is_empty():
		_log("[color=red]No existe ninguna entidad llamada '%s'. (Disponibles: perro, gato, zombi)[/color]" % entity_query)
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

	inventories[0].add_item(egg, amount)
	_log("[color=green]+%d %s agregado(s) a tu inventario.[/color]" % [amount, egg.display_name])


func _cmd_summon(args: PackedStringArray) -> void:
	if args.is_empty():
		_log("[color=orange]Uso: /summon <perro|gato|zombi> [cantidad][/color]")
		return

	var amount := 1
	if args.size() > 1 and args[-1].is_valid_int():
		amount = clampi(args[-1].to_int(), 1, 20)
		args = args.slice(0, args.size() - 1)

	var query := " ".join(args).strip_edges()
	var key := EntityTypes.find_key(query)
	if key.is_empty():
		_log("[color=red]No existe ninguna entidad llamada '%s'. (Disponibles: perro, gato, zombi)[/color]" % query)
		return

	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty():
		_log("[color=red]No hay un jugador activo para invocar la entidad.[/color]")
		return

	var scene_path: String = EntityTypes.TYPES[key]["scene"]
	var scene: PackedScene = load(scene_path)
	if scene == null:
		_log("[color=red]No se pudo cargar la escena de '%s'.[/color]" % key)
		return

	var player: Node3D = players[0]
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	if forward.length_squared() < 0.01:
		forward = Vector3.FORWARD

	var target_parent: Node = get_tree().current_scene
	if target_parent == null:
		target_parent = player.get_parent()

	for i in range(amount):
		var offset := forward * (2.5 + float(i) * 1.2)
		if amount > 1 and i > 0:
			var side := player.global_transform.basis.x * ((float(i % 2) * 2.0 - 1.0) * float((i + 1) / 2) * 0.8)
			offset += side

		var raw_pos := player.global_position + offset
		var spawn_pos := _snap_to_ground(raw_pos, player.global_position)
		var instance: Node3D = scene.instantiate()
		target_parent.add_child(instance)
		instance.global_position = spawn_pos

	_log("[color=green]Invocado(s) %d %s frente al jugador.[/color]" % [amount, EntityTypes.TYPES[key]["display_name"]])


func _cmd_tp(args: PackedStringArray) -> void:
	if args.size() < 2:
		_log("[color=orange]Uso: /tp <x> <z>  o  /tp <x> <y> <z>[/color]")
		return

	var players := get_tree().get_nodes_in_group("local_player")
	if players.is_empty():
		_log("[color=red]No hay jugador local para teletransportar.[/color]")
		return

	var player: Node3D = players[0]
	var target_x: float = float(args[0])
	var target_y: float = 0.0
	var target_z: float = 0.0

	if args.size() >= 3:
		target_y = float(args[1])
		target_z = float(args[2])
	else:
		target_z = float(args[1])
		target_y = _get_terrain_height_at(target_x, target_z) + 1.5

	player.global_position = Vector3(target_x, target_y, target_z)
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	_log("[color=cyan]Teletransportado a (%.1f, %.1f, %.1f).[/color]" % [target_x, target_y, target_z])


func _cmd_time(args: PackedStringArray) -> void:
	if args.is_empty():
		_log("[color=orange]Uso: /time <day|noon|sunset|night|sunrise|0.0-1.0>[/color]")
		return

	var sub := args[0].to_lower()
	if sub == "set" and args.size() > 1:
		sub = args[1].to_lower()

	var day_night := get_tree().get_first_node_in_group("day_night_cycle") as DayNightCycle
	if day_night == null:
		for n in get_tree().root.find_children("*", "DayNightCycle", true, false):
			day_night = n as DayNightCycle
			break

	if day_night == null:
		_log("[color=red]No se encontró el sistema de ciclo día/noche en el mundo.[/color]")
		return

	match sub:
		"day", "dia", "noon", "mediodia":
			day_night.set_time(0.5)
			_log("[color=yellow]Hora establecida a Mediodía (12:00).[/color]")
		"sunset", "atardecer", "tarde":
			day_night.set_time(0.75)
			_log("[color=orange]Hora establecida a Atardecer.[/color]")
		"night", "noche", "midnight", "medianoche":
			day_night.set_time(0.0)
			_log("[color=purple]Hora establecida a Medianoche (00:00).[/color]")
		"sunrise", "amanecer", "morning", "mañana":
			day_night.set_time(0.25)
			_log("[color=yellow]Hora establecida a Amanecer.[/color]")
		_:
			if sub.is_valid_float():
				var t := clampf(sub.to_float(), 0.0, 1.0)
				day_night.set_time(t)
				_log("[color=yellow]Hora establecida a %.2f.[/color]" % t)
			else:
				_log("[color=orange]Opciones válidas: day, noon, sunset, night, sunrise o valor entre 0.0 y 1.0[/color]")


func _get_terrain_height_at(wx: float, wz: float) -> float:
	var chunk_mgr = get_tree().get_first_node_in_group("chunk_manager")
	if chunk_mgr == null:
		for n in get_tree().root.find_children("*", "ChunkManager", true, false):
			chunk_mgr = n
			break
	if chunk_mgr != null and chunk_mgr.has_method("sample_height"):
		return chunk_mgr.sample_height(wx, wz)

	var space_state := get_viewport().get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(wx, 500.0, wz), Vector3(wx, -50.0, wz)
	)
	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return (result["position"] as Vector3).y
	return 10.0


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
	if _messages.size() > 100:
		_messages.pop_front()
	_refresh_visible_messages()


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

	match command_name:
		"give":
			var matches: Array = []
			for def in ObjectRegistry.get_all():
				if partial.is_empty() or def.id.to_lower().contains(partial_lower) or def.display_name.to_lower().contains(partial_lower):
					matches.append(def.id)
			for key in EntityTypes.TYPES.keys():
				var egg_id: String = "egg:" + str(key)
				if partial.is_empty() or egg_id.contains(partial_lower) or key.contains(partial_lower):
					matches.append(egg_id)
			_show_suggestions(matches)

		"summon":
			var matches: Array = []
			for key in EntityTypes.TYPES.keys():
				if partial.is_empty() or key.contains(partial_lower):
					if not matches.has(key):
						matches.append(key)
			_show_suggestions(matches)

		"time":
			var time_options := ["day", "noon", "sunset", "night", "sunrise"]
			var matches: Array = []
			for opt in time_options:
				if partial.is_empty() or opt.begins_with(partial_lower):
					matches.append(opt)
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
	if index < 0 or index >= _current_suggestions.size():
		return
	_tab_cycle_index = index
	_apply_suggestion(_current_suggestions[index])


func _cycle_tab_suggestion() -> void:
	if _current_suggestions.is_empty():
		return
	_tab_cycle_index = wrapi(_tab_cycle_index + 1, 0, _current_suggestions.size())
	suggestions_list.select(_tab_cycle_index)
	_apply_suggestion(_current_suggestions[_tab_cycle_index])


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

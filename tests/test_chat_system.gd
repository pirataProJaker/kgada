extends SceneTree

func _init() -> void:
	print("[test_chat] Iniciando pruebas del sistema de Chat...")
	
	# Instanciar Chat directamente para el test
	var chat_scene: PackedScene = load("res://ui/chat.tscn")
	var chat = chat_scene.instantiate()
	root.add_child(chat)
	
	# 1. Probar estado inicial
	assert(not chat.is_open(), "Chat debe iniciar cerrado")
	print("[test_chat] OK: Estado inicial cerrado.")
	
	# 2. Probar apertura
	chat._open()
	assert(chat.is_open(), "Chat debe estar abierto tras _open()")
	assert(chat.input_line.visible, "Input debe estar visible")
	print("[test_chat] OK: Apertura normal con T.")
	
	# 3. Probar cierre
	chat._close()
	assert(not chat.is_open(), "Chat debe estar cerrado tras _close()")
	assert(not chat.input_line.visible, "Input debe estar oculto")
	print("[test_chat] OK: Cierre con Escape o submit.")
	
	# 4. Probar apertura con /
	chat._open("/")
	assert(chat.input_line.text == "/", "Input debe contener '/' al abrir con slash")
	assert(chat.suggestions_list.visible, "Sugerencias de comandos deben estar visibles tras '/'")
	print("[test_chat] OK: Apertura con / y sugerencias de comandos iniciales.")
	
	# 5. Probar autocompletado de comandos
	chat._update_suggestions("/gi")
	assert(chat._current_suggestions.has("/give"), "Debe sugerir /give para '/gi'")
	print("[test_chat] OK: Sugerencia de comando /give.")
	
	# 6. Probar autocompletado de argumentos
	chat._update_suggestions("/time ")
	assert(chat._current_suggestions.has("day"), "Debe sugerir 'day' para /time")
	assert(chat._current_suggestions.has("night"), "Debe sugerir 'night' para /time")
	print("[test_chat] OK: Sugerencias de argumentos para /time.")
	
	chat._update_suggestions("/summon ")
	assert(chat._current_suggestions.has("perro"), "Debe sugerir 'perro' para /summon")
	assert(chat._current_suggestions.has("gato"), "Debe sugerir 'gato' para /summon")
	assert(chat._current_suggestions.has("zombi"), "Debe sugerir 'zombi' para /summon")
	print("[test_chat] OK: Sugerencias de mobs para /summon.")
	
	# 7. Probar ejecución de comandos
	chat._run_command("help")
	chat._run_command("clear")
	assert(chat._messages.is_empty(), "Historial debe estar vacío tras /clear")
	print("[test_chat] OK: Ejecución de /help y /clear.")
	
	# 8. Probar comando /give con cantidad
	chat._run_command("give basic_chest 5")
	print("[test_chat] OK: Ejecución de /give con cantidad.")
	
	# 9. Probar historial de comandos
	chat._on_submitted("/tp 100 200")
	chat._on_submitted("/time day")
	assert(chat._history.size() == 2, "Debe tener 2 comandos en el historial")
	chat._history_prev()
	assert(chat.input_line.text == "/time day", "Flecha arriba debe recuperar '/time day'")
	chat._history_prev()
	assert(chat.input_line.text == "/tp 100 200", "Flecha arriba de nuevo debe recuperar '/tp 100 200'")
	chat._history_next()
	assert(chat.input_line.text == "/time day", "Flecha abajo debe avanzar a '/time day'")
	print("[test_chat] OK: Historial de comandos arriba/abajo.")
	
	chat._close()
	print("[test_chat] TODAS LAS PRUEBAS DEL CHAT PASARON EXITOSAMENTE.")
	quit(0)

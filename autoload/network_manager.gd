extends Node
## Multijugador basico (Fase 2): host/join por ENet. El terreno NO se manda
## por red - cada peer lo genera localmente desde el mismo seed (ver
## chunk_manager.gd), asi que solo hace falta sincronizar jugadores.
##
## Limitaciones conocidas (a proposito, para no sobre-construir en un primer
## paso): la sincronizacion de posicion es "teleport" via RPC periodico, sin
## interpolacion ni prediccion. Esto NO se ha probado con dos instancias
## reales de Godot corriendo a la vez - falta esa validacion.

signal connection_status_changed(status: String)

const PORT := 8910
const MAX_PLAYERS := 16
const PLAYER_SCENE := preload("res://player/player.tscn")

# El nodo (en la escena actual) donde se agregan/quitan los jugadores.
# Lo asigna la escena principal (ver tests/world_test.gd).
var players_container: Node = null

var _spawned_peer_ids: Array[int] = []


func host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS)
	if error != OK:
		connection_status_changed.emit("Error al crear el servidor: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	connection_status_changed.emit("Alojando partida en el puerto %d..." % PORT)
	_on_peer_connected(multiplayer.get_unique_id())


func join_game(address: String) -> void:
	_clear_all_players()

	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		connection_status_changed.emit("Error al conectar: %s" % error)
		return

	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func() -> void:
		connection_status_changed.emit("Conectado a %s" % address)
	)
	multiplayer.connection_failed.connect(func() -> void:
		connection_status_changed.emit("No se pudo conectar a %s" % address)
	)
	multiplayer.server_disconnected.connect(func() -> void:
		connection_status_changed.emit("El servidor se desconecto.")
	)


## Para el modo solo (sin host/join): asegura que exista el jugador local sin
## pasar por RPC, ya que todavia no hay ningun peer conectado.
func ensure_local_player() -> void:
	if players_container != null and not players_container.has_node("1"):
		_spawn_player(1)


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Al que se acaba de unir, le mandamos spawn de todos los que ya estaban -
	# si no, alguien que se une tarde nunca veria a los jugadores previos.
	for existing_id in _spawned_peer_ids:
		if existing_id != peer_id:
			_spawn_player.rpc_id(peer_id, existing_id)

	if not _spawned_peer_ids.has(peer_id):
		_spawned_peer_ids.append(peer_id)
	_spawn_player.rpc(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_spawned_peer_ids.erase(peer_id)
	_despawn_player.rpc(peer_id)


func _clear_all_players() -> void:
	if players_container == null:
		return
	for child in players_container.get_children():
		if child.name.is_valid_int():
			child.queue_free()


@rpc("authority", "call_local", "reliable")
func _spawn_player(peer_id: int) -> void:
	if players_container == null or players_container.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	# Importante: la autoridad se fija ANTES de add_child, para que el propio
	# _ready() del jugador (que revisa is_multiplayer_authority) ya vea el
	# valor correcto desde el primer frame.
	player.set_multiplayer_authority(peer_id)
	players_container.add_child(player)


@rpc("authority", "call_local", "reliable")
func _despawn_player(peer_id: int) -> void:
	if players_container == null:
		return
	var node := players_container.get_node_or_null(str(peer_id))
	if node:
		node.queue_free()

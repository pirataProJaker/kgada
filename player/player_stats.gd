extends Node
class_name PlayerStats
## Estadisticas del jugador: vida, hambre y agua (0-100 cada una).
##
## El dueño (player.gd, que ya tiene la guardia de is_multiplayer_authority)
## llama a tick(delta) cada physics frame - este nodo no corre su propio
## _process, para no duplicar el chequeo de autoridad de red. Hambre y agua
## bajan lentamente con el tiempo; si llegan a 0 empiezan a quitar vida
## (inanicion/deshidratacion). Si hambre y agua estan por arriba de
## regen_min_stat_threshold, la vida se regenera sola lentamente.
##
## El HUD se auto-vincula al grupo "local_player_stats" (mismo patron que
## Inventory con "local_inventory") y lee health/hunger/water directamente
## cada frame para dibujar las barras.

const MAX_VALUE := 100.0

@export var hunger_drain_per_second := MAX_VALUE / 300.0 # se vacia en 5 minutos
@export var water_drain_per_second := MAX_VALUE / 240.0 # se vacia en 4 minutos
@export var starvation_damage_per_second := 1.0
@export var dehydration_damage_per_second := 1.5
@export var regen_per_second := 1.0
@export var regen_min_stat_threshold := 50.0 # hambre Y agua deben estar arriba de esto para regenerar vida sola

var health := MAX_VALUE
var hunger := MAX_VALUE
var water := MAX_VALUE


func _ready() -> void:
	if get_parent().is_multiplayer_authority():
		add_to_group("local_player_stats")


## Avanza las estadisticas `delta` segundos. Solo debe llamarse desde el
## dueño autoritativo del jugador.
func tick(delta: float) -> void:
	hunger = maxf(hunger - hunger_drain_per_second * delta, 0.0)
	water = maxf(water - water_drain_per_second * delta, 0.0)

	var damage := 0.0
	if hunger <= 0.0:
		damage += starvation_damage_per_second * delta
	if water <= 0.0:
		damage += dehydration_damage_per_second * delta

	if damage > 0.0:
		health = maxf(health - damage, 0.0)
	elif hunger >= regen_min_stat_threshold and water >= regen_min_stat_threshold:
		health = minf(health + regen_per_second * delta, MAX_VALUE)


func take_damage(amount: float) -> void:
	health = maxf(health - amount, 0.0)


func heal(amount: float) -> void:
	health = minf(health + amount, MAX_VALUE)


func feed(amount: float) -> void:
	hunger = minf(hunger + amount, MAX_VALUE)


func drink(amount: float) -> void:
	water = minf(water + amount, MAX_VALUE)


func reset_full() -> void:
	health = MAX_VALUE
	hunger = MAX_VALUE
	water = MAX_VALUE

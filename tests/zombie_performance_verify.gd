extends Node3D
## Mide el coste medio de fisica con un presupuesto de zombies configurable.
##   godot --headless --path . tests/zombie_performance_verify.tscn -- --count=64

const WARMUP_FRAMES := 30
const MEASURE_FRAMES := 120

@onready var manager: Node3D = $ZombiePopulationManager
@onready var player: Node3D = $Player

var _target_count := 64
var _phase := 0
var _warmup_frames := 0
var _measure_frames := 0
var _spawn_start_usec := 0
var _measure_start_usec := 0


func _ready() -> void:
	Engine.physics_ticks_per_second = 1000
	player.add_to_group("players")
	_target_count = _read_target_count()
	manager.max_active_zombies = _target_count
	_spawn_start_usec = Time.get_ticks_usec()
	manager.configure_world(24680)


func _physics_process(_delta: float) -> void:
	var active_count: int = manager.get_active_zombie_count()
	if _phase == 0:
		if active_count >= _target_count:
			var spawn_ms := float(Time.get_ticks_usec() - _spawn_start_usec) / 1000.0
			print("[perf] activos=%d materializacion_ms=%.3f" % [_target_count, spawn_ms])
			_phase = 1
			manager.set_process(false)
		return

	if _phase == 1:
		_warmup_frames += 1
		if _warmup_frames >= WARMUP_FRAMES:
			_phase = 2
			_measure_start_usec = Time.get_ticks_usec()
		return

	_measure_frames += 1
	if _measure_frames < MEASURE_FRAMES:
		return

	var elapsed_usec := Time.get_ticks_usec() - _measure_start_usec
	var average_ms := float(elapsed_usec) / float(MEASURE_FRAMES) / 1000.0
	print("[perf] activos=%d promedio_fisica_ms=%.3f" % [_target_count, average_ms])
	get_tree().quit(0)


func _read_target_count() -> int:
	var environment_count := OS.get_environment("ZOMBIE_COUNT")
	if not environment_count.is_empty():
		return maxi(1, int(environment_count))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--count="):
			return maxi(1, int(argument.trim_prefix("--count=")))
	return 64

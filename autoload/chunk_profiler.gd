extends Node

## Telemetría y registro de rendimiento en tiempo real para diagnóstico de carga/descarga de chunks.
## Escribe en tiempo real en chunk_performance.log para que pueda ser inspeccionado con total detalle.

const LOG_PATH := "res://chunk_performance.log"
const USER_LOG_PATH := "user://chunk_performance.log"
const SPIKE_THRESHOLD_MS := 20.0 # Considera un tirón cualquier fotograma que tarde >= 20ms (< 50 FPS)

static var _instance: ChunkProfiler = null

var _log_file: FileAccess = null
var _frame_count := 0
var _session_start_msec := 0
var _current_frame_events: Array[String] = []

var _recent_deltas: Array[float] = []
var _spike_count := 0
var _periodic_timer := 0.0
var _actual_log_path := ""
var _is_headless := false


func _ready() -> void:
	_instance = self
	_is_headless = DisplayServer.get_name() == "headless" or "--headless" in OS.get_cmdline_args()
	if _is_headless:
		# En modo headless (ej. tests automatizados), no sobrescribir el registro de gameplay del usuario
		return

	_session_start_msec = Time.get_ticks_msec()
	_init_log_file()
	log_event("================================================================")
	log_event("=== NUEVA SESION DE REGISTRO DE RENDIMIENTO PLAY SECTOR X ===")
	log_event("================================================================")
	log_event("Godot: %s | OS: %s | CPU Cores: %d" % [
		Engine.get_version_info()["string"],
		OS.get_name(),
		OS.get_processor_count()
	])
	log_event("Resolución: %s | VSync Mode: %d | Archivo de registro: %s" % [
		DisplayServer.window_get_size(),
		DisplayServer.window_get_vsync_mode(),
		_actual_log_path
	])
	log_event("Umbral de detección de tirones (Spikes): >= %.1f ms (< 50 FPS)" % SPIKE_THRESHOLD_MS)
	log_event("----------------------------------------------------------------")


func _init_log_file() -> void:
	_log_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log_file == null:
		_log_file = FileAccess.open(USER_LOG_PATH, FileAccess.WRITE)
		_actual_log_path = ProjectSettings.globalize_path(USER_LOG_PATH)
	else:
		_actual_log_path = ProjectSettings.globalize_path(LOG_PATH)


static func log_event(message: String) -> void:
	if _instance:
		_instance._log_event_impl(message)


func _log_event_impl(message: String) -> void:
	if _is_headless or _log_file == null:
		return
	var now_ms := Time.get_ticks_msec() - _session_start_msec
	var sec := now_ms / 1000.0
	var line := "[T+%.3fs] %s" % [sec, message]
	print(line)
	_log_file.store_line(line)
	_log_file.flush()


## Registra una sub-operación ocurrida en el fotograma actual para asociarla a cualquier tirón
static func record_frame_event(event_desc: String) -> void:
	if _instance:
		_instance._record_frame_event_impl(event_desc)


func _record_frame_event_impl(event_desc: String) -> void:
	if _is_headless:
		return
	_current_frame_events.append(event_desc)


func _process(delta: float) -> void:
	if _is_headless or _log_file == null:
		return

	_frame_count += 1
	var frame_ms := delta * 1000.0
	_recent_deltas.append(frame_ms)
	if _recent_deltas.size() > 60:
		_recent_deltas.pop_front()

	# Si el fotograma superó el umbral de tirón, registrar informe ultra-detallado
	if frame_ms >= SPIKE_THRESHOLD_MS:
		_spike_count += 1
		var fps: int = int(1000.0 / frame_ms) if frame_ms > 0.001 else 0
		var cpu_proc_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var cpu_phys_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		var cpu_nav_ms := Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
		var gpu_vsync_wait_ms := maxf(0.0, frame_ms - (cpu_proc_ms + cpu_phys_ms + cpu_nav_ms))
		var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var node_count := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var orphan_count := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var vram_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)

		var chunk_status := _get_chunk_manager_status()

		var events_str := " | ".join(_current_frame_events) if not _current_frame_events.is_empty() else "Sin eventos GDScript (Carga GPU / VSync Wait / Swapping)"
		log_event(">>> [TIRON #%d DETECTADO] Frame #%d: %.2f ms (%d FPS) | ScriptCPU: %.2fms, Fisica: %.2fms, GPU/VSyncWait: %.2fms | %s | DrawCalls: %d, Triangulos: %d, Nodos: %d (Huerfanos: %d), VRAM: %.1fMB | Operaciones: [%s]" % [
			_spike_count, _frame_count, frame_ms, fps,
			cpu_proc_ms, cpu_phys_ms, gpu_vsync_wait_ms,
			chunk_status,
			draw_calls, primitives, node_count, orphan_count, vram_mb,
			events_str
		])

	_current_frame_events.clear()

	# Informe periódico de salud cada 3 segundos
	_periodic_timer += delta
	if _periodic_timer >= 3.0:
		_periodic_timer = 0.0
		_log_periodic_status()


func _get_chunk_manager_status() -> String:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return "Chunks: N/A"
	var cm = tree.current_scene.get_node_or_null("ChunkManager")
	if cm == null:
		return "Chunks: NoEncontrado"
	var loaded: int = cm.get("_loaded_chunks").size() if "_loaded_chunks" in cm else -1
	var to_load: int = cm.get("_chunks_to_load").size() if "_chunks_to_load" in cm else -1
	var to_unload: int = cm.get("_chunks_to_unload").size() if "_chunks_to_unload" in cm else -1
	var pending_tasks: int = cm.get("_pending_task_ids").size() if "_pending_task_ids" in cm else -1
	var tree_q: int = cm.get("_tree_attach_queue").size() if "_tree_attach_queue" in cm else -1
	var bush_q: int = cm.get("_bush_attach_queue").size() if "_bush_attach_queue" in cm else -1
	return "Chunks: %d cargados, %d por cargar (hilos: %d), %d por descargar, colasVeg(T:%d, B:%d)" % [
		loaded, to_load, pending_tasks, to_unload, tree_q, bush_q
	]


func _log_periodic_status() -> void:
	var fps := Engine.get_frames_per_second()
	var max_d := 0.0
	var sum_d := 0.0
	for d in _recent_deltas:
		if d > max_d:
			max_d = d
		sum_d += d
	
	var count := maxf(1.0, float(_recent_deltas.size()))
	var avg_d := sum_d / count
	var min_fps: int = int(1000.0 / max_d) if max_d > 0.001 else fps
	var mem_mb := OS.get_static_memory_usage() / (1024.0 * 1024.0)
	var vram_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var chunk_status := _get_chunk_manager_status()

	log_event("[SALUD_FPS] Actual: %d FPS (Media: %.1f ms | Peor: %d FPS / %.1f ms) | %s | DrawCalls: %d | Triangulos: %d | RAM: %.1f MB | VRAM: %.1f MB | Tirones acumulados: %d" % [
		fps, avg_d, min_fps, max_d, chunk_status, draw_calls, primitives, mem_mb, vram_mb, _spike_count
	])


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _log_file:
			log_event("================================================================")
			log_event("=== SESION FINALIZADA. Tirones totales registrados: %d ===" % _spike_count)
			log_event("================================================================")
			_log_file.close()
			_log_file = null


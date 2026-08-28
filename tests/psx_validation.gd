extends Node3D
## Fase 0 - Escena de validacion: prueba visual del shader PSX (vertex snap +
## dither) y prueba de humo del nucleo Rust (GDExtension) via RustCore.ping().

func _ready() -> void:
	print("[psx_validation] Escena de validacion lista.")

	if ClassDB.class_exists("RustCore"):
		var rust_core = ClassDB.instantiate("RustCore")
		print("[psx_validation] Respuesta del nucleo Rust: ", rust_core.ping())
		rust_core.free()
	else:
		print("[psx_validation] RustCore no esta disponible todavia - compila el crate rust_core (cargo build) y reabre el proyecto.")

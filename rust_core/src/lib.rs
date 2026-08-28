use godot::prelude::*;

mod mob_ai;
mod terrain;
mod zombie_population;

struct RustCoreExtension;

#[gdextension]
unsafe impl ExtensionLibrary for RustCoreExtension {}

/// Nucleo de simulacion en Rust, expuesto a Godot via GDExtension.
///
/// Fase 0: esto solo prueba que el puente Godot <-> Rust funciona
/// ("hola mundo" nativo). La logica real (terreno/Marching Cubes, red,
/// IA, etc.) se ira agregando aqui en fases posteriores del roadmap.
#[derive(GodotClass)]
#[class(init, base=Node)]
struct RustCore {
    base: Base<Node>,
}

#[godot_api]
impl INode for RustCore {
    fn ready(&mut self) {
        godot_print!("[rust_core] Nucleo Rust conectado correctamente via GDExtension.");
    }
}

#[godot_api]
impl RustCore {
    #[func]
    fn ping(&self) -> String {
        "pong desde Rust".to_string()
    }
}

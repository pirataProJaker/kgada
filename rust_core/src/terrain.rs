use godot::prelude::*;
use lin_alg::f32::Vec3;
use mcubes::{MarchingCubes, MeshSide};
use noise::{Fbm, MultiFractal, NoiseFn, Perlin};

// Frecuencias bajas (mapa grande = features grandes, no ruido fino).
const BIOME_FREQ: f64 = 0.012;
const PLAINS_FREQ: f64 = 0.015;
const MOUNTAIN_FREQ: f64 = 0.010;

const PLAINS_BASE: f32 = 10.0;
const PLAINS_AMPLITUDE: f32 = 2.0;

const MOUNTAIN_BASE: f32 = 20.0;
const MOUNTAIN_AMPLITUDE: f32 = 14.0;
const TERRACE_STEP: f32 = 5.0;
const TERRACE_STRENGTH: f32 = 0.35;

/// Generador de terreno (Fase 1): produce UN chunk fijo usando el algoritmo
/// Marching Cubes (crate `mcubes`) a partir de ruido fractal (fBm) real, con
/// un sistema simple de biomas (llano <-> montaña) que se mezclan de forma
/// suave, y "aterrazado" en las zonas montañosas para dejar plataformas
/// planas donde construir incluso cerca de las cimas.
///
/// No hay streaming ni chunks multiples aun - eso es una fase posterior
/// (ver roadmap: Fase 1.5). El objetivo aqui es validar el pipeline
/// completo Rust -> Godot para generar y mostrar una malla de terreno.
#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct TerrainGenerator {
    base: Base<Node>,
}

#[godot_api]
impl TerrainGenerator {
    /// Genera un chunk de terreno y devuelve un Dictionary con "vertices"
    /// (PackedVector3Array), "normals" (PackedVector3Array) e "indices"
    /// (PackedInt32Array), listos para construir un ArrayMesh en GDScript.
    ///
    /// `chunk_origin_x`/`chunk_origin_z` son la posicion del chunk en el
    /// mundo (no la del mesh, que se mantiene local). Se usan solo para
    /// muestrear el ruido en coordenadas globales, para que chunks vecinos
    /// generen terreno continuo (sin costuras ni patrones repetidos).
    ///
    /// `city_center_x`/`city_center_z`/`city_inner_radius`/
    /// `city_outer_radius`/`city_flat_height`: zona de aplanado para la
    /// ciudad procedural (ver CityWorldSpawner en GDScript, que calcula
    /// estos 5 valores UNA vez al iniciar el mundo, a partir de la
    /// semilla). Dentro de `city_inner_radius` la altura queda 100% fija
    /// en `city_flat_height`; entre `city_inner_radius` y
    /// `city_outer_radius` se mezcla suavemente (smoothstep) hacia la
    /// altura natural, para que no se vea un escalon brusco en el borde.
    /// `city_inner_radius <= 0.0` desactiva el aplanado (comportamiento
    /// original, sin ciudad registrada todavia).
    #[func]
    fn generate_chunk(
        &self,
        resolution: i32,
        voxel_size: f32,
        seed: i32,
        chunk_origin_x: f32,
        chunk_origin_z: f32,
        city_center_x: f32,
        city_center_z: f32,
        city_inner_radius: f32,
        city_outer_radius: f32,
        city_flat_height: f32,
    ) -> VarDictionary {
        let dims = resolution.max(2) as usize;
        let mut values = Vec::with_capacity(dims * dims * dims);

        let seed_u32 = seed as u32;

        // Ruido de bioma (baja frecuencia -> regiones grandes y contiguas).
        // Se remapea de [-1, 1] a [0, 1] = "que tan montañoso" es el lugar.
        let biome_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(100)).set_octaves(2);

        // Llanuras: pocas octavas, amplitud baja -> ondulacion suave pero visible.
        let plains_noise = Fbm::<Perlin>::new(seed_u32)
            .set_octaves(3)
            .set_persistence(0.4);

        // Montañas: contraste real (esto es lo que las hace leerse como
        // montañas de verdad en vez de manchas de nieve sobre terreno plano).
        // El wobble del shader ya no es un problema aparte (se resolvio con
        // grid_precision en el material), asi que se puede subir la amplitud
        // sin que vuelva a verse "roto".
        let mountain_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(200))
            .set_octaves(4)
            .set_persistence(0.5);

        // Empaquetado plano: el indice debe ser x + y*dims + z*dims*dims,
        // por eso el orden de los bucles es z (mas externo), y, x (mas interno).
        for z in 0..dims {
            for y in 0..dims {
                for x in 0..dims {
                    let wx = chunk_origin_x as f64 + x as f64 * voxel_size as f64;
                    let wz = chunk_origin_z as f64 + z as f64 * voxel_size as f64;
                    let wy = y as f32 * voxel_size;

                    let height =
                        compute_natural_height(wx, wz, &biome_noise, &plains_noise, &mountain_noise);

                    let final_height = if city_inner_radius > 0.0 {
                        let dx = wx as f32 - city_center_x;
                        let dz = wz as f32 - city_center_z;
                        let dist = (dx * dx + dz * dz).sqrt();
                        let city_factor = if dist <= city_inner_radius {
                            1.0
                        } else if city_outer_radius <= city_inner_radius || dist >= city_outer_radius
                        {
                            0.0
                        } else {
                            let t = (dist - city_inner_radius)
                                / (city_outer_radius - city_inner_radius);
                            1.0 - (t * t * (3.0 - 2.0 * t))
                        };
                        height * (1.0 - city_factor) + city_flat_height * city_factor
                    } else {
                        height
                    };

                    // Positivo = solido/subsuelo, negativo = aire (mcubes espera
                    // que "adentro" sea el signo positivo - con el signo al
                    // reves las normales/orientacion de los triangulos salian
                    // invertidas, por eso la superficie se veia bien solo
                    // desde abajo).
                    values.push(final_height - wy);
                }
            }
        }

        let mc = match MarchingCubes::new(
            (dims, dims, dims),
            (voxel_size, voxel_size, voxel_size),
            (1.0, 1.0, 1.0),
            Vec3::new(0.0, 0.0, 0.0),
            values,
            0.0,
        ) {
            Ok(mc) => mc,
            Err(err) => {
                godot_error!("[terrain] Error generando el chunk: {err}");
                return VarDictionary::new();
            }
        };

        let mesh = mc.generate(MeshSide::OutsideOnly);

        let mut vertices = PackedVector3Array::new();
        let mut normals = PackedVector3Array::new();
        let mut indices = PackedInt32Array::new();

        for vertex in &mesh.vertices {
            vertices.push(Vector3::new(vertex.posit.x, vertex.posit.y, vertex.posit.z));
            normals.push(Vector3::new(vertex.normal.x, vertex.normal.y, vertex.normal.z));
        }
        for index in &mesh.indices {
            indices.push(*index as i32);
        }

        let mut dict = VarDictionary::new();
        dict.set("vertices", vertices);
        dict.set("normals", normals);
        dict.set("indices", indices);
        dict
    }

    /// Genera la misma malla Marching Cubes que usa el mundo jugable, pero
    /// desde una cuadricula de alturas editada por el creador de mapas.
    /// `heights` contiene una muestra por columna X/Z y debe tener
    /// `resolution * resolution` valores.
    #[func]
    fn generate_chunk_from_height_field(
        &self,
        resolution: i32,
        voxel_size: f32,
        heights: PackedFloat32Array,
    ) -> VarDictionary {
        let dims = resolution.max(2) as usize;
        let mut values = Vec::with_capacity(dims * dims * dims);

        for z in 0..dims {
            for y in 0..dims {
                for x in 0..dims {
                    let height_index = x + z * dims;
                    let height = heights.get(height_index).unwrap_or(10.0);
                    let wy = y as f32 * voxel_size;
                    values.push(height - wy);
                }
            }
        }

        let mc = match MarchingCubes::new(
            (dims, dims, dims),
            (voxel_size, voxel_size, voxel_size),
            (1.0, 1.0, 1.0),
            Vec3::new(0.0, 0.0, 0.0),
            values,
            0.0,
        ) {
            Ok(mc) => mc,
            Err(err) => {
                godot_error!("[terrain] Error generando altura editada: {err}");
                return VarDictionary::new();
            }
        };

        let mesh = mc.generate(MeshSide::OutsideOnly);
        let mut vertices = PackedVector3Array::new();
        let mut normals = PackedVector3Array::new();
        let mut indices = PackedInt32Array::new();

        for vertex in &mesh.vertices {
            vertices.push(Vector3::new(vertex.posit.x, vertex.posit.y, vertex.posit.z));
            normals.push(Vector3::new(vertex.normal.x, vertex.normal.y, vertex.normal.z));
        }
        for index in &mesh.indices {
            indices.push(*index as i32);
        }

        let mut dict = VarDictionary::new();
        dict.set("vertices", vertices);
        dict.set("normals", normals);
        dict.set("indices", indices);
        dict
    }

    /// Devuelve la altura NATURAL del terreno (sin aplanado de ciudad) en
    /// un punto (x, z) del mundo - un solo valor, sin generar malla. Usado
    /// por CityWorldSpawner (GDScript) para saber a que altura poner la
    /// plataforma plana de la ciudad, para que el aplanado combine bien
    /// con el terreno de alrededor en vez de usar una altura arbitraria.
    #[func]
    fn sample_height(&self, seed: i32, world_x: f32, world_z: f32) -> f32 {
        let seed_u32 = seed as u32;
        let biome_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(100)).set_octaves(2);
        let plains_noise = Fbm::<Perlin>::new(seed_u32)
            .set_octaves(3)
            .set_persistence(0.4);
        let mountain_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(200))
            .set_octaves(4)
            .set_persistence(0.5);

        compute_natural_height(
            world_x as f64,
            world_z as f64,
            &biome_noise,
            &plains_noise,
            &mountain_noise,
        )
    }
}

/// Formula de altura natural compartida entre `generate_chunk` (una vez
/// por chunk, reusando los mismos objetos Fbm para las 33x33x33 columnas)
/// y `sample_height` (una sola muestra puntual) - un unico lugar para la
/// formula evita que las dos terminen desincronizadas.
fn compute_natural_height(
    wx: f64,
    wz: f64,
    biome_noise: &Fbm<Perlin>,
    plains_noise: &Fbm<Perlin>,
    mountain_noise: &Fbm<Perlin>,
) -> f32 {
    let biome_raw = biome_noise.get([wx * BIOME_FREQ, wz * BIOME_FREQ]) as f32;
    let mountain_factor = (biome_raw * 0.5 + 0.5).clamp(0.0, 1.0);
    // Smoothstep: transicion de bioma mas suave/natural que un lerp lineal.
    let blend = mountain_factor * mountain_factor * (3.0 - 2.0 * mountain_factor);

    let plains_h =
        PLAINS_BASE + PLAINS_AMPLITUDE * plains_noise.get([wx * PLAINS_FREQ, wz * PLAINS_FREQ]) as f32;

    let mountain_raw = MOUNTAIN_BASE
        + MOUNTAIN_AMPLITUDE * mountain_noise.get([wx * MOUNTAIN_FREQ, wz * MOUNTAIN_FREQ]) as f32;
    let mountain_h = terrace(mountain_raw, TERRACE_STEP, TERRACE_STRENGTH);

    plains_h * (1.0 - blend) + mountain_h * blend
}

/// Mezcla una altura con una version "escalonada" (redondeada a multiplos de
/// `step`), creando plataformas planas cada cierta altura - asi hasta las
/// zonas montañosas tienen espacio para construir, en vez de terminar en un
/// pico puntiagudo sin nada alrededor. `strength` en [0, 1]: 0 = sin aterrazar
/// (suave), 1 = totalmente escalonado.
fn terrace(height: f32, step: f32, strength: f32) -> f32 {
    let stepped = (height / step).round() * step;
    height * (1.0 - strength) + stepped * strength
}


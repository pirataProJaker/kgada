use godot::prelude::*;
use lin_alg::f32::Vec3;
use mcubes::{MarchingCubes, MeshSide};
use noise::{Fbm, MultiFractal, NoiseFn, Perlin};

// Frecuencia muy baja para biomas grandes (un ciclo completo ~667m, biomas extensos).
const BIOME_FREQ: f64 = 0.0015;

// Alturas discretas fijas de cada meseta (en metros/bloques):
// Nivel 0 (Costa / Valle Bajo): 5.0m
// Nivel 1 (Llanura / Ciudad / Base): 10.0m
// Nivel 2 (Meseta Alta): 15.0m
// Nivel 3 (Altiplano Superior): 20.0m
const HEIGHT_VALLEY: f32 = 5.0;
const HEIGHT_PLAINS: f32 = 10.0;
const HEIGHT_PLATEAU: f32 = 15.0;
const HEIGHT_HIGHLANDS: f32 = 20.0;

// Ancho de la zona de transicion suave (smoothstep) entre biomas en espacio de ruido.
const TRANSITION_MARGIN: f32 = 0.035;

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

        // Ruido de bioma a frecuencia muy baja (extensas mesetas continuas).
        let biome_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(100))
            .set_octaves(2)
            .set_persistence(0.5);

        // Empaquetado plano: el indice debe ser x + y*dims + z*dims*dims,
        // por eso el orden de los bucles es z (mas externo), y, x (mas interno).
        for z in 0..dims {
            for y in 0..dims {
                for x in 0..dims {
                    let wx = chunk_origin_x as f64 + x as f64 * voxel_size as f64;
                    let wz = chunk_origin_z as f64 + z as f64 * voxel_size as f64;
                    let wy = y as f32 * voxel_size;

                    let height = compute_natural_height(wx, wz, &biome_noise);

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
        let biome_noise = Fbm::<Perlin>::new(seed_u32.wrapping_add(100))
            .set_octaves(2)
            .set_persistence(0.5);

        compute_natural_height(world_x as f64, world_z as f64, &biome_noise)
    }
}

#[inline]
fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Formula de altura natural de mesetas escalonadas:
/// Dentro de cada bioma, la superficie es 100% plana y estable (sin ruido ondulado).
/// En las fronteras de biomas, una rampa suave (smoothstep) conecta las mesetas.
fn compute_natural_height(wx: f64, wz: f64, biome_noise: &Fbm<Perlin>) -> f32 {
    let raw = biome_noise.get([wx * BIOME_FREQ, wz * BIOME_FREQ]) as f32;
    // Normalizar de [-1.0, 1.0] a [0.0, 1.0]
    let t = (raw * 0.5 + 0.5).clamp(0.0, 1.0);

    // 3 fronteras entre los 4 niveles de altura
    let split1 = 0.28; // Entre Valle (5m) y Llanura (10m)
    let split2 = 0.60; // Entre Llanura (10m) y Meseta (15m)
    let split3 = 0.85; // Entre Meseta (15m) y Altiplano (20m)

    if t < split1 - TRANSITION_MARGIN {
        HEIGHT_VALLEY
    } else if t < split1 + TRANSITION_MARGIN {
        let blend = smoothstep(split1 - TRANSITION_MARGIN, split1 + TRANSITION_MARGIN, t);
        HEIGHT_VALLEY * (1.0 - blend) + HEIGHT_PLAINS * blend
    } else if t < split2 - TRANSITION_MARGIN {
        HEIGHT_PLAINS
    } else if t < split2 + TRANSITION_MARGIN {
        let blend = smoothstep(split2 - TRANSITION_MARGIN, split2 + TRANSITION_MARGIN, t);
        HEIGHT_PLAINS * (1.0 - blend) + HEIGHT_PLATEAU * blend
    } else if t < split3 - TRANSITION_MARGIN {
        HEIGHT_PLATEAU
    } else if t < split3 + TRANSITION_MARGIN {
        let blend = smoothstep(split3 - TRANSITION_MARGIN, split3 + TRANSITION_MARGIN, t);
        HEIGHT_PLATEAU * (1.0 - blend) + HEIGHT_HIGHLANDS * blend
    } else {
        HEIGHT_HIGHLANDS
    }
}

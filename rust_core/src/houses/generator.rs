use godot::prelude::*;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use super::types::*;

pub struct HouseBlueprint {
    pub seed: u64,
    pub grid: HouseGrid,
    pub zone: HouseZoneType,
    pub floor_height: f32,
    pub total_floors: u8,
    pub has_terrace: bool,
    pub main_door_pos: (usize, usize),
    pub rooms: Vec<HouseRoom>,
    pub room_map_floor1: Vec<u8>,
    pub room_map_floor2: Vec<u8>,
    pub palette: HousePalette,
}

pub struct HouseGeneratorCore;

impl HouseGeneratorCore {
    /// Genera la huella y distribución volumétrica de la casa mediante agregación orgánica de cuartos.
    /// Respeta prioridades funcionales, permite que los cuartos rompan la caja hacia el terreno libre,
    /// y genera siluetas ricas en L, T, U y 2 pisos asimétricos con terrazas.
    pub fn generate(
        width: usize,
        depth: usize,
        zone: HouseZoneType,
        seed: u64,
    ) -> HouseBlueprint {
        let mut rng = StdRng::seed_from_u64(seed);
        let mut grid = HouseGrid::new(width, depth);

        let floor_h = match zone {
            HouseZoneType::ZonaX => 3.40,
            _ => 2.80,
        };

        // 1. Generación Orgánica de Cuartos según Tipología
        let (mut rooms, total_floors, main_door_pos) = match zone {
            HouseZoneType::ColoniaVieja => Self::generate_colonia_vieja_rooms(width, depth, &mut rng),
            HouseZoneType::ColoniaNueva => Self::generate_colonia_nueva_rooms(width, depth, &mut rng),
            HouseZoneType::ZonaX => Self::generate_zona_x_rooms(width, depth, &mut rng),
        };

        let mut map_f1 = vec![0u8; width * depth];
        let mut map_f2 = vec![0u8; width * depth];

        // 2. Mapear cuartos a las celdas de la cuadrícula y mapas de piso
        for r in &rooms {
            for z in r.z_min..r.z_max {
                for x in r.x_min..r.x_max {
                    if x < width && z < depth {
                        if r.floor == 1 {
                            map_f1[z * width + x] = r.id;
                        } else if r.floor == 2 {
                            // Planta Alta sólo se construye donde existe Planta Baja debajo
                            if map_f1[z * width + x] > 0 {
                                map_f2[z * width + x] = r.id;
                            }
                        }
                    }
                }
            }
        }

        // 3. Sanitizar cuartos para garantizar ergonomía y dimensiones mínimas
        Self::sanitize_rooms(&mut rooms, &mut map_f1, width, depth, 1);
        if total_floors >= 2 {
            for z in 0..depth {
                for x in 0..width {
                    if map_f1[z * width + x] == 0 {
                        map_f2[z * width + x] = 0;
                    }
                }
            }
            Self::sanitize_rooms(&mut rooms, &mut map_f2, width, depth, 2);
        }

        // 4. Sincronizar cuadrícula 3D estrictamente con los mapas finales de cuartos
        for z in 0..depth {
            for x in 0..width {
                if map_f2[z * width + x] > 0 {
                    grid.set(x, z, CellHeight::Floor2);
                } else if map_f1[z * width + x] > 0 {
                    grid.set(x, z, CellHeight::Floor1);
                } else {
                    grid.set(x, z, CellHeight::Empty);
                }
            }
        }

        // 5. Seleccionar paleta arquitectónica calibrada
        let palette = Self::pick_palette(zone, &mut rng);

        let has_terrace = grid.cells.iter().any(|c| *c == CellHeight::Floor1)
            && grid.cells.iter().any(|c| *c == CellHeight::Floor2);

        HouseBlueprint {
            seed,
            grid,
            zone,
            floor_height: floor_h,
            total_floors,
            has_terrace,
            main_door_pos,
            rooms,
            room_map_floor1: map_f1,
            room_map_floor2: map_f2,
            palette,
        }
    }

    /// Colonia Vieja: Casas de barrio tradicional con muros ciegos laterales (pared con pared).
    /// Siluetas en L (patio lateral trasero), U (patio central colonial) o rectangular con patio posterior.
    fn generate_colonia_vieja_rooms(
        w: usize,
        d: usize,
        rng: &mut StdRng,
    ) -> (Vec<HouseRoom>, u8, (usize, usize)) {
        let mut rooms = Vec::new();
        let mut next_id = 1u8;

        if w < 5 || d < 8 {
            let r = HouseRoom {
                id: next_id,
                room_type: RoomType::LivingRoom,
                floor: 1,
                x_min: 0,
                z_min: 0,
                x_max: w,
                z_max: d.min(6),
            };
            rooms.push(r);
            return (rooms, 1, (w / 2, 0));
        }

        // Patio trasero mínimo de 4 a 6 metros
        let rear_yard = rng.gen_range(4..=6).min(d.saturating_sub(7));
        let max_d = d.saturating_sub(rear_yard);

        // Crujía frontal obligatoria (pared con pared, x = 0..w)
        let front_d = rng.gen_range(5..=6).min(max_d.saturating_sub(2));
        let split_x = rng.gen_range(4..=(w.saturating_sub(4))).clamp(3, w.saturating_sub(3));
        let dining_d = 3usize.min(front_d.saturating_sub(2));

        // 1. Habitación frontal izquierda: Sala (LivingRoom)
        let living_id = next_id;
        next_id += 1;
        rooms.push(HouseRoom {
            id: living_id,
            room_type: RoomType::LivingRoom,
            floor: 1,
            x_min: 0,
            z_min: 0,
            x_max: split_x,
            z_max: front_d,
        });

        // 2. Habitación frontal derecha: Comedor (DiningRoom)
        // Adyacente a la Sala, sin muro divisorio intermedio (concepto abierto)
        let dining_id = next_id;
        next_id += 1;
        rooms.push(HouseRoom {
            id: dining_id,
            room_type: RoomType::DiningRoom,
            floor: 1,
            x_min: split_x,
            z_min: 0,
            x_max: w,
            z_max: dining_d,
        });

        // 3. Cocina compacta (Kitchen) detrás del Comedor
        // Cuenta con murete de separación abierto hacia el comedor y muro ciego hacia la sala
        let kitchen_id = next_id;
        next_id += 1;
        rooms.push(HouseRoom {
            id: kitchen_id,
            room_type: RoomType::Kitchen,
            floor: 1,
            x_min: split_x,
            z_min: dining_d,
            x_max: w,
            z_max: front_d,
        });

        let main_door_pos = (split_x / 2, 0);

        // Elegir arquetipo de silueta para el crecimiento hacia el patio
        let archetype = rng.gen_range(0..=3);

        match archetype {
            0 => {
                // ARQUETIPO L-SHAPE TRASERO IZQUIERDO (40% de casos):
                // El ala izquierda se proyecta hacia el fondo, el lado derecho queda como patio esquinero
                let wing_w = split_x;
                let bed_d = rng.gen_range(3..=4).min(max_d.saturating_sub(front_d + 2));
                let bed_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: 0,
                    z_min: front_d,
                    x_max: wing_w,
                    z_max: front_d + bed_d,
                });

                // Baño al fondo del ala (ventilado hacia el patio lateral)
                let bath_d = (max_d - (front_d + bed_d)).clamp(2, 3);
                if bath_d >= 2 {
                    let bath_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bath_id,
                        room_type: RoomType::Bathroom,
                        floor: 1,
                        x_min: 0,
                        z_min: front_d + bed_d,
                        x_max: wing_w,
                        z_max: front_d + bed_d + bath_d,
                    });
                }
            }
            1 => {
                // ARQUETIPO L-SHAPE TRASERO DERECHO (30% de casos):
                // El ala derecha se proyecta hacia el fondo, el lado izquierdo queda como patio esquinero
                let wing_x0 = split_x;
                let wing_x1 = w;
                let bed_d = rng.gen_range(3..=4).min(max_d.saturating_sub(front_d + 2));
                let bed_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: wing_x0,
                    z_min: front_d,
                    x_max: wing_x1,
                    z_max: front_d + bed_d,
                });

                let bath_d = (max_d - (front_d + bed_d)).clamp(2, 3);
                if bath_d >= 2 {
                    let bath_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bath_id,
                        room_type: RoomType::Bathroom,
                        floor: 1,
                        x_min: wing_x0,
                        z_min: front_d + bed_d,
                        x_max: wing_x1,
                        z_max: front_d + bed_d + bath_d,
                    });
                }
            }

            _ => {
                // ARQUETIPO RECTANGULAR TRADICIONAL COMPACTO (10%):
                let rear_d = max_d - front_d;
                if rear_d >= 4 {
                    let bath_w = 3usize.min(w / 3);
                    let bath_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bath_id,
                        room_type: RoomType::Bathroom,
                        floor: 1,
                        x_min: w - bath_w,
                        z_min: front_d,
                        x_max: w,
                        z_max: front_d + 2,
                    });

                    let bed1_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed1_id,
                        room_type: RoomType::Bedroom,
                        floor: 1,
                        x_min: 0,
                        z_min: front_d,
                        x_max: split_x,
                        z_max: max_d,
                    });

                    let bed2_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed2_id,
                        room_type: RoomType::Bedroom,
                        floor: 1,
                        x_min: split_x,
                        z_min: front_d + 2,
                        x_max: w,
                        z_max: max_d,
                    });
                }
            }
        }

        // --- PLANTA ALTA EN COLONIA VIEJA (~45% de probabilidad) ---
        let has_floor2 = rng.gen_bool(0.45);
        let total_floors = if has_floor2 { 2 } else { 1 };

        if has_floor2 {
            let f2_mode = rng.gen_range(0..=2);
            match f2_mode {
                0 => {
                    // MODO CRUJÍA FRONTAL COMPLETA (0..w, 0..front_d)
                    let bed1_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed1_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: 0,
                        z_min: 0,
                        x_max: split_x,
                        z_max: front_d,
                    });
                    let bed2_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed2_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: split_x,
                        z_min: 0,
                        x_max: w,
                        z_max: front_d,
                    });
                }
                1 => {
                    // MODO TORRE FRONTAL IZQUIERDA (0..split_x, 0..front_d)
                    let bed_up_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed_up_id,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: 0,
                        z_min: 0,
                        x_max: split_x,
                        z_max: front_d,
                    });
                }
                _ => {
                    // MODO TORRE FRONTAL DERECHA (split_x..w, 0..front_d)
                    let bed_up_id = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed_up_id,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: split_x,
                        z_min: 0,
                        x_max: w,
                        z_max: front_d,
                    });
                }
            }
        }

        (rooms, total_floors, main_door_pos)
    }

    /// Colonia Nueva (Infonavit): Lotes de 7x15m con pasillo lateral exterior de 1m y retiro de cochera.
    /// Siluetas en L frontal con porche techado, L posterior con zotehuela lateral, o 2 pisos con balcón.
    fn generate_colonia_nueva_rooms(
        w: usize,
        d: usize,
        rng: &mut StdRng,
    ) -> (Vec<HouseRoom>, u8, (usize, usize)) {
        let mut rooms = Vec::new();
        let mut next_id = 1u8;

        if w < 5 || d < 8 {
            let r = HouseRoom {
                id: next_id,
                room_type: RoomType::LivingRoom,
                floor: 1,
                x_min: 0,
                z_min: 2,
                x_max: w,
                z_max: d.min(8),
            };
            rooms.push(r);
            return (rooms, 1, (w / 2, 2));
        }

        // Pasillo de servicio lateral exterior de 1 metro
        let service_left = rng.gen_bool(0.5);
        let min_x = if service_left { 1 } else { 0 };
        let max_x = if service_left { w } else { w - 1 };
        let mid_x = min_x + 3;

        let front_z = rng.gen_range(2..=3);
        let rear_yard = rng.gen_range(2..=3);
        let max_z = (d.saturating_sub(rear_yard)).max(front_z + 8);

        let archetype = rng.gen_range(0..=2);
        let main_door_pos;

        match archetype {
            0 => {
                // ARQUETIPO 0: L-SHAPE FRONTAL CON COCHERA/PORCHE REMETIDO (~45%):
                let protrude_left = rng.gen_bool(0.5);
                let (front_wing_x0, front_wing_x1, porch_x0, porch_x1) = if protrude_left {
                    (min_x, mid_x, mid_x, max_x)
                } else {
                    (mid_x, max_x, min_x, mid_x)
                };

                // Ala saliente frontal: Recámara 1 o Estudio al frente
                let bed1_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed1_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: front_wing_x0,
                    z_min: front_z,
                    x_max: front_wing_x1,
                    z_max: front_z + 2,
                });

                // Comedor adyacente a la Sala en el ala saliente
                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: front_wing_x0,
                    z_min: front_z + 2,
                    x_max: front_wing_x1,
                    z_max: front_z + 5,
                });

                // Ala remetida: Sala de acceso en porche (concepto abierto con Comedor)
                let living_z0 = front_z + 2;
                let living_z1 = living_z0 + 4;
                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: porch_x0,
                    z_min: living_z0,
                    x_max: porch_x1,
                    z_max: living_z1,
                });

                main_door_pos = (porch_x0 + 1, living_z0);

                // Cocina compacta (3m x 2m) detrás del Comedor con vano abierto
                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: front_wing_x0,
                    z_min: front_z + 5,
                    x_max: front_wing_x1,
                    z_max: front_z + 7,
                });

                // Zona posterior: Baño detrás de la Sala
                let bath_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_id,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: porch_x0,
                    z_min: living_z1,
                    x_max: porch_x1,
                    z_max: living_z1 + 2,
                });

                let bed2_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed2_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: front_wing_x0,
                    z_min: front_z + 7,
                    x_max: front_wing_x1,
                    z_max: max_z.max(front_z + 10),
                });
            }
            1 => {
                // ARQUETIPO 1: L-SHAPE POSTERIOR CON ZOTEHUELA EN ESCUADRA (~35%):
                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: mid_x,
                    z_max: front_z + 5,
                });

                // Comedor adyacente a Sala (concepto abierto sin pared)
                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z,
                    x_max: max_x,
                    z_max: front_z + 3,
                });

                // Cocina compacta (3m x 2m) detrás del Comedor con murete de paso abierto
                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z + 3,
                    x_max: max_x,
                    z_max: front_z + 5,
                });

                main_door_pos = (min_x + 1, front_z);

                // Baño al centro
                let bath_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_id,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z + 5,
                    x_max: max_x,
                    z_max: front_z + 7,
                });

                // Solo el lado izquierdo se proyecta al patio (L-Shape posterior)
                let bed_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z + 5,
                    x_max: mid_x,
                    z_max: max_z,
                });
            }
            _ => {
                // ARQUETIPO 2: INFONAVIT COMPACTO RECTANGULAR (~20%):
                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: mid_x,
                    z_max: front_z + 5,
                });

                // Comedor adyacente a Sala (concepto abierto sin pared)
                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z,
                    x_max: max_x,
                    z_max: front_z + 3,
                });

                // Cocina compacta (3m x 2m) detrás del Comedor con murete de paso abierto
                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z + 3,
                    x_max: max_x,
                    z_max: front_z + 5,
                });

                main_door_pos = (min_x + 1, front_z);

                let bath_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_id,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z + 5,
                    x_max: mid_x,
                    z_max: front_z + 7,
                });

                let bed_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: mid_x,
                    z_min: front_z + 5,
                    x_max: max_x,
                    z_max: max_z,
                });
            }
        }

        // --- PLANTA ALTA EN INFONAVIT (~55% de probabilidad) ---
        let has_floor2 = rng.gen_bool(0.55);
        let total_floors = if has_floor2 { 2 } else { 1 };

        if has_floor2 {
            let f2_mode = rng.gen_range(0..=2);
            match f2_mode {
                0 => {
                    // MODO TERRAZA FRONTAL SOBRE COCHERA (~50%):
                    let f2_start_z = front_z + 2;
                    let bed1_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed1_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: min_x,
                        z_min: f2_start_z,
                        x_max: mid_x,
                        z_max: f2_start_z + 4,
                    });

                    let bath_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bath_up,
                        room_type: RoomType::Bathroom,
                        floor: 2,
                        x_min: mid_x,
                        z_min: f2_start_z,
                        x_max: max_x,
                        z_max: f2_start_z + 2,
                    });

                    let bed2_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed2_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: mid_x,
                        z_min: f2_start_z + 2,
                        x_max: max_x,
                        z_max: f2_start_z + 5,
                    });
                }
                1 => {
                    // MODO TORRE LATERAL EN "L" (~30%):
                    let bed1_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed1_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: min_x,
                        z_min: front_z,
                        x_max: mid_x,
                        z_max: front_z + 4,
                    });

                    let bed2_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed2_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: min_x,
                        z_min: front_z + 4,
                        x_max: mid_x,
                        z_max: front_z + 7,
                    });
                }
                _ => {
                    // MODO COMPLETO (~20%):
                    let bed1_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed1_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: min_x,
                        z_min: front_z,
                        x_max: mid_x,
                        z_max: front_z + 4,
                    });
                    let bed2_up = next_id; next_id += 1;
                    rooms.push(HouseRoom {
                        id: bed2_up,
                        room_type: RoomType::Bedroom,
                        floor: 2,
                        x_min: mid_x,
                        z_min: front_z,
                        x_max: max_x,
                        z_max: front_z + 4,
                    });
                }
            }
        }

        (rooms, total_floors, main_door_pos)
    }

    /// Zona X (Residencial de Lujo): Terrenos grandes, aislados a 4 vientos con amplios jardines.
    /// Mansiones contemporáneas en L monumental, U con patio/alberca central, o pabellones escalonados.
    fn generate_zona_x_rooms(
        w: usize,
        d: usize,
        rng: &mut StdRng,
    ) -> (Vec<HouseRoom>, u8, (usize, usize)) {
        let mut rooms = Vec::new();
        let mut next_id = 1u8;

        let margin_x = rng.gen_range(2..=3).min(w / 4);
        let min_x = margin_x;
        let max_x = w - margin_x;

        let front_z = rng.gen_range(4..=5).min(d / 4);
        let rear_yard = rng.gen_range(5..=7).min(d / 3);
        let max_z = d.saturating_sub(rear_yard);

        let build_w = max_x - min_x;
        let build_d = max_z - front_z;

        if build_w < 8 || build_d < 8 {
            let r = HouseRoom {
                id: next_id,
                room_type: RoomType::LivingRoom,
                floor: 1,
                x_min: min_x,
                z_min: front_z,
                x_max: max_x,
                z_max: max_z,
            };
            rooms.push(r);
            return (rooms, 1, ((min_x + max_x) / 2, front_z));
        }

        let archetype = rng.gen_range(0..=2);
        let main_door_pos;

        match archetype {
            0 => {
                // ARQUETIPO 0: GRAN MANSIÓN EN "L" MONUMENTAL CON JARDÍN EN ESCUADRA (~45%):
                let front_d = rng.gen_range(4..=5).min(build_d / 2);
                let foyer_w = build_w / 3;

                // Foyer / Gran Sala
                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: min_x + foyer_w,
                    z_max: front_z + front_d,
                });
                main_door_pos = (min_x + foyer_w / 2, front_z);

                // Comedor
                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: min_x + foyer_w,
                    z_min: front_z,
                    x_max: min_x + foyer_w * 2,
                    z_max: front_z + front_d,
                });

                // Cocina gourmet
                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: min_x + foyer_w * 2,
                    z_min: front_z,
                    x_max: max_x,
                    z_max: front_z + front_d,
                });

                // Ala Longitudinal Privada (se extiende hacia el jardín trasero)
                let wing_left = rng.gen_bool(0.5);
                let (wing_x0, wing_x1) = if wing_left {
                    (min_x, min_x + foyer_w.max(5))
                } else {
                    (max_x.saturating_sub(foyer_w.max(5)), max_x)
                };

                let suite_d = ((max_z - (front_z + front_d)) / 2).max(3);

                // Master Suite en planta baja
                let suite_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: suite_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: wing_x0,
                    z_min: front_z + front_d,
                    x_max: wing_x1,
                    z_max: front_z + front_d + suite_d,
                });

                // Baño Principal Amplio en Suite (ocupa todo el ancho, sin estudio apretado)
                let bath_spa_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_spa_id,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: wing_x0,
                    z_min: front_z + front_d + suite_d,
                    x_max: wing_x1,
                    z_max: max_z,
                });
            }
            1 => {
                // ARQUETIPO 1: RESIDENCIA EN "U" CON PATIO / ALBERCA CENTRAL (~35%):
                let front_d = 4usize.min(build_d / 2);
                let wing_w = 4usize.min(build_w / 3);

                // Pabellón Central: Sala y Comedor
                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: min_x + build_w / 2,
                    z_max: front_z + front_d,
                });
                main_door_pos = (min_x + build_w / 4, front_z);

                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: min_x + build_w / 2,
                    z_min: front_z,
                    x_max: max_x,
                    z_max: front_z + front_d,
                });

                // Ala Izquierda: Cocina + Lavandería
                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z + front_d,
                    x_max: min_x + wing_w,
                    z_max: max_z,
                });

                // Ala Derecha: Master Suite + Baño
                let suite_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: suite_id,
                    room_type: RoomType::Bedroom,
                    floor: 1,
                    x_min: max_x - wing_w,
                    z_min: front_z + front_d,
                    x_max: max_x,
                    z_max: front_z + front_d + 4,
                });

                let bath_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_id,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: max_x - wing_w,
                    z_min: front_z + front_d + 4,
                    x_max: max_x,
                    z_max: max_z,
                });
            }
            _ => {
                // ARQUETIPO 2: SILUETA ESCALONADA EN "T" (~20%):
                let foyer_w = build_w / 2;
                let foyer_x0 = min_x + build_w / 4;
                let foyer_x1 = foyer_x0 + foyer_w;

                let living_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: living_id,
                    room_type: RoomType::LivingRoom,
                    floor: 1,
                    x_min: foyer_x0,
                    z_min: front_z,
                    x_max: foyer_x1,
                    z_max: front_z + 4,
                });
                main_door_pos = ((foyer_x0 + foyer_x1) / 2, front_z);

                // Alas traseras amplias
                let dining_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: dining_id,
                    room_type: RoomType::DiningRoom,
                    floor: 1,
                    x_min: min_x,
                    z_min: front_z + 4,
                    x_max: min_x + build_w / 2,
                    z_max: max_z,
                });

                let kitchen_id = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: kitchen_id,
                    room_type: RoomType::Kitchen,
                    floor: 1,
                    x_min: min_x + build_w / 2,
                    z_min: front_z + 4,
                    x_max: max_x,
                    z_max: max_z,
                });
            }
        }

        // --- PLANTA ALTA EN ZONA X (80% de probabilidad) ---
        let has_floor2 = rng.gen_bool(0.80);
        let total_floors = if has_floor2 { 2 } else { 1 };

        if has_floor2 {
            let f2_mode = rng.gen_range(0..=1);
            if f2_mode == 0 {
                // MODO ROOF GARDEN CON SUITES SUPERIORES (~60%):
                let split_f2_x = min_x + build_w / 2;
                let bed1_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed1_up,
                    room_type: RoomType::Bedroom,
                    floor: 2,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: split_f2_x,
                    z_max: front_z + 5,
                });

                let gym_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: gym_up,
                    room_type: RoomType::GymOrGames,
                    floor: 2,
                    x_min: split_f2_x,
                    z_min: front_z,
                    x_max: max_x,
                    z_max: front_z + 5,
                });
            } else {
                // MODO VOLADIZO ASIMÉTRICO / TORRE EN "L" SUPERIOR (~40%):
                let wing_up_w = build_w / 2;
                let bed1_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed1_up,
                    room_type: RoomType::Bedroom,
                    floor: 2,
                    x_min: min_x,
                    z_min: front_z,
                    x_max: min_x + wing_up_w,
                    z_max: front_z + 4,
                });

                let bed2_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed2_up,
                    room_type: RoomType::Bedroom,
                    floor: 2,
                    x_min: min_x,
                    z_min: front_z + 4,
                    x_max: min_x + wing_up_w,
                    z_max: max_z.min(front_z + 8),
                });
            }
        }

        (rooms, total_floors, main_door_pos)
    }

    /// Paletas de color arquitectónicas calibradas.
    fn pick_palette(zone: HouseZoneType, rng: &mut StdRng) -> HousePalette {
        match zone {
            HouseZoneType::ColoniaVieja => {
                let walls = [
                    Color::from_rgb(0.58, 0.42, 0.32), // Adobe tostado
                    Color::from_rgb(0.68, 0.45, 0.35), // Terracota cálido
                    Color::from_rgb(0.72, 0.65, 0.45), // Amarillo ocre tradicional
                    Color::from_rgb(0.42, 0.48, 0.52), // Azul colonial deslavado
                    Color::from_rgb(0.55, 0.52, 0.46), // Yeso clásico
                ];
                HousePalette {
                    wall_ext: walls[rng.gen_range(0..walls.len())],
                    wall_int: Color::from_rgb(0.75, 0.73, 0.68),
                    floor: Color::from_rgb(0.38, 0.36, 0.33),
                    roof: Color::from_rgb(0.32, 0.30, 0.28),
                    trim: Color::from_rgb(0.85, 0.82, 0.75),
                    door: Color::from_rgb(0.28, 0.18, 0.12), // Madera oscura
                    window_frame: Color::from_rgb(0.18, 0.18, 0.20), // Herrería negra
                    window_glass: Color::from_rgba(0.40, 0.55, 0.70, 0.80),
                    tinaco: Color::from_rgb(0.12, 0.12, 0.12), // Negro Rotoplas
                }
            }
            HouseZoneType::ColoniaNueva => {
                let walls = [
                    Color::from_rgb(0.92, 0.90, 0.86), // Estuco marfil
                    Color::from_rgb(0.85, 0.82, 0.74), // Arena cálida
                    Color::from_rgb(0.80, 0.78, 0.75), // Gris perla uniforme
                    Color::from_rgb(0.78, 0.68, 0.58), // Cantera suave
                ];
                HousePalette {
                    wall_ext: walls[rng.gen_range(0..walls.len())],
                    wall_int: Color::from_rgb(0.90, 0.89, 0.87),
                    floor: Color::from_rgb(0.52, 0.49, 0.45),
                    roof: Color::from_rgb(0.28, 0.29, 0.31),
                    trim: Color::from_rgb(0.98, 0.98, 0.98),
                    door: Color::from_rgb(0.35, 0.25, 0.18),
                    window_frame: Color::from_rgb(0.88, 0.88, 0.88), // Aluminio blanco
                    window_glass: Color::from_rgba(0.45, 0.60, 0.75, 0.80),
                    tinaco: Color::from_rgb(0.12, 0.12, 0.12),
                }
            }
            HouseZoneType::ZonaX => {
                let walls = [
                    Color::from_rgb(0.96, 0.96, 0.96), // Blanco arquitectónico
                    Color::from_rgb(0.22, 0.24, 0.26), // Antracita moderno
                    Color::from_rgb(0.84, 0.82, 0.78), // Concreto pulido
                    Color::from_rgb(0.30, 0.24, 0.18), // Madera de teca tratada
                ];
                HousePalette {
                    wall_ext: walls[rng.gen_range(0..walls.len())],
                    wall_int: Color::from_rgb(0.98, 0.98, 0.98),
                    floor: Color::from_rgb(0.82, 0.80, 0.76), // Mármol / Porcelanato
                    roof: Color::from_rgb(0.15, 0.16, 0.18),
                    trim: Color::from_rgb(0.15, 0.15, 0.15),
                    door: Color::from_rgb(0.18, 0.12, 0.08), // Puerta monumental oscura
                    window_frame: Color::from_rgb(0.12, 0.12, 0.14), // Cancelería negra mate
                    window_glass: Color::from_rgba(0.20, 0.35, 0.50, 0.85),
                    tinaco: Color::from_rgb(0.70, 0.68, 0.62), // Beige oculto
                }
            }
        }
    }

    /// Audita y absorbe de forma procedural cualquier cuarto que resulte residual o plano (w <= 1 o d <= 1 o celdas < 4).
    /// El espacio se fusiona en el cuarto contiguo más cercano (haciéndolo más espacioso), eliminando cuartos planos o pasillos ciegos.
    fn sanitize_rooms(
        rooms: &mut Vec<HouseRoom>,
        room_map: &mut [u8],
        w: usize,
        d: usize,
        floor: u8,
    ) {
        loop {
            let mut absorbed_any = false;

            let floor_rooms: Vec<(usize, u8)> = rooms
                .iter()
                .enumerate()
                .filter(|(_, r)| r.floor == floor)
                .map(|(idx, r)| (idx, r.id))
                .collect();

            for (r_idx, r_id) in floor_rooms {
                let mut cell_coords = Vec::new();
                let mut min_rx = w;
                let mut max_rx = 0;
                let mut min_rz = d;
                let mut max_rz = 0;

                for z in 0..d {
                    for x in 0..w {
                        if room_map[z * w + x] == r_id {
                            cell_coords.push((x, z));
                            min_rx = min_rx.min(x);
                            max_rx = max_rx.max(x);
                            min_rz = min_rz.min(z);
                            max_rz = max_rz.max(z);
                        }
                    }
                }

                let count = cell_coords.len();
                let actual_w = if count > 0 { max_rx + 1 - min_rx } else { 0 };
                let actual_d = if count > 0 { max_rz + 1 - min_rz } else { 0 };

                if count == 0 {
                    rooms.remove(r_idx);
                    absorbed_any = true;
                    break;
                }

                if actual_w <= 1 || actual_d <= 1 || count < 4 {
                    // Buscar cuarto contiguo en las 4 direcciones cardinales
                    let mut neighbor_id = None;
                    for &(cx, cz) in &cell_coords {
                        let neighbors = [
                            (cx as i32, cz as i32 - 1),
                            (cx as i32, cz as i32 + 1),
                            (cx as i32 - 1, cz as i32),
                            (cx as i32 + 1, cz as i32),
                        ];
                        for (nx, nz) in neighbors {
                            if nx >= 0 && nx < w as i32 && nz >= 0 && nz < d as i32 {
                                let nid = room_map[nz as usize * w + nx as usize];
                                if nid > 0 && nid != r_id {
                                    neighbor_id = Some(nid);
                                    break;
                                }
                            }
                        }
                        if neighbor_id.is_some() {
                            break;
                        }
                    }

                    if let Some(target_nid) = neighbor_id {
                        // Reasignar celdas al vecino
                        for (cx, cz) in cell_coords {
                            room_map[cz * w + cx] = target_nid;
                        }
                        if let Some(target) = rooms.iter_mut().find(|r| r.id == target_nid && r.floor == floor) {
                            target.x_min = target.x_min.min(min_rx);
                            target.x_max = target.x_max.max(max_rx + 1);
                            target.z_min = target.z_min.min(min_rz);
                            target.z_max = target.z_max.max(max_rz + 1);
                        }
                    } else {
                        for (cx, cz) in cell_coords {
                            room_map[cz * w + cx] = 0;
                        }
                    }

                    rooms.remove(r_idx);
                    absorbed_any = true;
                    break;
                }
            }

            if !absorbed_any {
                break;
            }
        }
    }
}

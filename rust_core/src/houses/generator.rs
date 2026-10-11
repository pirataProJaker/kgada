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
    pub stair: Option<StairData>,
    pub commercial_meta: Option<CommercialMetadata>,
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
            HouseZoneType::CommercialConvenience => 3.20,
            _ => 2.80,
        };

        // 1. Generación Orgánica de Cuartos según Tipología
        let (mut rooms, total_floors, main_door_pos, comm_meta) = match zone {
            HouseZoneType::ColoniaVieja => {
                let (r, tf, dp) = Self::generate_colonia_vieja_rooms(width, depth, &mut rng);
                (r, tf, dp, None)
            }
            HouseZoneType::ColoniaNueva => {
                let (r, tf, dp) = Self::generate_colonia_nueva_rooms(width, depth, &mut rng);
                (r, tf, dp, None)
            }
            HouseZoneType::ZonaX => {
                let (r, tf, dp) = Self::generate_zona_x_rooms(width, depth, &mut rng);
                (r, tf, dp, None)
            }
            HouseZoneType::CommercialConvenience => {
                let (r, tf, dp, cm) = Self::generate_commercial_convenience_rooms(width, depth, &mut rng);
                (r, tf, dp, Some(cm))
            }
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

        // 4. Integrar Núcleo de Escalera y Circulación (Pasillo / Sala TV en Planta Alta)
        let stair = if total_floors >= 2 {
            let st = Self::integrate_stairs_and_circulation(
                &mut rooms,
                &mut map_f1,
                &mut map_f2,
                &grid,
                width,
                depth,
                total_floors,
                main_door_pos,
                &mut rng,
            );
            if st.is_some() {
                Self::sanitize_rooms(&mut rooms, &mut map_f2, width, depth, 2);
            }
            st
        } else {
            None
        };

        // 5. Sincronizar cuadrícula 3D estrictamente con los mapas finales de cuartos
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

        // 6. Seleccionar paleta arquitectónica calibrada
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
            stair,
            commercial_meta: comm_meta,
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

        // --- PLANTA ALTA EN COLONIA VIEJA (~55% de probabilidad) ---
        let has_floor2 = rng.gen_bool(0.55);
        let total_floors = if has_floor2 { 2 } else { 1 };

        if has_floor2 {
            // Planta Alta amplia (75% a 85% de la casa), deja terraza posterior sobre el patio
            let f2_max_z = (max_d.saturating_sub(1)).max(front_d + 3);

            // 1. Recámaras Frontales con ventanas hacia la calle:
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

            // 2. Crujía Intermedia y Posterior de Planta Alta:
            if f2_max_z > front_d + 2 {
                let bed3_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bed3_up,
                    room_type: RoomType::Bedroom,
                    floor: 2,
                    x_min: 0,
                    z_min: front_d,
                    x_max: split_x,
                    z_max: f2_max_z,
                });

                let bath_up = next_id; next_id += 1;
                rooms.push(HouseRoom {
                    id: bath_up,
                    room_type: RoomType::Bathroom,
                    floor: 2,
                    x_min: split_x,
                    z_min: front_d,
                    x_max: w,
                    z_max: (front_d + 3).min(f2_max_z),
                });
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
            // Planta Alta amplia en Infonavit (cubre 75% a 85% de la casa desde front_z hasta max_z - 1)
            let f2_max_z = (max_z.saturating_sub(1)).max(front_z + 6);
            let mid_f2_z = front_z + (f2_max_z - front_z) / 2;

            // Recámara 1 (Frontal / Principal con vista a la calle):
            let bed1_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bed1_up,
                room_type: RoomType::Bedroom,
                floor: 2,
                x_min: min_x,
                z_min: front_z,
                x_max: max_x,
                z_max: mid_f2_z,
            });

            // Baño Completo en Planta Alta:
            let bath_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bath_up,
                room_type: RoomType::Bathroom,
                floor: 2,
                x_min: min_x,
                z_min: mid_f2_z,
                x_max: mid_x,
                z_max: (mid_f2_z + 2).min(f2_max_z),
            });

            // Recámara 2 (Posterior con vista al patio):
            let bed2_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bed2_up,
                room_type: RoomType::Bedroom,
                floor: 2,
                x_min: mid_x,
                z_min: mid_f2_z,
                x_max: max_x,
                z_max: f2_max_z,
            });
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
            // Planta Alta amplia en Zona X (cubre 75% a 85% de la mansión, dejando terraza con vista al jardín/alberca)
            let f2_max_z = (max_z.saturating_sub(2)).max(front_z + 8);
            let split_f2_x = min_x + build_w / 2;
            let mid_f2_z = front_z + (f2_max_z - front_z) / 2;

            // Recámara Principal / Master Suite (Frontal Izquierda, con vista y balcón):
            let bed1_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bed1_up,
                room_type: RoomType::Bedroom,
                floor: 2,
                x_min: min_x,
                z_min: front_z,
                x_max: split_f2_x,
                z_max: mid_f2_z,
            });

            // Junior Suite / Recámara 2 (Frontal Derecha):
            let bed2_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bed2_up,
                room_type: RoomType::Bedroom,
                floor: 2,
                x_min: split_f2_x,
                z_min: front_z,
                x_max: max_x,
                z_max: mid_f2_z,
            });

            // Gimnasio / Sala de Juegos / Estudio (Posterior Izquierda):
            let gym_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: gym_up,
                room_type: RoomType::GymOrGames,
                floor: 2,
                x_min: min_x,
                z_min: mid_f2_z,
                x_max: split_f2_x,
                z_max: f2_max_z,
            });

            // Suite de Huéspedes / Recámara 3 (Posterior Derecha):
            let bed3_up = next_id; next_id += 1;
            rooms.push(HouseRoom {
                id: bed3_up,
                room_type: RoomType::Bedroom,
                floor: 2,
                x_min: split_f2_x,
                z_min: mid_f2_z,
                x_max: max_x,
                z_max: f2_max_z,
            });
        }

        (rooms, total_floors, main_door_pos)
    }

    /// Tienda de Conveniencia (OTXO):
    /// Distribución comercial con retiro para estacionamiento frontal o en "L" (doble calle),
    /// tótem gigante en la esquina de máxima visibilidad, marquesina perimetral,
    /// amplio piso de venta abierto, cuarto frío de refrigeradores, bodega y baño.
    fn generate_commercial_convenience_rooms(
        w: usize,
        d: usize,
        rng: &mut StdRng,
    ) -> (Vec<HouseRoom>, u8, (usize, usize), CommercialMetadata) {
        let mut rooms = Vec::new();
        let mut meta = CommercialMetadata::default();

        let to_world_x = |x: f32| -> f32 { x - (w as f32 * 0.5) };
        let to_world_z = |z: f32| -> f32 { z - (d as f32 * 0.5) };

        // 1. Evaluar si el lote permite doble estacionamiento en "L" (en esquina)
        // Se requieren al menos 16m x 16m para tener 5m de cajón + 1m de banqueta en ambos ejes
        // sin ahogar el edificio de la tienda.
        let allow_l_parking = w >= 16 && d >= 16;
        let use_l_parking = allow_l_parking && rng.gen_bool(0.70);

        let (b_xmin, b_xmax, b_zmin, b_zmax);
        let door_pos: (usize, usize);
        let corner_west = rng.gen_bool(0.5);

        let rear_yard = if d >= 24 { rng.gen_range(1..=3) } else { 0 };
        let lot_b_zmax = d.saturating_sub(rear_yard);

        if use_l_parking {
            // Caso Esquina con Doble Estacionamiento en "L"

            let park_d = 5usize;
            let park_w = 5usize;
            let sw_d = 1usize; // Banqueta 1m
            let sw_w = 1usize;

            if corner_west {
                // Estacionamiento al Sur (frente) y al Oeste (lateral)
                b_xmin = park_w + sw_w; // e.g. 6
                b_xmax = w;
                b_zmin = park_d + sw_d; // e.g. 6
                b_zmax = lot_b_zmax;

                // A. Tótem gigante en la esquina extrema exterior (1.8, 1.8)
                let totem_pos = Vector3::new(to_world_x(1.8), 0.0, to_world_z(1.8));
                let totem_h = rng.gen_range(8.0..=10.0);
                let totem_rot = std::f32::consts::PI * 0.25; // Ángulo hacia el cruce
                meta.totem_sign = Some(TotemSignData {
                    position: totem_pos,
                    height: totem_h,
                    rotation_y: totem_rot,
                });

                // B. Cajones Frontales (a lo largo de X, orientados al Norte)
                let front_bays_start_x = b_xmin as f32;
                let front_bays_end_x = b_xmax as f32;
                let front_avail = front_bays_end_x - front_bays_start_x;
                let num_front_bays = ((front_avail - 0.5) / 2.5).floor() as usize;
                for i in 0..num_front_bays {
                    let bay_cx = front_bays_start_x + 1.25 + (i as f32) * 2.5;
                    let bay_cz = 2.5;
                    meta.parking_bays.push(ParkingBayData {
                        position: Vector3::new(to_world_x(bay_cx), 0.02, to_world_z(bay_cz)),
                        size: Vector2::new(2.5, 5.0),
                        rotation_y: 0.0,
                    });
                }

                // C. Cajones Laterales Oeste (a lo largo de Z, orientados al Este)
                let side_bays_start_z = b_zmin as f32;
                let side_bays_end_z = b_zmax as f32;
                let side_avail = side_bays_end_z - side_bays_start_z;
                let num_side_bays = ((side_avail - 0.5) / 2.5).floor() as usize;
                for i in 0..num_side_bays {
                    let bay_cz = side_bays_start_z + 1.25 + (i as f32) * 2.5;
                    let bay_cx = 2.5;
                    meta.parking_bays.push(ParkingBayData {
                        position: Vector3::new(to_world_x(bay_cx), 0.02, to_world_z(bay_cz)),
                        size: Vector2::new(2.5, 5.0),
                        rotation_y: std::f32::consts::FRAC_PI_2,
                    });
                }

                // D. Bolardos amarillos protectores a lo largo del borde de banqueta
                let mut bx = b_xmin as f32;
                while bx <= b_xmax as f32 {
                    meta.bollards.push(Vector3::new(to_world_x(bx), 0.0, to_world_z(5.0)));
                    bx += 2.0;
                }
                let mut bz = b_zmin as f32;
                while bz <= b_zmax as f32 {
                    meta.bollards.push(Vector3::new(to_world_x(5.0), 0.0, to_world_z(bz)));
                    bz += 2.0;
                }

                // E. Banqueta perimetral elevada (+0.16m) en la L con guarnición amarilla
                let sw_y = 0.08f32;
                let sw_col = Color::from_rgb(0.76, 0.76, 0.75);
                let curb_col = Color::from_rgb(0.96, 0.78, 0.05);

                let sw_front_pos = Vector3::new(
                    to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5),
                    sw_y,
                    to_world_z(5.4),
                );
                let sw_front_size = Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 1.4);
                meta.sidewalk_boxes.push(InstanceBox { position: sw_front_pos, size: sw_front_size, color: sw_col });
                meta.sidewalk_boxes.push(InstanceBox {
                    position: Vector3::new(to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5), sw_y, to_world_z(4.65)),
                    size: Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 0.15),
                    color: curb_col,
                });

                let sw_side_pos = Vector3::new(
                    to_world_x(5.4),
                    sw_y,
                    to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
                );
                let sw_side_size = Vector3::new(1.4, 0.16, (b_zmax - b_zmin + 1) as f32);
                meta.sidewalk_boxes.push(InstanceBox { position: sw_side_pos, size: sw_side_size, color: sw_col });
                meta.sidewalk_boxes.push(InstanceBox {
                    position: Vector3::new(to_world_x(4.65), sw_y, to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5)),
                    size: Vector3::new(0.15, 0.16, (b_zmax - b_zmin + 1) as f32),
                    color: curb_col,
                });
            } else {
                // Estacionamiento al Sur y al Este
                b_xmin = 0;
                b_xmax = w - (park_w + sw_w);
                b_zmin = park_d + sw_d;
                b_zmax = lot_b_zmax;

                let totem_pos = Vector3::new(to_world_x(w as f32 - 1.8), 0.0, to_world_z(1.8));
                let totem_h = rng.gen_range(8.0..=10.0);
                let totem_rot = -std::f32::consts::PI * 0.25;
                meta.totem_sign = Some(TotemSignData {
                    position: totem_pos,
                    height: totem_h,
                    rotation_y: totem_rot,
                });

                // Cajones frontales
                let num_front_bays = ((b_xmax as f32 - 0.5) / 2.5).floor() as usize;
                for i in 0..num_front_bays {
                    let bay_cx = 1.25 + (i as f32) * 2.5;
                    let bay_cz = 2.5;
                    meta.parking_bays.push(ParkingBayData {
                        position: Vector3::new(to_world_x(bay_cx), 0.02, to_world_z(bay_cz)),
                        size: Vector2::new(2.5, 5.0),
                        rotation_y: 0.0,
                    });
                }

                // Cajones laterales Este
                let side_cx = w as f32 - 2.5;
                let num_side_bays = (((b_zmax - b_zmin) as f32 - 0.5) / 2.5).floor() as usize;
                for i in 0..num_side_bays {
                    let bay_cz = b_zmin as f32 + 1.25 + (i as f32) * 2.5;
                    meta.parking_bays.push(ParkingBayData {
                        position: Vector3::new(to_world_x(side_cx), 0.02, to_world_z(bay_cz)),
                        size: Vector2::new(2.5, 5.0),
                        rotation_y: -std::f32::consts::FRAC_PI_2,
                    });
                }

                // Bolardos
                let mut bx = b_xmin as f32;
                while bx <= b_xmax as f32 {
                    meta.bollards.push(Vector3::new(to_world_x(bx), 0.0, to_world_z(5.0)));
                    bx += 2.0;
                }
                let mut bz = b_zmin as f32;
                while bz <= b_zmax as f32 {
                    meta.bollards.push(Vector3::new(to_world_x(b_xmax as f32), 0.0, to_world_z(bz)));
                    bz += 2.0;
                }

                // Banqueta en L con guarnición amarilla
                let sw_y = 0.08f32;
                let sw_col = Color::from_rgb(0.76, 0.76, 0.75);
                let curb_col = Color::from_rgb(0.96, 0.78, 0.05);

                let sw_front_pos = Vector3::new(
                    to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5),
                    sw_y,
                    to_world_z(5.4),
                );
                let sw_front_size = Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 1.4);
                meta.sidewalk_boxes.push(InstanceBox { position: sw_front_pos, size: sw_front_size, color: sw_col });
                meta.sidewalk_boxes.push(InstanceBox {
                    position: Vector3::new(to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5), sw_y, to_world_z(4.65)),
                    size: Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 0.15),
                    color: curb_col,
                });

                let sw_side_pos = Vector3::new(
                    to_world_x(b_xmax as f32 + 0.7),
                    sw_y,
                    to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
                );
                let sw_side_size = Vector3::new(1.4, 0.16, (b_zmax - b_zmin + 1) as f32);
                meta.sidewalk_boxes.push(InstanceBox { position: sw_side_pos, size: sw_side_size, color: sw_col });
                meta.sidewalk_boxes.push(InstanceBox {
                    position: Vector3::new(to_world_x(b_xmax as f32 + 1.45), sw_y, to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5)),
                    size: Vector3::new(0.15, 0.16, (b_zmax - b_zmin + 1) as f32),
                    color: curb_col,
                });
            }
        } else {
            // Caso Estacionamiento Simple Frontal (Lotes regulares estándar: 15x20 a 15x30m, 300-450m²)
            let park_d = 5usize;
            let sw_d = 1usize;

            b_xmin = if w >= 15 { 1 } else { 0 };
            b_xmax = if w >= 15 { w - 1 } else { w };
            b_zmin = park_d + sw_d;
            b_zmax = lot_b_zmax;

            // Tótem en la esquina frontal izquierda del estacionamiento
            let totem_pos = Vector3::new(to_world_x(1.4), 0.0, to_world_z(1.4));
            let totem_h = rng.gen_range(8.0..=10.0);
            meta.totem_sign = Some(TotemSignData {
                position: totem_pos,
                height: totem_h,
                rotation_y: 0.0,
            });

            // Cajones de estacionamiento frontales en batería (estándar OTXO: 4 a 5 autos)
            let totem_margin = 2.40f32;
            let curb_margin = 0.50f32;
            let avail_w = (w as f32) - totem_margin - curb_margin;
            let target_bays = if avail_w >= 11.8 { 5 } else if avail_w >= 9.4 { 4 } else { 3 };
            let bay_w = (avail_w / target_bays as f32).min(2.50);
            for i in 0..target_bays {
                let bay_cx = totem_margin + (i as f32 * bay_w) + (bay_w * 0.5);
                meta.parking_bays.push(ParkingBayData {
                    position: Vector3::new(to_world_x(bay_cx), 0.02, to_world_z(2.5)),
                    size: Vector2::new(bay_w, 5.0),
                    rotation_y: 0.0,
                });
            }

            // Bolardos a lo largo del frente
            let mut bx = b_xmin as f32;
            while bx <= b_xmax as f32 {
                meta.bollards.push(Vector3::new(to_world_x(bx), 0.0, to_world_z(4.8)));
                bx += 2.0;
            }

            // Banqueta perimetral elevada que rodea toda la orilla del OTXO
            let sw_y = 0.08f32; // Altura de banqueta (0.16m total)
            let sw_col = Color::from_rgb(0.76, 0.76, 0.75); // Concreto claro
            let curb_col = Color::from_rgb(0.96, 0.78, 0.05); // Guarnición amarilla tráfico

            // 1. Banqueta frontal (a lo largo de toda la fachada y ventanales)
            let sw_f_pos = Vector3::new(
                to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5),
                sw_y,
                to_world_z(5.4),
            );
            let sw_f_size = Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 1.4);
            meta.sidewalk_boxes.push(InstanceBox { position: sw_f_pos, size: sw_f_size, color: sw_col });

            // Guarnición amarilla frontal hacia los cajones de estacionamiento
            let curb_f_pos = Vector3::new(
                to_world_x((b_xmin as f32 + b_xmax as f32) * 0.5),
                sw_y,
                to_world_z(4.65),
            );
            let curb_f_size = Vector3::new((b_xmax - b_xmin + 2) as f32, 0.16, 0.15);
            meta.sidewalk_boxes.push(InstanceBox { position: curb_f_pos, size: curb_f_size, color: curb_col });

            // 2. Banqueta lateral Oeste envolvente (dobla en la esquina)
            let sw_s_pos = Vector3::new(
                to_world_x(b_xmin as f32 - 0.7),
                sw_y,
                to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
            );
            let sw_s_size = Vector3::new(1.4, 0.16, (b_zmax - b_zmin + 1) as f32);
            meta.sidewalk_boxes.push(InstanceBox { position: sw_s_pos, size: sw_s_size, color: sw_col });

            // Guarnición amarilla lateral
            let curb_s_pos = Vector3::new(
                to_world_x(b_xmin as f32 - 1.45),
                sw_y,
                to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
            );
            let curb_s_size = Vector3::new(0.15, 0.16, (b_zmax - b_zmin + 1) as f32);
            meta.sidewalk_boxes.push(InstanceBox { position: curb_s_pos, size: curb_s_size, color: curb_col });

            // 3. Banqueta lateral Este si hay espacio perimetral abierto
            if b_xmax < w {
                let sw_e_pos = Vector3::new(
                    to_world_x(b_xmax as f32 + 0.7),
                    sw_y,
                    to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
                );
                let sw_e_size = Vector3::new(1.4, 0.16, (b_zmax - b_zmin + 1) as f32);
                meta.sidewalk_boxes.push(InstanceBox { position: sw_e_pos, size: sw_e_size, color: sw_col });

                let curb_e_pos = Vector3::new(
                    to_world_x(b_xmax as f32 + 1.45),
                    sw_y,
                    to_world_z((b_zmin as f32 + b_zmax as f32) * 0.5),
                );
                let curb_e_size = Vector3::new(0.15, 0.16, (b_zmax - b_zmin + 1) as f32);
                meta.sidewalk_boxes.push(InstanceBox { position: curb_e_pos, size: curb_e_size, color: curb_col });
            }
        }

        // ====================================================================
        // METADATOS DE ACCESO PROCEDURAL Y VENTANALES LATERALES
        // ====================================================================
        let b_w = b_xmax.saturating_sub(b_xmin);
        let b_d = b_zmax.saturating_sub(b_zmin);
        let back_depth = if b_d >= 14 { 5 } else if b_d >= 10 { 4 } else { 3 };
        let sales_z_end = b_zmax.saturating_sub(back_depth);

        // Lado lateral expuesto al estacionamiento / calle
        meta.lateral_parking_side = if use_l_parking {
            if corner_west { 1 } else { 2 }
        } else {
            0
        };

        // Regla procedural de ventanales en fachada lateral:
        // Si está en una esquina con estacionamiento en L, 65% de probabilidad de tener vitrales panorámicos.
        // Si no (35%), muro sólido amarillo continuo con anuncios, anaqueles o refrigeradores.
        let has_lateral_showcase = if use_l_parking {
            rng.gen_bool(0.65)
        } else {
            false
        };
        meta.has_lateral_showcase = has_lateral_showcase;
        meta.lateral_window_span = (b_zmin, sales_z_end);

        // Variabilidad en el punto de acceso frontal (Puerta principal):
        // En esquinas comerciales, los OXXOs frecuentemente tienen su acceso:
        // 1. En la esquina del edificio que da al estacionamiento y al tótem (Corner access).
        // 2. Al centro de la fachada.
        // 3. Desplazado al tercio opuesto.
        let entrance_roll: u32 = rng.gen_range(0..100);
        let (entrance_type, door_x) = if use_l_parking {
            if corner_west {
                if entrance_roll < 45 {
                    // Acceso en esquina Oeste (cercano al estacionamiento lateral y tótem)
                    let dx = (b_xmin + 2).min(b_xmax.saturating_sub(2));
                    (1u8, dx)
                } else if entrance_roll < 80 {
                    // Acceso centrado
                    (0u8, b_xmin + b_w / 2)
                } else {
                    // Acceso desplazado al Este
                    let dx = b_xmax.saturating_sub(2).max(b_xmin + 2);
                    (2u8, dx)
                }
            } else {
                if entrance_roll < 45 {
                    // Acceso en esquina Este (cercano al estacionamiento lateral Este y tótem)
                    let dx = b_xmax.saturating_sub(2).max(b_xmin + 2);
                    (1u8, dx)
                } else if entrance_roll < 80 {
                    // Acceso centrado
                    (0u8, b_xmin + b_w / 2)
                } else {
                    // Acceso desplazado al Oeste
                    let dx = (b_xmin + 2).min(b_xmax.saturating_sub(2));
                    (2u8, dx)
                }
            }
        } else {
            if entrance_roll < 60 {
                (0u8, b_xmin + b_w / 2)
            } else if entrance_roll < 80 {
                let dx = (b_xmin + 2).min(b_xmax.saturating_sub(2));
                (1u8, dx)
            } else {
                let dx = b_xmax.saturating_sub(2).max(b_xmin + 2);
                (2u8, dx)
            }
        };

        door_pos = (door_x, b_zmin);
        meta.entrance_type = entrance_type;

        // ====================================================================
        // PROPS DE ENTRADA Y MARQUESINA (Hielera, Bote de Basura, Letrero Fascia)
        // ====================================================================
        let door_wx = to_world_x(door_pos.0 as f32 + 0.5);
        let door_wz = to_world_z(door_pos.1 as f32);

        // Letrero de Fachada en la Marquesina OTXO alineado con el acceso (únicamente en la entrada)
        meta.fascia_signs.push(FasciaSignData {
            position: Vector3::new(door_wx, 3.35, door_wz - 0.48),
            size: Vector2::new(2.95, 1.80),
            rotation_y: 0.0,
        });

        // Bote de basura doble al costado de la puerta con más holgura
        let trash_x = if door_x > b_xmin + 2 { door_wx - 1.6 } else { door_wx + 1.6 };
        meta.trash_bin = Some(Vector3::new(trash_x, 0.16, door_wz - 0.55));

        // Hielera exterior en el extremo frontal opuesto al acceso
        let ice_x = if door_x < b_xmin + b_w / 2 {
            to_world_x(b_xmax as f32 - 1.3)
        } else {
            to_world_x(b_xmin as f32 + 1.3)
        };
        meta.ice_freezer = Some(Vector3::new(ice_x, 0.16, door_wz - 0.55));

        // ====================================================================
        // DISTRIBUCIÓN INTERIOR DE LA TIENDA OTXO
        // ====================================================================
        // 1. Piso de Venta (StoreFloor) - Amplio, abierto y luminoso
        rooms.push(HouseRoom {
            id: 1,
            room_type: RoomType::StoreFloor,
            floor: 1,
            x_min: b_xmin,
            z_min: b_zmin,
            x_max: b_xmax,
            z_max: sales_z_end,
        });

        // 2. Zona Trasera de Servicio: Cuarto Frío, Bodega y Baño
        // En tiendas de esquina, el cuarto frío se ubica del lado ciego para jamás
        // obstruir los ventanales de exhibición que dan a la calle lateral.
        let cold_w = (b_w * 45 / 100).max(3).min(b_w.saturating_sub(4));
        let bath_w = 2usize.min(b_w.saturating_sub(cold_w + 2));
        let store_w = b_w.saturating_sub(cold_w + bath_w);

        if use_l_parking && corner_west {
            // Lateral Oeste da a la calle: cuarto frío al Este (ciego)
            rooms.push(HouseRoom {
                id: 2,
                room_type: RoomType::ColdRoom,
                floor: 1,
                x_min: b_xmax.saturating_sub(cold_w),
                z_min: sales_z_end,
                x_max: b_xmax,
                z_max: b_zmax,
            });
            rooms.push(HouseRoom {
                id: 3,
                room_type: RoomType::Storage,
                floor: 1,
                x_min: b_xmin + bath_w,
                z_min: sales_z_end,
                x_max: b_xmax.saturating_sub(cold_w),
                z_max: b_zmax,
            });
            if bath_w > 0 {
                rooms.push(HouseRoom {
                    id: 4,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: b_xmin,
                    z_min: sales_z_end,
                    x_max: b_xmin + bath_w,
                    z_max: b_zmax,
                });
            }
        } else {
            // Cuarto frío al Oeste
            rooms.push(HouseRoom {
                id: 2,
                room_type: RoomType::ColdRoom,
                floor: 1,
                x_min: b_xmin,
                z_min: sales_z_end,
                x_max: b_xmin + cold_w,
                z_max: b_zmax,
            });
            rooms.push(HouseRoom {
                id: 3,
                room_type: RoomType::Storage,
                floor: 1,
                x_min: b_xmin + cold_w,
                z_min: sales_z_end,
                x_max: b_xmin + cold_w + store_w,
                z_max: b_zmax,
            });
            if bath_w > 0 {
                rooms.push(HouseRoom {
                    id: 4,
                    room_type: RoomType::Bathroom,
                    floor: 1,
                    x_min: b_xmin + cold_w + store_w,
                    z_min: sales_z_end,
                    x_max: b_xmax,
                    z_max: b_zmax,
                });
            }
        }

        (rooms, 1, door_pos, meta)
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
            HouseZoneType::CommercialConvenience => {
                HousePalette {
                    wall_ext: Color::from_rgb(0.96, 0.78, 0.15), // Muro amarillo institucional OTXO
                    wall_int: Color::from_rgb(0.92, 0.92, 0.90), // Blanco interior
                    floor: Color::from_rgb(0.85, 0.85, 0.82),    // Loseta comercial clara
                    roof: Color::from_rgb(0.30, 0.30, 0.32),     // Azotea industrial
                    trim: Color::from_rgb(0.85, 0.08, 0.08),     // Rojo OTXO
                    door: Color::from_rgb(0.20, 0.20, 0.22),     // Cancelería aluminio
                    window_frame: Color::from_rgb(0.18, 0.18, 0.20), // Marcos de ventanal oscuro
                    window_glass: Color::from_rgba(0.25, 0.45, 0.65, 0.65), // Vidrio comercial
                    tinaco: Color::from_rgb(0.15, 0.15, 0.15),   // Tinaco / condensadores
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
                .filter(|(_, r)| r.floor == floor && r.room_type != RoomType::Hallway)
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

    /// Integra de forma 100% procedural el núcleo de escalera entre Planta Baja y Planta Alta.
    /// Valida que la escalera nazca en un muro de la Sala, no tape la puerta principal,
    /// tenga espacio libre para ingresar (sin chocar con la pared), piso 2 construido arriba,
    /// y genere un Pasillo/Sala de TV distribuidor en Planta Alta que conecte a todas las recámaras.
    fn integrate_stairs_and_circulation(
        rooms: &mut Vec<HouseRoom>,
        map_f1: &mut [u8],
        map_f2: &mut [u8],
        _grid: &HouseGrid,
        width: usize,
        depth: usize,
        total_floors: u8,
        main_door_pos: (usize, usize),
        rng: &mut StdRng,
    ) -> Option<StairData> {
        if total_floors < 2 {
            return None;
        }

        // 1. Encontrar la Sala en Planta Baja
        let living_room = rooms
            .iter()
            .find(|r| r.floor == 1 && r.room_type == RoomType::LivingRoom)
            .cloned()?;

        let living_w = living_room.x_max.saturating_sub(living_room.x_min);
        let living_d = living_room.z_max.saturating_sub(living_room.z_min);

        #[derive(Clone)]
        struct Candidate {
            stair_type: StairType,
            x: usize,
            z: usize,
            width: usize,
            length: usize,
            orientation: u8,
        }
        let mut l_candidates = Vec::new();
        let mut straight_candidates = Vec::new();
        let mut u_candidates = Vec::new();

        // 2. Proponer candidatos para Escalera en "L" (2m x 2m en esquinas de muros)
        // La escalera en L es la favorita para casas mexicanas porque abraza la esquina
        // y deja la entrada y salida 100% libres hacia el centro del cuarto.
        if living_w >= 3 && living_d >= 3 {
            let corners = [
                // (x_corner, z_corner, orientation, entry_dx, entry_dz, exit_dx, exit_dz)
                // NW: Landing en (x, z), entrada en (x, z+1) desde Sur, salida en (x+1, z) hacia Este
                (living_room.x_min, living_room.z_min, 0u8, 0isize, 2isize, 2isize, 0isize),
                // NE: Landing en (x+1, z), entrada en (x+1, z+1) desde Sur, salida en (x, z) hacia Oeste
                (living_room.x_max.saturating_sub(2), living_room.z_min, 1u8, 1isize, 2isize, -1isize, 0isize),
                // SW: Landing en (x, z+1), entrada en (x+1, z+1) desde Este, salida en (x, z) hacia Norte
                (living_room.x_min, living_room.z_max.saturating_sub(2), 2u8, 2isize, 1isize, 0isize, -1isize),
                // SE: Landing en (x+1, z+1), entrada en (x, z+1) desde Oeste, salida en (x+1, z) hacia Norte
                (living_room.x_max.saturating_sub(2), living_room.z_max.saturating_sub(2), 3u8, -1isize, 1isize, 1isize, -1isize),
            ];

            for (cx, cz, ori, en_dx, en_dz, ex_dx, ex_dz) in corners {
                if cx + 2 > width || cz + 2 > depth {
                    continue;
                }
                // Piso 2 construido en los 4 cuadrantes
                let valid_f2 = (0..2).all(|dx| {
                    (0..2).all(|dz| {
                        let px = cx + dx;
                        let pz = cz + dz;
                        px < width && pz < depth && map_f2[pz * width + px] > 0
                    })
                });

                // Entrada libre: la celda frente al primer escalón debe estar en la Sala de PB
                let en_x = cx as isize + en_dx;
                let en_z = cz as isize + en_dz;
                let entry_clear = en_x >= 0 && (en_x as usize) < width && en_z >= 0 && (en_z as usize) < depth
                    && map_f1[(en_z as usize) * width + (en_x as usize)] == living_room.id;

                // Salida libre: la celda frente a la llegada en PA debe estar construida en Piso 2
                let ex_x = cx as isize + ex_dx;
                let ex_z = cz as isize + ex_dz;
                let exit_clear = ex_x >= 0 && (ex_x as usize) < width && ex_z >= 0 && (ex_z as usize) < depth
                    && map_f2[(ex_z as usize) * width + (ex_x as usize)] > 0;

                // No bloquear puerta principal
                let blocks_door = (0..2).any(|dx| {
                    (0..2).any(|dz| {
                        let px = cx + dx;
                        let pz = cz + dz;
                        let dist = (px as isize - main_door_pos.0 as isize).abs()
                            + (pz as isize - main_door_pos.1 as isize).abs();
                        dist <= 1
                    })
                });

                if valid_f2 && entry_clear && exit_clear && !blocks_door {
                    l_candidates.push(Candidate {
                        stair_type: StairType::LShape,
                        x: cx,
                        z: cz,
                        width: 2,
                        length: 2,
                        orientation: ori,
                    });
                }
            }
        }

        // 3. Proponer candidatos para Escalera Recta (1m ancho x 3m largo)
        // Regla estricta 1: La escalera DEBE estar adosada a una pared exterior del perímetro (NUNCA en medio de la sala ni en la división con el comedor).
        // Regla estricta 2: La bajada NUNCA debe dar contra una pared; debe haber >= 1m libre al inicio.
        if living_w >= 2 && living_d >= 4 {
            let mut possible_xs = Vec::new();
            // Verificar si el lado izquierdo de la sala es pared exterior perimetral
            let left_is_ext = living_room.x_min == 0
                || (living_room.x_min > 0 && map_f1[living_room.z_min * width + (living_room.x_min - 1)] == 0);
            if left_is_ext {
                possible_xs.push(living_room.x_min);
            }

            // Verificar si el lado derecho de la sala es pared exterior perimetral (NO el límite abierto con el comedor)
            let right_is_ext = living_room.x_max >= width
                || map_f1[living_room.z_min * width + living_room.x_max] == 0;
            if right_is_ext {
                possible_xs.push(living_room.x_max.saturating_sub(1));
            }

            // Si por geometría ninguna pared lateral es 0 (caso atípico), default al muro izquierdo
            if possible_xs.is_empty() {
                possible_xs.push(living_room.x_min);
            }

            for &x_start in &possible_xs {
                if x_start >= width {
                    continue;
                }
                // Asegurar al menos 1 celda libre antes del primer escalón (z_start > living_min)
                let min_z = living_room.z_min + 1;
                let max_z = living_room.z_max.saturating_sub(3);
                if min_z <= max_z {
                    for z_start in min_z..=max_z {
                        // Verificar que en Planta Alta haya losa construida
                        let valid_f2 = (0..3).all(|dz| {
                            let cz = z_start + dz;
                            x_start < width && cz < depth && map_f2[cz * width + x_start] > 0
                        });
                        // Entrada libre en PB en (x_start, z_start - 1)
                        let entry_clear = map_f1[(z_start - 1) * width + x_start] == living_room.id;
                        // Salida libre en PA en (x_start, z_start + 3)
                        let exit_clear = (z_start + 3) < depth && map_f2[(z_start + 3) * width + x_start] > 0;

                        // No bloquear puerta principal
                        let blocks_door = (0..3).any(|dz| {
                            let cz = z_start + dz;
                            let dist = (x_start as isize - main_door_pos.0 as isize).abs()
                                + (cz as isize - main_door_pos.1 as isize).abs();
                            dist <= 1
                        });

                        if valid_f2 && entry_clear && exit_clear && !blocks_door {
                            straight_candidates.push(Candidate {
                                stair_type: StairType::Straight,
                                x: x_start,
                                z: z_start,
                                width: 1,
                                length: 3,
                                orientation: 0,
                            });
                        }
                    }
                }
            }
        }

        // 4. Proponer candidatos para Escalera en "U" (2m ancho x 3m largo)
        if living_w >= 4 && living_d >= 4 {
            let possible_xs = [living_room.x_min, living_room.x_max.saturating_sub(2)];
            for &x_start in &possible_xs {
                if x_start + 2 > width {
                    continue;
                }
                let min_z = living_room.z_min + 1;
                let max_z = living_room.z_max.saturating_sub(3);
                if min_z <= max_z {
                    for z_start in min_z..=max_z {
                        let valid_f2 = (0..2).all(|dx| {
                            (0..3).all(|dz| {
                                let cx = x_start + dx;
                                let cz = z_start + dz;
                                cx < width && cz < depth && map_f2[cz * width + cx] > 0
                            })
                        });
                        let entry_clear = (0..2).all(|dx| {
                            map_f1[(z_start - 1) * width + (x_start + dx)] == living_room.id
                        });
                        let blocks_door = (0..2).any(|dx| {
                            (0..3).any(|dz| {
                                let cx = x_start + dx;
                                let cz = z_start + dz;
                                let dist = (cx as isize - main_door_pos.0 as isize).abs()
                                    + (cz as isize - main_door_pos.1 as isize).abs();
                                dist <= 1
                            })
                        });
                        if valid_f2 && entry_clear && !blocks_door {
                            u_candidates.push(Candidate {
                                stair_type: StairType::UShape,
                                x: x_start,
                                z: z_start,
                                width: 2,
                                length: 3,
                                orientation: 0,
                            });
                        }
                    }
                }
            }
        }

        // Preferencia arquitectónica: Escalera Recta adosada a pared exterior (85% de las veces)
        // ya que es la solución más limpia y ergonómica en residencias mexicanas
        let choice = if !straight_candidates.is_empty() && (rng.gen_bool(0.85) || (l_candidates.is_empty() && u_candidates.is_empty())) {
            straight_candidates[rng.gen_range(0..straight_candidates.len())].clone()
        } else if !l_candidates.is_empty() {
            l_candidates[rng.gen_range(0..l_candidates.len())].clone()
        } else if !u_candidates.is_empty() {
            u_candidates[rng.gen_range(0..u_candidates.len())].clone()
        } else if !straight_candidates.is_empty() {
            straight_candidates[rng.gen_range(0..straight_candidates.len())].clone()
        } else {
            return None;
        };

        // 5. Configurar el Gran Pasillo Distribuidor y Habitaciones en Planta Alta
        // En lugar de mutilar cuartos preexistentes o dejar rincones inaccesibles,
        // Planta Alta se organiza alrededor de un Gran Pasillo Distribuidor generoso y continuo.

        // Encontrar los límites de construcción de Planta Alta
        let mut f2_min_x = width;
        let mut f2_max_x = 0;
        let mut f2_min_z = depth;
        let mut f2_max_z = 0;
        for z in 0..depth {
            for x in 0..width {
                if map_f2[z * width + x] > 0 {
                    f2_min_x = f2_min_x.min(x);
                    f2_max_x = f2_max_x.max(x);
                    f2_min_z = f2_min_z.min(z);
                    f2_max_z = f2_max_z.max(z);
                }
            }
        }
        if f2_max_x < f2_min_x || f2_max_z < f2_min_z {
            return None;
        }
        f2_max_x += 1; // Exclusivo
        f2_max_z += 1; // Exclusivo

        // Limpiar cuartos anteriores de Planta Alta para reconstruirlos sin deformaciones ni esquinas muertas
        rooms.retain(|r| r.floor != 2);

        let mut next_id = rooms.iter().map(|r| r.id).max().unwrap_or(0) + 1;
        let hall_id = next_id; next_id += 1;
        let bed1_id = next_id; next_id += 1; // Recámara 1 (Principal / Frontal)
        let bed2_id = next_id; next_id += 1; // Recámara 2 (Posterior)
        let bath_id = next_id; next_id += 1; // Baño Completo Planta Alta

        // Determinar celdas del Gran Pasillo Distribuidor
        let mut hall_cells: Vec<(usize, usize)> = Vec::new();

        // 5.1 Hueco físico de la escalera
        for dx in 0..choice.width {
            for dz in 0..choice.length {
                let cx = choice.x + dx;
                let cz = choice.z + dz;
                if cx < width && cz < depth && map_f2[cz * width + cx] > 0 {
                    hall_cells.push((cx, cz));
                }
            }
        }

        // 5.2 Desembarque y Corredor Distribuidor (ancho mínimo de 1.5 a 2m, abierto al tiro de la escalera)
        let (land_start_z, land_end_z) = match choice.stair_type {
            StairType::Straight => {
                let lz = choice.z + choice.length;
                (lz, (lz + 2).min(f2_max_z))
            }
            StairType::LShape => {
                let lz = match choice.orientation {
                    0 | 2 => choice.z,
                    1 => (choice.z + choice.length).min(f2_max_z),
                    _ => choice.z.saturating_sub(1),
                };
                (lz, (lz + 2).min(f2_max_z))
            }
            StairType::UShape => {
                let lz = choice.z;
                (lz, (lz + 2).min(f2_max_z))
            }
        };

        // Corredor a lo largo y al frente del desembarque:
        // Si la escalera está pegada al muro izquierdo (choice.x == f2_min_x):
        // El pasillo corre inmediatamente a su lado (choice.x + 1 .. choice.x + 3)
        // eliminando cualquier muro divisorio entre la escalera y la circulación.
        let is_stair_on_left = choice.x <= f2_min_x + 1;
        let (hall_x0, hall_x1) = if is_stair_on_left {
            let x0 = choice.x;
            let x1 = (choice.x + choice.width + 1).min(f2_max_x).max(choice.x + 2);
            (x0, x1)
        } else {
            let x1 = choice.x + choice.width;
            let x0 = (choice.x.saturating_sub(1)).max(f2_min_x).min(x1.saturating_sub(2));
            (x0, x1)
        };

        for cz in choice.z..land_end_z {
            for cx in hall_x0..hall_x1 {
                if cx < width && cz < depth && map_f2[cz * width + cx] > 0 {
                    hall_cells.push((cx, cz));
                }
            }
        }

        // Marcar todas las celdas del pasillo en map_f2
        for &(cx, cz) in &hall_cells {
            map_f2[cz * width + cx] = hall_id;
        }

        // 5.3 Asignar el resto de Planta Alta con ergonomía limpia:
        // Frontal: Recámara 1 (Principal)
        // Posterior: Recámara 2 y Baño Completo
        let mid_split_z = land_start_z.max(f2_min_z + 3);

        for cz in f2_min_z..f2_max_z {
            for cx in f2_min_x..f2_max_x {
                if map_f2[cz * width + cx] == hall_id || map_f2[cz * width + cx] == 0 {
                    continue;
                }

                if cz < mid_split_z {
                    // Zona frontal: Recámara 1 (Principal) con ventanas a la calle
                    map_f2[cz * width + cx] = bed1_id;
                } else {
                    // Zona posterior: Si está del lado de la escalera y tiene >= 2m de profundidad, asignar a Baño
                    let is_bath_side = if is_stair_on_left {
                        cx < (f2_min_x + 3).min(f2_max_x)
                    } else {
                        cx >= f2_max_x.saturating_sub(3)
                    };

                    if is_bath_side && cz >= land_start_z && cz < (land_start_z + 3).min(f2_max_z) {
                        map_f2[cz * width + cx] = bath_id;
                    } else {
                        map_f2[cz * width + cx] = bed2_id;
                    }
                }
            }
        }

        // 5.4 Reconstruir la lista de HouseRoom para Planta Alta a partir de map_f2
        for &(r_id, r_type) in &[
            (hall_id, RoomType::Hallway),
            (bed1_id, RoomType::Bedroom),
            (bed2_id, RoomType::Bedroom),
            (bath_id, RoomType::Bathroom),
        ] {
            let mut min_rx = width;
            let mut max_rx = 0;
            let mut min_rz = depth;
            let mut max_rz = 0;
            let mut count = 0;

            for z in 0..depth {
                for x in 0..width {
                    if map_f2[z * width + x] == r_id {
                        min_rx = min_rx.min(x);
                        max_rx = max_rx.max(x);
                        min_rz = min_rz.min(z);
                        max_rz = max_rz.max(z);
                        count += 1;
                    }
                }
            }

            if count > 0 {
                rooms.push(HouseRoom {
                    id: r_id,
                    room_type: r_type,
                    floor: 2,
                    x_min: min_rx,
                    z_min: min_rz,
                    x_max: max_rx + 1,
                    z_max: max_rz + 1,
                });
            }
        }

        Some(StairData {
            stair_type: choice.stair_type,
            x: choice.x,
            z: choice.z,
            width: choice.width,
            length: choice.length,
            orientation: choice.orientation,
        })
    }
}

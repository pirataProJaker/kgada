use godot::prelude::*;
use rand::SeedableRng;
use rand::rngs::StdRng;
use super::types::*;

pub struct FacilityGeneratorCore;

impl FacilityGeneratorCore {
    /// Genera el plano maestro completo de la instalación militar a partir de sus dimensiones.
    /// Cuadrícula modular calibrada a 1 celda = 1.0 metro (1x1 mt por textura).
    pub fn generate(
        width_m: f32,
        depth_m: f32,
        facility_type: FacilityType,
        seed: u64,
    ) -> FacilityBlueprint {
        let cell_size = 1.0;
        // Dimensiones en metros = celdas (1 metro = 1 celda modular)
        let grid_w = (width_m.round() as usize).clamp(50, 100);
        let grid_d = (depth_m.round() as usize).clamp(60, 120);

        let mut _rng = StdRng::seed_from_u64(seed);
        let mut grid = vec![vec![FacilityCell::Empty; grid_d]; grid_w];
        let mut structures = Vec::new();
        let mut props = Vec::new();
        let mut decals = Vec::new();
        let mut next_struct_id = 1u32;

        let half_w_m = grid_w as f32 * 0.5;
        let half_d_m = grid_d as f32 * 0.5;

        // =====================================================================
        // PASO 1: PERÍMETRO Y TORRES DE VIGILANCIA (Esquinas y Flancos)
        // =====================================================================
        for x in 0..grid_w {
            grid[x][0] = FacilityCell::PerimeterWall;
            grid[x][grid_d - 1] = FacilityCell::PerimeterWall;
        }
        for z in 0..grid_d {
            grid[0][z] = FacilityCell::PerimeterWall;
            grid[grid_w - 1][z] = FacilityCell::PerimeterWall;
        }

        // 4 Torres de vigilancia en las 4 esquinas (3x3 metros cada una)
        let corner_positions = [
            (1, 1, 0.0),
            (grid_w - 4, 1, std::f32::consts::FRAC_PI_2),
            (grid_w - 4, grid_d - 4, std::f32::consts::PI),
            (1, grid_d - 4, -std::f32::consts::FRAC_PI_2),
        ];

        for (cx, cz, rot) in corner_positions {
            Self::try_place(
                &mut grid, &mut structures, &mut next_struct_id,
                StructureKind::Watchtower, cx, cz, rot, cell_size, half_w_m, half_d_m,
            );
        }

        // Torres intermedias en muros laterales
        if grid_d >= 70 {
            let mid_z = grid_d / 2 - 1;
            Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Watchtower, 1, mid_z, -std::f32::consts::FRAC_PI_2, cell_size, half_w_m, half_d_m);
            Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Watchtower, grid_w - 4, mid_z, std::f32::consts::FRAC_PI_2, cell_size, half_w_m, half_d_m);
        }

        // =====================================================================
        // PASO 2: PUERTA DE ENTRADA PRINCIPAL (PORTÓN DE 6.0 METROS) Y CHECKPOINT
        // =====================================================================
        let gate_cx = grid_w / 2;
        let gate_start_x = gate_cx - 3;
        let gate_end_x = gate_cx + 3;

        // Abrir portón de exactamente 6 metros (6 celdas de 1x1m) en Z=0
        for gx in gate_start_x..gate_end_x {
            grid[gx][0] = FacilityCell::Road;
        }

        let checkpoint_pos = Vector3::new(0.0, 0.0, -half_d_m);

        // Garita de vigilancia (3x3m): Inmediatamente a la derecha del portón (flanco derecho)
        let guard_x = gate_end_x + 1;
        Self::try_place(
            &mut grid, &mut structures, &mut next_struct_id,
            StructureKind::Guardhouse, guard_x, 1, 0.0, cell_size, half_w_m, half_d_m,
        );

        // Props de la entrada perfectamente alineados con el portón de 6m:
        // 1. Pluma vehicular (longitud 5.6m cubriendo de x = -2.8 a +2.8)
        props.push(PlacedProp {
            recipe_name: "barrier_gate".to_string(),
            position: Vector3::new(-2.8, 0.0, -half_d_m + 0.2),
            rotation_y: 0.0,
        });

        // 2. Parapeto táctico de sacos de arena en el puesto de guardia
        props.push(PlacedProp {
            recipe_name: "sandbags".to_string(),
            position: Vector3::new(3.6, 0.0, -half_d_m - 0.4),
            rotation_y: 0.0,
        });

        // =====================================================================
        // PASO 3: RED VIAL INTERNA (Bulevar Central 6m + Avenidas Transversales 4m)
        // =====================================================================
        // Bulevar central de 6 celdas (6m) de ancho
        for z in 0..(grid_d - 18) {
            for gx in gate_start_x..gate_end_x {
                grid[gx][z] = FacilityCell::Road;
            }
        }

        // Calles transversales de 4m de ancho
        let street_z1 = 20.min(grid_d - 25); // Sector Logística / Cuarteles Frontal
        let street_z2 = 44.min(grid_d - 25); // Sector Hangares / Cuarteles Medio
        let street_z3 = 68.min(grid_d - 20); // Sector Alto Mando & Búnker

        for &sz in &[street_z1, street_z2, street_z3] {
            for dz in 0..4 {
                let z = sz + dz;
                if z < grid_d - 1 {
                    for x in 1..(grid_w - 1) {
                        grid[x][z] = FacilityCell::Road;
                    }
                }
            }
        }

        // Calles laterales de patrulla perimetral (2m de ancho)
        for z in 1..(grid_d - 1) {
            grid[1][z] = FacilityCell::Road;
            grid[2][z] = FacilityCell::Road;
            grid[grid_w - 3][z] = FacilityCell::Road;
            grid[grid_w - 2][z] = FacilityCell::Road;
        }

        // =====================================================================
        // PASO 4: COLOCACIÓN DE CUARTELES Y ESTRUCTURAS MILITARES
        // =====================================================================
        let mut bunker_entrance_pos = None;

        match facility_type {
            FacilityType::MilitaryBase => {
                // -------------------------------------------------------------
                // SECTOR CUARTELES DE TROPA (Lado Derecho: X de 44 a grid_w - 4)
                // -------------------------------------------------------------
                // Columna A de Cuarteles (X = 45..51, ancho 6m, fondo 10m)
                // Columna B de Cuarteles (X = 54..60, ancho 6m, fondo 10m)
                // Columna C de Servicios  (X = 63..73, ancho 8-10m)

                // Bloque 1 (Z: 6..18)
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 45, 6, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 54, 6, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::MessHall, 63, 6, 0.0, cell_size, half_w_m, half_d_m);

                // Bloque 2 (Z: 26..38)
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 45, 26, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 54, 26, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::MedicalClinic, 63, 26, 0.0, cell_size, half_w_m, half_d_m);

                // Bloque 3 (Z: 50..62)
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 45, 50, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 54, 50, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Armory, 63, 50, 0.0, cell_size, half_w_m, half_d_m);

                // Cuarteles adicionales si hay profundidad suficiente
                if grid_d >= 90 {
                    Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 45, 38, 0.0, cell_size, half_w_m, half_d_m);
                    Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 54, 38, 0.0, cell_size, half_w_m, half_d_m);
                }

                // -------------------------------------------------------------
                // SECTOR LOGÍSTICA & AVIACIÓN (Lado Izquierdo: X de 4 a 36)
                // -------------------------------------------------------------
                // Bloque 1 (Z: 4..19): Helipuerto táctico + Depósito de combustible
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Helipad, 6, 5, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::FuelDepot, 24, 7, 0.0, cell_size, half_w_m, half_d_m);

                // Bloque 2 (Z: 25..43): Hangar masivo + Taller de blindados
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Hangar, 5, 25, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::VehicleWorkshop, 23, 27, 0.0, cell_size, half_w_m, half_d_m);

                // Bloque 3 (Z: 49..65): Puesto de telecomunicaciones & radar + Armería secundaria
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::CommsRadarPost, 8, 51, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Armory, 20, 51, 0.0, cell_size, half_w_m, half_d_m);

                // Nidos de ametralladora en los accesos
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::MachineGunBunker, 28, 1, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::MachineGunBunker, 50, 1, 0.0, cell_size, half_w_m, half_d_m);

                // -------------------------------------------------------------
                // SECTOR ALTO MANDO & BÚNKER SUBTERRÁNEO (Fondo: Z > 72)
                // -------------------------------------------------------------
                let hq_x = 44;
                let hq_z = (grid_d - 18).max(street_z3 + 5);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::CommandHQ, hq_x, hq_z, 0.0, cell_size, half_w_m, half_d_m);

                let b_x = 10;
                let b_z = (grid_d - 16).max(street_z3 + 5);
                let b_placed = Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::BunkerEntrance, b_x, b_z, 0.0, cell_size, half_w_m, half_d_m);

                if b_placed {
                    // Escotilla del búnker ubicada justo frente a la entrada del portal blindado
                    let hatch_x = b_x + 14;
                    let hatch_z = b_z + 2;
                    let b_wx = (hatch_x as f32 + 2.0) * cell_size - half_w_m;
                    let b_wz = (hatch_z as f32 + 2.0) * cell_size - half_d_m;
                    bunker_entrance_pos = Some(Vector3::new(b_wx, 0.0, b_wz));
                }
            }

            FacilityType::NuclearPlant => {
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::CoolingTower, 6, 25, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::ReactorContainment, 42, 25, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::CommandHQ, 42, 55, 0.0, cell_size, half_w_m, half_d_m);
            }

            _ => {
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::CommandHQ, 42, 50, 0.0, cell_size, half_w_m, half_d_m);
                Self::try_place(&mut grid, &mut structures, &mut next_struct_id, StructureKind::Barracks, 45, 10, 0.0, cell_size, half_w_m, half_d_m);
            }
        }

        // =====================================================================
        // PASO 5: PINTADO MODULAR DE BALDOSAS DE SUELO (1 BALDOSA = 1x1 METRO)
        // =====================================================================
        // Capas del Texture2DArray militar (1 textura = 1 cuadrícula de 1x1m):
        // 14: Asfalto táctico oscuro
        // 16: Asfalto con juntas / bordes de rodaje
        // 22: Borde táctico de advertencia
        // 23: Hormigón liso de cimentación
        // 25: Terreno militar verde oliva / camuflaje
        // 26: Losa de hormigón con adoquines (aceras y cuarteles)
        // 27: Hormigón de taller industrial
        // 28: Losa táctica de helipuerto
        // 29: Franjas amarillas y negras de advertencia (Hazard stripes)
        // 31: Rejilla metálica de acero industrial
        // 35: Chevron militar de tránsito
        // 17: Grava y tierra táctica de explanada

        let mut floor_tiles = vec![vec![17u8; grid_d]; grid_w];

        // 1. Zonas perimetrales exteriores: Terreno militar verde oliva
        for x in 0..grid_w {
            for z in 0..grid_d {
                if x < 4 || x >= grid_w - 4 || z < 3 || z >= grid_d - 3 {
                    floor_tiles[x][z] = 25;
                }
            }
        }

        // 2. Calles y bulevar con asfalto militar
        for x in 0..grid_w {
            for z in 0..grid_d {
                if grid[x][z] == FacilityCell::Road {
                    // Bordes de la calle con juntas de rodaje (16), centro con asfalto liso (14)
                    let is_curb = (x == gate_start_x || x == gate_end_x - 1)
                        || (z == street_z1 || z == street_z1 + 3 || z == street_z2 || z == street_z2 + 3);
                    floor_tiles[x][z] = if is_curb { 16 } else { 14 };
                }
            }
        }

        // 3. PORTÓN DE ENTRADA: FRANJAS AMARILLAS Y NEGRAS DE PELIGRO EN EL PISO
        // Sincronizado exactamente con el portón de 6m (columnas gate_start_x a gate_end_x - 1)
        for gx in gate_start_x..gate_end_x {
            floor_tiles[gx][0] = 29; // Umbral exacto del portón: Franjas amarillas/negras
            floor_tiles[gx][1] = 29; // Segunda fila de advertencia
        }

        // 4. Suelos especializados bajo y alrededor de cada estructura
        for s in &structures {
            let cx = s.cell_x;
            let cz = s.cell_z;
            let cw = s.cells_w;
            let cd = s.cells_d;

            match s.kind {
                StructureKind::Barracks | StructureKind::MessHall | StructureKind::MedicalClinic | StructureKind::Armory => {
                    // Cimentación bajo el edificio (23) y banqueta/acera perimetral de 1m (26)
                    let x0 = cx.saturating_sub(1);
                    let x1 = (cx + cw + 1).min(grid_w);
                    let z0 = cz.saturating_sub(1);
                    let z1 = (cz + cd + 1).min(grid_d);
                    for px in x0..x1 {
                        for pz in z0..z1 {
                            if floor_tiles[px][pz] != 14 && floor_tiles[px][pz] != 16 && floor_tiles[px][pz] != 29 {
                                floor_tiles[px][pz] = if px >= cx && px < cx + cw && pz >= cz && pz < cz + cd { 23 } else { 26 };
                            }
                        }
                    }
                }

                StructureKind::Hangar | StructureKind::VehicleWorkshop => {
                    // Suelo de rejilla metálica industrial (31) y franja de advertencia en el acceso frontal
                    for px in cx..(cx + cw).min(grid_w) {
                        for pz in cz..(cz + cd).min(grid_d) {
                            floor_tiles[px][pz] = 31;
                        }
                    }
                    // Franja de advertencia en el acceso frontal (última fila Z)
                    let front_z = (cz + cd - 1).min(grid_d - 1);
                    for px in cx..(cx + cw).min(grid_w) {
                        floor_tiles[px][front_z] = 29; // Franjas amarillas/negras en la puerta
                    }
                }

                StructureKind::Helipad => {
                    // Losa de helipuerto (28), borde de precaución (22) y chevrons en el centro (35)
                    let center_x = cx + cw / 2;
                    let center_z = cz + cd / 2;
                    for px in cx..(cx + cw).min(grid_w) {
                        for pz in cz..(cz + cd).min(grid_d) {
                            let is_border = px == cx || px == cx + cw - 1 || pz == cz || pz == cz + cd - 1;
                            let is_center = (px as isize - center_x as isize).abs() <= 1 && (pz as isize - center_z as isize).abs() <= 1;
                            if is_border {
                                floor_tiles[px][pz] = 22; // Borde de advertencia
                            } else if is_center {
                                floor_tiles[px][pz] = 35; // Chevron militar
                            } else {
                                floor_tiles[px][pz] = 28; // Losa de helipuerto
                            }
                        }
                    }
                }

                StructureKind::FuelDepot => {
                    // Rejillas metálicas sobre solera de contención de vertidos
                    for px in cx..(cx + cw).min(grid_w) {
                        for pz in cz..(cz + cd).min(grid_d) {
                            floor_tiles[px][pz] = 31;
                        }
                    }
                }

                StructureKind::CommandHQ => {
                    let x0 = cx.saturating_sub(1);
                    let x1 = (cx + cw + 1).min(grid_w);
                    let z0 = cz.saturating_sub(1);
                    let z1 = (cz + cd + 1).min(grid_d);
                    for px in x0..x1 {
                        for pz in z0..z1 {
                            if floor_tiles[px][pz] != 14 && floor_tiles[px][pz] != 16 {
                                floor_tiles[px][pz] = 26;
                            }
                        }
                    }
                }

                StructureKind::BunkerEntrance => {
                    // Losa reforzada y franjas de advertencia en el acceso
                    for px in cx..(cx + cw).min(grid_w) {
                        for pz in cz..(cz + cd).min(grid_d) {
                            floor_tiles[px][pz] = 26;
                        }
                    }
                }

                _ => {}
            }
        }

        // 5. Señalización en el acceso a la escotilla del búnker
        if let Some(b_pos) = bunker_entrance_pos {
            let hx = ((b_pos.x + half_w_m) / cell_size).round() as usize;
            let hz = ((b_pos.z + half_d_m) / cell_size).round() as usize;
            let x0 = hx.saturating_sub(2);
            let x1 = (hx + 3).min(grid_w);
            let z0 = hz.saturating_sub(2);
            let z1 = (hz + 3).min(grid_d);
            for px in x0..x1 {
                for pz in z0..z1 {
                    let is_border = px == x0 || px == x1 - 1 || pz == z0 || pz == z1 - 1;
                    floor_tiles[px][pz] = if is_border { 29 } else { 23 };
                }
            }
        }

        // =====================================================================
        // PASO 6: CALCOMANÍAS MILITARES DE ALTO IMPACTO
        // =====================================================================
        for s in &structures {
            match s.kind {
                StructureKind::Hangar => {
                    decals.push(FacilityDecalPoint {
                        position: Vector3::new(s.world_pos.x, 3.8, s.world_pos.z + s.world_size.z * 0.51),
                        normal: Vector3::new(0.0, 0.0, 1.0),
                        size: Vector2::new(3.0, 1.5),
                        category: "military_decal".to_string(),
                        style_id: 1,
                    });
                }
                StructureKind::FuelDepot => {
                    decals.push(FacilityDecalPoint {
                        position: Vector3::new(s.world_pos.x, 2.2, s.world_pos.z + s.world_size.z * 0.51),
                        normal: Vector3::new(0.0, 0.0, 1.0),
                        size: Vector2::new(1.8, 1.8),
                        category: "military_decal".to_string(),
                        style_id: 65,
                    });
                }
                StructureKind::CommandHQ => {
                    decals.push(FacilityDecalPoint {
                        position: Vector3::new(s.world_pos.x, 3.0, s.world_pos.z + s.world_size.z * 0.51),
                        normal: Vector3::new(0.0, 0.0, 1.0),
                        size: Vector2::new(2.4, 1.2),
                        category: "military_decal".to_string(),
                        style_id: 36,
                    });
                }
                StructureKind::BunkerEntrance => {
                    decals.push(FacilityDecalPoint {
                        position: Vector3::new(s.world_pos.x, 2.0, s.world_pos.z - s.world_size.z * 0.51),
                        normal: Vector3::new(0.0, 0.0, -1.0),
                        size: Vector2::new(1.8, 1.8),
                        category: "military_decal".to_string(),
                        style_id: 62,
                    });
                }
                _ => {}
            }
        }

        FacilityBlueprint {
            facility_type,
            width_m,
            depth_m,
            cell_size,
            grid_w,
            grid_d,
            structures,
            props,
            decals,
            bunker_entrance: bunker_entrance_pos,
            checkpoint_gate: checkpoint_pos,
            floor_tiles,
        }
    }

    /// Intenta colocar una estructura en la grilla sin solaparse con muros o calles.
    fn try_place(
        grid: &mut [Vec<FacilityCell>],
        structures: &mut Vec<PlacedStructure>,
        next_id: &mut u32,
        kind: StructureKind,
        cx: usize,
        cz: usize,
        rot: f32,
        cell_size: f32,
        half_w_m: f32,
        half_d_m: f32,
    ) -> bool {
        let (cw, cd) = kind.cell_dimensions();
        let grid_w = grid.len();
        let grid_d = grid[0].len();

        if cx + cw >= grid_w - 1 || cz + cd >= grid_d - 1 {
            return false;
        }

        // Verificar que todas las celdas estén libres
        for x in cx..(cx + cw) {
            for z in cz..(cz + cd) {
                if grid[x][z] != FacilityCell::Empty {
                    return false;
                }
            }
        }

        let s_id = *next_id;
        *next_id += 1;

        // Reclamar las celdas
        for x in cx..(cx + cw) {
            for z in cz..(cz + cd) {
                grid[x][z] = FacilityCell::Structure(s_id);
            }
        }

        let world_w = cw as f32 * cell_size;
        let world_d = cd as f32 * cell_size;
        let world_h = kind.height_meters();

        let wx = (cx as f32 + cw as f32 * 0.5) * cell_size - half_w_m;
        let wz = (cz as f32 + cd as f32 * 0.5) * cell_size - half_d_m;

        structures.push(PlacedStructure {
            id: s_id,
            kind,
            cell_x: cx,
            cell_z: cz,
            cells_w: cw,
            cells_d: cd,
            world_pos: Vector3::new(wx, 0.0, wz),
            world_size: Vector3::new(world_w, world_h, world_d),
            rotation_y: rot,
        });

        true
    }
}

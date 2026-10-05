use std::collections::HashSet;
use godot::prelude::*;
use super::generator::HouseBlueprint;
use super::types::*;
use super::wall_details::*;

pub struct HouseMeshingResult {
    pub walls_ext: Vec<InstanceBox>,
    pub walls_int: Vec<InstanceBox>,
    pub roofs: Vec<InstanceBox>,
    pub floors: Vec<InstanceBox>,
    pub carpentry: Vec<InstanceBox>,
    pub glass: Vec<InstanceBox>,
    pub doors: Vec<DoorInstance>,
    pub windows: Vec<WindowInstance>,
    pub wall_details: Vec<WallDetailInstance>,
    pub collision_boxes: Vec<HouseCollisionBox>,
}

impl HouseMeshingResult {
    pub fn solid_interior_and_structure_boxes(&self) -> Vec<InstanceBox> {
        let mut all = Vec::with_capacity(
            self.walls_int.len() + self.roofs.len() + self.floors.len() + self.carpentry.len()
        );
        all.extend_from_slice(&self.floors);
        all.extend_from_slice(&self.walls_int);
        all.extend_from_slice(&self.roofs);
        all.extend_from_slice(&self.carpentry);
        all
    }

    pub fn all_solid_boxes(&self) -> Vec<InstanceBox> {
        let mut all = Vec::with_capacity(
            self.walls_ext.len() + self.walls_int.len() + self.roofs.len() + self.floors.len() + self.carpentry.len()
        );
        all.extend_from_slice(&self.floors);
        all.extend_from_slice(&self.walls_ext);
        all.extend_from_slice(&self.walls_int);
        all.extend_from_slice(&self.roofs);
        all.extend_from_slice(&self.carpentry);
        all
    }
}

#[derive(Debug, Clone, Copy)]
struct WallOpening {
    center: f32, // Coordenada central sobre el eje de la pared (X o Z)
    width: f32,
    y_bottom: f32,
    height: f32,
    is_door: bool,
    door_style: u8,
    is_main_door: bool,
}

pub struct HouseMesher;

impl HouseMesher {
    /// Descompone una máscara 2D booleana en un número mínimo de rectángulos continuos (Greedy Rectangle Decomposition).
    /// Elimina completamente las costuras de 1x1m y los cortes entre habitaciones en techos y pisos.
    fn decompose_rectangles(w: usize, d: usize, mask: &[bool]) -> Vec<(usize, usize, usize, usize)> {
        let mut covered = vec![false; w * d];
        let mut rects = Vec::new();

        for z in 0..d {
            for x in 0..w {
                if mask[z * w + x] && !covered[z * w + x] {
                    // 1. Expandir anchura a lo largo de X
                    let mut max_x = x;
                    while max_x < w && mask[z * w + max_x] && !covered[z * w + max_x] {
                        max_x += 1;
                    }

                    // 2. Expandir altura a lo largo de Z mientras todo el ancho [x..max_x) esté disponible
                    let mut max_z = z + 1;
                    'expand_z: while max_z < d {
                        for cx in x..max_x {
                            if !mask[max_z * w + cx] || covered[max_z * w + cx] {
                                break 'expand_z;
                            }
                        }
                        max_z += 1;
                    }

                    // 3. Marcar como cubierto
                    for cz in z..max_z {
                        for cx in x..max_x {
                            covered[cz * w + cx] = true;
                        }
                    }

                    rects.push((x, z, max_x - x, max_z - z));
                }
            }
        }

        rects
    }

    /// Convierte el HouseBlueprint en cajas tridimensionales sólidas para GPU Hardware Instancing.
    /// Cero planos, cero vértices invertidos, 100% volúmenes sólidos.
    pub fn build_mesh(blueprint: &HouseBlueprint, show_roofs: bool) -> HouseMeshingResult {
        let grid = &blueprint.grid;
        let w = grid.width;
        let d = grid.depth;
        let h1 = blueprint.floor_height;
        let h2 = h1 * 2.0;
        let pal = &blueprint.palette;

        let mut walls_ext = Vec::new();
        let mut walls_int = Vec::new();
        let mut roofs = Vec::new();
        let mut floors = Vec::new();
        let mut carpentry = Vec::new();
        let mut glass = Vec::new();
        let mut doors = Vec::new();
        let mut windows = Vec::new();
        let mut col_boxes = Vec::new();
        let mut all_wall_spans: Vec<WallSpan> = Vec::new();
        let mut door_style_counter: u8 = 0;

        let ext_th = 0.20f32; // Muro exterior sólido de 20cm
        let int_th = 0.12f32; // Muro interior divisorio de 12cm
        let pretil_h = 0.55f32; // Pretil mexicano de 55cm (integrado en el muro exterior)

        let to_world_x = |x: f32| -> f32 { x - (w as f32 * 0.5) };
        let to_world_z = |z: f32| -> f32 { z - (d as f32 * 0.5) };

        // Registro de puertas para la jerarquía de circulación (Árbol de acceso):
        // Cada cuarto privado (Recámara, Baño) tiene un máximo estricto de 1 SOLA PUERTA.
        let mut private_doors_placed: HashSet<u8> = HashSet::new();
        let mut social_doors_placed: HashSet<(u8, u8)> = HashSet::new();

        // ====================================================================
        // 1. LOSAS MONOLÍTICAS CONTINUAS DE PISO Y ENTREPISO (Greedy Decomp)
        // ====================================================================
        // Losa de Planta Baja
        let mut mask_f1 = vec![false; w * d];
        for z in 0..d {
            for x in 0..w {
                mask_f1[z * w + x] = grid.get(x, z).is_built();
            }
        }
        let slab_embed = 0.08f32; // 8cm adentro del muro exterior (20cm) para eliminar 100% el Z-fighting en fachadas

        for (rx, rz, rw, rd) in Self::decompose_rectangles(w, d, &mask_f1) {
            let mut x0 = to_world_x(rx as f32);
            let mut x1 = to_world_x((rx + rw) as f32);
            let mut z0 = to_world_z(rz as f32);
            let mut z1 = to_world_z((rz + rd) as f32);

            let ext_n = (rx..rx + rw).all(|cx| rz == 0 || !mask_f1[(rz - 1) * w + cx]);
            let ext_s = (rx..rx + rw).all(|cx| rz + rd == d || !mask_f1[(rz + rd) * w + cx]);
            let ext_w = (rz..rz + rd).all(|cz| rx == 0 || !mask_f1[cz * w + rx - 1]);
            let ext_e = (rz..rz + rd).all(|cz| rx + rw == w || !mask_f1[cz * w + rx + rw]);

            if ext_w { x0 += slab_embed; }
            if ext_e { x1 -= slab_embed; }
            if ext_n { z0 += slab_embed; }
            if ext_s { z1 -= slab_embed; }

            if x1 > x0 && z1 > z0 {
                let pos = Vector3::new((x0 + x1) * 0.5, 0.08, (z0 + z1) * 0.5);
                let size = Vector3::new(x1 - x0, 0.16, z1 - z0);
                floors.push(InstanceBox { position: pos, size, color: pal.floor });
                col_boxes.push(HouseCollisionBox { position: pos, size });
            }
        }

        // Losa de Entrepiso (Piso 2)
        if blueprint.total_floors >= 2 {
            let mut mask_f2 = vec![false; w * d];
            for z in 0..d {
                for x in 0..w {
                    let is_stair_hole = if let Some(stair) = blueprint.stair {
                        x >= stair.x && x < stair.x + stair.width && z >= stair.z && z < stair.z + stair.length
                    } else {
                        false
                    };
                    mask_f2[z * w + x] = !is_stair_hole && (grid.get(x, z) == CellHeight::Floor2);
                }
            }
            for (rx, rz, rw, rd) in Self::decompose_rectangles(w, d, &mask_f2) {
                let mut x0 = to_world_x(rx as f32);
                let mut x1 = to_world_x((rx + rw) as f32);
                let mut z0 = to_world_z(rz as f32);
                let mut z1 = to_world_z((rz + rd) as f32);

                let ext_n = (rx..rx + rw).all(|cx| rz == 0 || !mask_f2[(rz - 1) * w + cx]);
                let ext_s = (rx..rx + rw).all(|cx| rz + rd == d || !mask_f2[(rz + rd) * w + cx]);
                let ext_w = (rz..rz + rd).all(|cz| rx == 0 || !mask_f2[cz * w + rx - 1]);
                let ext_e = (rz..rz + rd).all(|cz| rx + rw == w || !mask_f2[cz * w + rx + rw]);

                if ext_w { x0 += slab_embed; }
                if ext_e { x1 -= slab_embed; }
                if ext_n { z0 += slab_embed; }
                if ext_s { z1 -= slab_embed; }

                if x1 > x0 && z1 > z0 {
                    let pos = Vector3::new((x0 + x1) * 0.5, h1 - 0.08, (z0 + z1) * 0.5);
                    let size = Vector3::new(x1 - x0, 0.16, z1 - z0);
                    floors.push(InstanceBox { position: pos, size, color: pal.floor });
                    col_boxes.push(HouseCollisionBox { position: pos, size });
                }
            }
        }

        // ====================================================================
        // 2. TECHOS Y AZOTEAS MONOLÍTICAS CONTINUAS (Zero Seams / Zero Gaps)
        // ====================================================================
        if show_roofs {
            // Techo de Planta Baja (únicamente en celdas PB que NO tienen Planta Alta encima)
            let mut mask_roof_f1 = vec![false; w * d];
            for z in 0..d {
                for x in 0..w {
                    mask_roof_f1[z * w + x] = grid.get(x, z) == CellHeight::Floor1;
                }
            }
            for (rx, rz, rw, rd) in Self::decompose_rectangles(w, d, &mask_roof_f1) {
                let mut x0 = to_world_x(rx as f32);
                let mut x1 = to_world_x((rx + rw) as f32);
                let mut z0 = to_world_z(rz as f32);
                let mut z1 = to_world_z((rz + rd) as f32);

                let ext_n = (rx..rx + rw).all(|cx| rz == 0 || !grid.get(cx, rz - 1).is_built());
                let ext_s = (rx..rx + rw).all(|cx| rz + rd == d || !grid.get(cx, rz + rd).is_built());
                let ext_w = (rz..rz + rd).all(|cz| rx == 0 || !grid.get(rx - 1, cz).is_built());
                let ext_e = (rz..rz + rd).all(|cz| rx + rw == w || !grid.get(rx + rw, cz).is_built());

                if ext_w { x0 += slab_embed; }
                if ext_e { x1 -= slab_embed; }
                if ext_n { z0 += slab_embed; }
                if ext_s { z1 -= slab_embed; }

                if x1 > x0 && z1 > z0 {
                    let pos = Vector3::new((x0 + x1) * 0.5, h1 - 0.10, (z0 + z1) * 0.5);
                    let size = Vector3::new(x1 - x0, 0.20, z1 - z0);
                    roofs.push(InstanceBox { position: pos, size, color: pal.roof });
                    col_boxes.push(HouseCollisionBox { position: pos, size });
                }
            }

            // Techo de Planta Alta
            if blueprint.total_floors >= 2 {
                let mut mask_roof_f2 = vec![false; w * d];
                for z in 0..d {
                    for x in 0..w {
                        mask_roof_f2[z * w + x] = grid.get(x, z) == CellHeight::Floor2;
                    }
                }
                for (rx, rz, rw, rd) in Self::decompose_rectangles(w, d, &mask_roof_f2) {
                    let mut x0 = to_world_x(rx as f32);
                    let mut x1 = to_world_x((rx + rw) as f32);
                    let mut z0 = to_world_z(rz as f32);
                    let mut z1 = to_world_z((rz + rd) as f32);

                    let ext_n = (rx..rx + rw).all(|cx| rz == 0 || !mask_roof_f2[(rz - 1) * w + cx]);
                    let ext_s = (rx..rx + rw).all(|cx| rz + rd == d || !mask_roof_f2[(rz + rd) * w + cx]);
                    let ext_w = (rz..rz + rd).all(|cz| rx == 0 || !mask_roof_f2[cz * w + rx - 1]);
                    let ext_e = (rz..rz + rd).all(|cz| rx + rw == w || !mask_roof_f2[cz * w + rx + rw]);

                    if ext_w { x0 += slab_embed; }
                    if ext_e { x1 -= slab_embed; }
                    if ext_n { z0 += slab_embed; }
                    if ext_s { z1 -= slab_embed; }

                    if x1 > x0 && z1 > z0 {
                        let pos = Vector3::new((x0 + x1) * 0.5, h2 - 0.10, (z0 + z1) * 0.5);
                        let size = Vector3::new(x1 - x0, 0.20, z1 - z0);
                        roofs.push(InstanceBox { position: pos, size, color: pal.roof });
                        col_boxes.push(HouseCollisionBox { position: pos, size });
                    }
                }
            }
        }

        // ====================================================================
        // 3. MUROS CONTINUOS CON VANOS Y PRETILES INTEGRADOS
        // ====================================================================
        let total_floors = blueprint.total_floors;

        for fl in 1..=total_floors {
            let room_map = if fl == 1 { &blueprint.room_map_floor1 } else { &blueprint.room_map_floor2 };
            let base_y_bot = if fl == 1 { 0.0 } else { h1 };
            let base_y_top = if fl == 1 { h1 } else { h2 };

            // ----------------------------------------------------------------
            // A. MUROS HORIZONTALES (Eje X, z fijo de 0 a d)
            // ----------------------------------------------------------------
            for z in 0..=d {
                let mut x = 0;
                while x < w {
                    let r_north = if z > 0 { room_map[(z - 1) * w + x] } else { 0 };
                    let r_south = if z < d { room_map[z * w + x] } else { 0 };

                    let has_wall = r_north != r_south && (r_north > 0 || r_south > 0);
                    if !has_wall {
                        x += 1;
                        continue;
                    }

                    // Concepto abierto: Sala y Comedor NUNCA tienen pared divisoria entre sí
                    if r_north > 0 && r_south > 0 {
                        let tn = Self::get_room_type(blueprint, r_north);
                        let ts = Self::get_room_type(blueprint, r_south);
                        if (tn == RoomType::LivingRoom && ts == RoomType::DiningRoom)
                            || (tn == RoomType::DiningRoom && ts == RoomType::LivingRoom)
                        {
                            x += 1;
                            continue;
                        }
                    }

                    let is_exterior = r_north == 0 || r_south == 0;
                    let is_ext_north_outside = r_north == 0 && r_south > 0;
                    let is_ext_south_outside = r_north > 0 && r_south == 0;

                    let x_start = x;
                    while x < w {
                        let rn = if z > 0 { room_map[(z - 1) * w + x] } else { 0 };
                        let rs = if z < d { room_map[z * w + x] } else { 0 };

                        if is_exterior {
                            // Para muros exteriores de fachada/trasera, agrupamos todo el tramo exterior continuo
                            let same_side_outside = (is_ext_north_outside && rn == 0 && rs > 0)
                                || (is_ext_south_outside && rn > 0 && rs == 0);
                            if !same_side_outside {
                                break;
                            }
                            // Separar tramos que tienen piso arriba de los que tienen azotea abierta (pretil parejo)
                            let cell_floor_above = fl == 1 && (
                                (z > 0 && blueprint.room_map_floor2[(z - 1) * w + x] > 0)
                                    || (z < d && blueprint.room_map_floor2[z * w + x] > 0)
                            );
                            let first_floor_above = fl == 1 && (
                                (z > 0 && blueprint.room_map_floor2[(z - 1) * w + x_start] > 0)
                                    || (z < d && blueprint.room_map_floor2[z * w + x_start] > 0)
                            );
                            if cell_floor_above != first_floor_above {
                                break;
                            }
                        } else {
                            // Muro interior: divide exactamente el mismo par de habitaciones
                            if rn != r_north || rs != r_south {
                                break;
                            }
                        }
                        x += 1;
                    }
                    let x_end = x;

                    let thick = if is_exterior { ext_th } else { int_th };

                    // Verificar si arriba de este tramo hay un piso superior
                    let has_floor_above = fl == 1 && (x_start..x_end).any(|cx| {
                        (z > 0 && blueprint.room_map_floor2[(z - 1) * w + cx] > 0)
                            || (z < d && blueprint.room_map_floor2[z * w + cx] > 0)
                    });

                    // Si es exterior y no tiene piso arriba, extiende hacia arriba el pretil
                    let y_top = if is_exterior {
                        if !has_floor_above && show_roofs {
                            base_y_top + pretil_h
                        } else {
                            base_y_top
                        }
                    } else {
                        // Los muros interiores terminan en el lecho inferior de la losa de techo
                        base_y_top - 0.18
                    };
                    let y_bot = if is_exterior && fl > 1 { base_y_bot - 0.03 } else { base_y_bot };

                    // Posicionamiento estricto hacia el INTERIOR del lote (elimina Z-fighting con vecinos):
                    // El muro exterior se expande hacia adentro del terreno para que su cara exterior
                    // quede exactamente al ras de la línea de lindero (Z = 0 o Z = d).
                    let z_world = if is_ext_north_outside {
                        to_world_z(z as f32) + thick * 0.5
                    } else if is_ext_south_outside {
                        to_world_z(z as f32) - thick * 0.5
                    } else {
                        to_world_z(z as f32)
                    };

                    let mut x_start_world = to_world_x(x_start as f32);
                    let mut x_end_world = to_world_x(x_end as f32);

                    if is_exterior {
                        // Extender en esquinas interiores (reflex corners) para sellar el hueco de la esquina
                        let c_nw = if z > 0 && x_start > 0 { room_map[(z - 1) * w + (x_start - 1)] > 0 } else { false };
                        let c_sw = if z < d && x_start > 0 { room_map[z * w + (x_start - 1)] > 0 } else { false };
                        if c_nw && c_sw {
                            x_start_world -= thick;
                        }

                        let c_ne = if z > 0 && x_end < w { room_map[(z - 1) * w + x_end] > 0 } else { false };
                        let c_se = if z < d && x_end < w { room_map[z * w + x_end] > 0 } else { false };
                        if c_ne && c_se {
                            x_end_world += thick;
                        }
                    } else {
                        let west_ext = x_start == 0 || (
                            (z > 0 && room_map[(z - 1) * w + (x_start - 1)] == 0)
                            || (z < d && room_map[z * w + (x_start - 1)] == 0)
                        );
                        let east_ext = x_end == w || (
                            (z > 0 && room_map[(z - 1) * w + x_end] == 0)
                            || (z < d && room_map[z * w + x_end] == 0)
                        );
                        if west_ext {
                            x_start_world += ext_th;
                        }
                        if east_ext {
                            x_end_world -= ext_th;
                        }
                    }

                    let seg_len = (x_end - x_start) as f32;

                    let mut openings = Vec::new();
                    let is_front_facade = is_ext_north_outside;

                    if is_front_facade && fl == 1 {
                        let door_x = blueprint.main_door_pos.0;
                        let is_main_door_z = z == blueprint.main_door_pos.1;
                        let mut cur_sx = x_start;
                        while cur_sx < x_end {
                            let room_id = room_map[z * w + cur_sx];
                            let span_start = cur_sx;
                            while cur_sx < x_end && room_map[z * w + cur_sx] == room_id {
                                cur_sx += 1;
                            }
                            let span_end = cur_sx;
                            let span_len = (span_end - span_start) as f32;
                            let span_start_w = to_world_x(span_start as f32);
                            let span_end_w = to_world_x(span_end as f32);
                            let span_open_north = Self::is_true_open_north(blueprint, span_start, span_end, z);

                            if is_main_door_z && door_x >= span_start && door_x < span_end {
                                let door_w = 0.95f32;
                                let door_h = 2.20f32;
                                let min_jamb = 0.50f32; // Mocheta mínima obligatoria de 50cm

                                // Puerta principal con margen de esquina garantizado
                                let raw_door_center = to_world_x(door_x as f32 + 0.5);
                                let min_door_center = span_start_w + ext_th + door_w * 0.5 + 0.20;
                                let max_door_center = span_end_w - ext_th - door_w * 0.5 - 0.20;
                                let door_center = if min_door_center <= max_door_center {
                                    raw_door_center.clamp(min_door_center, max_door_center)
                                } else {
                                    raw_door_center
                                };

                                openings.push(WallOpening {
                                    center: door_center,
                                    width: door_w,
                                    y_bottom: y_bot,
                                    height: door_h,
                                    is_door: true,
                                    door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                    is_main_door: true,
                                });

                                // Ventanal de Sala con separación garantizada (únicamente si da al exterior abierto)
                                if span_open_north {
                                    let door_left = door_center - door_w * 0.5;
                                    let door_right = door_center + door_w * 0.5;
                                    let space_right = (span_end_w - ext_th - min_jamb) - door_right;
                                    let space_left = door_left - (span_start_w + ext_th + min_jamb);

                                    if space_right >= 1.60 {
                                        let win_w = space_right.min(1.60);
                                        let win_center = (door_right + min_jamb) + win_w * 0.5;
                                        openings.push(WallOpening {
                                            center: win_center,
                                            width: win_w,
                                            y_bottom: y_bot + 0.90,
                                            height: 1.30,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    } else if space_left >= 1.60 {
                                        let win_w = space_left.min(1.60);
                                        let win_center = (door_left - min_jamb) - win_w * 0.5;
                                        openings.push(WallOpening {
                                            center: win_center,
                                            width: win_w,
                                            y_bottom: y_bot + 0.90,
                                            height: 1.30,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    }
                                }
                            } else if span_open_north && span_len >= 2.0 {
                                // Cuarto frontal sin puerta principal: ventana centrada si es fachada exterior real
                                let span_center = (span_start_w + span_end_w) * 0.5;
                                openings.push(WallOpening {
                                    center: span_center,
                                    width: 1.20f32.min(span_len - 0.8),
                                    y_bottom: y_bot + 0.90,
                                    height: 1.30,
                                    is_door: false,
                                    door_style: 0,
                                    is_main_door: false,
                                });
                            }
                        }
                    } else if is_front_facade && fl == 2 {
                        // Ventanas de planta alta por cada habitación frontal que dé a fachada abierta al exterior
                        let mut cur_sx = x_start;
                        while cur_sx < x_end {
                            let room_id = room_map[z * w + cur_sx];
                            let span_start = cur_sx;
                            while cur_sx < x_end && room_map[z * w + cur_sx] == room_id {
                                cur_sx += 1;
                            }
                            let span_end = cur_sx;
                            let span_len = (span_end - span_start) as f32;
                            let span_open_north = Self::is_true_open_north(blueprint, span_start, span_end, z);

                            if span_open_north && span_len >= 2.0 {
                                let span_start_w = to_world_x(span_start as f32);
                                let span_end_w = to_world_x(span_end as f32);
                                let span_center = (span_start_w + span_end_w) * 0.5;
                                openings.push(WallOpening {
                                    center: span_center,
                                    width: 1.30f32.min(span_len - 0.6),
                                    y_bottom: y_bot + 0.95,
                                    height: 1.25,
                                    is_door: false,
                                    door_style: 0,
                                    is_main_door: false,
                                });
                            }
                        }
                    } else if is_ext_south_outside && fl == 1 {
                        // Fachada trasera al patio en Planta Baja: procesar cada habitación que dé a patio abierto
                        let mut cur_sx = x_start;
                        while cur_sx < x_end {
                            let room_id = room_map[(z - 1) * w + cur_sx];
                            let span_start = cur_sx;
                            while cur_sx < x_end && room_map[(z - 1) * w + cur_sx] == room_id {
                                cur_sx += 1;
                            }
                            let span_end = cur_sx;
                            let span_len = (span_end - span_start) as f32;
                            let span_start_w = to_world_x(span_start as f32);
                            let span_end_w = to_world_x(span_end as f32);
                            let span_center = (span_start_w + span_end_w) * 0.5;
                            let span_open_south = Self::is_true_open_south(blueprint, span_start, span_end, z);

                            if span_open_south {
                                let r_type = Self::get_room_type(blueprint, room_id);
                                if r_type == RoomType::Bathroom {
                                    // Baño al patio: ventana alta de baño garantizada (NUNCA puerta)
                                    if span_len >= 1.5 {
                                        openings.push(WallOpening {
                                            center: span_center,
                                            width: 0.60,
                                            y_bottom: y_bot + 1.80,
                                            height: 0.45,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    }
                                } else if r_type.is_social_or_circulation() {
                                    // Distribuidor / Cocina al patio: puerta de patio
                                    if span_len >= 1.4 {
                                        openings.push(WallOpening {
                                            center: span_center,
                                            width: 0.90,
                                            y_bottom: y_bot,
                                            height: 2.15,
                                            is_door: true,
                                            door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                            is_main_door: false,
                                        });
                                    }
                                } else if r_type == RoomType::Bedroom {
                                    // Recámara al patio: ventana residencial normal
                                    if span_len >= 2.0 {
                                        openings.push(WallOpening {
                                            center: span_center,
                                            width: 1.20,
                                            y_bottom: y_bot + 1.00,
                                            height: 1.15,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    }
                                }
                            }
                        }
                    } else if is_ext_south_outside && fl == 2 {
                        // Fachada trasera en Planta Alta únicamente si da a patio exterior real
                        let mut cur_sx = x_start;
                        while cur_sx < x_end {
                            let room_id = room_map[(z - 1) * w + cur_sx];
                            let span_start = cur_sx;
                            while cur_sx < x_end && room_map[(z - 1) * w + cur_sx] == room_id {
                                cur_sx += 1;
                            }
                            let span_end = cur_sx;
                            let span_len = (span_end - span_start) as f32;
                            let span_start_w = to_world_x(span_start as f32);
                            let span_end_w = to_world_x(span_end as f32);
                            let span_center = (span_start_w + span_end_w) * 0.5;
                            let span_open_south = Self::is_true_open_south(blueprint, span_start, span_end, z);

                            if span_open_south {
                                let r_type = Self::get_room_type(blueprint, room_id);
                                if r_type == RoomType::Bathroom {
                                    if span_len >= 1.5 {
                                        openings.push(WallOpening {
                                            center: span_center,
                                            width: 0.60,
                                            y_bottom: y_bot + 1.80,
                                            height: 0.45,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    }
                                } else if span_len >= 2.0 {
                                    openings.push(WallOpening {
                                        center: span_center,
                                        width: 1.20,
                                        y_bottom: y_bot + 1.00,
                                        height: 1.15,
                                        is_door: false,
                                        door_style: 0,
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                    } else if !is_exterior {
                        // Muro interior horizontal entre cuartos r_north y r_south
                        let type_n = Self::get_room_type(blueprint, r_north);
                        let type_s = Self::get_room_type(blueprint, r_south);
                        let is_n_private = type_n.is_private();
                        let is_s_private = type_s.is_private();

                        // 1. Privado con Privado: Puerta en suite si uno es Baño y otro es Recámara, o paso en Planta Alta si están aisladas
                        if is_n_private && is_s_private {
                            let is_bath_suite = (type_n == RoomType::Bathroom && type_s == RoomType::Bedroom)
                                || (type_s == RoomType::Bathroom && type_n == RoomType::Bedroom);
                            let has_f2_hall = blueprint.rooms.iter().any(|r| r.floor == 2 && (r.room_type == RoomType::Hallway || r.room_type == RoomType::LivingRoom));
                            let is_floor2_pass = fl == 2 && !has_f2_hall && (!private_doors_placed.contains(&r_north) || !private_doors_placed.contains(&r_south));
                            if (is_bath_suite || is_floor2_pass) && seg_len >= 1.00 {
                                let priv_id = if is_bath_suite {
                                    if type_n == RoomType::Bathroom { r_north } else { r_south }
                                } else {
                                    if !private_doors_placed.contains(&r_north) { r_north } else { r_south }
                                };
                                if !private_doors_placed.contains(&priv_id) {
                                    private_doors_placed.insert(priv_id);
                                    let center_x = (x_start_world + x_end_world) * 0.5;
                                    openings.push(WallOpening {
                                        center: center_x,
                                        width: 0.85,
                                        y_bottom: y_bot,
                                        height: 2.10,
                                        is_door: true,
                                        door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                        // 2. Privado con Social: Exactamente 1 puerta para acceder al cuarto privado
                        else if is_n_private != is_s_private {
                            let priv_id = if is_n_private { r_north } else { r_south };
                            if !private_doors_placed.contains(&priv_id) && seg_len >= 1.00 {
                                private_doors_placed.insert(priv_id);
                                let center_x = (x_start_world + x_end_world) * 0.5;
                                openings.push(WallOpening {
                                    center: center_x,
                                    width: 0.85,
                                    y_bottom: y_bot,
                                    height: 2.10,
                                    is_door: true,
                                    door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                    is_main_door: false,
                                });
                            }
                        }
                        // 3. Social con Social (Sala, Comedor, Cocina, Pasillo): vano abierto para Cocina o puerta de acceso
                        else {
                            let pair = (r_north.min(r_south), r_north.max(r_south));
                            if !social_doors_placed.contains(&pair) && seg_len >= 1.40 {
                                social_doors_placed.insert(pair);
                                let center_x = (x_start_world + x_end_world) * 0.5;

                                let is_kitchen_pass = (type_n == RoomType::Kitchen && (type_s == RoomType::DiningRoom || type_s == RoomType::LivingRoom))
                                    || (type_s == RoomType::Kitchen && (type_n == RoomType::DiningRoom || type_n == RoomType::LivingRoom));

                                if is_kitchen_pass {
                                    // Vano amplio sin puerta (murete de separación abierto hacia el comedor/área social)
                                    let pass_w = (seg_len - 0.80).clamp(1.50, 2.20);
                                    openings.push(WallOpening {
                                        center: center_x,
                                        width: pass_w,
                                        y_bottom: y_bot,
                                        height: 2.25,
                                        is_door: true,
                                        door_style: 255, // ¡Vano abierto libre, sin hoja de puerta!
                                        is_main_door: false,
                                    });
                                } else {
                                    openings.push(WallOpening {
                                        center: center_x,
                                        width: 0.90,
                                        y_bottom: y_bot,
                                        height: 2.15,
                                        is_door: true,
                                        door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                    }

                    // Resolver colisiones y ordenar vanos
                    let clean_openings = Self::resolve_openings_separation(openings);

                    let norm = if is_ext_north_outside {
                        Vector3::new(0.0, 0.0, -1.0)
                    } else {
                        Vector3::new(0.0, 0.0, 1.0)
                    };

                    let target_walls = if is_exterior { &mut walls_ext } else { &mut walls_int };
                    Self::build_continuous_wall_x(
                        target_walls,
                        &mut carpentry,
                        &mut glass,
                        &mut doors,
                        &mut windows,
                        &mut col_boxes,
                        x_start_world,
                        x_end_world,
                        z_world,
                        y_bot,
                        y_top,
                        thick,
                        &clean_openings,
                        pal,
                        is_exterior,
                        norm,
                        fl as u8,
                    );

                    // Registrar tramo exterior en all_wall_spans para el sistema centralizado de detalles
                    if is_exterior && fl == 1 {
                        let seg_len = (x_end_world - x_start_world).abs();
                        if seg_len >= 1.5 {
                            let face_z = z_world + norm.z * (thick * 0.5);
                            let openings_intervals: Vec<(f32, f32, f32, f32)> = clean_openings
                                .iter()
                                .map(|o| (
                                    o.center - o.width * 0.5,
                                    o.center + o.width * 0.5,
                                    o.y_bottom,
                                    o.y_bottom + o.height,
                                ))
                                .collect();
                            all_wall_spans.push(WallSpan {
                                is_axis_x: true,
                                start: x_start_world.min(x_end_world),
                                end: x_start_world.max(x_end_world),
                                face_coord: face_z,
                                normal: norm,
                                is_exterior: true,
                                wall_height: y_top - y_bot,
                                is_blank: clean_openings.is_empty(),
                                openings: openings_intervals,
                            });
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // B. MUROS VERTICALES (Eje Z, x fijo de 0 a w)
            // ----------------------------------------------------------------
            for x in 0..=w {
                let mut z = 0;
                while z < d {
                    let r_west = if x > 0 { room_map[z * w + (x - 1)] } else { 0 };
                    let r_east = if x < w { room_map[z * w + x] } else { 0 };

                    let has_wall = r_west != r_east && (r_west > 0 || r_east > 0);
                    if !has_wall {
                        z += 1;
                        continue;
                    }

                    // Concepto abierto: Sala y Comedor NUNCA tienen pared divisoria entre sí
                    if r_west > 0 && r_east > 0 {
                        let tw = Self::get_room_type(blueprint, r_west);
                        let te = Self::get_room_type(blueprint, r_east);
                        if (tw == RoomType::LivingRoom && te == RoomType::DiningRoom)
                            || (tw == RoomType::DiningRoom && te == RoomType::LivingRoom)
                        {
                            z += 1;
                            continue;
                        }
                    }

                    let is_exterior = r_west == 0 || r_east == 0;
                    let is_ext_west_outside = r_west == 0 && r_east > 0;
                    let is_ext_east_outside = r_west > 0 && r_east == 0;

                    let z_start = z;
                    while z < d {
                        let rw = if x > 0 { room_map[z * w + (x - 1)] } else { 0 };
                        let re = if x < w { room_map[z * w + x] } else { 0 };

                        if is_exterior {
                            let same_side_outside = (is_ext_west_outside && rw == 0 && re > 0)
                                || (is_ext_east_outside && rw > 0 && re == 0);
                            if !same_side_outside {
                                break;
                            }
                            // Separar tramos que tienen piso arriba de los que tienen azotea abierta (pretil parejo)
                            let cell_floor_above = fl == 1 && (
                                (x > 0 && blueprint.room_map_floor2[z * w + (x - 1)] > 0)
                                    || (x < w && blueprint.room_map_floor2[z * w + x] > 0)
                            );
                            let first_floor_above = fl == 1 && (
                                (x > 0 && blueprint.room_map_floor2[z_start * w + (x - 1)] > 0)
                                    || (x < w && blueprint.room_map_floor2[z_start * w + x] > 0)
                            );
                            if cell_floor_above != first_floor_above {
                                break;
                            }
                        } else {
                            if rw != r_west || re != r_east {
                                break;
                            }
                        }
                        z += 1;
                    }
                    let z_end = z;

                    let thick = if is_exterior { ext_th } else { int_th };

                    let has_floor_above = fl == 1 && (z_start..z_end).any(|cz| {
                        (x > 0 && blueprint.room_map_floor2[cz * w + (x - 1)] > 0)
                            || (x < w && blueprint.room_map_floor2[cz * w + x] > 0)
                    });

                    let y_top = if is_exterior {
                        if !has_floor_above && show_roofs {
                            base_y_top + pretil_h
                        } else {
                            base_y_top
                        }
                    } else {
                        // Los muros interiores terminan en el lecho inferior de la losa de techo
                        base_y_top - 0.18
                    };
                    let y_bot = if is_exterior && fl > 1 { base_y_bot - 0.03 } else { base_y_bot };

                    // Posicionamiento estricto hacia el INTERIOR del lote (elimina Z-fighting con vecinos):
                    let x_world = if is_ext_west_outside {
                        to_world_x(x as f32) + thick * 0.5
                    } else if is_ext_east_outside {
                        to_world_x(x as f32) - thick * 0.5
                    } else {
                        to_world_x(x as f32)
                    };

                    // Ajuste en esquinas y límites para empalme cerrado sin Z-fighting ni penetración
                    let mut z_start_world = to_world_z(z_start as f32);
                    let mut z_end_world = to_world_z(z_end as f32);

                    if is_exterior {
                        let has_h_wall_start = z_start == 0 || (
                            if is_ext_west_outside && x < w {
                                room_map[(z_start - 1) * w + x] == 0
                            } else if is_ext_east_outside && x > 0 {
                                room_map[(z_start - 1) * w + (x - 1)] == 0
                            } else {
                                false
                            }
                        );
                        if has_h_wall_start {
                            z_start_world += thick;
                        }

                        let has_h_wall_end = z_end == d || (
                            if is_ext_west_outside && x < w {
                                room_map[z_end * w + x] == 0
                            } else if is_ext_east_outside && x > 0 {
                                room_map[z_end * w + (x - 1)] == 0
                            } else {
                                false
                            }
                        );
                        if has_h_wall_end {
                            z_end_world -= thick;
                        }
                    } else {
                        // Muro interior: si colinda con el exterior al Norte o al Sur, recortar ext_th para jamás penetrar la fachada
                        let north_ext = z_start == 0 || (
                            (x > 0 && room_map[(z_start - 1) * w + (x - 1)] == 0)
                            || (x < w && room_map[(z_start - 1) * w + x] == 0)
                        );
                        let south_ext = z_end == d || (
                            (x > 0 && room_map[z_end * w + (x - 1)] == 0)
                            || (x < w && room_map[z_end * w + x] == 0)
                        );
                        if north_ext {
                            z_start_world += ext_th;
                        }
                        if south_ext {
                            z_end_world -= ext_th;
                        }
                    }
                    let seg_len = (z_end - z_start) as f32;

                    let mut openings = Vec::new();
                    let is_party_wall = (x == 0 || x == w) && blueprint.zone == HouseZoneType::ColoniaVieja;

                    if !is_party_wall && is_exterior {
                        let mut cur_sz = z_start;
                        while cur_sz < z_end {
                            let room_id = if r_west > 0 { room_map[cur_sz * w + (x - 1)] } else { room_map[cur_sz * w + x] };
                            let span_start = cur_sz;
                            while cur_sz < z_end && (if r_west > 0 { room_map[cur_sz * w + (x - 1)] } else { room_map[cur_sz * w + x] }) == room_id {
                                cur_sz += 1;
                            }
                            let span_end = cur_sz;
                            let span_len = (span_end - span_start) as f32;
                            let span_start_w = to_world_z(span_start as f32);
                            let span_end_w = to_world_z(span_end as f32);
                            let span_center = (span_start_w + span_end_w) * 0.5;

                            let span_is_open_outside = if r_west == 0 {
                                Self::is_true_open_west(blueprint, x, span_start, span_end)
                            } else {
                                Self::is_true_open_east(blueprint, x, span_start, span_end)
                            };

                            let touches_stair = if let Some(stair) = blueprint.stair {
                                let stair_wall_x = (stair.x == x && r_east > 0) || (stair.x + stair.width == x && r_west > 0);
                                let stair_z_overlap = span_start < stair.z + stair.length && span_end > stair.z;
                                stair_wall_x && stair_z_overlap
                            } else {
                                false
                            };

                            let r_type = Self::get_room_type(blueprint, room_id);
                            if touches_stair && span_is_open_outside {
                                if fl == 1 && span_len >= 1.5 {
                                    // Ventana de Escalera Alta y Vertical únicamente si da a fachada o pasillo exterior real
                                    let stair_obj = blueprint.stair.unwrap();
                                    let stair_win_center = to_world_z(stair_obj.z as f32 + stair_obj.length as f32 * 0.5);
                                    openings.push(WallOpening {
                                        center: stair_win_center,
                                        width: 0.65,
                                        y_bottom: y_bot + 1.20,
                                        height: 2.20,
                                        is_door: false,
                                        door_style: 0,
                                        is_main_door: false,
                                    });
                                }
                            } else if span_is_open_outside {
                                if r_type == RoomType::Bathroom {
                                    if span_len >= 1.5 {
                                        openings.push(WallOpening {
                                            center: span_center,
                                            width: 0.60,
                                            y_bottom: y_bot + 1.80,
                                            height: 0.45,
                                            is_door: false,
                                            door_style: 0,
                                            is_main_door: false,
                                        });
                                    }
                                } else if span_len >= 2.5 {
                                    openings.push(WallOpening {
                                        center: span_center,
                                        width: 1.10,
                                        y_bottom: y_bot + 1.05,
                                        height: 1.10,
                                        is_door: false,
                                        door_style: 0,
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                    } else if !is_exterior {
                        // Muro interior vertical entre cuartos r_west y r_east
                        let type_w = Self::get_room_type(blueprint, r_west);
                        let type_e = Self::get_room_type(blueprint, r_east);
                        let is_w_private = type_w.is_private();
                        let is_e_private = type_e.is_private();

                        // 1. Privado con Privado: Puerta en suite si uno es Baño y otro es Recámara, o paso en Planta Alta si están aisladas
                        if is_w_private && is_e_private {
                            let is_bath_suite = (type_w == RoomType::Bathroom && type_e == RoomType::Bedroom)
                                || (type_e == RoomType::Bathroom && type_w == RoomType::Bedroom);
                            let has_f2_hall = blueprint.rooms.iter().any(|r| r.floor == 2 && (r.room_type == RoomType::Hallway || r.room_type == RoomType::LivingRoom));
                            let is_floor2_pass = fl == 2 && !has_f2_hall && (!private_doors_placed.contains(&r_west) || !private_doors_placed.contains(&r_east));
                            if (is_bath_suite || is_floor2_pass) && seg_len >= 1.00 {
                                let priv_id = if is_bath_suite {
                                    if type_w == RoomType::Bathroom { r_west } else { r_east }
                                } else {
                                    if !private_doors_placed.contains(&r_west) { r_west } else { r_east }
                                };
                                if !private_doors_placed.contains(&priv_id) {
                                    private_doors_placed.insert(priv_id);
                                    let center_z = (z_start_world + z_end_world) * 0.5;
                                    openings.push(WallOpening {
                                        center: center_z,
                                        width: 0.85,
                                        y_bottom: y_bot,
                                        height: 2.10,
                                        is_door: true,
                                        door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                        // 2. Privado con Social: Exactamente 1 puerta si no se le ha colocado una
                        else if is_w_private != is_e_private {
                            let priv_id = if is_w_private { r_west } else { r_east };
                            if !private_doors_placed.contains(&priv_id) && seg_len >= 1.00 {
                                private_doors_placed.insert(priv_id);
                                let center_z = (z_start_world + z_end_world) * 0.5;
                                openings.push(WallOpening {
                                    center: center_z,
                                    width: 0.85,
                                    y_bottom: y_bot,
                                    height: 2.10,
                                    is_door: true,
                                    door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                    is_main_door: false,
                                });
                            }
                        }
                        // 3. Social con Social: vano abierto para Cocina o puerta entre este par
                        else {
                            let pair = (r_west.min(r_east), r_west.max(r_east));
                            if !social_doors_placed.contains(&pair) && seg_len >= 1.40 {
                                social_doors_placed.insert(pair);
                                let center_z = (z_start_world + z_end_world) * 0.5;

                                let is_kitchen_pass = (type_w == RoomType::Kitchen && (type_e == RoomType::DiningRoom || type_e == RoomType::LivingRoom))
                                    || (type_e == RoomType::Kitchen && (type_w == RoomType::DiningRoom || type_w == RoomType::LivingRoom));

                                if is_kitchen_pass {
                                    // Vano amplio sin puerta (murete de separación abierto hacia el comedor/área social)
                                    let pass_w = (seg_len - 0.80).clamp(1.50, 2.20);
                                    openings.push(WallOpening {
                                        center: center_z,
                                        width: pass_w,
                                        y_bottom: y_bot,
                                        height: 2.25,
                                        is_door: true,
                                        door_style: 255, // ¡Vano abierto libre, sin hoja de puerta!
                                        is_main_door: false,
                                    });
                                } else {
                                    openings.push(WallOpening {
                                        center: center_z,
                                        width: 0.90,
                                        y_bottom: y_bot,
                                        height: 2.15,
                                        is_door: true,
                                        door_style: { let s = door_style_counter % 8; door_style_counter += 1; s },
                                        is_main_door: false,
                                    });
                                }
                            }
                        }
                    }

                    let clean_openings = Self::resolve_openings_separation(openings);

                    let norm = if is_ext_west_outside {
                        Vector3::new(-1.0, 0.0, 0.0)
                    } else {
                        Vector3::new(1.0, 0.0, 0.0)
                    };

                    let target_walls = if is_exterior { &mut walls_ext } else { &mut walls_int };
                    Self::build_continuous_wall_z(
                        target_walls,
                        &mut carpentry,
                        &mut glass,
                        &mut doors,
                        &mut windows,
                        &mut col_boxes,
                        x_world,
                        z_start_world,
                        z_end_world,
                        y_bot,
                        y_top,
                        thick,
                        &clean_openings,
                        pal,
                        is_exterior,
                        norm,
                        fl as u8,
                    );

                    // Registrar tramo exterior en all_wall_spans para el sistema centralizado de detalles
                    if is_exterior && fl == 1 {
                        let seg_len = (z_end_world - z_start_world).abs();
                        if seg_len >= 1.5 {
                            let face_x = x_world + norm.x * (thick * 0.5);
                            let openings_intervals: Vec<(f32, f32, f32, f32)> = clean_openings
                                .iter()
                                .map(|o| (
                                    o.center - o.width * 0.5,
                                    o.center + o.width * 0.5,
                                    o.y_bottom,
                                    o.y_bottom + o.height,
                                ))
                                .collect();
                            all_wall_spans.push(WallSpan {
                                is_axis_x: false,
                                start: z_start_world.min(z_end_world),
                                end: z_start_world.max(z_end_world),
                                face_coord: face_x,
                                normal: norm,
                                is_exterior: true,
                                wall_height: y_top - y_bot,
                                is_blank: clean_openings.is_empty(),
                                openings: openings_intervals,
                            });
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 4. TINACO ROTOPLAS (En la azotea más alta)
        // ====================================================================
        if show_roofs {
            let mut highest_roof_cells = Vec::new();
            for z in 0..d {
                for x in 0..w {
                    let cell = grid.get(x, z);
                    if cell.is_built() {
                        let y = if cell == CellHeight::Floor2 { h2 } else { h1 };
                        highest_roof_cells.push((x, z, y));
                    }
                }
            }

            if let Some(&(tx, tz, ty)) = highest_roof_cells.last() {
                let x_c = to_world_x(tx as f32 + 0.5);
                let z_c = to_world_z(tz as f32 + 0.5);

                let base_pos = Vector3::new(x_c, ty + 0.15, z_c);
                let base_size = Vector3::new(0.85, 0.30, 0.85);
                carpentry.push(InstanceBox { position: base_pos, size: base_size, color: pal.trim });

                let tinaco_pos = Vector3::new(x_c, ty + 0.45 + 0.55, z_c);
                let tinaco_size = Vector3::new(0.75, 1.10, 0.75);
                carpentry.push(InstanceBox { position: tinaco_pos, size: tinaco_size, color: pal.tinaco });

                let lid_pos = Vector3::new(x_c, ty + 1.55 + 0.05, z_c);
                let lid_size = Vector3::new(0.60, 0.10, 0.60);
                carpentry.push(InstanceBox { position: lid_pos, size: lid_size, color: pal.tinaco });
            }
        }

        // ====================================================================
        // 5. SISTEMA CENTRALIZADO DE DETALLES Y DEFECTOS DE PARED (WallDetailSystem)
        // ====================================================================
        let wall_details = WallDetailSystem::generate_details(
            &all_wall_spans,
            blueprint.zone,
            blueprint.seed,
            blueprint.floor_height,
        );

        HouseMeshingResult {
            walls_ext,
            walls_int,
            roofs,
            floors,
            carpentry,
            glass,
            doors,
            windows,
            wall_details,
            collision_boxes: col_boxes,
        }
    }


    pub fn is_true_open_north(blueprint: &HouseBlueprint, x_start: usize, x_end: usize, z: usize) -> bool {
        let w = blueprint.grid.width;
        if z == 0 {
            return true;
        }
        (x_start..x_end).all(|x| {
            if x >= w { return true; }
            blueprint.room_map_floor1[(z - 1) * w + x] == 0
                && blueprint.room_map_floor2[(z - 1) * w + x] == 0
        })
    }

    pub fn is_true_open_south(blueprint: &HouseBlueprint, x_start: usize, x_end: usize, z: usize) -> bool {
        let w = blueprint.grid.width;
        let d = blueprint.grid.depth;
        if z >= d {
            return true;
        }
        (x_start..x_end).all(|x| {
            if x >= w { return true; }
            blueprint.room_map_floor1[z * w + x] == 0
                && blueprint.room_map_floor2[z * w + x] == 0
        })
    }

    pub fn is_true_open_west(blueprint: &HouseBlueprint, x: usize, z_start: usize, z_end: usize) -> bool {
        let w = blueprint.grid.width;
        let d = blueprint.grid.depth;
        if x == 0 {
            return true;
        }
        (z_start..z_end).all(|z| {
            if z >= d { return true; }
            blueprint.room_map_floor1[z * w + (x - 1)] == 0
                && blueprint.room_map_floor2[z * w + (x - 1)] == 0
        })
    }

    pub fn is_true_open_east(blueprint: &HouseBlueprint, x: usize, z_start: usize, z_end: usize) -> bool {
        let w = blueprint.grid.width;
        let d = blueprint.grid.depth;
        if x >= w {
            return true;
        }
        (z_start..z_end).all(|z| {
            if z >= d { return true; }
            blueprint.room_map_floor1[z * w + x] == 0
                && blueprint.room_map_floor2[z * w + x] == 0
        })
    }

    fn get_room_type(blueprint: &HouseBlueprint, room_id: u8) -> RoomType {
        for r in &blueprint.rooms {
            if r.id == room_id {
                return r.room_type;
            }
        }
        RoomType::Empty
    }

    /// Resuelve colisiones entre aberturas para garantizar una separación (mocheta) mínima de 40cm.
    /// Si una ventana y una puerta compiten por espacio, la puerta tiene prioridad y la ventana se recorta o descarta.
    fn resolve_openings_separation(mut openings: Vec<WallOpening>) -> Vec<WallOpening> {
        if openings.len() <= 1 {
            return openings;
        }

        openings.sort_by(|a, b| a.center.partial_cmp(&b.center).unwrap_or(std::cmp::Ordering::Equal));

        let min_gap = 0.40f32;
        let mut clean: Vec<WallOpening> = Vec::new();

        for op in openings {
            if let Some(prev) = clean.last_mut() {
                let prev_right = prev.center + prev.width * 0.5;
                let op_left = op.center - op.width * 0.5;

                if op_left < prev_right + min_gap {
                    // Conflicto de espacio detectado
                    if !op.is_door && prev.is_door {
                        // op es ventana y prev es puerta: recortar la ventana
                        let new_left = prev_right + min_gap;
                        let old_right = op.center + op.width * 0.5;
                        let new_w = old_right - new_left;
                        if new_w >= 0.70 {
                            let mut trimmed = op;
                            trimmed.width = new_w;
                            trimmed.center = new_left + new_w * 0.5;
                            clean.push(trimmed);
                        }
                    } else if op.is_door && !prev.is_door {
                        // op es puerta y prev es ventana: recortar la ventana previa
                        let new_right = op.center - op.width * 0.5 - min_gap;
                        let old_left = prev.center - prev.width * 0.5;
                        let new_w = new_right - old_left;
                        if new_w >= 0.70 {
                            prev.width = new_w;
                            prev.center = old_left + new_w * 0.5;
                            clean.push(op);
                        } else {
                            *prev = op; // Reemplazar ventana por puerta
                        }
                    }
                } else {
                    clean.push(op);
                }
            } else {
                clean.push(op);
            }
        }

        clean
    }

    /// Construye una pared horizontal continua sólida y perfora sus vanos con cajas 3D exactas.
    fn build_continuous_wall_x(
        walls: &mut Vec<InstanceBox>,
        carpentry: &mut Vec<InstanceBox>,
        glass: &mut Vec<InstanceBox>,
        doors: &mut Vec<DoorInstance>,
        windows: &mut Vec<WindowInstance>,
        col_boxes: &mut Vec<HouseCollisionBox>,
        x_start: f32,
        x_end: f32,
        z_pos: f32,
        y_bot: f32,
        y_top: f32,
        thick: f32,
        openings: &[WallOpening],
        pal: &HousePalette,
        is_exterior: bool,
        wall_normal: Vector3,
        floor: u8,
    ) {
        if x_end <= x_start {
            return;
        }

        let wall_color = if is_exterior { pal.wall_ext } else { pal.wall_int };
        let wall_h = y_top - y_bot;
        let mut cur_x = x_start;

        for op in openings {
            let op_left = (op.center - op.width * 0.5).max(x_start);
            let op_right = (op.center + op.width * 0.5).min(x_end);

            if op_left > cur_x {
                let seg_w = op_left - cur_x;
                let center = Vector3::new(cur_x + seg_w * 0.5, y_bot + wall_h * 0.5, z_pos);
                let size = Vector3::new(seg_w, wall_h, thick);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            let op_w = op_right - op_left;
            let op_center_x = (op_left + op_right) * 0.5;

            // Antepecho inferior
            if op.y_bottom > y_bot {
                let sill_h = op.y_bottom - y_bot;
                let center = Vector3::new(op_center_x, y_bot + sill_h * 0.5, z_pos);
                let size = Vector3::new(op_w, sill_h, thick);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            // Dintel superior
            let op_y_end = op.y_bottom + op.height;
            if op_y_end < y_top {
                let lintel_h = y_top - op_y_end;
                let center = Vector3::new(op_center_x, op_y_end + lintel_h * 0.5, z_pos);
                let size = Vector3::new(op_w, lintel_h, thick);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            if op.is_door {
                let jamb_w = 0.04f32;
                let header_h = 0.04f32;
                let frame_depth = thick * 1.05;

                // Jamba izquierda
                let left_pos = Vector3::new(op_left + jamb_w * 0.5, op.y_bottom + op.height * 0.5, z_pos);
                let left_size = Vector3::new(jamb_w, op.height, frame_depth);
                carpentry.push(InstanceBox { position: left_pos, size: left_size, color: pal.trim });

                // Jamba derecha
                let right_pos = Vector3::new(op_right - jamb_w * 0.5, op.y_bottom + op.height * 0.5, z_pos);
                let right_size = Vector3::new(jamb_w, op.height, frame_depth);
                carpentry.push(InstanceBox { position: right_pos, size: right_size, color: pal.trim });

                // Dintel superior del marco
                let header_pos = Vector3::new(op_center_x, op.y_bottom + op.height - header_h * 0.5, z_pos);
                let header_size = Vector3::new(op_w, header_h, frame_depth);
                carpentry.push(InstanceBox { position: header_pos, size: header_size, color: pal.trim });

                // DoorInstance para renderizar con WoodenDoor texturizada en Godot (si no es vano abierto 255)
                if op.door_style != 255 {
                    doors.push(DoorInstance {
                        position: Vector3::new(op_center_x, op.y_bottom, z_pos),
                        size: Vector3::new(op_w - jamb_w * 2.0, op.height - header_h, 0.06),
                        rotation_y: 0.0, // Muro horizontal (eje X)
                        style_id: op.door_style,
                        is_main: op.is_main_door,
                    });
                }
            } else {
                let frame_w = 0.04f32;
                let frame_depth = thick * 1.05;

                let left_pos = Vector3::new(op_left + frame_w * 0.5, op.y_bottom + op.height * 0.5, z_pos);
                let left_size = Vector3::new(frame_w, op.height, frame_depth);
                carpentry.push(InstanceBox { position: left_pos, size: left_size, color: pal.window_frame });

                let right_pos = Vector3::new(op_right - frame_w * 0.5, op.y_bottom + op.height * 0.5, z_pos);
                let right_size = Vector3::new(frame_w, op.height, frame_depth);
                carpentry.push(InstanceBox { position: right_pos, size: right_size, color: pal.window_frame });

                let top_pos = Vector3::new(op_center_x, op.y_bottom + op.height - frame_w * 0.5, z_pos);
                let top_size = Vector3::new(op_w, frame_w, frame_depth);
                carpentry.push(InstanceBox { position: top_pos, size: top_size, color: pal.window_frame });

                let bot_pos = Vector3::new(op_center_x, op.y_bottom + frame_w * 0.5, z_pos);
                let bot_size = Vector3::new(op_w, frame_w, frame_depth);
                carpentry.push(InstanceBox { position: bot_pos, size: bot_size, color: pal.window_frame });

                let glass_pos = Vector3::new(op_center_x, op.y_bottom + op.height * 0.5, z_pos);
                let glass_size = Vector3::new(op_w - frame_w * 2.0, op.height - frame_w * 2.0, 0.03);
                glass.push(InstanceBox { position: glass_pos, size: glass_size, color: pal.window_glass });

                if is_exterior {
                    windows.push(WindowInstance {
                        position: Vector3::new(op_center_x, op.y_bottom + op.height * 0.5, z_pos + wall_normal.z * (thick * 0.5 + 0.02)),
                        size: Vector2::new(op_w, op.height),
                        normal: wall_normal,
                        floor,
                    });
                }
            }

            cur_x = op_right;
        }

        if cur_x < x_end {
            let seg_w = x_end - cur_x;
            let center = Vector3::new(cur_x + seg_w * 0.5, y_bot + wall_h * 0.5, z_pos);
            let size = Vector3::new(seg_w, wall_h, thick);
            walls.push(InstanceBox { position: center, size, color: wall_color });
            col_boxes.push(HouseCollisionBox { position: center, size });
        }
    }

    /// Construye una pared vertical continua sólida y perfora sus vanos con cajas 3D exactas.
    fn build_continuous_wall_z(
        walls: &mut Vec<InstanceBox>,
        carpentry: &mut Vec<InstanceBox>,
        glass: &mut Vec<InstanceBox>,
        doors: &mut Vec<DoorInstance>,
        windows: &mut Vec<WindowInstance>,
        col_boxes: &mut Vec<HouseCollisionBox>,
        x_pos: f32,
        z_start: f32,
        z_end: f32,
        y_bot: f32,
        y_top: f32,
        thick: f32,
        openings: &[WallOpening],
        pal: &HousePalette,
        is_exterior: bool,
        wall_normal: Vector3,
        floor: u8,
    ) {
        if z_end <= z_start {
            return;
        }

        let wall_color = if is_exterior { pal.wall_ext } else { pal.wall_int };
        let wall_h = y_top - y_bot;
        let mut cur_z = z_start;

        for op in openings {
            let op_top = (op.center - op.width * 0.5).max(z_start);
            let op_bot = (op.center + op.width * 0.5).min(z_end);

            if op_top > cur_z {
                let seg_d = op_top - cur_z;
                let center = Vector3::new(x_pos, y_bot + wall_h * 0.5, cur_z + seg_d * 0.5);
                let size = Vector3::new(thick, wall_h, seg_d);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            let op_d = op_bot - op_top;
            let op_center_z = (op_top + op_bot) * 0.5;

            // Antepecho inferior
            if op.y_bottom > y_bot {
                let sill_h = op.y_bottom - y_bot;
                let center = Vector3::new(x_pos, y_bot + sill_h * 0.5, op_center_z);
                let size = Vector3::new(thick, sill_h, op_d);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            // Dintel superior
            let op_y_end = op.y_bottom + op.height;
            if op_y_end < y_top {
                let lintel_h = y_top - op_y_end;
                let center = Vector3::new(x_pos, op_y_end + lintel_h * 0.5, op_center_z);
                let size = Vector3::new(thick, lintel_h, op_d);
                walls.push(InstanceBox { position: center, size, color: wall_color });
                col_boxes.push(HouseCollisionBox { position: center, size });
            }

            if op.is_door {
                let jamb_w = 0.04f32;
                let header_h = 0.04f32;
                let frame_depth = thick * 1.05;

                let j1_pos = Vector3::new(x_pos, op.y_bottom + op.height * 0.5, op_top + jamb_w * 0.5);
                let j1_size = Vector3::new(frame_depth, op.height, jamb_w);
                carpentry.push(InstanceBox { position: j1_pos, size: j1_size, color: pal.trim });

                let j2_pos = Vector3::new(x_pos, op.y_bottom + op.height * 0.5, op_bot - jamb_w * 0.5);
                let j2_size = Vector3::new(frame_depth, op.height, jamb_w);
                carpentry.push(InstanceBox { position: j2_pos, size: j2_size, color: pal.trim });

                let header_pos = Vector3::new(x_pos, op.y_bottom + op.height - header_h * 0.5, op_center_z);
                let header_size = Vector3::new(frame_depth, header_h, op_d);
                carpentry.push(InstanceBox { position: header_pos, size: header_size, color: pal.trim });

                // DoorInstance para renderizar con WoodenDoor texturizada en Godot (si no es vano abierto 255)
                if op.door_style != 255 {
                    doors.push(DoorInstance {
                        position: Vector3::new(x_pos, op.y_bottom, op_center_z),
                        size: Vector3::new(op_d - jamb_w * 2.0, op.height - header_h, 0.06),
                        rotation_y: std::f32::consts::FRAC_PI_2, // Muro vertical (eje Z) → 90°
                        style_id: op.door_style,
                        is_main: op.is_main_door,
                    });
                }
            } else {
                let frame_w = 0.04f32;
                let frame_depth = thick * 1.05;

                let j1_pos = Vector3::new(x_pos, op.y_bottom + op.height * 0.5, op_top + frame_w * 0.5);
                let j1_size = Vector3::new(frame_depth, op.height, frame_w);
                carpentry.push(InstanceBox { position: j1_pos, size: j1_size, color: pal.window_frame });

                let j2_pos = Vector3::new(x_pos, op.y_bottom + op.height * 0.5, op_bot - frame_w * 0.5);
                let j2_size = Vector3::new(frame_depth, op.height, frame_w);
                carpentry.push(InstanceBox { position: j2_pos, size: j2_size, color: pal.window_frame });

                let top_pos = Vector3::new(x_pos, op.y_bottom + op.height - frame_w * 0.5, op_center_z);
                let top_size = Vector3::new(frame_depth, frame_w, op_d);
                carpentry.push(InstanceBox { position: top_pos, size: top_size, color: pal.window_frame });

                let bot_pos = Vector3::new(x_pos, op.y_bottom + frame_w * 0.5, op_center_z);
                let bot_size = Vector3::new(frame_depth, frame_w, op_d);
                carpentry.push(InstanceBox { position: bot_pos, size: bot_size, color: pal.window_frame });

                let glass_pos = Vector3::new(x_pos, op.y_bottom + op.height * 0.5, op_center_z);
                let glass_size = Vector3::new(0.03, op.height - frame_w * 2.0, op_d - frame_w * 2.0);
                glass.push(InstanceBox { position: glass_pos, size: glass_size, color: pal.window_glass });

                if is_exterior {
                    windows.push(WindowInstance {
                        position: Vector3::new(x_pos + wall_normal.x * (thick * 0.5 + 0.02), op.y_bottom + op.height * 0.5, op_center_z),
                        size: Vector2::new(op_d, op.height),
                        normal: wall_normal,
                        floor,
                    });
                }
            }

            cur_z = op_bot;
        }

        if cur_z < z_end {
            let seg_d = z_end - cur_z;
            let center = Vector3::new(x_pos, y_bot + wall_h * 0.5, cur_z + seg_d * 0.5);
            let size = Vector3::new(thick, wall_h, seg_d);
            walls.push(InstanceBox { position: center, size, color: wall_color });
            col_boxes.push(HouseCollisionBox { position: center, size });
        }
    }
}

use godot::prelude::*;
use super::types::*;

pub struct FacilityMesher;

pub struct FacilityMeshingResult {
    pub ground_boxes: Vec<InstanceBox>,
    pub perimeter_boxes: Vec<InstanceBox>,
    pub structure_boxes: Vec<InstanceBox>,
    pub collision_boxes: Vec<CollisionBox>,
}

impl FacilityMesher {
    /// Construye todas las cajas 3D sólidas y cajas de colisión a partir del plano maestro.
    /// Cuadrícula calibrada a 1x1 metro por textura (+0 Draw Calls por tipo de superficie).
    pub fn build(blueprint: &FacilityBlueprint) -> FacilityMeshingResult {
        let mut ground_boxes = Vec::new();
        let mut perimeter_boxes = Vec::new();
        let mut structure_boxes = Vec::new();
        let mut collision_boxes = Vec::new();

        let half_w = blueprint.width_m * 0.5;
        let half_d = blueprint.depth_m * 0.5;

        // Paletas cromáticas de especificación militar PSX
        let col_concrete = Color::from_rgb(0.48, 0.49, 0.46);
        let col_wall_military = Color::from_rgb(0.38, 0.42, 0.35); // Verde oliva táctico
        let col_wall_concrete = Color::from_rgb(0.55, 0.55, 0.53);
        let col_roof_metal = Color::from_rgb(0.28, 0.30, 0.28);
        let col_helipad_yellow = Color::from_rgb(0.85, 0.72, 0.18);
        let col_fuel_tank = Color::from_rgb(0.65, 0.65, 0.65);

        // 1. Baldosas individuales de suelo (1 baldosa = 1 celda modular de 1x1m = 1 textura exacta)
        for z in 0..blueprint.grid_d {
            for x in 0..blueprint.grid_w {
                let layer_idx = blueprint.floor_tiles[x][z];
                let wx = (x as f32 + 0.5) * blueprint.cell_size - half_w;
                let wz = (z as f32 + 0.5) * blueprint.cell_size - half_d;
                ground_boxes.push(InstanceBox {
                    position: Vector3::new(wx, -0.05, wz),
                    size: Vector3::new(blueprint.cell_size, 0.10, blueprint.cell_size),
                    color: Color::from_rgba(layer_idx as f32 / 255.0, 0.85, 0.0, 1.0),
                });
            }
        }

        // Explanada exterior frontal frente al portón de acceso (5 filas de 1x1m)
        let apron_rows = 5;
        let gate_cx = blueprint.grid_w / 2;
        let gate_start_x = gate_cx - 3;
        let gate_end_x = gate_cx + 3;
        for az in 0..apron_rows {
            for x in 0..blueprint.grid_w {
                let is_road = x >= gate_start_x && x < gate_end_x;
                let layer_idx = if az == 0 && is_road {
                    29 // Franjas de advertencia amarillo/negro en el umbral del portón
                } else if is_road {
                    let is_curb = x == gate_start_x || x == gate_end_x - 1;
                    if is_curb { 16 } else { 14 } // Asfalto de aproximación
                } else {
                    17 // Grava y tierra exterior
                };
                let wx = (x as f32 + 0.5) * blueprint.cell_size - half_w;
                let wz = -half_d - (az as f32 + 0.5) * blueprint.cell_size;
                ground_boxes.push(InstanceBox {
                    position: Vector3::new(wx, -0.05, wz),
                    size: Vector3::new(blueprint.cell_size, 0.10, blueprint.cell_size),
                    color: Color::from_rgba(layer_idx as f32 / 255.0, 0.85, 0.0, 1.0),
                });
            }
        }

        // 2. Muro perimetral exterior (altura 3.6m, espesor 0.5m)
        let wall_h = 3.60;
        let wall_t = 0.50;

        // Muro trasero (+Z)
        perimeter_boxes.push(InstanceBox {
            position: Vector3::new(0.0, wall_h * 0.5, half_d - wall_t * 0.5),
            size: Vector3::new(blueprint.width_m, wall_h, wall_t),
            color: col_wall_military,
        });
        collision_boxes.push(CollisionBox {
            position: Vector3::new(0.0, wall_h * 0.5, half_d - wall_t * 0.5),
            size: Vector3::new(blueprint.width_m, wall_h, wall_t),
        });

        // Muros laterales (+X y -X)
        perimeter_boxes.push(InstanceBox {
            position: Vector3::new(half_w - wall_t * 0.5, wall_h * 0.5, 0.0),
            size: Vector3::new(wall_t, wall_h, blueprint.depth_m),
            color: col_wall_military,
        });
        collision_boxes.push(CollisionBox {
            position: Vector3::new(half_w - wall_t * 0.5, wall_h * 0.5, 0.0),
            size: Vector3::new(wall_t, wall_h, blueprint.depth_m),
        });

        perimeter_boxes.push(InstanceBox {
            position: Vector3::new(-half_w + wall_t * 0.5, wall_h * 0.5, 0.0),
            size: Vector3::new(wall_t, wall_h, blueprint.depth_m),
            color: col_wall_military,
        });
        collision_boxes.push(CollisionBox {
            position: Vector3::new(-half_w + wall_t * 0.5, wall_h * 0.5, 0.0),
            size: Vector3::new(wall_t, wall_h, blueprint.depth_m),
        });

        // Muro frontal (con hueco EXACTO de 6.0 metros para el portón vehicular)
        let seg_w = half_w - 3.0;
        if seg_w > 1.0 {
            // Segmento izquierdo (-half_w hasta -3.0)
            let seg_left_x = -half_w + seg_w * 0.5;
            perimeter_boxes.push(InstanceBox {
                position: Vector3::new(seg_left_x, wall_h * 0.5, -half_d + wall_t * 0.5),
                size: Vector3::new(seg_w, wall_h, wall_t),
                color: col_wall_military,
            });
            collision_boxes.push(CollisionBox {
                position: Vector3::new(seg_left_x, wall_h * 0.5, -half_d + wall_t * 0.5),
                size: Vector3::new(seg_w, wall_h, wall_t),
            });

            // Segmento derecho (+3.0 hasta +half_w)
            let seg_right_x = 3.0 + seg_w * 0.5;
            perimeter_boxes.push(InstanceBox {
                position: Vector3::new(seg_right_x, wall_h * 0.5, -half_d + wall_t * 0.5),
                size: Vector3::new(seg_w, wall_h, wall_t),
                color: col_wall_military,
            });
            collision_boxes.push(CollisionBox {
                position: Vector3::new(seg_right_x, wall_h * 0.5, -half_d + wall_t * 0.5),
                size: Vector3::new(seg_w, wall_h, wall_t),
            });
        }

        // 3. Generación geométrica de cada estructura
        for s in &blueprint.structures {
            let pos = s.world_pos;
            let size = s.world_size;

            match s.kind {
                StructureKind::Watchtower => {
                    // Pilares de la torre (4 patas de acero)
                    let leg_t = 0.35;
                    let tower_h = size.y;
                    let cabin_h = 2.40;
                    let leg_h = tower_h - cabin_h;

                    for dx in &[-0.5, 0.5] {
                        for dz in &[-0.5, 0.5] {
                            let lx = pos.x + dx * (size.x - leg_t);
                            let lz = pos.z + dz * (size.z - leg_t);
                            structure_boxes.push(InstanceBox {
                                position: Vector3::new(lx, leg_h * 0.5, lz),
                                size: Vector3::new(leg_t, leg_h, leg_t),
                                color: col_wall_military,
                            });
                        }
                    }

                    // Plataforma y caseta superior
                    let cabin_pos = Vector3::new(pos.x, leg_h + cabin_h * 0.5, pos.z);
                    structure_boxes.push(InstanceBox {
                        position: cabin_pos,
                        size: Vector3::new(size.x, cabin_h, size.z),
                        color: col_wall_concrete,
                    });
                    // Techo de la caseta con alero
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, tower_h + 0.10, pos.z),
                        size: Vector3::new(size.x + 0.4, 0.20, size.z + 0.4),
                        color: col_roof_metal,
                    });

                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, tower_h * 0.5, pos.z),
                        size: Vector3::new(size.x, tower_h, size.z),
                    });
                }

                StructureKind::Guardhouse => {
                    // Caseta compacta con losa y alero
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x, size.y, size.z),
                        color: col_wall_military,
                    });
                    // Techo
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.12, pos.z),
                        size: Vector3::new(size.x + 0.5, 0.22, size.z + 0.5),
                        color: col_roof_metal,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::Hangar => {
                    let wall_thick = 0.50;

                    // Muros exteriores (laterales y fondo)
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x - size.x * 0.5 + wall_thick * 0.5, size.y * 0.5, pos.z),
                        size: Vector3::new(wall_thick, size.y, size.z),
                        color: col_wall_military,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x + size.x * 0.5 - wall_thick * 0.5, size.y * 0.5, pos.z),
                        size: Vector3::new(wall_thick, size.y, size.z),
                        color: col_wall_military,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z - size.z * 0.5 + wall_thick * 0.5),
                        size: Vector3::new(size.x, size.y, wall_thick),
                        color: col_wall_military,
                    });

                    // Techo abovedado de metal
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.20, pos.z),
                        size: Vector3::new(size.x + 0.8, 0.40, size.z + 0.6),
                        color: col_roof_metal,
                    });

                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::Barracks | StructureKind::CommandHQ | StructureKind::MessHall | StructureKind::MedicalClinic | StructureKind::Armory => {
                    // Cuerpo del edificio
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x, size.y, size.z),
                        color: if s.kind == StructureKind::CommandHQ || s.kind == StructureKind::MedicalClinic {
                            col_wall_concrete
                        } else {
                            col_wall_military
                        },
                    });
                    // Techo con alero
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.12, pos.z),
                        size: Vector3::new(size.x + 0.5, 0.25, size.z + 0.5),
                        color: col_roof_metal,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::VehicleWorkshop => {
                    let wall_thick = 0.50;
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x - size.x * 0.5 + wall_thick * 0.5, size.y * 0.5, pos.z),
                        size: Vector3::new(wall_thick, size.y, size.z),
                        color: col_wall_military,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x + size.x * 0.5 - wall_thick * 0.5, size.y * 0.5, pos.z),
                        size: Vector3::new(wall_thick, size.y, size.z),
                        color: col_wall_military,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z - size.z * 0.5 + wall_thick * 0.5),
                        size: Vector3::new(size.x, size.y, wall_thick),
                        color: col_wall_military,
                    });
                    // Techo
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.15, pos.z),
                        size: Vector3::new(size.x + 0.6, 0.30, size.z + 0.6),
                        color: col_roof_metal,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::CommsRadarPost => {
                    let cabin_h = 3.6;
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, cabin_h * 0.5, pos.z),
                        size: Vector3::new(size.x, cabin_h, size.z),
                        color: col_wall_concrete,
                    });
                    // Mástil
                    let mast_h = size.y - cabin_h;
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, cabin_h + mast_h * 0.5, pos.z),
                        size: Vector3::new(0.5, mast_h, 0.5),
                        color: col_fuel_tank,
                    });
                    // Plato / radar
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.25, pos.z),
                        size: Vector3::new(2.2, 0.5, 0.8),
                        color: col_helipad_yellow,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, cabin_h * 0.5, pos.z),
                        size: Vector3::new(size.x, cabin_h, size.z),
                    });
                }

                StructureKind::Helipad => {
                    // Letra "H" táctica militar elevada 2cm sobre el suelo
                    let bar_w = 0.8;
                    let h_len = 6.0;
                    // Barra izquierda
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x - 2.0, 0.02, pos.z),
                        size: Vector3::new(bar_w, 0.04, h_len),
                        color: col_helipad_yellow,
                    });
                    // Barra derecha
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x + 2.0, 0.02, pos.z),
                        size: Vector3::new(bar_w, 0.04, h_len),
                        color: col_helipad_yellow,
                    });
                    // Travesaño
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, 0.02, pos.z),
                        size: Vector3::new(4.0, 0.04, bar_w),
                        color: col_helipad_yellow,
                    });
                }

                StructureKind::FuelDepot => {
                    // Batería de 2 tanques cilíndricos
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x - size.x * 0.25, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x * 0.42, size.y, size.z * 0.85),
                        color: col_fuel_tank,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x + size.x * 0.25, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x * 0.42, size.y, size.z * 0.85),
                        color: col_fuel_tank,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::BunkerEntrance => {
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x, size.y, size.z),
                        color: col_wall_concrete,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.15, pos.z),
                        size: Vector3::new(size.x + 0.4, 0.30, size.z + 0.4),
                        color: col_roof_metal,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                StructureKind::MachineGunBunker => {
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size: Vector3::new(size.x, size.y, size.z),
                        color: col_wall_military,
                    });
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y + 0.10, pos.z),
                        size: Vector3::new(size.x + 0.3, 0.20, size.z + 0.3),
                        color: col_roof_metal,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }

                _ => {
                    structure_boxes.push(InstanceBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                        color: col_wall_military,
                    });
                    collision_boxes.push(CollisionBox {
                        position: Vector3::new(pos.x, size.y * 0.5, pos.z),
                        size,
                    });
                }
            }
        }

        FacilityMeshingResult {
            ground_boxes,
            perimeter_boxes,
            structure_boxes,
            collision_boxes,
        }
    }
}

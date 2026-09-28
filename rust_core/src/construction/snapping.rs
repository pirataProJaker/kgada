use godot::prelude::*;

/// Redondea un valor continuo al múltiplo más cercano del paso de rejilla especificado.
#[inline]
pub fn snap_scalar(val: f32, step: f32) -> f32 {
    if step <= 0.0 {
        return val;
    }
    (val / step).round() * step
}

/// Snapping 3D básico a la rejilla métrica.
pub fn snap_to_grid(pos: Vector3, step: f32) -> Vector3 {
    Vector3::new(
        snap_scalar(pos.x, step),
        snap_scalar(pos.y, step),
        snap_scalar(pos.z, step),
    )
}

/// Snapping para Pisos y Techos (Modo Horizontal XZ):
/// Fija rígidamente la altura Y al punto de origen p0.
/// Sigue el cursor del ratón de forma completamente continua y fluida (SIN saltos de rejilla),
/// garantizando únicamente el MÍNIMO ESTRICTO de 1 metro por cada lado (|Δx| >= 1.0, |Δz| >= 1.0).
pub fn snap_floor_point(origin: Vector3, ray_hit: Vector3, min_step: f32) -> Vector3 {
    let s = min_step.max(1.0);
    let dx = ray_hit.x - origin.x;
    let dz = ray_hit.z - origin.z;

    let clamped_dx = if dx.abs() < s {
        if dx >= 0.0 { s } else { -s }
    } else {
        dx
    };

    let clamped_dz = if dz.abs() < s {
        if dz >= 0.0 { s } else { -s }
    } else {
        dz
    };

    Vector3::new(
        origin.x + clamped_dx,
        origin.y,
        origin.z + clamped_dz,
    )
}

/// Snapping para Paredes (Modo Vertical Y):
/// Permite desplazar en altura Y de forma continua con un mínimo de 1 metro de altura.
pub fn snap_wall_height(origin_y: f32, ray_hit_y: f32, _step: f32, min_height: f32) -> f32 {
    let raw_height = ray_hit_y - origin_y;
    let min_h = min_height.max(1.0);
    if raw_height.abs() < min_h {
        if raw_height >= 0.0 { min_h } else { -min_h }
    } else {
        raw_height
    }
}

/// Magnet Snapping: Busca si el cursor está a menos de `threshold` de un vértice o arista
/// existente para cerrar habitaciones o acoplar esquinas limpiamente.
pub fn find_closest_magnet_point(target: Vector3, existing_points: &[Vector3], threshold: f32) -> Option<Vector3> {
    let mut closest_pt = None;
    let mut min_dist_sq = threshold * threshold;

    for &pt in existing_points {
        let dist_sq = (pt.x - target.x).powi(2) + (pt.y - target.y).powi(2) + (pt.z - target.z).powi(2);
        if dist_sq < min_dist_sq {
            min_dist_sq = dist_sq;
            closest_pt = Some(pt);
        }
    }

    closest_pt
}

/// Resultado del anclaje magnético de un punto a un piso.
#[derive(Debug, Clone, Copy)]
pub struct FloorSnapResult {
    pub position: Vector3,
    pub is_valid: bool,
    pub is_on_edge: bool,
    pub is_corner: bool,
    pub edge_index: i32, // -1: Ninguno, 0: Norte (Z min), 1: Este (X max), 2: Sur (Z max), 3: Oeste (X min)
}

/// Ancla un punto al perímetro (orillas) o superficie interior de un piso rectangular.
pub fn snap_point_to_floor_rect(
    pos: Vector3,
    min_x: f32,
    max_x: f32,
    min_z: f32,
    max_z: f32,
    floor_y: f32,
    edge_threshold: f32,
    max_reach_margin: f32,
) -> FloorSnapResult {
    let clamped_x = pos.x.clamp(min_x, max_x);
    let clamped_z = pos.z.clamp(min_z, max_z);
    let dist_to_rect_sq = (pos.x - clamped_x).powi(2) + (pos.z - clamped_z).powi(2);

    if dist_to_rect_sq > max_reach_margin.powi(2) {
        return FloorSnapResult {
            position: pos,
            is_valid: false,
            is_on_edge: false,
            is_corner: false,
            edge_index: -1,
        };
    }

    let d_west = (pos.x - min_x).abs();
    let d_east = (pos.x - max_x).abs();
    let d_north = (pos.z - min_z).abs();
    let d_south = (pos.z - max_z).abs();

    let near_west = d_west <= edge_threshold;
    let near_east = d_east <= edge_threshold;
    let near_north = d_north <= edge_threshold;
    let near_south = d_south <= edge_threshold;

    let inset = 0.10f32; // Inset de medio espesor de pared (0.20m / 2) para que el muro descanse 100% sobre el piso
    let in_min_x = (min_x + inset).min(max_x - inset);
    let in_max_x = (max_x - inset).max(min_x + inset);
    let in_min_z = (min_z + inset).min(max_z - inset);
    let in_max_z = (max_z - inset).max(min_z + inset);

    let in_clamped_x = pos.x.clamp(in_min_x, in_max_x);
    let in_clamped_z = pos.z.clamp(in_min_z, in_max_z);

    // Comprobar esquinas (confluencia de dos bordes ortogonales)
    if near_north && near_west {
        return FloorSnapResult {
            position: Vector3::new(in_min_x, floor_y, in_min_z),
            is_valid: true,
            is_on_edge: true,
            is_corner: true,
            edge_index: 0,
        };
    } else if near_north && near_east {
        return FloorSnapResult {
            position: Vector3::new(in_max_x, floor_y, in_min_z),
            is_valid: true,
            is_on_edge: true,
            is_corner: true,
            edge_index: 0,
        };
    } else if near_south && near_west {
        return FloorSnapResult {
            position: Vector3::new(in_min_x, floor_y, in_max_z),
            is_valid: true,
            is_on_edge: true,
            is_corner: true,
            edge_index: 2,
        };
    } else if near_south && near_east {
        return FloorSnapResult {
            position: Vector3::new(in_max_x, floor_y, in_max_z),
            is_valid: true,
            is_on_edge: true,
            is_corner: true,
            edge_index: 2,
        };
    }

    // Comprobar borde más cercano
    let min_d = d_west.min(d_east).min(d_north).min(d_south);
    if min_d <= edge_threshold {
        if min_d == d_west {
            return FloorSnapResult {
                position: Vector3::new(in_min_x, floor_y, in_clamped_z),
                is_valid: true,
                is_on_edge: true,
                is_corner: false,
                edge_index: 3,
            };
        } else if min_d == d_east {
            return FloorSnapResult {
                position: Vector3::new(in_max_x, floor_y, in_clamped_z),
                is_valid: true,
                is_on_edge: true,
                is_corner: false,
                edge_index: 1,
            };
        } else if min_d == d_north {
            return FloorSnapResult {
                position: Vector3::new(in_clamped_x, floor_y, in_min_z),
                is_valid: true,
                is_on_edge: true,
                is_corner: false,
                edge_index: 0,
            };
        } else {
            return FloorSnapResult {
                position: Vector3::new(in_clamped_x, floor_y, in_max_z),
                is_valid: true,
                is_on_edge: true,
                is_corner: false,
                edge_index: 2,
            };
        }
    }

    // Punto dentro del piso pero alejado de orillas
    FloorSnapResult {
        position: Vector3::new(in_clamped_x, floor_y, in_clamped_z),
        is_valid: true,
        is_on_edge: false,
        is_corner: false,
        edge_index: -1,
    }
}


pub mod types;
pub mod snapping;
pub mod mesh_generator;
pub mod engine_node;

pub use types::{BuildingElementType, MaterialType, GridCoord3D, BuildingElement};
pub use snapping::{snap_to_grid, snap_floor_point, snap_wall_height, find_closest_magnet_point};
pub use mesh_generator::ConstructionMeshGenerator;
pub use engine_node::ConstructionEngine;

#[cfg(test)]
mod tests {
    use super::*;
    use godot::prelude::*;

    #[test]
    fn test_floor_snapping_locks_y() {
        let origin = Vector3::new(0.0, 5.0, 0.0);
        let ray = Vector3::new(3.4, 12.8, 4.1);
        let snapped = snap_floor_point(origin, ray, 1.0);

        assert_eq!(snapped.y, 5.0, "La altura Y debe permanecer bloqueada al origen");
        assert!((snapped.x - 3.4).abs() < 0.001, "X debe seguir el cursor de forma continua");
        assert!((snapped.z - 4.1).abs() < 0.001, "Z debe seguir el cursor de forma continua");
    }

    #[test]
    fn test_wall_snapping_height() {
        let origin_y = 2.0;
        let ray_y = 5.2;
        let h = snap_wall_height(origin_y, ray_y, 1.0, 1.0);
        assert!((h - 3.2).abs() < 0.001, "Altura de pared debe ser continua de 3.2m");
    }

    #[test]
    fn test_magnet_snapping() {
        let existing = vec![
            Vector3::new(0.0, 0.0, 0.0),
            Vector3::new(5.0, 0.0, 5.0),
        ];

        let cursor_near = Vector3::new(5.15, 0.05, 4.95);
        let magnet = find_closest_magnet_point(cursor_near, &existing, 0.40);
        assert_eq!(magnet, Some(Vector3::new(5.0, 0.0, 5.0)), "Debe hacer magnet snap al vértice cercano");

        let cursor_far = Vector3::new(8.0, 0.0, 8.0);
        let no_magnet = find_closest_magnet_point(cursor_far, &existing, 0.40);
        assert_eq!(no_magnet, None, "No debe hacer snap si está fuera del umbral");
    }
}

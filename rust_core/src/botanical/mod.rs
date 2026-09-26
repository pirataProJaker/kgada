pub mod species;
pub mod graph;
pub mod growth;
pub mod mesh_builder;
pub mod tree_node;

pub use species::{FoliageType, SpeciesProfile};
pub use graph::{BotanicalGraph, NodeSegment, Bud, LeafClusterNode};
pub use growth::generate_tree_growth;
pub use mesh_builder::{BotanicalMeshBuilder, TreeMeshData, RawSurfaceData};
pub use tree_node::BotanicalTree;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_growth_determinism() {
        let species = SpeciesProfile::alnus_acuminata();
        let g1 = generate_tree_growth(&species, 98765, 0.8, &[]);
        let g2 = generate_tree_growth(&species, 98765, 0.8, &[]);

        assert_eq!(g1.nodes.len(), g2.nodes.len(), "Misma semilla y edad debe producir la misma cantidad de nodos");
        assert_eq!(g1.leaf_clusters.len(), g2.leaf_clusters.len(), "Misma cantidad de hojas");
        assert!((g1.current_height() - g2.current_height()).abs() < 1e-4, "Misma altura");
    }

    #[test]
    fn test_height_scales_with_age() {
        let species = SpeciesProfile::alnus_acuminata();
        let sprout = generate_tree_growth(&species, 123, 0.0, &[]);
        let young = generate_tree_growth(&species, 123, 0.4, &[]);
        let adult = generate_tree_growth(&species, 123, 1.0, &[]);

        assert!(sprout.current_height() < young.current_height(), "El brote debe ser menor que el arbol joven");
        assert!(young.current_height() < adult.current_height(), "El arbol joven debe ser menor que el adulto");
        assert!(sprout.current_height() <= 0.5, "El brote debe ser de menos de 50cm");
        assert!(adult.current_height() >= 10.0, "El adulto debe superar los 10m");
    }

    #[test]
    fn test_pruning_removes_branches() {
        let species = SpeciesProfile::alnus_acuminata();
        let mut tree = generate_tree_growth(&species, 555, 0.9, &[]);

        let initial_active = tree.active_segments().count();
        let initial_leaves = tree.active_clusters().count();

        // Encontrar una rama primaria
        let primary_id = tree.active_segments().find(|n| n.depth == 1 && n.order_index == 0).map(|n| n.id).expect("Debe haber ramas primarias");

        let pruned_count = tree.prune_branch(primary_id);
        assert!(pruned_count > 0, "Debe haber podado al menos un nodo");

        let new_active = tree.active_segments().count();
        assert_eq!(new_active, initial_active - pruned_count, "Los nodos activos deben haberse reducido exactamente en pruned_count");
        assert!(tree.active_clusters().count() <= initial_leaves, "Las hojas asociadas a la rama podada deben desactivarse");
    }

    #[test]
    fn test_lod_decimation() {
        let species = SpeciesProfile::alnus_acuminata();
        let tree = generate_tree_growth(&species, 777, 0.85, &[]);

        let lod0 = BotanicalMeshBuilder::build_lod0(&tree, &species, 0);
        let lod1 = BotanicalMeshBuilder::build_lod1(&tree, &species, 0);
        let lod2 = BotanicalMeshBuilder::build_lod2(&tree, &species, 0);
        let lod3 = BotanicalMeshBuilder::build_lod3(&tree, &species);

        assert!(lod0.total_triangles() > lod1.total_triangles(), "LOD0 debe tener mas triangulos que LOD1");
        assert!(lod1.total_triangles() > lod2.total_triangles(), "LOD1 debe tener mas triangulos que LOD2");
        assert!(lod2.total_triangles() > lod3.total_triangles(), "LOD2 debe tener mas triangulos que LOD3");
        assert_eq!(lod3.total_triangles(), 2, "LOD3 debe tener exactamente 2 triangulos");

        // Verificación estricta del nuevo modo RadialCross20 (exactamente 20 triángulos de follaje)
        let lod0_radial = BotanicalMeshBuilder::build_lod0(&tree, &species, 1);
        assert_eq!(lod0_radial.leaves.triangle_count(), 20, "RadialCross20 debe tener exactamente 20 triangulos de hojas");
    }
}

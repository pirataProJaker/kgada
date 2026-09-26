use godot::prelude::*;
use godot::classes::ArrayMesh;
use godot::classes::mesh::{ArrayType, PrimitiveType};
use super::graph::BotanicalGraph;
use super::growth::generate_tree_growth;
use super::mesh_builder::{BotanicalMeshBuilder, RawSurfaceData};
use super::species::SpeciesProfile;

/// Nodo de Árbol Botánico Procedural en Rust.
///
/// Soporta:
/// - Crecimiento continuo de 0.0 (semilla/brote) a 1.0 (árbol adulto).
/// - Poda interactiva en tiempo real (cortar ramas y ver la redistribución de savia).
/// - LODs sincronizados (LOD 0 en 3D, LOD 1 en aletas 2D, LOD 2/3 en billboards).
/// - Arquitectura genérica por especies (con Alnus acuminata como especie piloto).
#[derive(GodotClass)]
#[class(init, base=Node3D)]
pub struct BotanicalTree {
    base: Base<Node3D>,

    species_id: GString,
    age: f32,
    seed_value: i64,
    current_lod: i32,
    foliage_mode: i32,

    graph_cached: Option<BotanicalGraph>,
    species_cached: Option<SpeciesProfile>,
}

#[godot_api]
impl INode3D for BotanicalTree {
    fn ready(&mut self) {
        if self.species_id.is_empty() {
            self.species_id = "alnus_acuminata".into();
        }
        if self.seed_value == 0 {
            self.seed_value = 12345;
        }
        if self.age <= 0.0 {
            self.age = 0.85; // Por defecto árbol joven-adulto
        }
        self.foliage_mode = 2; // 2 = LushBranchBoughs por defecto
        self.rebuild_graph();
    }
}

#[godot_api]
impl BotanicalTree {
    /// Obtiene el perfil de especie actual.
    fn get_species(&self) -> SpeciesProfile {
        match self.species_id.to_string().to_lowercase().as_str() {
            "classic_oak" | "oak" => SpeciesProfile::classic_oak(),
            "autumn_birch" | "birch" => SpeciesProfile::autumn_birch(),
            "weeping_willow" | "willow" => SpeciesProfile::weeping_willow(),
            "dead_tree" | "dead" => SpeciesProfile::dead_tree(),
            "alnus_acuminata" | "alnus" | _ => SpeciesProfile::alnus_acuminata(),
        }
    }

    /// Reconstruye el grafo botánico según la edad y la semilla actuales.
    #[func]
    pub fn rebuild_graph(&mut self) {
        let species = self.get_species();
        let pruned = self.graph_cached.as_ref().map(|g| g.pruned_nodes_history.clone()).unwrap_or_default();
        let graph = generate_tree_growth(&species, self.seed_value as u64, self.age, &pruned);
        self.species_cached = Some(species);
        self.graph_cached = Some(graph);
    }

    /// Asigna una nueva edad (0.0 a 1.0) y actualiza el grafo botánico.
    #[func]
    pub fn set_age(&mut self, new_age: f32) {
        self.age = new_age.clamp(0.0, 1.0);
        self.rebuild_graph();
    }

    #[func]
    pub fn get_age(&self) -> f32 {
        self.age
    }

    #[func]
    pub fn set_tree_seed(&mut self, new_seed: i64) {
        self.seed_value = new_seed;
        // Limpiar podas al cambiar de semilla
        if let Some(g) = self.graph_cached.as_mut() {
            g.pruned_nodes_history.clear();
        }
        self.rebuild_graph();
    }

    #[func]
    pub fn get_tree_seed(&self) -> i64 {
        self.seed_value
    }

    #[func]
    pub fn set_species_id(&mut self, id: GString) {
        self.species_id = id;
        self.rebuild_graph();
    }

    #[func]
    pub fn get_species_id(&self) -> GString {
        self.species_id.clone()
    }

    /// Poda una rama específica por su índice de nodo.
    /// Retorna la cantidad de nodos cortados.
    #[func]
    pub fn prune_branch(&mut self, node_id: i32) -> i32 {
        if let Some(graph) = self.graph_cached.as_mut() {
            let count = graph.prune_branch(node_id as usize);
            return count as i32;
        }
        0
    }

    /// Poda una rama primaria aleatoria (ideal para pruebas y demostraciones interactivas).
    #[func]
    pub fn prune_random_branch(&mut self) -> i32 {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let graph = self.graph_cached.as_mut().unwrap();
        // Buscar un nodo activo de rama primaria (depth == 1, order == 0)
        let candidate_id = graph
            .active_segments()
            .find(|n| n.depth == 1 && n.order_index == 0)
            .map(|n| n.id);

        if let Some(id) = candidate_id {
            graph.prune_branch(id) as i32
        } else {
            0
        }
    }

    /// Restaura todas las podas para devolver al árbol a su forma natural completa.
    #[func]
    pub fn restore_all_branches(&mut self) {
        if let Some(graph) = self.graph_cached.as_mut() {
            graph.pruned_nodes_history.clear();
        }
        self.rebuild_graph();
    }

    #[func]
    pub fn set_foliage_mode(&mut self, mode: i32) {
        self.foliage_mode = mode;
    }

    #[func]
    pub fn get_foliage_mode(&self) -> i32 {
        self.foliage_mode
    }

    /// Retorna los límites de la copa como Vector3(y_base, y_top, r_max).
    #[func]
    pub fn get_canopy_bounds(&mut self) -> Vector3 {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }
        let graph = self.graph_cached.as_ref().unwrap();
        let (y_base, y_top, r_max) = BotanicalMeshBuilder::calculate_canopy_bounds(graph);
        Vector3::new(y_base, y_top, r_max)
    }

    /// Retorna un Array con los segmentos de ramas activas.
    #[func]
    pub fn get_branch_segments(&mut self) -> VarArray {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }
        let graph = self.graph_cached.as_ref().unwrap();
        let mut arr = VarArray::new();

        for seg in graph.active_segments() {
            if seg.depth > 0 {
                let mut dict = VarDictionary::new();
                dict.set("start", seg.start_pos);
                dict.set("end", seg.end_pos);
                dict.set("depth", seg.depth as i64);
                dict.set("order", seg.order_index as i64);
                dict.set("radius", seg.base_radius);
                arr.push(&dict.to_variant());
            }
        }
        arr
    }

    /// Devuelve un Dictionary con los buffers de vértices, normales, UVs e índices
    /// para el nivel de LOD especificado (0, 1, 2, 3).
    #[func]
    pub fn get_lod_data(&mut self, lod: i32) -> VarDictionary {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        mesh_data.to_godot_dict()
    }

    /// Genera y devuelve directamente un `ArrayMesh` de Godot para el nivel de LOD especificado.
    ///
    /// - Superficie 0: Madera (Tronco y ramas)
    /// - Superficie 1: Hojas (Racimos de follaje)
    #[func]
    pub fn get_lod_mesh(&mut self, lod: i32) -> Option<Gd<ArrayMesh>> {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        let mut array_mesh = ArrayMesh::new_gd();

        // Superficie 0: Madera
        if !mesh_data.wood.indices.is_empty() {
            Self::add_surface_from_raw(&mut array_mesh, &mesh_data.wood);
        }

        // Superficie 1: Hojas
        if !mesh_data.leaves.indices.is_empty() {
            Self::add_surface_from_raw(&mut array_mesh, &mesh_data.leaves);
        }

        Some(array_mesh)
    }

    /// Devuelve un Array con [wood_mesh, leaves_mesh] separados para el nivel de LOD especificado.
    /// Permite asignar mallas individuales a nodos MultiMeshInstance3D conservando exactamente 2 draw calls.
    #[func]
    pub fn get_lod_split_meshes(&mut self, lod: i32) -> VarArray {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        let mut wood_mesh = ArrayMesh::new_gd();
        if !mesh_data.wood.indices.is_empty() {
            Self::add_surface_from_raw(&mut wood_mesh, &mesh_data.wood);
        }

        let mut leaves_mesh = ArrayMesh::new_gd();
        if !mesh_data.leaves.indices.is_empty() {
            Self::add_surface_from_raw(&mut leaves_mesh, &mesh_data.leaves);
        }

        let mut arr = VarArray::new();
        arr.push(&wood_mesh.to_variant());
        arr.push(&leaves_mesh.to_variant());
        arr
    }

    /// Devuelve la malla ArrayMesh de madera (tronco y ramas) para el LOD especificado.
    #[func]
    pub fn get_lod_wood_mesh(&mut self, lod: i32) -> Option<Gd<ArrayMesh>> {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        let mut array_mesh = ArrayMesh::new_gd();
        if !mesh_data.wood.indices.is_empty() {
            Self::add_surface_from_raw(&mut array_mesh, &mesh_data.wood);
        }
        Some(array_mesh)
    }

    /// Devuelve la malla ArrayMesh de hojas/ramas para el LOD especificado.
    #[func]
    pub fn get_lod_leaves_mesh(&mut self, lod: i32) -> Option<Gd<ArrayMesh>> {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        let mut array_mesh = ArrayMesh::new_gd();
        if !mesh_data.leaves.indices.is_empty() {
            Self::add_surface_from_raw(&mut array_mesh, &mesh_data.leaves);
        }
        Some(array_mesh)
    }

    #[func]
    pub fn set_current_lod(&mut self, lod: i32) {
        self.current_lod = lod.clamp(0, 3);
    }

    #[func]
    pub fn get_current_lod(&self) -> i32 {
        self.current_lod
    }

    /// Función auxiliar interna para construir una superficie en ArrayMesh.
    fn add_surface_from_raw(array_mesh: &mut Gd<ArrayMesh>, raw: &RawSurfaceData) {
        if raw.indices.is_empty() {
            return;
        }
        let mut p_verts = PackedVector3Array::new();
        let mut p_norms = PackedVector3Array::new();
        let mut p_uvs = PackedVector2Array::new();
        let mut p_indices = PackedInt32Array::new();

        for v in &raw.vertices { p_verts.push(*v); }
        for n in &raw.normals { p_norms.push(*n); }
        for u in &raw.uvs { p_uvs.push(*u); }
        for i in &raw.indices { p_indices.push(*i); }

        let mut arrays = VarArray::new();
        for _ in 0..ArrayType::MAX.ord() {
            arrays.push(&Variant::nil());
        }
        arrays.set(ArrayType::VERTEX.ord() as usize, &p_verts.to_variant());
        arrays.set(ArrayType::NORMAL.ord() as usize, &p_norms.to_variant());
        arrays.set(ArrayType::TEX_UV.ord() as usize, &p_uvs.to_variant());
        arrays.set(ArrayType::INDEX.ord() as usize, &p_indices.to_variant());

        array_mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);
    }

    /// Retorna la cantidad total de triángulos calculados para el LOD especificado.
    #[func]
    pub fn get_total_triangles(&mut self, lod: i32) -> i32 {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }

        let species = self.species_cached.as_ref().unwrap();
        let graph = self.graph_cached.as_ref().unwrap();

        let mesh_data = match lod {
            0 => BotanicalMeshBuilder::build_lod0(graph, species, self.foliage_mode),
            1 => BotanicalMeshBuilder::build_lod1(graph, species, self.foliage_mode),
            2 => BotanicalMeshBuilder::build_lod2(graph, species, self.foliage_mode),
            _ => BotanicalMeshBuilder::build_lod3(graph, species),
        };

        mesh_data.total_triangles() as i32
    }

    /// Retorna la cantidad de ramas activas vivas.
    #[func]
    pub fn get_branch_count(&mut self) -> i32 {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }
        let graph = self.graph_cached.as_ref().unwrap();
        graph.active_segments().filter(|s| s.depth > 0 && s.order_index == 0).count() as i32
    }

    /// Retorna la altura actual del árbol en metros.
    #[func]
    pub fn get_height(&mut self) -> f32 {
        if self.graph_cached.is_none() {
            self.rebuild_graph();
        }
        self.graph_cached.as_ref().unwrap().current_height()
    }
}

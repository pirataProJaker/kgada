use godot::prelude::*;
use godot::classes::{BoxMesh, MultiMesh};
use godot::classes::multi_mesh::TransformFormat;

use super::network::RoadNetwork;
use super::profile::{RoadCrossSection, MedianStyle};
use super::solver::{RoadSolver, RoadEngineOutput};

/// Motor Procedural de Calles y Carreteras de Alto Rendimiento en Rust.
///
/// Gestiona la red vial como un grafo modular de secciones transversales y produce
/// buffers de instancias de cubos (GPU Instancing con MultiMesh) listos para renderizarse
/// con exactamente 1-2 draw calls por categoría física (asfalto, banquetas, camellones).
#[derive(GodotClass)]
#[class(init, base=Node3D)]
pub struct RoadEngine {
    base: Base<Node3D>,

    network: RoadNetwork,
    cached_output: Option<RoadEngineOutput>,
}

#[godot_api]
impl INode3D for RoadEngine {
    fn ready(&mut self) {
        godot_print!("[RoadEngine] Motor de Carreteras Procedurales inicializado en Rust.");
    }
}

#[godot_api]
impl RoadEngine {
    /// Limpia todos los nodos, tramos y mallas de la red.
    #[func]
    pub fn clear(&mut self) {
        self.network.clear();
        self.cached_output = None;
    }

    /// Añade un nodo de intersección o punto final de vía en las coordenadas dadas.
    /// Retorna el ID numérico del nodo. Si ya existe un nodo en esa posición (<0.2m), lo reutiliza.
    #[func]
    pub fn add_node(&mut self, pos: Vector3) -> i32 {
        self.cached_output = None;
        self.network.add_or_find_node(pos) as i32
    }

    /// Añade un tramo de calle entre dos nodos especificando su categoría y parámetros editables.
    ///
    /// Categorías soportadas:
    /// - "residential_2lane": Calle residencial típica de 2 sentidos y banquetas.
    /// - "residential_narrow": Calle estrecha de 1 carril con banqueta lateral.
    /// - "divided_boulevard": Bulevar de 2 calzadas con camellón arbolado al centro.
    /// - "stream_parkway": Avenida con arroyo o canal en medio y banquetas exteriores.
    /// - "commercial_4lane": Avenida continua de 4 carriles de alta capacidad.
    /// - "rural_2lane": Carretera rural sin banquetas.
    #[func]
    pub fn add_road(
        &mut self,
        from_node: i32,
        to_node: i32,
        category: GString,
        params: VarDictionary,
    ) -> i32 {
        self.cached_output = None;

        let cat_str = category.to_string().to_lowercase();
        let mut profile = match cat_str.as_str() {
            "residential_narrow" | "narrow" => RoadCrossSection::residential_narrow_1lane(),
            "divided_boulevard" | "boulevard" => {
                let lanes = params.get("lanes").map(|v| v.to::<i64>() as usize).unwrap_or(3);
                let med_w = params.get("median_width").map(|v| v.to::<f64>() as f32).unwrap_or(8.0);
                let med_style_str = params.get("median_style").map(|v| v.to::<GString>().to_string()).unwrap_or_else(|| "trees".to_string());
                RoadCrossSection::divided_boulevard(lanes, med_w, MedianStyle::from_str(&med_style_str))
            }
            "stream_parkway" | "parkway" | "stream" => {
                let lanes = params.get("lanes").map(|v| v.to::<i64>() as usize).unwrap_or(2);
                let stream_w = params.get("stream_width").map(|v| v.to::<f64>() as f32).unwrap_or(16.0);
                RoadCrossSection::stream_parkway(lanes, stream_w)
            }
            "commercial_4lane" | "commercial" | "avenue" => RoadCrossSection::commercial_avenue_4lane(),
            "rural_2lane" | "rural" => RoadCrossSection::rural_road_2lane(),
            _ => RoadCrossSection::residential_2lane(),
        };

        // Sobrescritura paramétrica opcional enviada en el Dictionary
        if let Some(lw) = params.get("lane_width") {
            profile.lane_width = lw.to::<f64>() as f32;
        }
        if let Some(sw_w) = params.get("sidewalk_width") {
            profile.sidewalk_width = sw_w.to::<f64>() as f32;
        }
        if let Some(has_l) = params.get("has_left_sidewalk") {
            profile.has_left_sidewalk = has_l.to::<bool>();
        }
        if let Some(has_r) = params.get("has_right_sidewalk") {
            profile.has_right_sidewalk = has_r.to::<bool>();
        }
        if let Some(ts) = params.get("tree_spacing") {
            profile.tree_spacing = ts.to::<f64>() as f32;
        }
        if let Some(fd) = params.get("foundation_depth") {
            profile.foundation_depth = fd.to::<f64>() as f32;
        }
        if let Some(re) = params.get("road_surface_elevation") {
            profile.road_surface_elevation = re.to::<f64>() as f32;
        }
        if let Some(ch) = params.get("curb_height") {
            profile.curb_height = ch.to::<f64>() as f32;
        }
        if let Some(lm) = params.get("has_lane_markings") {
            profile.has_lane_markings = lm.to::<bool>();
        }

        match self.network.add_road_edge(from_node as usize, to_node as usize, profile) {
            Some(id) => id as i32,
            None => -1,
        }
    }

    /// Resuelve las intersecciones y calcula la geometría completa.
    #[func]
    pub fn solve(&mut self) {
        let output = RoadSolver::solve_network(&self.network);
        self.cached_output = Some(output);
    }

    /// Asegura que los cálculos estén actualizados.
    fn ensure_solved(&mut self) {
        if self.cached_output.is_none() {
            self.solve();
        }
    }

    /// Retorna el nodo MultiMesh de asfalto (calzadas vehiculares continuas).
    /// Listo para asignarse a un `MultiMeshInstance3D` en Godot (1 solo draw call).
    #[func]
    pub fn get_asphalt_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.asphalt_instances)
    }

    /// Retorna el nodo MultiMesh para banquetas de concreto.
    #[func]
    pub fn get_sidewalk_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.sidewalk_instances)
    }

    /// Retorna el nodo MultiMesh para bordillos / guarniciones.
    #[func]
    pub fn get_curb_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.curb_instances)
    }

    /// Retorna el nodo MultiMesh para camellones centrales (pasto, tierra, arroyo).
    #[func]
    pub fn get_median_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.median_instances)
    }

    /// Retorna el nodo MultiMesh para las losas de intersecciones / cruces vehiculares.
    #[func]
    pub fn get_junction_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.junction_instances)
    }

    /// Retorna el nodo MultiMesh para señalización horizontal y marcas viales de pintura blanca.
    #[func]
    pub fn get_paint_multimesh(&mut self) -> Option<Gd<MultiMesh>> {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        Self::create_multimesh_from_transforms(&output.paint_instances)
    }

    /// Retorna un Array de Transform3D con los puntos de siembra regular de árboles en camellones.
    #[func]
    pub fn get_tree_socket_transforms(&mut self) -> VarArray {
        self.ensure_solved();
        let output = self.cached_output.as_ref().unwrap();
        let mut arr = VarArray::new();
        for t in &output.tree_socket_transforms {
            arr.push(&t.to_variant());
        }
        arr
    }

    /// Retorna la cantidad total de cubos instanciados en toda la red.
    #[func]
    pub fn get_total_box_count(&mut self) -> i32 {
        self.ensure_solved();
        self.cached_output.as_ref().unwrap().total_box_count() as i32
    }

    /// Construye un MultiMesh de Godot usando BoxMesh unitario (1x1x1m) y aplica los transforms escalados.
    fn create_multimesh_from_transforms(transforms: &[Transform3D]) -> Option<Gd<MultiMesh>> {
        let mut mm = MultiMesh::new_gd();
        mm.set_transform_format(TransformFormat::TRANSFORM_3D);

        if transforms.is_empty() {
            mm.set_instance_count(0);
            return Some(mm);
        }

        let mut unit_box = BoxMesh::new_gd();
        unit_box.set_size(Vector3::ONE);

        mm.set_mesh(&unit_box);
        mm.set_instance_count(transforms.len() as i32);

        for (idx, transform) in transforms.iter().enumerate() {
            mm.set_instance_transform(idx as i32, *transform);
        }

        Some(mm)
    }
}

use godot::prelude::*;
use super::graph::{BotanicalGraph, NodeSegment};
use super::species::SpeciesProfile;

/// Datos crudos de una superficie de malla (Wood o Leaves).
#[derive(Default, Clone)]
pub struct RawSurfaceData {
    pub vertices: Vec<Vector3>,
    pub normals: Vec<Vector3>,
    pub uvs: Vec<Vector2>,
    pub indices: Vec<i32>,
}

impl RawSurfaceData {
    pub fn new() -> Self {
        Self {
            vertices: Vec::with_capacity(512),
            normals: Vec::with_capacity(512),
            uvs: Vec::with_capacity(512),
            indices: Vec::with_capacity(768),
        }
    }

    /// Añade un cuadrilátero (2 triángulos) especificando los 4 vértices en orden horario/antihorario.
    pub fn add_quad(
        &mut self,
        v0: Vector3,
        v1: Vector3,
        v2: Vector3,
        v3: Vector3,
        uv0: Vector2,
        uv1: Vector2,
        uv2: Vector2,
        uv3: Vector2,
    ) {
        let base_idx = self.vertices.len() as i32;

        let edge1 = v1 - v0;
        let edge2 = v2 - v0;
        let norm = edge1.cross(edge2).normalized();

        self.vertices.push(v0);
        self.vertices.push(v1);
        self.vertices.push(v2);
        self.vertices.push(v3);

        self.normals.push(norm);
        self.normals.push(norm);
        self.normals.push(norm);
        self.normals.push(norm);

        self.uvs.push(uv0);
        self.uvs.push(uv1);
        self.uvs.push(uv2);
        self.uvs.push(uv3);

        // Triángulo 1: [0, 1, 2]
        self.indices.push(base_idx);
        self.indices.push(base_idx + 1);
        self.indices.push(base_idx + 2);

        // Triángulo 2: [0, 2, 3]
        self.indices.push(base_idx);
        self.indices.push(base_idx + 2);
        self.indices.push(base_idx + 3);
    }

    /// Añade un cuadrilátero con normales explícitas por cada vértice (e.g. normales esféricas de follaje).
    pub fn add_quad_with_normals(
        &mut self,
        v0: Vector3,
        v1: Vector3,
        v2: Vector3,
        v3: Vector3,
        n0: Vector3,
        n1: Vector3,
        n2: Vector3,
        n3: Vector3,
        uv0: Vector2,
        uv1: Vector2,
        uv2: Vector2,
        uv3: Vector2,
    ) {
        let base_idx = self.vertices.len() as i32;

        self.vertices.push(v0);
        self.vertices.push(v1);
        self.vertices.push(v2);
        self.vertices.push(v3);

        self.normals.push(n0);
        self.normals.push(n1);
        self.normals.push(n2);
        self.normals.push(n3);

        self.uvs.push(uv0);
        self.uvs.push(uv1);
        self.uvs.push(uv2);
        self.uvs.push(uv3);

        self.indices.push(base_idx);
        self.indices.push(base_idx + 1);
        self.indices.push(base_idx + 2);

        self.indices.push(base_idx);
        self.indices.push(base_idx + 2);
        self.indices.push(base_idx + 3);
    }

    /// Añade un triángulo con normales y UVs explícitas.
    pub fn add_triangle(
        &mut self,
        v0: Vector3,
        v1: Vector3,
        v2: Vector3,
        uv0: Vector2,
        uv1: Vector2,
        uv2: Vector2,
    ) {
        let base_idx = self.vertices.len() as i32;
        let norm = (v1 - v0).cross(v2 - v0).normalized();

        self.vertices.push(v0);
        self.vertices.push(v1);
        self.vertices.push(v2);

        self.normals.push(norm);
        self.normals.push(norm);
        self.normals.push(norm);

        self.uvs.push(uv0);
        self.uvs.push(uv1);
        self.uvs.push(uv2);

        self.indices.push(base_idx);
        self.indices.push(base_idx + 1);
        self.indices.push(base_idx + 2);
    }

    /// Añade un triángulo con normales y UVs explícitas por cada vértice.
    pub fn add_triangle_with_normals(
        &mut self,
        v0: Vector3,
        v1: Vector3,
        v2: Vector3,
        n0: Vector3,
        n1: Vector3,
        n2: Vector3,
        uv0: Vector2,
        uv1: Vector2,
        uv2: Vector2,
    ) {
        let base_idx = self.vertices.len() as i32;

        self.vertices.push(v0);
        self.vertices.push(v1);
        self.vertices.push(v2);

        self.normals.push(n0);
        self.normals.push(n1);
        self.normals.push(n2);

        self.uvs.push(uv0);
        self.uvs.push(uv1);
        self.uvs.push(uv2);

        self.indices.push(base_idx);
        self.indices.push(base_idx + 1);
        self.indices.push(base_idx + 2);
    }

    /// Convierte a Dictionary de Godot con PackedArrays.
    pub fn to_godot_dict(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        let mut p_verts = PackedVector3Array::new();
        let mut p_norms = PackedVector3Array::new();
        let mut p_uvs = PackedVector2Array::new();
        let mut p_indices = PackedInt32Array::new();

        for v in &self.vertices { p_verts.push(*v); }
        for n in &self.normals { p_norms.push(*n); }
        for u in &self.uvs { p_uvs.push(*u); }
        for i in &self.indices { p_indices.push(*i); }

        dict.set("vertices", p_verts);
        dict.set("normals", p_norms);
        dict.set("uvs", p_uvs);
        dict.set("indices", p_indices);
        dict
    }

    pub fn triangle_count(&self) -> usize {
        self.indices.len() / 3
    }
}

/// Malla completa del árbol (Tronco/Ramas + Hojas).
#[derive(Default, Clone)]
pub struct TreeMeshData {
    pub wood: RawSurfaceData,
    pub leaves: RawSurfaceData,
}

impl TreeMeshData {
    pub fn to_godot_dict(&self) -> VarDictionary {
        let mut dict = VarDictionary::new();
        dict.set("wood", self.wood.to_godot_dict());
        dict.set("leaves", self.leaves.to_godot_dict());
        dict.set("total_triangles", (self.wood.triangle_count() + self.leaves.triangle_count()) as i64);
        dict
    }

    pub fn total_triangles(&self) -> usize {
        self.wood.triangle_count() + self.leaves.triangle_count()
    }
}

/// Calcula una base ortonormal (u, v) perpendicular a un vector de dirección d.
fn get_orthonormal_basis(d: Vector3) -> (Vector3, Vector3) {
    let d_norm = d.normalized();
    let u = if d_norm.dot(Vector3::UP).abs() < 0.95 {
        d_norm.cross(Vector3::UP).normalized()
    } else {
        d_norm.cross(Vector3::RIGHT).normalized()
    };
    let v = d_norm.cross(u).normalized();
    (u, v)
}

/// Variante de fronda/racimo de hojas en el atlas 2x2.
#[derive(Clone, Copy)]
pub struct AlnusLeafVariant {
    pub uv_min: Vector2,
    pub uv_max: Vector2,
    pub anchor: Vector2,
}

pub const ALNUS_VARIANTS: [AlnusLeafVariant; 4] = [
    // Variant 0: hojaAlnus1 (Quadrant top-left [0..0.5, 0..0.5])
    // Coordenada exacta en px provista por el usuario: (610, 1027) -> normalizado en 1024 = (610/1024, 1023/1024)
    AlnusLeafVariant {
        uv_min: Vector2::new(0.0, 0.0),
        uv_max: Vector2::new(0.5, 0.5),
        anchor: Vector2::new(610.0 / 1024.0, 1023.0 / 1024.0),
    },
    // Variant 1: hojaAlnus2 (Quadrant top-right [0.5..1.0, 0..0.5])
    // Coordenada exacta en px provista por el usuario: (511, 755) -> normalizado en 1024 = (511/1024, 755/1024)
    AlnusLeafVariant {
        uv_min: Vector2::new(0.5, 0.0),
        uv_max: Vector2::new(1.0, 0.5),
        anchor: Vector2::new(511.0 / 1024.0, 755.0 / 1024.0),
    },
    // Variant 2: hojaAlnus3 (Quadrant bottom-left [0..0.5, 0.5..1.0])
    // Coordenada exacta en px provista por el usuario: (544, 730) -> normalizado en 1024 = (544/1024, 730/1024)
    AlnusLeafVariant {
        uv_min: Vector2::new(0.0, 0.5),
        uv_max: Vector2::new(0.5, 1.0),
        anchor: Vector2::new(544.0 / 1024.0, 730.0 / 1024.0),
    },
    // Variant 3: hojaAlnus4 (Quadrant bottom-right [0.5..1.0, 0.5..1.0])
    // Coordenada exacta en px provista por el usuario: (498, 509) -> normalizado en 1024 = (498/1024, 509/1024)
    AlnusLeafVariant {
        uv_min: Vector2::new(0.5, 0.5),
        uv_max: Vector2::new(1.0, 1.0),
        anchor: Vector2::new(498.0 / 1024.0, 509.0 / 1024.0),
    },
];

/// Generador de geometría Low-Poly con sincronización de LODs.
pub struct BotanicalMeshBuilder;

impl BotanicalMeshBuilder {
    /// Calcula los límites verticales y el radio horizontal máximo de la copa del árbol.
    /// Retorna (y_base, y_top, r_max).
    pub fn calculate_canopy_bounds(graph: &BotanicalGraph) -> (f32, f32, f32) {
        let mut min_branch_y = f32::MAX;
        let mut max_y = 0.0f32;
        let mut max_r = 0.5f32;

        for seg in graph.active_segments() {
            if seg.depth > 0 {
                min_branch_y = min_branch_y.min(seg.start_pos.y).min(seg.end_pos.y);
                max_y = max_y.max(seg.start_pos.y).max(seg.end_pos.y);
                let r_start = (seg.start_pos.x * seg.start_pos.x + seg.start_pos.z * seg.start_pos.z).sqrt();
                let r_end = (seg.end_pos.x * seg.end_pos.x + seg.end_pos.z * seg.end_pos.z).sqrt();
                max_r = max_r.max(r_start).max(r_end);
            } else {
                max_y = max_y.max(seg.end_pos.y);
            }
        }

        for cluster in graph.active_clusters() {
            min_branch_y = min_branch_y.min(cluster.position.y);
            max_y = max_y.max(cluster.position.y);
            let r = (cluster.position.x * cluster.position.x + cluster.position.z * cluster.position.z).sqrt();
            max_r = max_r.max(r);
        }

        if min_branch_y == f32::MAX {
            min_branch_y = max_y * 0.25;
        }

        let y_base = (min_branch_y - 0.2).max(0.5);
        let y_top = max_y + 0.3;
        let r_max = max_r + 0.35;

        (y_base, y_top, r_max)
    }

    /// Construye exactamente 10 planos radiales en estrella (10 quads = exactamente 20 triángulos).
    /// Los planos se extienden verticalmente desde y_base hasta y_top,
    /// y horizontalmente desde el centro del tronco (r = 0) hasta la punta de la rama más lejana (r = r_max).
    /// Cada plano se mapea a uno de los 10 slots en un atlas 5x2 (5 columnas x 2 filas).
    pub fn build_radial_cross_20(surface: &mut RawSurfaceData, graph: &BotanicalGraph) {
        let (y_base, y_top, r_max) = Self::calculate_canopy_bounds(graph);
        let num_planes = 10;
        let canopy_center = Vector3::new(0.0, (y_base + y_top) * 0.5, 0.0);

        for k in 0..num_planes {
            let angle = (k as f32) * (std::f32::consts::TAU / (num_planes as f32));
            let cos_a = angle.cos();
            let sin_a = angle.sin();
            let dir = Vector3::new(cos_a, 0.0, sin_a);

            // Vértices del quad (1 quad = 2 triángulos):
            // v0: base interior (tronco)
            // v1: base exterior (radio máximo)
            // v2: copa exterior (radio máximo)
            // v3: copa interior (ápice del tronco)
            let v0 = Vector3::new(0.0, y_base, 0.0);
            let v1 = dir * r_max + Vector3::new(0.0, y_base, 0.0);
            let v2 = dir * r_max + Vector3::new(0.0, y_top, 0.0);
            let v3 = Vector3::new(0.0, y_top, 0.0);

            // Mapeo UV en atlas 5x2 (5 columnas, 2 filas) con margen de subpíxel anti-sangrado:
            let col = (k % 5) as f32;
            let row = (k / 5) as f32;
            let u_inset = 1.5 / 2560.0;
            let v_inset = 1.5 / 1024.0;
            let u_min = col * 0.2 + u_inset;
            let u_max = (col + 1.0) * 0.2 - u_inset;
            let v_min = row * 0.5 + v_inset;
            let v_max = (row + 1.0) * 0.5 - v_inset;

            let uv0 = Vector2::new(u_min, v_max);
            let uv1 = Vector2::new(u_max, v_max);
            let uv2 = Vector2::new(u_max, v_min);
            let uv3 = Vector2::new(u_min, v_min);

            // Normales esféricas volumétricas suaves para recepción de luz 360
            let mut n0 = (v0 - canopy_center).normalized();
            if n0.length_squared() < 0.01 {
                n0 = Vector3::new(cos_a, 0.2, sin_a).normalized();
            }
            let n1 = (v1 - canopy_center + Vector3::new(0.0, 0.5, 0.0)).normalized();
            let n2 = (v2 - canopy_center + Vector3::new(0.0, 1.0, 0.0)).normalized();
            let mut n3 = (v3 - canopy_center).normalized();
            if n3.length_squared() < 0.01 {
                n3 = Vector3::new(cos_a, 0.5, sin_a).normalized();
            }

            surface.add_quad_with_normals(v0, v1, v2, v3, n0, n1, n2, n3, uv0, uv1, uv2, uv3);
        }
    }

    /// Construye ramas frondosas tridimensionales utilizando el atlas 2x2
    /// de boughs botánicos provisto por el usuario (alnus_bough_atlas.png).
    ///
    /// - Soporta árboles jóvenes (age < 0.38): utiliza los brotes y hojas tiernas
    ///   de las imágenes anteriores (alnus_leaf_atlas.png) tal como solicitó el usuario.
    /// - Soporta árboles adultos (age >= 0.38): distribuye boughs frondosos en las ramas
    ///   secundarias, puntas terminales y verticilos exteriores, respetando la estructura
    ///   leñosa visible del tronco y ramas maestras.
    /// - En cada bough, genera quads cuya diagonal conecta el tallo leñoso (U_min, V_max)
    ///   con la punta de la rama (U_max, V_min).
    /// - single_card = false (LOD 0): 2 quads cruzados ("X" volumétrica).
    /// - single_card = true (LOD 1 / 2): 1 quad principal de máxima cobertura.
    pub fn build_lush_branch_boughs(
        surface: &mut RawSurfaceData,
        graph: &BotanicalGraph,
        canopy_center: Vector3,
        single_card: bool,
    ) {
        // 1. Árboles que apenas van creciendo (saplings / brotes):
        // Tal como pidió el usuario: las imágenes anteriores (alnus_leaf_atlas.png con pocas hojas)
        // se utilizan para los árboles jóvenes en desarrollo.
        if graph.current_age < 0.38 {
            for cluster in &graph.leaf_clusters {
                if cluster.is_active {
                    Self::build_leaf_cluster(
                        surface,
                        cluster.position,
                        cluster.direction,
                        cluster.scale,
                        1,
                        cluster.variant_idx,
                        canopy_center,
                    );
                }
            }
            return;
        }

        // 2. Árboles maduros (age >= 0.38):
        let uv_insets = 6.0 / 1024.0;
        let get_quadrant_uvs = |var_idx: usize| -> (Vector2, Vector2, Vector2, Vector2) {
            let col = (var_idx % 2) as f32;
            let row = (var_idx / 2) as f32;
            let u0 = col * 0.5 + uv_insets;
            let u1 = (col + 1.0) * 0.5 - uv_insets;
            let v0 = row * 0.5 + uv_insets;
            let v1 = (row + 1.0) * 0.5 - uv_insets;

            // v0 (tallo en la madera): bottom-left
            // v1: bottom-right
            // v2 (punta de la rama): top-right
            // v3: top-left
            (
                Vector2::new(u0, v1),
                Vector2::new(u1, v1),
                Vector2::new(u1, v0),
                Vector2::new(u0, v0),
            )
        };

        let _maturity = ((graph.current_age - 0.38) / 0.62).clamp(0.0, 1.0);
        let mut branches_to_render: Vec<(Vector3, Vector3, usize, f32)> = Vec::new();

        // A) Ramas Primarias del Árbol (Pegar las imágenes de 5m a las ramas procedurales):
        // Cada rama procedural lleva en cruz 2 imágenes (4 triángulos en LOD 0, 2 triángulos en LOD 1)
        // que siguen exactamente la trayectoria botánica de la rama procedural de 5 metros.
        let branch_roots: Vec<&NodeSegment> = graph
            .active_segments()
            .filter(|s| s.depth == 1 && s.order_index == 0)
            .collect();

        for (b_idx, root) in branch_roots.iter().enumerate() {
            // 1. Reconstruir la cadena completa de la rama procedural desde el tronco hasta su punta
            let mut chain: Vec<Vector3> = vec![root.start_pos, root.end_pos];
            let mut curr_id = root.id;
            loop {
                let mut next_child: Option<&NodeSegment> = None;
                if curr_id < graph.nodes.len() {
                    for &cid in &graph.nodes[curr_id].children_ids {
                        if cid < graph.nodes.len() {
                            let child = &graph.nodes[cid];
                            if !child.is_pruned && child.depth == 1 {
                                next_child = Some(child);
                                break;
                            }
                        }
                    }
                }
                if let Some(child) = next_child {
                    chain.push(child.end_pos);
                    curr_id = child.id;
                } else {
                    break;
                }
            }

            if chain.len() < 2 {
                continue;
            }

            let chain_last = *chain.last().unwrap();
            
            // Punto de inserción en la rama procedural:
            // La base de la imagen nace en la rama procedural (primer segmento root.start_pos o root.end_pos)
            let p_base = root.start_pos;

            // Dirección real de la rama procedural en el espacio 3D
            let branch_diff = chain_last - p_base;
            let branch_dist = branch_diff.length();
            if branch_dist < 0.20 {
                continue;
            }
            let forward = branch_diff / branch_dist;

            // Longitud de la tarjeta de 5 metros: cubre exactamente la rama procedural
            // y se extiende un 12% adicional para que el follaje envuelva completamente la punta
            let card_len = (branch_dist * 1.15).max(3.8);
            let p_tip = p_base + forward * card_len;
            let var_idx = (root.id + b_idx) % 4;

            branches_to_render.push((p_base, p_tip, var_idx, card_len));
        }



        // Generación de Geometría en 3D:
        // - Cada bough genera una tarjeta cuadrada de diagonal L (~5m) mapeada perfectamente sin deformación.
        // - single_card = false (LOD 0): 2 planos cruzados en "X" (4 triángulos por rama).
        // - single_card = true (LOD 1 / 2): 1 plano principal a ~18° (2 triángulos por rama).
        for (p_start, p_end, var_idx, _card_len) in branches_to_render {
            let diff = p_end - p_start;
            let len = diff.length();
            if len < 0.20 {
                continue;
            }
            let forward = diff / len;

            let mut side = forward.cross(Vector3::UP);
            if side.length_squared() < 0.001 {
                side = forward.cross(Vector3::RIGHT);
            }
            let side = side.normalized();
            let up_perp = side.cross(forward).normalized();

            let (uv0, uv1, uv2, uv3) = get_quadrant_uvs(var_idx);

            // Plano 1: Orientación horizontal / extendida (~18° de inclinación) para captar luz cenital y sombra
            // Plano 2: Cruzado vertical (~-72°) para volumen y grosor desde el suelo y laterales ("cruz" en X)
            let angles = if single_card {
                vec![0.30f32] // 1 plano principal = 2 triángulos
            } else {
                vec![0.30f32, -1.25f32] // 2 planos en cruz = 4 triángulos
            };

            let p_mid = (p_start + p_end) * 0.5;
            let half_diag = len * 0.5;

            for angle in angles {
                let n_card = (side * angle.cos() + up_perp * angle.sin()).normalized();

                // Cuadrilátero cuadrado perfecto rotado 45° a lo largo de su diagonal:
                // Diagonal 1 (v0 a v2): desde el tallo en la rama procedural (p_start) hasta la punta exterior (p_end)
                // Diagonal 2 (v3 a v1): perpendicular en el plano de la tarjeta, de longitud idéntica len
                let v0 = p_start;
                let v1 = p_mid + n_card * half_diag;
                let v2 = p_end;
                let v3 = p_mid - n_card * half_diag;

                // Normales esféricas de copa con sesgo cenital para sombreado volumétrico suave
                let n0 = ((v0 - canopy_center).normalized() * 0.70 + Vector3::UP * 0.45).normalized();
                let n1 = ((v1 - canopy_center).normalized() * 0.70 + Vector3::UP * 0.45).normalized();
                let n2 = ((v2 - canopy_center).normalized() * 0.70 + Vector3::UP * 0.45).normalized();
                let n3 = ((v3 - canopy_center).normalized() * 0.70 + Vector3::UP * 0.45).normalized();

                surface.add_quad_with_normals(v0, v1, v2, v3, n0, n1, n2, n3, uv0, uv1, uv2, uv3);
            }
        }
    }

    /// Genera la malla en LOD 0:
    /// - Tronco: Prisma continuo de 3 lados (sección triangular).
    /// - Ramas primarias y secundarias: Prismas y pirámides de 3 caras.
    /// - Hojas:
    ///   - foliage_mode == 2: Ramas frondosas cruzadas en 3D (LushBranchBoughs, 4 tris/rama).
    ///   - foliage_mode == 1: 10 planos radiales en estrella (RadialCross20, 20 tris).
    ///   - foliage_mode == 0: Triángulos inteligentes a lo largo de cada rama + racimos.
    pub fn build_lod0(graph: &BotanicalGraph, species: &SpeciesProfile, foliage_mode: i32) -> TreeMeshData {
        let mut mesh = TreeMeshData::default();

        // 1. Geometría de Madera: Tronco Principal Continuo (extrusión con bisectores / miter joints perfectos)
        let mut trunk_segments: Vec<&NodeSegment> = graph
            .active_segments()
            .filter(|s| s.depth == 0)
            .collect();
        trunk_segments.sort_by_key(|s| s.order_index);
        Self::extrude_continuous_trunk(&mut mesh.wood, &trunk_segments, 6);

        // 2. Ramas Primarias Procedurales
        for seg in graph.active_segments().filter(|s| s.depth > 0) {
            if foliage_mode == 2 && seg.depth > 1 {
                // Las ramillas secundarias finas ya están representadas en la imagen de 5m
                continue;
            }
            Self::extrude_prism_3sides(&mut mesh.wood, seg);
        }

        // 2. Geometría de Follaje (solo si la especie produce hojas)
        if species.cards_per_cluster > 0 {
            let canopy_center = Vector3::new(0.0, graph.current_height() * 0.55, 0.0);
            if foliage_mode == 2 {
                Self::build_lush_branch_boughs(&mut mesh.leaves, graph, canopy_center, false);
            } else if foliage_mode == 1 {
                Self::build_radial_cross_20(&mut mesh.leaves, graph);
            } else {
                Self::build_branch_vertical_triangles(&mut mesh.leaves, graph, canopy_center);

                for cluster in &graph.leaf_clusters {
                    if cluster.is_active {
                        Self::build_leaf_cluster(
                            &mut mesh.leaves,
                            cluster.position,
                            cluster.direction,
                            cluster.scale,
                            1,
                            cluster.variant_idx,
                            canopy_center,
                        );
                    }
                }
            }
        }

        mesh
    }

    /// Genera la malla en LOD 1 (Sincronizado):
    /// - Tronco: Mantiene el prisma de 3 caras.
    /// - Ramas: Colapsan de prismas 3D a **Aletas 2D (quads)** exactamente alineadas con la normal de la rama.
    /// - Hojas: Sincronizadas según foliage_mode (1 quad por bough en modo 2).
    pub fn build_lod1(graph: &BotanicalGraph, species: &SpeciesProfile, foliage_mode: i32) -> TreeMeshData {
        let mut mesh = TreeMeshData::default();

        let mut trunk_segments: Vec<&NodeSegment> = graph
            .active_segments()
            .filter(|s| s.depth == 0)
            .collect();
        trunk_segments.sort_by_key(|s| s.order_index);
        Self::extrude_continuous_trunk(&mut mesh.wood, &trunk_segments, 4);

        for seg in graph.active_segments().filter(|s| s.depth > 0) {
            if foliage_mode == 2 && seg.depth > 1 {
                continue;
            }
            Self::build_branch_fin_2d(&mut mesh.wood, seg);
        }

        if species.cards_per_cluster > 0 {
            let canopy_center = Vector3::new(0.0, graph.current_height() * 0.55, 0.0);
            if foliage_mode == 2 {
                Self::build_lush_branch_boughs(&mut mesh.leaves, graph, canopy_center, true);
            } else if foliage_mode == 1 {
                Self::build_radial_cross_20(&mut mesh.leaves, graph);
            } else {
                Self::build_branch_vertical_triangles(&mut mesh.leaves, graph, canopy_center);

                for cluster in &graph.leaf_clusters {
                    if cluster.is_active {
                        Self::build_leaf_cluster(
                            &mut mesh.leaves,
                            cluster.position,
                            cluster.direction,
                            cluster.scale,
                            1,
                            cluster.variant_idx,
                            canopy_center,
                        );
                    }
                }
            }
        }

        mesh
    }

    /// Genera la malla en LOD 2:
    /// - Tronco: Colapsa a un cuadrilátero vertical tipo cinta (2 triángulos).
    /// - Follaje: Simplificado según foliage_mode.
    pub fn build_lod2(graph: &BotanicalGraph, species: &SpeciesProfile, foliage_mode: i32) -> TreeMeshData {
        let mut mesh = TreeMeshData::default();

        // Tronco simplificado a 1 aleta vertical continua
        if let Some(first_seg) = graph.nodes.first() {
            let base_pos = first_seg.start_pos;
            let base_r = first_seg.base_radius;

            // Encontrar la cima del tronco
            let mut top_pos = base_pos;
            for seg in graph.active_segments().filter(|s| s.depth == 0) {
                if seg.end_pos.y > top_pos.y {
                    top_pos = seg.end_pos;
                }
            }

            let hw = base_r * 1.1;
            mesh.wood.add_quad(
                base_pos + Vector3::new(-hw, 0.0, 0.0),
                base_pos + Vector3::new(hw, 0.0, 0.0),
                top_pos + Vector3::new(hw * 0.4, 0.0, 0.0),
                top_pos + Vector3::new(-hw * 0.4, 0.0, 0.0),
                Vector2::new(0.0, 2.0),
                Vector2::new(1.0, 2.0),
                Vector2::new(1.0, 0.0),
                Vector2::new(0.0, 0.0),
            );
        }

        if species.cards_per_cluster > 0 {
            let canopy_center = Vector3::new(0.0, graph.current_height() * 0.55, 0.0);
            if foliage_mode == 2 {
                Self::build_lush_branch_boughs(&mut mesh.leaves, graph, canopy_center, true);
            } else if foliage_mode == 1 {
                Self::build_radial_cross_20(&mut mesh.leaves, graph);
            } else {
                let branch_roots: Vec<&NodeSegment> = graph
                    .active_segments()
                    .filter(|s| s.depth == 1 && s.order_index == 0)
                    .collect();

                for (i, root) in branch_roots.iter().enumerate() {
                    if i % 2 == 0 {
                        Self::build_smart_branch_foliage(&mut mesh.leaves, graph, root, i, canopy_center);
                    }
                }
            }
        }

        mesh
    }

    /// Genera la geometría de follaje de triángulos inteligentes que siguen exactamente el recorrido de cada rama.
    pub fn build_branch_vertical_triangles(
        surface: &mut RawSurfaceData,
        graph: &BotanicalGraph,
        canopy_center: Vector3,
    ) {
        let branch_roots: Vec<&NodeSegment> = graph
            .active_segments()
            .filter(|s| s.depth == 1 && s.order_index == 0)
            .collect();

        for (branch_idx, root) in branch_roots.iter().enumerate() {
            Self::build_smart_branch_foliage(surface, graph, root, branch_idx, canopy_center);
        }
    }

    /// Construye triángulos inteligentes que siguen con exactitud milimétrica la curva y el sag de la rama:
    /// - Empieza con la punta de un triángulo pegada al tronco donde nace la rama (p0).
    /// - La columna vertebral de la rama se subdivide a intervalos botánicos de ~0.55m (tamaño de un racimo real).
    /// - La madera pasa exactamente por el centro vertical del follaje (cero hojas en el aire, cero en el suelo).
    /// - Escala botánica real: las hojas tienen un tamaño de 9-11cm con brotes ascendentes hacia el sol.
    /// - Cada intervalo muestra una de las 4 variantes recortadas por el usuario.
    /// - Las ramillas secundarias y bifurcaciones de la copa tienen su propio triángulo anclado a la rama madre.
    pub fn build_smart_branch_foliage(
        surface: &mut RawSurfaceData,
        graph: &BotanicalGraph,
        root: &NodeSegment,
        branch_idx: usize,
        canopy_center: Vector3,
    ) {
        // 1. Trazar la columna vertebral cruda (spine) de la rama primaria
        let mut spine_raw: Vec<Vector3> = vec![root.start_pos, root.end_pos];
        let mut current_id = root.id;

        loop {
            let mut next_child: Option<&NodeSegment> = None;
            if current_id < graph.nodes.len() {
                for &cid in &graph.nodes[current_id].children_ids {
                    if cid < graph.nodes.len() {
                        let child = &graph.nodes[cid];
                        if !child.is_pruned && child.depth == 1 {
                            next_child = Some(child);
                            break;
                        }
                    }
                }
            }
            if let Some(child) = next_child {
                spine_raw.push(child.end_pos);
                current_id = child.id;
            } else {
                break;
            }
        }

        if spine_raw.len() < 2 {
            return;
        }

        // Medir longitud acumulada de la rama
        let mut seg_lens = Vec::with_capacity(spine_raw.len() - 1);
        let mut total_len = 0.0f32;
        for i in 0..(spine_raw.len() - 1) {
            let d = (spine_raw[i + 1] - spine_raw[i]).length();
            seg_lens.push(d);
            total_len += d;
        }

        if total_len < 0.25 {
            return;
        }

        // Subdivisión inteligente: 1 racimo cada ~0.45m de rama para cubrirla densamente sin huecos
        let step_len = 0.45f32;
        let num_intervals = ((total_len / step_len).round() as usize).max(2);
        let actual_step = total_len / (num_intervals as f32);

        // Muestrear puntos directamente sobre la trayectoria de la madera
        let mut spine_nodes: Vec<Vector3> = Vec::with_capacity(num_intervals + 1);
        spine_nodes.push(spine_raw[0]);

        for j in 1..num_intervals {
            let target_dist = j as f32 * actual_step;
            let mut accum = 0.0f32;
            let mut sampled_pt = spine_raw[spine_raw.len() - 1];

            for (seg_idx, &slen) in seg_lens.iter().enumerate() {
                if accum + slen >= target_dist && slen > 0.001 {
                    let local_t = (target_dist - accum) / slen;
                    sampled_pt = spine_raw[seg_idx].lerp(spine_raw[seg_idx + 1], local_t);
                    break;
                }
                accum += slen;
            }
            spine_nodes.push(sampled_pt);
        }
        spine_nodes.push(spine_raw[spine_raw.len() - 1]);

        let num_nodes = spine_nodes.len();

        // Función para calcular normales esféricas hacia afuera de la copa
        let compute_norm = |v: Vector3| -> Vector3 {
            let to_vert = v - canopy_center;
            let n = if to_vert.length_squared() > 0.001 {
                to_vert.normalized()
            } else {
                Vector3::UP
            };
            Vector3::new(n.x, n.y.max(0.18), n.z).normalized()
        };

        // 2. Vértices superior e inferior anclados a cada nodo de la madera
        let mut top_verts: Vec<Vector3> = Vec::with_capacity(num_nodes);
        let mut bot_verts: Vec<Vector3> = Vec::with_capacity(num_nodes);

        for (i, &p) in spine_nodes.iter().enumerate() {
            if i == 0 {
                // En el collar del tronco: H = 0 (la punta del triángulo nace pegada al tronco)
                top_verts.push(p);
                bot_verts.push(p);
            } else {
                let frac = i as f32 / (num_nodes - 1) as f32;
                // Envergadura vertical botánica generosa: hojas grandes, visibles y frondosas
                let profile = 1.0 - (frac - 0.45).abs() * 0.60;
                let h_up = (1.10 * profile).clamp(0.68, 1.25);
                let h_down = (0.55 * profile).clamp(0.32, 0.62);

                top_verts.push(p + Vector3::UP * h_up);
                bot_verts.push(p - Vector3::UP * h_down);
            }
        }

        // 3. Generar la cinta de triángulos inteligentes a lo largo de la rama
        for i in 0..(num_nodes - 1) {
            let variant_idx = (branch_idx + i) % 4;
            let var = &ALNUS_VARIANTS[variant_idx];
            let u0 = var.uv_min.x;
            let u1 = var.uv_max.x;
            let v0 = var.uv_min.y;
            let v1 = var.uv_max.y;
            let v_mid = v0 + (v1 - v0) * var.anchor.y;

            if i == 0 {
                // Intervalo 0: EXACTAMENTE 1 TRIÁNGULO empezando en la punta pegada al tronco (p0)
                let p0 = top_verts[0];
                let t1 = top_verts[1];
                let b1 = bot_verts[1];

                let n0 = compute_norm(p0);
                let n1 = compute_norm(t1);
                let n2 = compute_norm(b1);

                surface.add_triangle_with_normals(
                    p0, t1, b1,
                    n0, n1, n2,
                    Vector2::new(u0, v_mid),
                    Vector2::new(u1, v0),
                    Vector2::new(u1, v1),
                );
            } else {
                // Intervalos sucesivos: 2 triángulos (1 quad vertical que sigue la curvatura)
                let t_prev = top_verts[i];
                let b_prev = bot_verts[i];
                let t_next = top_verts[i + 1];
                let b_next = bot_verts[i + 1];

                let nt0 = compute_norm(t_prev);
                let nb0 = compute_norm(b_prev);
                let nt1 = compute_norm(t_next);
                let nb1 = compute_norm(b_next);

                surface.add_quad_with_normals(
                    b_prev, b_next, t_next, t_prev,
                    nb0, nb1, nt1, nt0,
                    Vector2::new(u0, v1),
                    Vector2::new(u1, v1),
                    Vector2::new(u1, v0),
                    Vector2::new(u0, v0),
                );
            }
        }

        // 4. Sub-Ramas de Follaje Lateral (Follaje Volumétrico 3D que se ramifica de la madera):
        // En cada nodo intermedio, brota un racimo lateral (alternando izquierda y derecha)
        // anclado exactamente en la madera y proyectándose hacia afuera en el espacio 3D.
        for i in 1..num_nodes {
            let p_wood = spine_nodes[i];
            let dir_forward = if i < num_nodes - 1 {
                (spine_nodes[i + 1] - spine_nodes[i - 1]).normalized()
            } else {
                (spine_nodes[i] - spine_nodes[i - 1]).normalized()
            };

            let lateral_axis = dir_forward.cross(Vector3::UP).normalized();
            let frac = i as f32 / (num_nodes - 1) as f32;
            let sprig_len = (1.05 * (1.0 - (frac - 0.50).abs() * 0.50)).clamp(0.75, 1.20);

            // Alternar lado: impar = izquierda, par = derecha. En la punta, ambos lados.
            let sides: Vec<f32> = if i == num_nodes - 1 {
                vec![1.0, -1.0]
            } else if i % 2 == 1 {
                vec![1.0]
            } else {
                vec![-1.0]
            };

            for side in sides {
                let sprig_dir = (lateral_axis * side * 0.85 + dir_forward * 0.40 - Vector3::UP * 0.10).normalized();
                let tip = p_wood + sprig_dir * sprig_len;

                let t = tip + Vector3::UP * 0.65;
                let b = tip - Vector3::UP * 0.38;

                let var_idx = (branch_idx + i * 2 + if side > 0.0 { 1 } else { 2 }) % 4;
                let var = &ALNUS_VARIANTS[var_idx];
                let u0 = var.uv_min.x;
                let u1 = var.uv_max.x;
                let v0 = var.uv_min.y;
                let v1 = var.uv_max.y;
                let v_mid = v0 + (v1 - v0) * var.anchor.y;

                let n0 = compute_norm(p_wood);
                let n1 = compute_norm(t);
                let n2 = compute_norm(b);

                surface.add_triangle_with_normals(
                    p_wood, t, b,
                    n0, n1, n2,
                    Vector2::new(u0, v_mid),
                    Vector2::new(u1, v0),
                    Vector2::new(u1, v1),
                );
            }
        }

        // 5. Ramillas secundarias (Depth 2): cada una tiene 1 triángulo inteligente que nace en la madera madre
        let mut queue: Vec<usize> = root.children_ids.clone();
        while let Some(child_id) = queue.pop() {
            if child_id < graph.nodes.len() {
                let child = &graph.nodes[child_id];
                if !child.is_pruned {
                    if child.depth == 2 {
                        let p0 = child.start_pos;
                        let tip = child.end_pos;
                        let twig_len = (tip - p0).length();

                        if twig_len > 0.12 {
                            let t = tip + Vector3::UP * 0.60;
                            let b = tip - Vector3::UP * 0.35;

                            let var_idx = (branch_idx + child.order_index + 1) % 4;
                            let var = &ALNUS_VARIANTS[var_idx];
                            let u0 = var.uv_min.x;
                            let u1 = var.uv_max.x;
                            let v0 = var.uv_min.y;
                            let v1 = var.uv_max.y;
                            let v_mid = v0 + (v1 - v0) * var.anchor.y;

                            let n0 = compute_norm(p0);
                            let n1 = compute_norm(t);
                            let n2 = compute_norm(b);

                            surface.add_triangle_with_normals(
                                p0, t, b,
                                n0, n1, n2,
                                Vector2::new(u0, v_mid),
                                Vector2::new(u1, v0),
                                Vector2::new(u1, v1),
                            );
                        }
                    }
                    queue.extend_from_slice(&child.children_ids);
                }
            }
        }
    }

    /// Genera la malla en LOD 3 (Ultra-distancia: exactamente 2 triángulos en GPU):
    /// - 1 triángulo para el tronco.
    /// - 1 triángulo para la copa.
    pub fn build_lod3(graph: &BotanicalGraph, species: &SpeciesProfile) -> TreeMeshData {
        let mut mesh = TreeMeshData::default();

        let height = graph.current_height().max(0.5);
        let base_r = graph.nodes.first().map(|s| s.base_radius).unwrap_or(0.15);

        // Triángulo 1: Tronco cónico
        let t_w = (base_r * 1.2).max(0.05);
        let t_top_y = height * 0.65;
        mesh.wood.add_triangle(
            Vector3::new(-t_w, 0.0, -0.02),
            Vector3::new(t_w, 0.0, -0.02),
            Vector3::new(0.0, t_top_y, -0.02),
            Vector2::new(0.0, 2.0),
            Vector2::new(1.0, 2.0),
            Vector2::new(0.5, 0.0),
        );

        if species.cards_per_cluster > 0 {
            // Triángulo 2: Copa envolvente
            let c_base_y = height * 0.28;
            let c_top_y = height * 1.02;
            let c_w = (height * 0.40).max(0.3);

            mesh.leaves.add_triangle(
                Vector3::new(-c_w, c_base_y, 0.02),
                Vector3::new(c_w, c_base_y, 0.02),
                Vector3::new(0.0, c_top_y, 0.02),
                Vector2::new(-0.5, 1.0),
                Vector2::new(1.5, 1.0),
                Vector2::new(0.5, 0.0),
            );
        }

        mesh
    }

    /// Extruye el tronco continuo completo utilizando planos de corte bisectores (miter joints)
    /// garantizando continuidad absoluta y cero costuras, escalones o fisuras entre segmentos.
    fn extrude_continuous_trunk(surface: &mut RawSurfaceData, segments: &[&NodeSegment], sides: usize) {
        if segments.is_empty() {
            return;
        }

        // 1. Extraer los puntos y radios ordenados a lo largo del fuste
        let mut points: Vec<Vector3> = Vec::with_capacity(segments.len() + 1);
        let mut radii: Vec<f32> = Vec::with_capacity(segments.len() + 1);

        points.push(segments[0].start_pos);
        radii.push(segments[0].base_radius);

        for seg in segments {
            points.push(seg.end_pos);
            radii.push(seg.tip_radius);
        }

        let num_nodes = points.len();
        let tau = std::f32::consts::TAU;

        // 2. Calcular los anillos (rings) de vértices y normales en cada plano bisector
        let mut rings: Vec<Vec<(Vector3, Vector3)>> = Vec::with_capacity(num_nodes);

        for k in 0..num_nodes {
            let tangent = if k == 0 {
                (points[1] - points[0]).normalized()
            } else if k == num_nodes - 1 {
                (points[k] - points[k - 1]).normalized()
            } else {
                let d_prev = (points[k] - points[k - 1]).normalized();
                let d_next = (points[k + 1] - points[k]).normalized();
                let bisector = (d_prev + d_next).normalized();
                if bisector.length_squared() < 0.001 { d_next } else { bisector }
            };

            let mut ring = Vec::with_capacity(sides);
            for s in 0..sides {
                let angle = (s as f32) * (tau / sides as f32);
                let ref_dir = Vector3::new(angle.cos(), 0.0, angle.sin());
                let norm = (ref_dir - tangent * ref_dir.dot(tangent)).normalized();
                let v = points[k] + norm * radii[k];
                ring.push((v, norm));
            }
            rings.push(ring);
        }

        // 3. Generar quads que conectan ring[k] con ring[k+1]
        for k in 0..(num_nodes - 1) {
            let v_base = points[k].y * 0.40;
            let v_tip = points[k + 1].y * 0.40;

            for s in 0..sides {
                let next = (s + 1) % sides;
                let u0 = s as f32 / sides as f32;
                let u1 = (s + 1) as f32 / sides as f32;

                let (v0, n0) = rings[k][s];
                let (v1, n1) = rings[k][next];
                let (v2, n2) = rings[k + 1][next];
                let (v3, n3) = rings[k + 1][s];

                surface.add_quad_with_normals(
                    v0, v1, v2, v3,
                    n0, n1, n2, n3,
                    Vector2::new(u0, v_base),
                    Vector2::new(u1, v_base),
                    Vector2::new(u1, v_tip),
                    Vector2::new(u0, v_tip),
                );
            }
        }
    }

    /// Extruye un segmento como un prisma de 3 caras (6 triángulos) con normales cilíndricas suaves.
    fn extrude_prism_3sides(surface: &mut RawSurfaceData, seg: &NodeSegment) {
        let dir = seg.end_pos - seg.start_pos;
        let len = dir.length();
        if len < 0.001 {
            return;
        }

        let (u, v) = get_orthonormal_basis(dir);

        // 3 vértices alrededor de la base y de la punta (ángulos a 0°, 120°, 240°)
        let angles = [
            0.0f32,
            120.0f32.to_radians(),
            240.0f32.to_radians(),
        ];

        let mut ring_base = [Vector3::ZERO; 3];
        let mut ring_tip = [Vector3::ZERO; 3];
        let mut normals = [Vector3::ZERO; 3];

        for i in 0..3 {
            let cos_a = angles[i].cos();
            let sin_a = angles[i].sin();
            let norm = (u * cos_a + v * sin_a).normalized();
            normals[i] = norm;

            ring_base[i] = seg.start_pos + norm * seg.base_radius;
            ring_tip[i] = seg.end_pos + norm * seg.tip_radius;
        }

        let (v_base, v_tip) = if seg.depth == 0 {
            (seg.start_pos.y * 0.40, seg.end_pos.y * 0.40)
        } else {
            let b = seg.start_pos.length() * 0.40;
            (b, b + len * 0.40)
        };

        // 3 caras laterales del prisma con normales suaves para apariencia cilíndrica
        for i in 0..3 {
            let next = (i + 1) % 3;
            let u0 = i as f32 / 3.0;
            let u1 = (i + 1) as f32 / 3.0;

            // Orden anti-horario exterior: ring_base[next] -> ring_base[i] -> ring_tip[i] -> ring_tip[next]
            // para que las normales geométricas apunten hacia afuera y coincidan con las normales por vértice
            surface.add_quad_with_normals(
                ring_base[next],
                ring_base[i],
                ring_tip[i],
                ring_tip[next],
                normals[next],
                normals[i],
                normals[i],
                normals[next],
                Vector2::new(u1, v_base),
                Vector2::new(u0, v_base),
                Vector2::new(u0, v_tip),
                Vector2::new(u1, v_tip),
            );
        }
    }

    /// Genera una rama simplificada como una aleta 2D (1 quad = 2 triángulos).
    fn build_branch_fin_2d(surface: &mut RawSurfaceData, seg: &NodeSegment) {
        let dir = seg.end_pos - seg.start_pos;
        let len = dir.length();
        if len < 0.001 { return; }

        let (u, _v) = get_orthonormal_basis(dir);
        let offset_base = u * (seg.base_radius * 1.1);
        let offset_tip = u * (seg.tip_radius * 1.1);

        surface.add_quad(
            seg.start_pos - offset_base,
            seg.start_pos + offset_base,
            seg.end_pos + offset_tip,
            seg.end_pos - offset_tip,
            Vector2::new(0.0, 1.0),
            Vector2::new(1.0, 1.0),
            Vector2::new(1.0, 0.0),
            Vector2::new(0.0, 0.0),
        );
    }

    /// Genera tarjetas de follaje con anclaje botánico exacto según las coordenadas del usuario.
    /// Conecta sin holguras ni desajustes el extremo de la rama con el tallo visible en la textura.
    #[allow(dead_code)]
    fn build_leaf_cluster(
        surface: &mut RawSurfaceData,
        anchor_pos: Vector3,
        dir: Vector3,
        scale: f32,
        card_count: usize,
        variant_idx: usize,
        canopy_center: Vector3,
    ) {
        let variant = &ALNUS_VARIANTS[variant_idx % 4];
        let u_a = variant.anchor.x;
        let v_a = variant.anchor.y;

        // Dirección del racimo de hojas: sigue la dirección de la rama/ramilla con una caída pendular suave por gravedad
        let forward = if dir.length_squared() > 0.001 {
            (dir - Vector3::UP * 0.08).normalized()
        } else {
            Vector3::UP
        };

        let (right_base, _) = get_orthonormal_basis(forward);
        let normal_base = forward.cross(right_base).normalized();

        let w_m = scale;
        let h_m = scale;

        let angles = match card_count {
            1 => vec![0.0f32],
            2 => vec![-35.0f32.to_radians(), 35.0f32.to_radians()],
            _ => vec![-45.0f32.to_radians(), 15.0f32.to_radians(), 75.0f32.to_radians()],
        };

        let u_min = variant.uv_min.x;
        let u_max = variant.uv_max.x;
        let v_min = variant.uv_min.y;
        let v_max = variant.uv_max.y;

        let uv0 = Vector2::new(u_min, v_max); // Bottom-left
        let uv1 = Vector2::new(u_max, v_max); // Bottom-right
        let uv2 = Vector2::new(u_max, v_min); // Top-right
        let uv3 = Vector2::new(u_min, v_min); // Top-left

        for &roll in &angles {
            let cos_r = roll.cos();
            let sin_r = roll.sin();
            let right = right_base * cos_r + normal_base * sin_r;

            // Vértices 3D anclados con precisión milimétrica donde la madera conecta con el tallo
            let v0 = anchor_pos - right * (u_a * w_m) - forward * ((1.0 - v_a) * h_m);
            let v1 = anchor_pos + right * ((1.0 - u_a) * w_m) - forward * ((1.0 - v_a) * h_m);
            let v2 = anchor_pos + right * ((1.0 - u_a) * w_m) + forward * (v_a * h_m);
            let v3 = anchor_pos - right * (u_a * w_m) + forward * (v_a * h_m);

            // Normales esféricas suavizadas: radian desde el centroide de la copa hacia afuera
            // para producir un sombreado 3D suave, exuberante y volumétrico bajo la luz direccional.
            let compute_norm = |v: Vector3| -> Vector3 {
                let to_vert = v - canopy_center;
                let s_norm = if to_vert.length_squared() > 0.001 {
                    to_vert.normalized()
                } else {
                    Vector3::UP
                };
                Vector3::new(s_norm.x, s_norm.y.max(0.15), s_norm.z).normalized()
            };

            let n0 = compute_norm(v0);
            let n1 = compute_norm(v1);
            let n2 = compute_norm(v2);
            let n3 = compute_norm(v3);

            surface.add_quad_with_normals(v0, v1, v2, v3, n0, n1, n2, n3, uv0, uv1, uv2, uv3);
        }
    }
}

use godot::prelude::*;
use super::graph::{BotanicalGraph, LeafClusterNode, NodeId, NodeSegment};
use super::species::SpeciesProfile;

/// Pseudo-generador de números aleatorios ultra-rápido y determinista basado en splitmix64.
struct FastRng {
    state: u64,
}

impl FastRng {
    fn new(seed: u64) -> Self {
        Self { state: seed.wrapping_add(0x9E3779B97F4A7C15) }
    }

    fn next_u64(&mut self) -> u64 {
        self.state = self.state.wrapping_add(0x9E3779B97F4A7C15);
        let mut z = self.state;
        z = (z ^ (z >> 30)).wrapping_mul(0xBF58476D1CE4E5B9);
        z = (z ^ (z >> 27)).wrapping_mul(0x94D049BB133111EB);
        z ^ (z >> 31)
    }

    fn next_f32(&mut self) -> f32 {
        (self.next_u64() >> 40) as f32 / ((1u64 << 24) as f32)
    }

    fn range_f32(&mut self, min: f32, max: f32) -> f32 {
        min + (max - min) * self.next_f32()
    }
}

/// Genera o hace crecer el `BotanicalGraph` hasta una edad determinada (`age` entre 0.0 y 1.0).
///
/// Preserva el historial de podas que haya realizado el jugador: si una rama
/// fue cortada, sus nodos se mantienen podados sin importar cuánto crezca el árbol.
pub fn generate_tree_growth(
    species: &SpeciesProfile,
    seed: u64,
    age: f32,
    previously_pruned: &[NodeId],
) -> BotanicalGraph {
    let mut graph = BotanicalGraph::new(seed);
    graph.current_age = age.clamp(0.0, 1.0);
    graph.pruned_nodes_history = previously_pruned.to_vec();

    let mut rng = FastRng::new(seed);

    // Curva biológica sigmoidal suave de crecimiento
    let t = graph.current_age.powf(0.85);

    // 1. Altura total y radio base según la edad
    let current_trunk_height = species.sprout_height
        + (species.max_adult_height - species.sprout_height) * t;

    let current_base_radius = species.sprout_base_radius
        + (species.max_adult_base_radius - species.sprout_base_radius) * t.powf(1.15);

    // Cantidad de segmentos activos del tronco (de 2 en brote a species.trunk_segments en adulto)
    let num_trunk_segs = ((2.0 + (species.trunk_segments as f32 - 2.0) * t).round() as usize)
        .max(2)
        .min(species.trunk_segments);

    let seg_height = current_trunk_height / (num_trunk_segs as f32);

    // 2. Construcción del Tronco Principal (Depth 0) con curvaturas orgánicas y grosor variable
    let seed_f = (seed % 10000) as f32;
    // Ángulo de inclinación predominante dependiente de la semilla (fototropismo / inclinación natural del terreno)
    let lean_angle = (seed_f * 0.437 + 1.25) % (std::f32::consts::TAU);
    let lean_dir = Vector3::new(lean_angle.cos(), 0.0, lean_angle.sin());
    let perp_dir = Vector3::new(-lean_angle.sin(), 0.0, lean_angle.cos());

    // Amplitud de curvatura natural y sinuosidad
    let lean_amp = current_trunk_height * 0.065 * (species.trunk_curvature / 0.08);
    let sinuosity_amp = current_trunk_height * 0.035 * (species.trunk_curvature / 0.08);

    let mut current_pos = Vector3::ZERO;
    let mut trunk_node_ids = Vec::with_capacity(num_trunk_segs);

    // Calculamos el radio orgánico por altura con Root Flare (pata de elefante), conicidad biológica y musculatura
    let calc_trunk_radius = |height: f32| -> f32 {
        let u = (height / current_trunk_height).clamp(0.0, 1.0);
        // Ensanchamiento basal cóncavo (buttress / pata de elefante)
        let buttress = 1.0 + 0.85 * (-height / 1.1).exp();
        // Conicidad biológica suave (más constante en fuste bajo, más cónica arriba)
        let taper = (1.0 - species.trunk_taper * u.powf(0.72)).max(0.12);
        // Micro-ondulaciones leñosas orgánicas del tronco (musculatura leñosa)
        let organic_wave = 1.0 + 0.05 * ((height * 2.2 + seed_f * 0.1).sin());
        (current_base_radius * buttress * taper * organic_wave).max(0.032)
    };

    let mut current_r = calc_trunk_radius(0.0);

    for i in 0..num_trunk_segs {
        let frac = (i + 1) as f32 / num_trunk_segs as f32;
        let next_y = (i + 1) as f32 * seg_height;
        let next_r = calc_trunk_radius(next_y);

        // Curvatura botánica natural y balance gravitacional:
        // El fuste se arquea suavemente en el tercio medio pero la copa se reorienta
        // verticalmente hacia el cenit (fototropismo negativo al centro de gravedad).
        let s_curve = (frac * std::f32::consts::PI).sin();
        let wander = ((frac * std::f32::consts::TAU * 1.5 + seed_f * 0.12).sin()) * (frac * (1.0 - frac) * 2.0);
        
        // Desviaciones sinuosas sutiles de la corteza
        let jitter_x = ((i as f32 * 3.4 + seed_f * 0.08).sin()) * 0.015 * current_trunk_height * frac;
        let jitter_z = ((i as f32 * 4.2 + seed_f * 0.14).cos()) * 0.015 * current_trunk_height * frac;

        let disp = lean_dir * (s_curve * lean_amp)
            + perp_dir * (wander * sinuosity_amp)
            + Vector3::new(jitter_x, 0.0, jitter_z);

        let next_pos = Vector3::new(disp.x, next_y, disp.z);

        let parent_id = if i == 0 { None } else { Some(trunk_node_ids[i - 1]) };
        let node_id = graph.add_segment(NodeSegment {
            id: 0,
            parent_id,
            start_pos: current_pos,
            end_pos: next_pos,
            base_radius: current_r,
            tip_radius: next_r,
            depth: 0,
            order_index: i,
            vigor: 1.0,
            is_pruned: false,
            children_ids: Vec::new(),
        });

        trunk_node_ids.push(node_id);
        current_pos = next_pos;
        current_r = next_r;
    }

    // 3. Ramas Primarias (Depth 1), Ramillas Secundarias (Depth 2) y Horquilla Apical
    // Las ramas comienzan a brotar cuando el árbol supera el 12% de madurez
    if graph.current_age > 0.12 && num_trunk_segs >= 3 {
        let branch_start_seg = ((num_trunk_segs as f32 * species.branch_start_ratio).floor() as usize)
            .max(1);

        // Ángulo áureo (137.5 grados) para distribución natural alrededor del tronco
        let golden_angle = 137.507764f32.to_radians();
        let mut branch_counter = 0;

        for seg_idx in branch_start_seg..(num_trunk_segs - 1) {
            let parent_trunk_id = trunk_node_ids[seg_idx];
            let seg_start = graph.nodes[parent_trunk_id].start_pos;
            let seg_end = graph.nodes[parent_trunk_id].end_pos;
            let seg_r = graph.nodes[parent_trunk_id].base_radius;
            let seg_tip_r = graph.nodes[parent_trunk_id].tip_radius;

            let height_frac_seg = seg_start.y / current_trunk_height;
            // Densidad de ramas: 2 en base y cima, 3 en tercio medio para copa frondosa continua
            let branches_in_seg = if height_frac_seg > 0.70 || height_frac_seg < 0.28 {
                2
            } else if height_frac_seg >= 0.35 && height_frac_seg <= 0.65 {
                3
            } else {
                2
            };

            for b in 0..branches_in_seg {
                let attach_t = 0.15 + 0.70 * ((b as f32 + rng.range_f32(0.2, 0.8)) / (branches_in_seg as f32));
                let trunk_center = seg_start.lerp(seg_end, attach_t);
                let trunk_r_at_t = seg_r * (1.0 - attach_t) + seg_tip_r * attach_t;

                // Azimut alrededor del tronco con distribución áurea + variación orgánica
                let azimuth = (branch_counter as f32 * golden_angle)
                    + rng.range_f32(-0.35, 0.35);
                branch_counter += 1;

                let radial_dir = Vector3::new(azimuth.cos(), 0.0, azimuth.sin()).normalized();

                // Conexión Inteligente: la rama nace desde la corteza exterior del tronco
                // con penetración interna para un anclaje leñoso continuo sin holguras.
                let collar_origin = trunk_center + radial_dir * (trunk_r_at_t * 0.70);

                // Copa ovada y redondeada amplia de Alnus (árbol frondoso deciduo, NO cono de pino):
                // Envergadura máxima en tercio medio-inferior (~35%-50% de altura),
                // y cúpula superior ancha y redondeada (mantiene 55-60% de envergadura en la cima).
                let height_frac = trunk_center.y / current_trunk_height;
                let canopy_profile = if height_frac < 0.35 {
                    0.80 + 0.20 * (height_frac / 0.35)
                } else {
                    let u = (height_frac - 0.35) / 0.65;
                    (1.0 - 0.45 * u.powf(1.3)).max(0.55)
                };

                let total_branch_len = current_trunk_height
                    * species.branch_length_ratio
                    * canopy_profile
                    * (t.clamp(0.25, 1.0));

                let branch_base_r = (trunk_r_at_t * 0.35).max(0.016);
                let collar_r = branch_base_r * species.branch_collar_factor;
                // Ramas bajas tienen más segmentos para curvarse suavemente bajo gravedad
                let branch_segs = if height_frac < 0.55 {
                    species.branch_segments.max(4)
                } else {
                    3
                };
                let b_seg_len = total_branch_len / (branch_segs as f32);

                // Ángulo de inserción botánico de Alnus acuminata:
                // Base: ~68°-76° respecto a la vertical (se extienden ampliamente hacia los lados).
                // Medio: ~56°-64°. Copa alta: ~45°-52°.
                let base_elev_deg = 48.0 + 26.0 * (1.0 - height_frac).powf(1.1);
                let elev_deg = base_elev_deg
                    + rng.range_f32(-species.branch_angle_variance_deg, species.branch_angle_variance_deg);
                let elev_rad = elev_deg.to_radians();

                let initial_b_dir = (radial_dir * elev_rad.sin() + Vector3::UP * elev_rad.cos()).normalized();
                let mut current_b_dir = initial_b_dir;
                let mut b_curr_pos = collar_origin;
                let mut b_curr_r = collar_r;
                let mut parent_branch_id = parent_trunk_id;

                let height_leaf_scale = 1.0 - height_frac * 0.35;

                for bs in 0..branch_segs {
                    let b_next_r = if bs == 0 {
                        branch_base_r
                    } else {
                        (b_curr_r * 0.68).max(0.008)
                    };

                    // Curvatura botánica orgánica y gravitacional:
                    // Arco suave y continuo donde la rama se sostiene con vigor,
                    // con una leve flexión por peso y elevación suave en la punta hacia el sol.
                    let u = (bs as f32 + 0.5) / (branch_segs as f32);
                    let sag = (u * std::f32::consts::PI).sin() * (0.12 * (1.0 - height_frac * 0.5));
                    let phototropism = u * 0.10;
                    let side_axis = initial_b_dir.cross(Vector3::UP).normalized();
                    let lateral_sway = ((bs as f32 * 1.3 + branch_counter as f32 * 0.9 + seed_f * 0.1).sin()) * 0.08;
                    current_b_dir = (initial_b_dir - Vector3::UP * sag + Vector3::UP * phototropism + side_axis * lateral_sway).normalized();

                    let b_next_pos = b_curr_pos + current_b_dir * b_seg_len;

                    let prim_id = graph.add_segment(NodeSegment {
                        id: 0,
                        parent_id: Some(parent_branch_id),
                        start_pos: b_curr_pos,
                        end_pos: b_next_pos,
                        base_radius: b_curr_r,
                        tip_radius: b_next_r,
                        depth: 1,
                        order_index: bs,
                        vigor: 1.0,
                        is_pruned: false,
                        children_ids: Vec::new(),
                    });

                    parent_branch_id = prim_id;
                    b_curr_pos = b_next_pos;
                    b_curr_r = b_next_r;

                    // Racimo de follaje intermedio a partir del segundo segmento
                    if bs >= 1 && graph.current_age > 0.22 {
                        let mid_scale = species.leaf_cluster_size
                            * (0.35 + 0.65 * t)
                            * (0.80 + 0.20 * (bs as f32 / branch_segs as f32))
                            * height_leaf_scale;
                        let var_idx = branch_counter % 4;
                        graph.leaf_clusters.push(LeafClusterNode {
                            parent_node_id: prim_id,
                            position: b_curr_pos,
                            direction: current_b_dir,
                            scale: mid_scale,
                            is_active: true,
                            variant_idx: var_idx,
                        });
                    }

                    // Ramilla secundaria lateral alterna (Depth 2)
                    if bs >= 1 && graph.current_age > 0.30 && rng.next_f32() < species.secondary_branch_chance {
                        let side_sign = if bs % 2 == 1 { 1.0 } else { -1.0 };
                        let side_axis = current_b_dir.cross(Vector3::UP).normalized() * side_sign;
                        let sec_dir = (current_b_dir * 0.60 + side_axis * 0.68 + Vector3::UP * 0.16).normalized();
                        let sec_len = b_seg_len * 0.85;
                        let sec_end = b_curr_pos + sec_dir * sec_len;

                        let sec_id = graph.add_segment(NodeSegment {
                            id: 0,
                            parent_id: Some(prim_id),
                            start_pos: b_curr_pos,
                            end_pos: sec_end,
                            base_radius: b_next_r * 0.80,
                            tip_radius: 0.006,
                            depth: 2,
                            order_index: 0,
                            vigor: 0.85,
                            is_pruned: false,
                            children_ids: Vec::new(),
                        });

                        // Racimo de hojas al final de la ramilla lateral
                        let sec_scale = species.leaf_cluster_size * (0.30 + 0.70 * t) * 0.85 * height_leaf_scale;
                        let sec_var_idx = (branch_counter + 1) % 4;
                        graph.leaf_clusters.push(LeafClusterNode {
                            parent_node_id: sec_id,
                            position: sec_end,
                            direction: sec_dir,
                            scale: sec_scale,
                            is_active: true,
                            variant_idx: sec_var_idx,
                        });

                        // Ramita terciaria en árboles maduros para poblar el interior de la copa
                        if graph.current_age > 0.38 {
                            let tert_dir = (sec_dir * 0.65 - side_axis * 0.55 + Vector3::UP * 0.15).normalized();
                            let tert_len = sec_len * 0.60;
                            let tert_end = sec_end + tert_dir * tert_len;

                            let tert_id = graph.add_segment(NodeSegment {
                                id: 0,
                                parent_id: Some(sec_id),
                                start_pos: sec_end,
                                end_pos: tert_end,
                                base_radius: 0.006,
                                tip_radius: 0.003,
                                depth: 2,
                                order_index: 1,
                                vigor: 0.75,
                                is_pruned: false,
                                children_ids: Vec::new(),
                            });

                            let tert_scale = species.leaf_cluster_size * (0.35 + 0.65 * t) * 0.80 * height_leaf_scale;
                            graph.leaf_clusters.push(LeafClusterNode {
                                parent_node_id: tert_id,
                                position: tert_end,
                                direction: tert_dir,
                                scale: tert_scale,
                                is_active: true,
                                variant_idx: (branch_counter + 2) % 4,
                            });
                        }
                    }
                }

                // Racimos de follaje terminales en la punta de la rama
                let tip_scale = species.leaf_cluster_size * (0.38 + 0.62 * t) * height_leaf_scale;
                if graph.current_age > 0.35 {
                    let side_cross = current_b_dir.cross(Vector3::UP).normalized();
                    let fork_left_dir = (current_b_dir * 0.72 + side_cross * 0.48 + Vector3::UP * 0.20).normalized();
                    let fork_right_dir = (current_b_dir * 0.72 - side_cross * 0.48 + Vector3::UP * 0.20).normalized();
                    let fork_center_dir = (current_b_dir * 0.88 + Vector3::UP * 0.25).normalized();

                    graph.leaf_clusters.push(LeafClusterNode {
                        parent_node_id: parent_branch_id,
                        position: b_curr_pos + fork_left_dir * 0.35,
                        direction: fork_left_dir,
                        scale: tip_scale,
                        is_active: true,
                        variant_idx: (branch_counter + 2) % 4,
                    });
                    graph.leaf_clusters.push(LeafClusterNode {
                        parent_node_id: parent_branch_id,
                        position: b_curr_pos + fork_right_dir * 0.35,
                        direction: fork_right_dir,
                        scale: tip_scale,
                        is_active: true,
                        variant_idx: (branch_counter + 3) % 4,
                    });
                    graph.leaf_clusters.push(LeafClusterNode {
                        parent_node_id: parent_branch_id,
                        position: b_curr_pos + fork_center_dir * 0.40,
                        direction: fork_center_dir,
                        scale: tip_scale * 1.05,
                        is_active: true,
                        variant_idx: branch_counter % 4,
                    });
                } else {
                    let tip_scale = species.leaf_cluster_size * (0.38 + 0.62 * t) * height_leaf_scale;
                    graph.leaf_clusters.push(LeafClusterNode {
                        parent_node_id: parent_branch_id,
                        position: b_curr_pos,
                        direction: current_b_dir,
                        scale: tip_scale,
                        is_active: true,
                        variant_idx: branch_counter % 4,
                    });
                }
            }
        }
    }

    // 4. Corona Apical Abierta y Dispersa en la Cima del Tronco
    // En Alnus acuminata, la cima del tronco no forma una bola maciza ("gorda"),
    // sino que se abre en múltiples guías/líderes ascendentes esbeltos y dispersos ("grande y disperso todo")
    // que se proyectan hacia el cielo con claros de luz azul entre ellos.
    if let Some(&top_trunk_id) = trunk_node_ids.last() {
        let top_pos = graph.nodes[top_trunk_id].end_pos;
        let top_r = graph.nodes[top_trunk_id].tip_radius;

        if graph.current_age > 0.20 {
            let num_apical_leaders = 3;

            for f in 0..num_apical_leaders {
                let jitter = ((seed + f as u64 * 41) % 24) as f32 - 12.0;
                let f_angle = (f as f32 * 120.0 + jitter).to_radians();

                // Dirección ascendente divergente en cúpula redondeada (elevación ~52°-58°)
                let horiz_spread = 0.68 + 0.10 * (f as f32 % 2.0);
                let f_dir_seg1 = Vector3::new(
                    f_angle.cos() * horiz_spread,
                    0.74,
                    f_angle.sin() * horiz_spread,
                ).normalized();

                let total_leader_len = current_trunk_height * 0.19 * (0.4 + 0.6 * t);
                let half_len = total_leader_len * 0.52;
                let seg1_end = top_pos + f_dir_seg1 * half_len;

                // Segmento 1 del líder apical
                let leader1_id = graph.add_segment(NodeSegment {
                    id: 0,
                    parent_id: Some(top_trunk_id),
                    start_pos: top_pos,
                    end_pos: seg1_end,
                    base_radius: top_r * 0.80,
                    tip_radius: 0.010,
                    depth: 1,
                    order_index: 0,
                    vigor: 1.0,
                    is_pruned: false,
                    children_ids: Vec::new(),
                });

                // Racimo intermedio aireado (pequeño y disperso)
                let mid_crown_scale = species.leaf_cluster_size * 0.50 * (0.4 + 0.6 * t);
                graph.leaf_clusters.push(LeafClusterNode {
                    parent_node_id: leader1_id,
                    position: seg1_end,
                    direction: f_dir_seg1,
                    scale: mid_crown_scale,
                    is_active: true,
                    variant_idx: f % 4,
                });

                // Segmento 2 que se proyecta aún más alto
                let f_dir_seg2 = (f_dir_seg1 + Vector3::new(f_angle.cos() * 0.12, 0.04, f_angle.sin() * 0.12)).normalized();
                let seg2_end = seg1_end + f_dir_seg2 * half_len;

                let leader2_id = graph.add_segment(NodeSegment {
                    id: 0,
                    parent_id: Some(leader1_id),
                    start_pos: seg1_end,
                    end_pos: seg2_end,
                    base_radius: 0.010,
                    tip_radius: 0.005,
                    depth: 1,
                    order_index: 1,
                    vigor: 0.9,
                    is_pruned: false,
                    children_ids: Vec::new(),
                });

                // Racimo terminal en la punta del líder
                let tip_crown_scale = species.leaf_cluster_size * 0.55 * (0.4 + 0.6 * t);
                graph.leaf_clusters.push(LeafClusterNode {
                    parent_node_id: leader2_id,
                    position: seg2_end,
                    direction: f_dir_seg2,
                    scale: tip_crown_scale,
                    is_active: true,
                    variant_idx: (f + 1) % 4,
                });

                // Ramilla lateral divergente del líder para dispersión airosa
                let side_angle = f_angle + 75.0f32.to_radians();
                let twig_dir = (f_dir_seg2 * 0.68 + Vector3::new(side_angle.cos() * 0.60, 0.08, side_angle.sin() * 0.60)).normalized();
                let twig_end = seg1_end + twig_dir * (half_len * 0.72);

                let twig_id = graph.add_segment(NodeSegment {
                    id: 0,
                    parent_id: Some(leader1_id),
                    start_pos: seg1_end,
                    end_pos: twig_end,
                    base_radius: 0.006,
                    tip_radius: 0.003,
                    depth: 2,
                    order_index: 0,
                    vigor: 0.75,
                    is_pruned: false,
                    children_ids: Vec::new(),
                });

                let twig_scale = species.leaf_cluster_size * 0.46 * (0.4 + 0.6 * t);
                graph.leaf_clusters.push(LeafClusterNode {
                    parent_node_id: twig_id,
                    position: twig_end,
                    direction: twig_dir,
                    scale: twig_scale,
                    is_active: true,
                    variant_idx: (f + 2) % 4,
                });
            }
        }
    }

    // 5. Brote Pequeño Inicial (age < 0.12)
    if graph.current_age <= 0.12 && graph.leaf_clusters.is_empty() {
        if let Some(&top_id) = trunk_node_ids.last() {
            let top_pos = graph.nodes[top_id].end_pos;
            graph.leaf_clusters.push(LeafClusterNode {
                parent_node_id: top_id,
                position: top_pos,
                direction: Vector3::UP,
                scale: 0.35 + 0.40 * graph.current_age,
                is_active: true,
                variant_idx: 0,
            });
        }
    }

    // Re-aplicar historial de podas
    for &pruned_id in previously_pruned {
        graph.prune_branch(pruned_id);
    }

    graph
}

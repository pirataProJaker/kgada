use godot::prelude::*;
use super::network::{RoadNetwork, RoadNode, RoadEdge};
use super::profile::MedianStyle;

/// Contenedor de todas las instancias de cajas generadas para GPU Instancing.
#[derive(Debug, Default, Clone)]
pub struct RoadEngineOutput {
    pub asphalt_instances: Vec<Transform3D>,
    pub sidewalk_instances: Vec<Transform3D>,
    pub curb_instances: Vec<Transform3D>,
    pub median_instances: Vec<Transform3D>,
    pub junction_instances: Vec<Transform3D>,
    pub paint_instances: Vec<Transform3D>,
    pub tree_socket_transforms: Vec<Transform3D>,
}

impl RoadEngineOutput {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn total_box_count(&self) -> usize {
        self.asphalt_instances.len()
            + self.sidewalk_instances.len()
            + self.curb_instances.len()
            + self.median_instances.len()
            + self.junction_instances.len()
            + self.paint_instances.len()
    }
}

pub struct RoadSolver;

impl RoadSolver {
    /// Resuelve las intersecciones, recorta las calzadas y genera las cajas instanciadas GPU
    /// para toda la red vial con cimentación profunda y elevación anti-Z-fighting.
    pub fn solve_network(network: &RoadNetwork) -> RoadEngineOutput {
        let mut output = RoadEngineOutput::new();

        if network.nodes.is_empty() || network.edges.is_empty() {
            return output;
        }

        // 1. Calcular el retranqueo (setback) necesario en cada extremo de cada tramo
        let mut edge_setbacks: Vec<(f32, f32)> = Vec::with_capacity(network.edges.len());

        for edge in &network.edges {
            let sb_from = Self::calculate_node_setback(network, edge.from_node, edge.id);
            let sb_to = Self::calculate_node_setback(network, edge.to_node, edge.id);
            edge_setbacks.push((sb_from, sb_to));
        }

        // 2. Generar las cajas de cruce e intersección en cada nodo con 2 o más vías conectadas
        for node in &network.nodes {
            if node.connected_edges.len() >= 2 {
                Self::build_intersection_junction(&mut output, network, node);
            }
        }

        // 3. Generar las cajas de tramos rectos de calzadas, banquetas, bordillos, camellones y pintura
        for (edge_idx, edge) in network.edges.iter().enumerate() {
            let (sb_from, sb_to) = edge_setbacks[edge_idx];
            Self::build_edge_ribbon(&mut output, network, edge, sb_from, sb_to);
        }

        output
    }

    /// Calcula la distancia que un tramo debe retirarse de un nodo
    /// basándose en el ancho vehicular de las calles que cruzan transversalmente.
    fn calculate_node_setback(network: &RoadNetwork, node_id: usize, current_edge_id: usize) -> f32 {
        let node = &network.nodes[node_id];
        if node.connected_edges.len() <= 1 {
            return 0.0; // Calle sin salida / fondo de saco
        }

        let current_edge = &network.edges[current_edge_id];
        let dir_current = current_edge.outward_direction(&network.nodes, node_id);

        let mut max_setback = 0.0f32;

        for &other_edge_id in &node.connected_edges {
            if other_edge_id == current_edge_id {
                continue;
            }

            let other_edge = &network.edges[other_edge_id];
            let dir_other = other_edge.outward_direction(&network.nodes, node_id);
            let dot = dir_current.dot(dir_other);

            // Si dot < -0.85, son colineales y opuestas (la misma calle continuando recta).
            if dot < -0.85 {
                continue;
            }

            // Calle transversal / que cruza: el retranqueo es la mitad del ancho vehicular de la otra vía,
            // proyectado según el ángulo de cruce (sin_theta).
            let sin_theta = (1.0 - dot * dot).max(0.0625).sqrt();
            let other_roadway_half = other_edge.profile.total_roadway_width() * 0.5;
            let sb = other_roadway_half / sin_theta;

            if sb > max_setback {
                max_setback = sb;
            }
        }

        max_setback
    }

    /// Construye la losa vehicular y las banquetas/bordillos de esquina en una intersección.
    fn build_intersection_junction(
        output: &mut RoadEngineOutput,
        network: &RoadNetwork,
        node: &RoadNode,
    ) {
        if node.connected_edges.is_empty() {
            return;
        }

        // 1. Identificar la vía principal (la de mayor calzada vehicular)
        let mut primary_edge = &network.edges[node.connected_edges[0]];
        for &edge_id in &node.connected_edges {
            let edge = &network.edges[edge_id];
            if edge.profile.total_roadway_width() > primary_edge.profile.total_roadway_width() {
                primary_edge = edge;
            }
        }

        let fwd_primary = primary_edge.outward_direction(&network.nodes, node.id);
        let world_up = Vector3::UP;
        let right_primary = if fwd_primary.dot(world_up).abs() > 0.99 {
            Vector3::RIGHT
        } else {
            world_up.cross(fwd_primary).normalized()
        };
        let up_primary = fwd_primary.cross(right_primary).normalized();
        let basis_rot = Basis::from_cols(right_primary, up_primary, fwd_primary);

        let primary_roadway_w = primary_edge.profile.total_roadway_width();
        let mut max_crossing_roadway_w = 0.0f32;
        let mut crossing_edge_opt: Option<&RoadEdge> = None;

        for &edge_id in &node.connected_edges {
            let edge = &network.edges[edge_id];
            let dir = edge.outward_direction(&network.nodes, node.id);
            if dir.dot(fwd_primary).abs() < 0.85 {
                let w = edge.profile.total_roadway_width();
                if w > max_crossing_roadway_w {
                    max_crossing_roadway_w = w;
                    crossing_edge_opt = Some(edge);
                }
            }
        }

        if max_crossing_roadway_w < 0.1 {
            max_crossing_roadway_w = primary_roadway_w;
        }

        let y_bot = -primary_edge.profile.foundation_depth;
        let y_road = primary_edge.profile.road_surface_elevation;
        let y_walk = primary_edge.profile.sidewalk_top_elevation();

        // 2. Losa vehicular de intersección (asfalto continuo con cimentación profunda)
        let junction_trans = Self::make_solid_box(
            node.position,
            basis_rot,
            primary_roadway_w,
            max_crossing_roadway_w,
            y_bot,
            y_road,
        );
        output.junction_instances.push(junction_trans);

        // 3. Esquinas peatonales de banquetas y bordillos de esquina
        if let Some(crossing_edge) = crossing_edge_opt {
            let curb_w = primary_edge.profile.curb_width;
            let sw_w_a = primary_edge.profile.sidewalk_width + curb_w;
            let sw_w_b = crossing_edge.profile.sidewalk_width + crossing_edge.profile.curb_width;

            if sw_w_a > 0.1 && sw_w_b > 0.1 {
                for sx in [-1.0f32, 1.0f32] {
                    for sz in [-1.0f32, 1.0f32] {
                        let has_a = if sx < 0.0 { primary_edge.profile.has_left_sidewalk } else { primary_edge.profile.has_right_sidewalk };
                        let has_b = if sz < 0.0 { crossing_edge.profile.has_left_sidewalk } else { crossing_edge.profile.has_right_sidewalk };

                        if has_a && has_b {
                            let loc_x = sx * (primary_roadway_w * 0.5 + sw_w_a * 0.5);
                            let loc_z = sz * (max_crossing_roadway_w * 0.5 + sw_w_b * 0.5);
                            let corner_ground = node.position + basis_rot * Vector3::new(loc_x, 0.0, loc_z);

                            // Losa de banqueta en la esquina
                            let corner_sw_trans = Self::make_solid_box(
                                corner_ground,
                                basis_rot,
                                sw_w_a,
                                sw_w_b,
                                y_bot,
                                y_walk,
                            );
                            output.sidewalk_instances.push(corner_sw_trans);

                            // Bordillos de protección en los bordes internos de la esquina
                            if primary_edge.profile.has_curbs && curb_w > 0.01 {
                                // Bordillo lateral (da hacia la calle principal)
                                let curb_side_loc = Vector3::new(
                                    sx * (primary_roadway_w * 0.5 + curb_w * 0.5),
                                    0.0,
                                    loc_z,
                                );
                                output.curb_instances.push(Self::make_solid_box(
                                    node.position + basis_rot * curb_side_loc,
                                    basis_rot,
                                    curb_w,
                                    sw_w_b,
                                    y_bot,
                                    y_walk + 0.005,
                                ));

                                // Bordillo frontal (da hacia la calle que cruza)
                                let curb_front_loc = Vector3::new(
                                    loc_x,
                                    0.0,
                                    sz * (max_crossing_roadway_w * 0.5 + curb_w * 0.5),
                                );
                                output.curb_instances.push(Self::make_solid_box(
                                    node.position + basis_rot * curb_front_loc,
                                    basis_rot,
                                    sw_w_a,
                                    curb_w,
                                    y_bot,
                                    y_walk + 0.005,
                                ));
                            }
                        }
                    }
                }
            }
        }
    }

    /// Construye las cajas de tramos rectos de calzadas, banquetas, bordillos, camellones y pintura vial.
    fn build_edge_ribbon(
        output: &mut RoadEngineOutput,
        network: &RoadNetwork,
        edge: &RoadEdge,
        sb_from: f32,
        sb_to: f32,
    ) {
        let p_start_raw = network.nodes[edge.from_node].position;
        let p_end_raw = network.nodes[edge.to_node].position;

        let delta = p_end_raw - p_start_raw;
        let total_len = delta.length();
        if total_len <= (sb_from + sb_to + 0.5) {
            return;
        }

        let fwd = delta / total_len;
        let world_up = Vector3::UP;
        let right = if fwd.dot(world_up).abs() > 0.99 {
            Vector3::RIGHT
        } else {
            world_up.cross(fwd).normalized()
        };
        let up = fwd.cross(right).normalized();
        let basis_rot = Basis::from_cols(right, up, fwd);

        // Puntos efectivos tras el retranqueo de intersecciones
        let p_start = p_start_raw + fwd * sb_from;
        let p_end = p_end_raw - fwd * sb_to;
        let length = (p_end - p_start).length();
        if length <= 0.2 {
            return;
        }

        let center = (p_start + p_end) * 0.5;
        let prof = &edge.profile;

        let y_bot = -prof.foundation_depth;
        let y_road = prof.road_surface_elevation;
        let y_walk = prof.sidewalk_top_elevation();
        let curb_w = prof.curb_width;

        if prof.is_divided {
            // =========================================================================
            // VÍA DIVIDIDA (Bulevar / Autopista con Camellón Central o Arroyo)
            // =========================================================================
            let r_w = prof.single_roadway_width();
            let m_w = prof.median_width;

            // 1. Calzada Izquierda (Asfalto elevado con cimentación profunda)
            let left_road_offset = -(m_w * 0.5 + r_w * 0.5);
            let left_road_center = center + right * left_road_offset;
            output.asphalt_instances.push(Self::make_solid_box(
                left_road_center,
                basis_rot,
                r_w,
                length,
                y_bot,
                y_road,
            ));

            // 2. Calzada Derecha (Asfalto elevado con cimentación profunda)
            let right_road_offset = m_w * 0.5 + r_w * 0.5;
            let right_road_center = center + right * right_road_offset;
            output.asphalt_instances.push(Self::make_solid_box(
                right_road_center,
                basis_rot,
                r_w,
                length,
                y_bot,
                y_road,
            ));

            // 3. Señalización vial (Líneas discontinuas entre carriles en ambas calzadas)
            if prof.has_lane_markings && prof.lanes_per_direction > 1 {
                for lane_k in 1..prof.lanes_per_direction {
                    let lateral = -r_w * 0.5 + (lane_k as f32) * prof.lane_width;
                    // Calzada izquierda
                    Self::generate_dashed_paint_markings(
                        output,
                        left_road_center + right * lateral,
                        basis_rot,
                        length,
                        prof.lane_marking_dash_len,
                        prof.lane_marking_gap_len,
                        y_road,
                    );
                    // Calzada derecha
                    Self::generate_dashed_paint_markings(
                        output,
                        right_road_center + right * lateral,
                        basis_rot,
                        length,
                        prof.lane_marking_dash_len,
                        prof.lane_marking_gap_len,
                        y_road,
                    );
                }
            }

            // 4. Camellón Central
            if m_w > 0.1 {
                if prof.median_style == MedianStyle::Stream {
                    // Arroyo / Canal hundido
                    let stream_y_bot = y_road - 1.60;
                    let stream_y_top = y_road - 0.40;
                    output.median_instances.push(Self::make_solid_box(
                        center,
                        basis_rot,
                        m_w,
                        length,
                        stream_y_bot,
                        stream_y_top,
                    ));
                } else {
                    // Camellón elevado con césped/árboles/arbustos
                    if prof.has_median_curbs && m_w > (curb_w * 2.0 + 0.3) && curb_w > 0.01 {
                        // Bordillo izquierdo del camellón
                        let curb_l_off = -(m_w * 0.5 - curb_w * 0.5);
                        output.curb_instances.push(Self::make_solid_box(
                            center + right * curb_l_off,
                            basis_rot,
                            curb_w,
                            length,
                            y_bot,
                            y_walk,
                        ));

                        // Bordillo derecho del camellón
                        let curb_r_off = m_w * 0.5 - curb_w * 0.5;
                        output.curb_instances.push(Self::make_solid_box(
                            center + right * curb_r_off,
                            basis_rot,
                            curb_w,
                            length,
                            y_bot,
                            y_walk,
                        ));

                        // Relleno de pasto/tierra central (ligeramente elevado)
                        let grass_w = m_w - curb_w * 2.0;
                        output.median_instances.push(Self::make_solid_box(
                            center,
                            basis_rot,
                            grass_w,
                            length,
                            y_bot,
                            y_walk + 0.01,
                        ));
                    } else {
                        output.median_instances.push(Self::make_solid_box(
                            center,
                            basis_rot,
                            m_w,
                            length,
                            y_bot,
                            y_walk,
                        ));
                    }

                    // Sockets de árboles en el camellón
                    if prof.tree_spacing > 1.0 {
                        Self::generate_median_tree_sockets(
                            output,
                            center,
                            fwd,
                            up,
                            length,
                            prof.tree_spacing,
                            y_walk,
                        );
                    }
                }
            }

            // 5. Banquetas y Bordillos Exteriores
            let half_outer = m_w * 0.5 + r_w;

            if prof.has_left_sidewalk {
                let curb_off = -(half_outer + curb_w * 0.5);
                let sw_off = -(half_outer + curb_w + prof.sidewalk_width * 0.5);

                if prof.has_curbs && curb_w > 0.01 {
                    output.curb_instances.push(Self::make_solid_box(
                        center + right * curb_off,
                        basis_rot,
                        curb_w,
                        length,
                        y_bot,
                        y_walk,
                    ));
                }

                output.sidewalk_instances.push(Self::make_solid_box(
                    center + right * sw_off,
                    basis_rot,
                    prof.sidewalk_width,
                    length,
                    y_bot,
                    y_walk,
                ));
            }

            if prof.has_right_sidewalk {
                let curb_off = half_outer + curb_w * 0.5;
                let sw_off = half_outer + curb_w + prof.sidewalk_width * 0.5;

                if prof.has_curbs && curb_w > 0.01 {
                    output.curb_instances.push(Self::make_solid_box(
                        center + right * curb_off,
                        basis_rot,
                        curb_w,
                        length,
                        y_bot,
                        y_walk,
                    ));
                }

                output.sidewalk_instances.push(Self::make_solid_box(
                    center + right * sw_off,
                    basis_rot,
                    prof.sidewalk_width,
                    length,
                    y_bot,
                    y_walk,
                ));
            }
        } else {
            // =========================================================================
            // CALLE NORMAL CONTINUA (Residencial / Comercial sin división central)
            // =========================================================================
            let r_w = prof.single_roadway_width();

            // 1. Calzada Única Central (Asfalto elevado con cimentación profunda)
            output.asphalt_instances.push(Self::make_solid_box(
                center,
                basis_rot,
                r_w,
                length,
                y_bot,
                y_road,
            ));

            // 2. Señalización vial (Línea central o divisorias de carriles)
            if prof.has_lane_markings {
                if prof.lanes_per_direction > 1 {
                    for lane_k in 1..(prof.lanes_per_direction * 2) {
                        if lane_k == prof.lanes_per_direction {
                            continue; // Línea central
                        }
                        let lateral = -r_w * 0.5 + (lane_k as f32) * prof.lane_width;
                        Self::generate_dashed_paint_markings(
                            output,
                            center + right * lateral,
                            basis_rot,
                            length,
                            prof.lane_marking_dash_len,
                            prof.lane_marking_gap_len,
                            y_road,
                        );
                    }
                }
            }

            // 3. Banqueta y Bordillo Izquierdo
            if prof.has_left_sidewalk {
                let curb_off = -(r_w * 0.5 + curb_w * 0.5);
                let sw_off = -(r_w * 0.5 + curb_w + prof.sidewalk_width * 0.5);

                if prof.has_curbs && curb_w > 0.01 {
                    output.curb_instances.push(Self::make_solid_box(
                        center + right * curb_off,
                        basis_rot,
                        curb_w,
                        length,
                        y_bot,
                        y_walk,
                    ));
                }

                output.sidewalk_instances.push(Self::make_solid_box(
                    center + right * sw_off,
                    basis_rot,
                    prof.sidewalk_width,
                    length,
                    y_bot,
                    y_walk,
                ));
            }

            // 4. Banqueta y Bordillo Derecho
            if prof.has_right_sidewalk {
                let curb_off = r_w * 0.5 + curb_w * 0.5;
                let sw_off = r_w * 0.5 + curb_w + prof.sidewalk_width * 0.5;

                if prof.has_curbs && curb_w > 0.01 {
                    output.curb_instances.push(Self::make_solid_box(
                        center + right * curb_off,
                        basis_rot,
                        curb_w,
                        length,
                        y_bot,
                        y_walk,
                    ));
                }

                output.sidewalk_instances.push(Self::make_solid_box(
                    center + right * sw_off,
                    basis_rot,
                    prof.sidewalk_width,
                    length,
                    y_bot,
                    y_walk,
                ));
            }
        }
    }

    /// Construye una caja sólida orientada en 3D con cimentación inferior (y_bottom) y superficie superior (y_top).
    /// Esto elimina cualquier z-fighting con el terreno o huecos en pendientes.
    fn make_solid_box(
        center_ground: Vector3,
        basis_rot: Basis,
        width: f32,
        length: f32,
        y_bottom: f32,
        y_top: f32,
    ) -> Transform3D {
        let thickness = (y_top - y_bottom).max(0.01);
        let y_center = (y_bottom + y_top) * 0.5;
        let up_vec = basis_rot.col_b();
        let center = center_ground + up_vec * y_center;
        let size = Vector3::new(width, thickness, length);
        let scaled_basis = basis_rot * Basis::from_scale(size);
        Transform3D::new(scaled_basis, center)
    }

    /// Genera rayas discontinuas de pintura vial instanciadas sobre la superficie del asfalto.
    fn generate_dashed_paint_markings(
        output: &mut RoadEngineOutput,
        center_ground: Vector3,
        basis_rot: Basis,
        total_length: f32,
        dash_len: f32,
        gap_len: f32,
        y_road: f32,
    ) {
        let cycle = dash_len + gap_len;
        if total_length < dash_len || cycle < 0.1 {
            return;
        }

        let count = (total_length / cycle).floor() as usize;
        if count == 0 {
            return;
        }

        let fwd = basis_rot.col_c();
        let start_dist = -total_length * 0.5 + dash_len * 0.5 + gap_len * 0.5;

        for i in 0..count {
            let dist = start_dist + (i as f32) * cycle;
            let dash_ground = center_ground + fwd * dist;
            // Grosor de pintura: 8mm sobre el asfalto (evita z-fighting con el asfalto por completo)
            let trans = Self::make_solid_box(
                dash_ground,
                basis_rot,
                0.15,
                dash_len,
                y_road + 0.002,
                y_road + 0.010,
            );
            output.paint_instances.push(trans);
        }
    }

    /// Distribuye sockets para árboles en el camellón respetando un margen de seguridad en los extremos.
    fn generate_median_tree_sockets(
        output: &mut RoadEngineOutput,
        center: Vector3,
        fwd: Vector3,
        up: Vector3,
        length: f32,
        spacing: f32,
        median_top_y: f32,
    ) {
        let clearance = 8.0f32.max(spacing * 0.5);
        let usable_length = length - clearance * 2.0;
        if usable_length < spacing * 0.5 {
            return;
        }

        let count = ((usable_length / spacing).floor() as usize).max(1);
        let step = usable_length / (count as f32);
        let start = -usable_length * 0.5 + step * 0.5;

        for i in 0..count {
            let cur = start + (i as f32) * step;
            let pos = center + fwd * cur + up * median_top_y;
            let transform = Transform3D::new(Basis::IDENTITY, pos);
            output.tree_socket_transforms.push(transform);
        }
    }
}

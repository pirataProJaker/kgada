use godot::prelude::*;
use super::profile::RoadCrossSection;

/// Nodo de intersección o punto final de una trayectoria vial.
#[derive(Debug, Clone)]
pub struct RoadNode {
    pub id: usize,
    pub position: Vector3,
    pub connected_edges: Vec<usize>,
}

/// Tramo de calle entre dos nodos con su perfil transversal asignado.
#[derive(Debug, Clone)]
pub struct RoadEdge {
    pub id: usize,
    pub from_node: usize,
    pub to_node: usize,
    pub profile: RoadCrossSection,
}

impl RoadEdge {
    /// Vector director de la trayectoria (de from_node a to_node).
    pub fn direction(&self, nodes: &[RoadNode]) -> Vector3 {
        let p_start = nodes[self.from_node].position;
        let p_end = nodes[self.to_node].position;
        let d = p_end - p_start;
        let len = d.length();
        if len > 0.001 {
            d / len
        } else {
            Vector3::FORWARD
        }
    }

    /// Longitud métrica del tramo.
    pub fn length(&self, nodes: &[RoadNode]) -> f32 {
        let p_start = nodes[self.from_node].position;
        let p_end = nodes[self.to_node].position;
        (p_end - p_start).length()
    }

    /// Vector director unitario saliendo desde el nodo `at_node` a lo largo de este tramo.
    pub fn outward_direction(&self, nodes: &[RoadNode], at_node: usize) -> Vector3 {
        let other_node = if self.from_node == at_node {
            self.to_node
        } else {
            self.from_node
        };
        let p_start = nodes[at_node].position;
        let p_end = nodes[other_node].position;
        let d = p_end - p_start;
        let len = d.length();
        if len > 0.001 {
            d / len
        } else {
            Vector3::FORWARD
        }
    }
}

/// Grafo de la red vial en memoria nativa de Rust.
#[derive(Debug, Default, Clone)]
pub struct RoadNetwork {
    pub nodes: Vec<RoadNode>,
    pub edges: Vec<RoadEdge>,
}

impl RoadNetwork {
    pub fn new() -> Self {
        Self {
            nodes: Vec::with_capacity(64),
            edges: Vec::with_capacity(128),
        }
    }

    pub fn clear(&mut self) {
        self.nodes.clear();
        self.edges.clear();
    }

    /// Añade o reutiliza un nodo en la posición dada (tolerancia de 0.20m para snapping automático).
    pub fn add_or_find_node(&mut self, pos: Vector3) -> usize {
        for node in &self.nodes {
            if node.position.distance_to(pos) < 0.20 {
                return node.id;
            }
        }

        let id = self.nodes.len();
        self.nodes.push(RoadNode {
            id,
            position: pos,
            connected_edges: Vec::with_capacity(4),
        });
        id
    }

    /// Añade un tramo de carretera entre dos nodos con un perfil transversal dado.
    pub fn add_road_edge(&mut self, from_node: usize, to_node: usize, profile: RoadCrossSection) -> Option<usize> {
        if from_node >= self.nodes.len() || to_node >= self.nodes.len() || from_node == to_node {
            return None;
        }

        // Evitar duplicados exactos
        for edge in &self.edges {
            if (edge.from_node == from_node && edge.to_node == to_node)
                || (edge.from_node == to_node && edge.to_node == from_node)
            {
                return Some(edge.id);
            }
        }

        let edge_id = self.edges.len();
        self.edges.push(RoadEdge {
            id: edge_id,
            from_node,
            to_node,
            profile,
        });

        self.nodes[from_node].connected_edges.push(edge_id);
        self.nodes[to_node].connected_edges.push(edge_id);

        Some(edge_id)
    }
}

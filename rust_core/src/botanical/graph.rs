use godot::prelude::*;

/// Identificador único de un segmento en el grafo botánico.
pub type NodeId = usize;

/// Segmento individual de madera (sección de tronco o rama).
#[derive(Debug, Clone)]
pub struct NodeSegment {
    pub id: NodeId,
    pub parent_id: Option<NodeId>,
    /// Coordenada tridimensional de inicio del segmento (Y-up local).
    pub start_pos: Vector3,
    /// Coordenada tridimensional de final del segmento (Y-up local).
    pub end_pos: Vector3,
    /// Radio base (en metros).
    pub base_radius: f32,
    /// Radio en la punta (en metros).
    pub tip_radius: f32,
    /// Nivel de profundidad en la jerarquía botánica:
    /// 0 = Tronco principal, 1 = Rama primaria, 2 = Rama secundaria.
    pub depth: usize,
    /// Índice secuencial dentro de su propia rama (0 = base de la rama).
    pub order_index: usize,
    /// Vigor o flujo de savia (determina la velocidad de engrosamiento y brote).
    pub vigor: f32,
    /// Si este nodo fue podado o cortado por el jugador.
    pub is_pruned: bool,
    /// Nodos hijos conectados a la punta o cuerpo de este segmento.
    pub children_ids: Vec<NodeId>,
}

/// Yema o punto de crecimiento activo/durmiente.
#[derive(Debug, Clone)]
pub struct Bud {
    pub parent_node_id: NodeId,
    pub position: Vector3,
    pub direction: Vector3,
    /// Si es yema apical (crecimiento hacia adelante) o axilar (crecimiento lateral).
    pub is_apical: bool,
    /// Si está latente esperando a activarse por edad o tras una poda vecina.
    pub dormant: bool,
    /// Edad a partir de la cual despierta esta yema.
    pub activation_age: f32,
}

/// Racimo de hojas situado en los brotes terminales.
#[derive(Debug, Clone)]
pub struct LeafClusterNode {
    pub parent_node_id: NodeId,
    pub position: Vector3,
    pub direction: Vector3,
    pub scale: f32,
    pub is_active: bool,
    pub variant_idx: usize,
}

/// Estructura de datos completa del Grafo Botánico.
///
/// Modela el esqueleto vivo del árbol, permitiendo simular crecimiento
/// continuo, ramificación fractal y poda interactiva en tiempo real.
#[derive(Debug, Clone)]
pub struct BotanicalGraph {
    pub seed: u64,
    pub current_age: f32,
    pub nodes: Vec<NodeSegment>,
    pub buds: Vec<Bud>,
    pub leaf_clusters: Vec<LeafClusterNode>,
    /// Historial de IDs de nodos podados por el jugador.
    pub pruned_nodes_history: Vec<NodeId>,
}

impl BotanicalGraph {
    pub fn new(seed: u64) -> Self {
        Self {
            seed,
            current_age: 0.0,
            nodes: Vec::with_capacity(64),
            buds: Vec::with_capacity(32),
            leaf_clusters: Vec::with_capacity(48),
            pruned_nodes_history: Vec::new(),
        }
    }

    /// Añade un nuevo segmento al grafo y devuelve su NodeId asignado.
    pub fn add_segment(&mut self, mut segment: NodeSegment) -> NodeId {
        let id = self.nodes.len();
        segment.id = id;
        if let Some(parent_id) = segment.parent_id {
            if parent_id < self.nodes.len() {
                self.nodes[parent_id].children_ids.push(id);
            }
        }
        self.nodes.push(segment);
        id
    }

    /// Poda una rama a partir de un nodo específico.
    ///
    /// Marca el nodo y **todos sus descendientes** como podados (`is_pruned = true`).
    /// Además, redistribuye el vigor hacia el nodo padre para simular la
    /// respuesta biológica donde la savia impulsa los brotes vecinos restantes.
    /// Devuelve la cantidad de nodos que fueron cortados.
    pub fn prune_branch(&mut self, target_node_id: NodeId) -> usize {
        if target_node_id >= self.nodes.len() || self.nodes[target_node_id].is_pruned {
            return 0;
        }

        // Recolectar recursivamente todos los nodos descendientes
        let mut to_prune = Vec::new();
        let mut stack = vec![target_node_id];

        while let Some(current_id) = stack.pop() {
            to_prune.push(current_id);
            if current_id < self.nodes.len() {
                for &child_id in &self.nodes[current_id].children_ids {
                    if child_id < self.nodes.len() && !self.nodes[child_id].is_pruned {
                        stack.push(child_id);
                    }
                }
            }
        }

        let pruned_count = to_prune.len();
        for &id in &to_prune {
            self.nodes[id].is_pruned = true;
            self.pruned_nodes_history.push(id);
        }

        // Desactivar racimos de hojas que estuvieran conectados a nodos podados
        for cluster in &mut self.leaf_clusters {
            if to_prune.contains(&cluster.parent_node_id) {
                cluster.is_active = false;
            }
        }

        // Desactivar yemas de los nodos podados
        self.buds.retain(|b| !to_prune.contains(&b.parent_node_id));

        // Respuesta biológica: aumentar vigor en el nodo padre si existe
        if let Some(parent_id) = self.nodes[target_node_id].parent_id {
            if parent_id < self.nodes.len() && !self.nodes[parent_id].is_pruned {
                self.nodes[parent_id].vigor += 0.25 * (pruned_count as f32);
                // Si el padre tiene yemas durmientes, despertar una yema axilar
                for bud in &mut self.buds {
                    if bud.parent_node_id == parent_id && bud.dormant {
                        bud.dormant = false;
                        bud.activation_age = self.current_age; // Brota de inmediato
                        break;
                    }
                }
            }
        }

        pruned_count
    }

    /// Retorna los segmentos activos (no podados).
    pub fn active_segments(&self) -> impl Iterator<Item = &NodeSegment> {
        self.nodes.iter().filter(|n| !n.is_pruned)
    }

    /// Retorna los racimos de hojas activos.
    pub fn active_clusters(&self) -> impl Iterator<Item = &LeafClusterNode> {
        self.leaf_clusters.iter().filter(|c| c.is_active)
    }

    /// Calcula la altura total actual del árbol en metros.
    pub fn current_height(&self) -> f32 {
        let mut max_y = 0.0f32;
        for node in self.active_segments() {
            max_y = max_y.max(node.start_pos.y).max(node.end_pos.y);
        }
        for cluster in self.active_clusters() {
            max_y = max_y.max(cluster.position.y + cluster.scale * 0.5);
        }
        max_y
    }
}

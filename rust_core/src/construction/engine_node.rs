use godot::classes::{
    BoxShape3D, CollisionShape3D, Mesh, MultiMesh, MultiMeshInstance3D, Node3D, StandardMaterial3D,
    StaticBody3D,
};
use godot::prelude::*;
use std::collections::HashMap;

use super::mesh_generator::ConstructionMeshGenerator;
use super::snapping::*;
use super::types::*;

/// Motor principal de construcción modular con GPU Hardware Instancing (`MultiMeshInstance3D`).
/// Diseñado para manejar miles de cubos, pisos, paredes y vanos consumiendo apenas 1 o 2 Draw Calls.
#[derive(GodotClass)]
#[class(init, base=Node3D)]
pub struct ConstructionEngine {
    base: Base<Node3D>,
    elements: HashMap<u64, BuildingElement>,
    next_id: u64,
    grid_step: f32,
    multimesh_containers: HashMap<(BuildingElementType, MaterialType), Gd<MultiMeshInstance3D>>,
    collision_body: Option<Gd<StaticBody3D>>,
    floor_spans: Vec<FloorSpan>,
    wall_spans: Vec<WallSpan>,
}

#[godot_api]
impl INode3D for ConstructionEngine {
    fn ready(&mut self) {
        godot_print!("[ConstructionEngine] Motor de construcción modular GPU instanced inicializado.");
    }
}

#[godot_api]
impl ConstructionEngine {
    /// Calcula el punto con snap según el modo (0: Piso/Techo XZ, 1: Pared).
    /// Completamente continuo: sigue el cursor con precisión fluida,
    /// garantizando estrictamente el mínimo de 1.0m por lado (sin saltos discretos).
    #[func]
    pub fn calc_snap_point(&self, origin: Vector3, ray_hit: Vector3, mode: i32) -> Vector3 {
        match mode {
            0 => {
                // Modo Piso/Techo: Desplazamiento continuo en plano XZ a altura constante Y
                snap_floor_point(origin, ray_hit, self.grid_step.max(1.0))
            }
            1 => {
                // Modo Pared: Desplazamiento continuo con longitud mínima de 1.0m
                let dist_x = ray_hit.x - origin.x;
                let dist_z = ray_hit.z - origin.z;
                let len = (dist_x * dist_x + dist_z * dist_z).sqrt();
                let (clamped_x, clamped_z) = if len < 1.0 {
                    if len > 0.001 {
                        (origin.x + (dist_x / len) * 1.0, origin.z + (dist_z / len) * 1.0)
                    } else {
                        (origin.x + 1.0, origin.z)
                    }
                } else {
                    (ray_hit.x, ray_hit.z)
                };

                let h = snap_wall_height(origin.y, ray_hit.y, self.grid_step.max(1.0), 1.0);
                Vector3::new(clamped_x, origin.y + h, clamped_z)
            }
            _ => snap_to_grid(ray_hit, self.grid_step.max(1.0)),
        }
    }

    /// Construye un tramo rectangular o lineal de piso entre p0 y p1 en el plano XZ.
    /// Retorna las posiciones mundiales de todos los bloques instanciados.
    #[func]
    pub fn add_floor_span(&mut self, p0: Vector3, p1: Vector3, material_idx: i32) -> PackedVector3Array {
        let mut placed = PackedVector3Array::new();
        let mat = MaterialType::from_i32(material_idx);
        let step = self.grid_step.max(1.0);

        let min_x = p0.x.min(p1.x);
        let max_x = p0.x.max(p1.x);
        let min_z = p0.z.min(p1.z);
        let max_z = p0.z.max(p1.z);
        let y_coord = p0.y;

        let total_w = (max_x - min_x).max(1.0);
        let total_d = (max_z - min_z).max(1.0);

        let count_x = (total_w / step).round().max(1.0) as i32;
        let count_z = (total_d / step).round().max(1.0) as i32;

        let step_x = total_w / count_x as f32;
        let step_z = total_d / count_z as f32;

        for ix in 0..count_x {
            for iz in 0..count_z {
                let w_pos = Vector3::new(
                    min_x + (ix as f32 + 0.5) * step_x,
                    y_coord + 0.02,
                    min_z + (iz as f32 + 0.5) * step_z,
                );
                let coord = GridCoord3D::from_vec3(w_pos);

                self.next_id += 1;
                let elem = BuildingElement {
                    id: self.next_id,
                    element_type: BuildingElementType::Floor,
                    grid_pos: coord,
                    world_pos: w_pos,
                    scale: Vector3::new(step_x, 1.0, step_z),
                    rotation_deg: 0.0,
                    material_type: mat,
                    is_built: mat != MaterialType::Frame,
                    custom_paint_id: 0,
                };

                self.elements.insert(elem.id, elem);
                placed.push(w_pos);
            }
        }

        self.floor_spans.push(FloorSpan::new(p0, p1));
        self.rebuild_multimeshes();
        placed
    }

    /// Construye una pared vertical entre p0 y p1 con la altura especificada.
    #[func]
    pub fn add_wall_span(&mut self, p0: Vector3, p1: Vector3, height: f32, material_idx: i32) -> PackedVector3Array {
        self.add_wall_span_with_openings(p0, p1, height, material_idx, Array::new())
    }

    /// Construye una pared vertical entre p0 y p1 integrando vanos de puertas y ventanas planificados previamente.
    #[func]
    pub fn add_wall_span_with_openings(
        &mut self,
        p0: Vector3,
        p1: Vector3,
        height: f32,
        material_idx: i32,
        openings: Array<Dictionary>,
    ) -> PackedVector3Array {
        let mut placed = PackedVector3Array::new();
        let mat = MaterialType::from_i32(material_idx);

        let dist_x = p1.x - p0.x;
        let dist_z = p1.z - p0.z;
        let length = (dist_x * dist_x + dist_z * dist_z).sqrt().max(1.0);
        let u_x = dist_x / length;
        let u_z = dist_z / length;

        let eff_height = height.max(1.0);
        let base_y = p0.y;
        let angle_rad = dist_z.atan2(dist_x);
        let rot_deg = -angle_rad.to_degrees();

        struct ParsedOpening {
            op_type: BuildingElementType,
            t_min: f32,
            t_max: f32,
            y_min: f32,
            y_max: f32,
        }

        let mut parsed: Vec<ParsedOpening> = Vec::new();
        for i in 0..openings.len() {
            if let Some(dict) = openings.get(i) {
                let op_type_val: i32 = dict.get("type").and_then(|v: Variant| v.try_to::<i32>().ok()).unwrap_or(3);
                let t_min: f32 = dict.get("t_min").and_then(|v: Variant| v.try_to::<f32>().ok()).unwrap_or(0.0).clamp(0.0, length);
                let t_max: f32 = dict.get("t_max").and_then(|v: Variant| v.try_to::<f32>().ok()).unwrap_or(1.0).clamp(0.0, length);
                let y_min: f32 = dict.get("y_bottom").and_then(|v: Variant| v.try_to::<f32>().ok()).unwrap_or(0.0).clamp(0.0, eff_height);
                let y_max: f32 = dict.get("y_top").and_then(|v: Variant| v.try_to::<f32>().ok()).unwrap_or(2.1).clamp(0.0, eff_height);

                if t_max > t_min + 0.1 && y_max > y_min + 0.1 {
                    parsed.push(ParsedOpening {
                        op_type: BuildingElementType::from_i32(op_type_val),
                        t_min,
                        t_max,
                        y_min,
                        y_max,
                    });
                }
            }
        }

        // 1. Instanciar todos los marcos de vanos (Puertas y Ventanas) planificados sin descartar ninguno
        for op in &parsed {
            let op_w = op.t_max - op.t_min;
            let op_h = op.y_max - op.y_min;
            let op_mid_t = op.t_min + op_w * 0.5;
            let op_wx = p0.x + u_x * op_mid_t;
            let op_wz = p0.z + u_z * op_mid_t;
            let frame_pos = Vector3::new(op_wx, base_y + op.y_min, op_wz);
            let frame_coord = GridCoord3D::from_vec3(frame_pos);

            self.next_id += 1;
            let elem = BuildingElement {
                id: self.next_id,
                element_type: op.op_type,
                grid_pos: frame_coord,
                world_pos: frame_pos,
                scale: Vector3::new(op_w, op_h, 1.0),
                rotation_deg: rot_deg,
                material_type: mat,
                is_built: mat != MaterialType::Frame,
                custom_paint_id: 0,
            };
            self.elements.insert(elem.id, elem);
            placed.push(frame_pos);
        }

        // 2. Descomposición 2D por sustracción booleana exacta (Guillotine Subtraction / Troquelado):
        // Partimos del rectángulo completo del muro [0, length] x [0, eff_height].
        // Cada vano (puerta, ventana, o combinaciones apiladas/múltiples) troquela su rectángulo,
        // garantizando matemáticamente cero huecos hacia el cielo y cero bloques colgantes o deformes.
        #[derive(Clone, Copy, Debug)]
        struct WallRect2D {
            t0: f32,
            t1: f32,
            y0: f32,
            y1: f32,
        }

        let mut solid_rects = vec![WallRect2D {
            t0: 0.0,
            t1: length,
            y0: 0.0,
            y1: eff_height,
        }];

        for op in &parsed {
            let ht0 = op.t_min.clamp(0.0, length);
            let ht1 = op.t_max.clamp(0.0, length);
            let hy0 = op.y_min.clamp(0.0, eff_height);
            let hy1 = op.y_max.clamp(0.0, eff_height);

            if ht1 <= ht0 + 0.005 || hy1 <= hy0 + 0.005 {
                continue;
            }

            let mut next_solids: Vec<WallRect2D> = Vec::new();

            for r in solid_rects {
                let ix0 = r.t0.max(ht0);
                let ix1 = r.t1.min(ht1);
                let iy0 = r.y0.max(hy0);
                let iy1 = r.y1.min(hy1);

                // Si no hay intersección con área positiva, el rectángulo se conserva intacto
                if ix1 <= ix0 + 0.005 || iy1 <= iy0 + 0.005 {
                    next_solids.push(r);
                    continue;
                }

                // Hay solape: troquelar r en hasta 4 piezas ortogonales disjuntas alrededor del hueco
                // 1. Pieza izquierda (columna a toda la altura de r)
                if ix0 - r.t0 > 0.005 {
                    next_solids.push(WallRect2D {
                        t0: r.t0,
                        t1: ix0,
                        y0: r.y0,
                        y1: r.y1,
                    });
                }

                // 2. Pieza derecha (columna a toda la altura de r)
                if r.t1 - ix1 > 0.005 {
                    next_solids.push(WallRect2D {
                        t0: ix1,
                        t1: r.t1,
                        y0: r.y0,
                        y1: r.y1,
                    });
                }

                // 3. Pieza inferior (antepecho / alféizar / dintel intermedio)
                if iy0 - r.y0 > 0.005 {
                    next_solids.push(WallRect2D {
                        t0: ix0,
                        t1: ix1,
                        y0: r.y0,
                        y1: iy0,
                    });
                }

                // 4. Pieza superior (dintel superior / viga sobre vano)
                if r.y1 - iy1 > 0.005 {
                    next_solids.push(WallRect2D {
                        t0: ix0,
                        t1: ix1,
                        y0: iy1,
                        y1: r.y1,
                    });
                }
            }

            solid_rects = next_solids;
        }

        // 3. Fusión de rectángulos contiguos para minimizar mallas y draw calls
        let mut merged = true;
        while merged {
            merged = false;
            'outer: for i in 0..solid_rects.len() {
                for j in (i + 1)..solid_rects.len() {
                    let a = solid_rects[i];
                    let b = solid_rects[j];

                    // Fusión horizontal: misma franja vertical Y y bordes T en contacto
                    if (a.y0 - b.y0).abs() < 0.005 && (a.y1 - b.y1).abs() < 0.005 {
                        if (a.t1 - b.t0).abs() < 0.005 {
                            solid_rects[i].t1 = b.t1;
                            solid_rects.swap_remove(j);
                            merged = true;
                            break 'outer;
                        } else if (b.t1 - a.t0).abs() < 0.005 {
                            solid_rects[i].t0 = b.t0;
                            solid_rects.swap_remove(j);
                            merged = true;
                            break 'outer;
                        }
                    }

                    // Fusión vertical: misma franja horizontal T y bordes Y en contacto
                    if (a.t0 - b.t0).abs() < 0.005 && (a.t1 - b.t1).abs() < 0.005 {
                        if (a.y1 - b.y0).abs() < 0.005 {
                            solid_rects[i].y1 = b.y1;
                            solid_rects.swap_remove(j);
                            merged = true;
                            break 'outer;
                        } else if (b.y1 - a.y0).abs() < 0.005 {
                            solid_rects[i].y0 = b.y0;
                            solid_rects.swap_remove(j);
                            merged = true;
                            break 'outer;
                        }
                    }
                }
            }
        }

        // 4. Instanciar los bloques de muro sólido generados
        for r in solid_rects {
            let seg_w = r.t1 - r.t0;
            let seg_h = r.y1 - r.y0;
            if seg_w < 0.005 || seg_h < 0.005 {
                continue;
            }

            let t_mid = r.t0 + seg_w * 0.5;
            let w_pos = Vector3::new(p0.x + u_x * t_mid, base_y + r.y0, p0.z + u_z * t_mid);
            let coord = GridCoord3D::from_vec3(w_pos);

            self.next_id += 1;
            let elem = BuildingElement {
                id: self.next_id,
                element_type: BuildingElementType::Wall,
                grid_pos: coord,
                world_pos: w_pos,
                scale: Vector3::new(seg_w, seg_h, 1.0),
                rotation_deg: rot_deg,
                material_type: mat,
                is_built: mat != MaterialType::Frame,
                custom_paint_id: 0,
            };
            self.elements.insert(elem.id, elem);
            placed.push(w_pos);
        }

        self.wall_spans.push(WallSpan::new(p0, p1, eff_height));
        self.rebuild_multimeshes();
        placed
    }

    /// Reemplaza una pared en `pos` por un vano (3: Puerta, 4: Ventana).
    #[func]
    pub fn add_opening(&mut self, pos: Vector3, opening_type: i32) -> bool {
        let mut closest_id = None;
        let mut min_d = 1.5 * 1.5;
        for elem in self.elements.values() {
            let d = elem.world_pos.distance_squared_to(pos);
            if d < min_d {
                min_d = d;
                closest_id = Some(elem.id);
            }
        }

        if let Some(id) = closest_id {
            if let Some(elem) = self.elements.get_mut(&id) {
                let new_type = BuildingElementType::from_i32(opening_type);
                elem.element_type = new_type;
                self.rebuild_multimeshes();
                return true;
            }
        }
        false
    }

    /// Elimina el elemento en `pos`.
    #[func]
    pub fn remove_element_at(&mut self, pos: Vector3) -> bool {
        let mut closest_id = None;
        let mut min_d = 1.5 * 1.5;
        for elem in self.elements.values() {
            let d = elem.world_pos.distance_squared_to(pos);
            if d < min_d {
                min_d = d;
                closest_id = Some(elem.id);
            }
        }

        if let Some(id) = closest_id {
            self.elements.remove(&id);
            self.rebuild_multimeshes();
            return true;
        }
        false
    }

    /// Aplica un material a la estructura en `pos`.
    /// Si es Frame (sin material definitivo), adopta `material_idx` y queda bloqueada a ese material.
    /// Si ya tiene un material asignado:
    /// - Si coincide: retorna 2 (progreso/confirmado).
    /// - Si es diferente: retorna -1 (bloqueada: no acepta otro material).
    #[func]
    pub fn apply_material_at(&mut self, pos: Vector3, material_idx: i32) -> i32 {
        let mut closest_id = None;
        let mut min_d = 1.5 * 1.5;
        for elem in self.elements.values() {
            let d = elem.world_pos.distance_squared_to(pos);
            if d < min_d {
                min_d = d;
                closest_id = Some(elem.id);
            }
        }

        if let Some(id) = closest_id {
            if let Some(elem) = self.elements.get_mut(&id) {
                let target_mat = MaterialType::from_i32(material_idx);
                if elem.material_type == MaterialType::Frame || !elem.is_built {
                    elem.material_type = target_mat;
                    elem.is_built = true;
                    self.rebuild_multimeshes();
                    return 1; // Material asignado con éxito
                } else if elem.material_type == target_mat {
                    return 2; // Ya tiene este material
                } else {
                    return -1; // Bloqueado: no acepta otro material
                }
            }
        }
        0 // No hay elemento en la posición
    }

    /// Retorna el tipo de material del elemento en `pos` (-1 si no existe, 5 si es Frame).
    #[func]
    pub fn get_element_material_at(&self, pos: Vector3) -> i32 {
        let mut closest = None;
        let mut min_d = 1.5 * 1.5;
        for elem in self.elements.values() {
            let d = elem.world_pos.distance_squared_to(pos);
            if d < min_d {
                min_d = d;
                closest = Some(elem.material_type.to_i32());
            }
        }
        closest.unwrap_or(-1)
    }

    /// Limpia todos los elementos construidos.
    #[func]
    pub fn clear_all(&mut self) {
        self.elements.clear();
        self.floor_spans.clear();
        self.wall_spans.clear();
        for container in self.multimesh_containers.values_mut() {
            container.queue_free();
        }
        self.multimesh_containers.clear();
        if let Some(mut body) = self.collision_body.take() {
            body.queue_free();
        }
    }

    /// Devuelve la cantidad total de bloques o paneles construidos en la escena.
    #[func]
    pub fn get_element_count(&self) -> i32 {
        self.elements.len() as i32
    }

    /// Devuelve la cantidad de elementos construidos según su tipo (0: Floor, 1: Wall, 2: Ceiling, 3: DoorFrame, 4: WindowFrame).
    #[func]
    pub fn get_element_count_by_type(&self, elem_type: i32) -> i32 {
        let target_type = BuildingElementType::from_i32(elem_type);
        self.elements.values().filter(|e| e.element_type == target_type).count() as i32
    }

    /// Registra manualmente un tramo rectangular de piso (p.ej. desde un PlannedSite).
    #[func]
    pub fn register_floor_span(&mut self, p0: Vector3, p1: Vector3) -> bool {
        self.floor_spans.push(FloorSpan::new(p0, p1));
        true
    }

    /// Retorna la lista de todos los tramos de piso registrados como Array de Diccionarios.
    #[func]
    pub fn get_floor_spans(&self) -> Array<Dictionary> {
        let mut arr = Array::new();
        for span in &self.floor_spans {
            let mut dict = Dictionary::new();
            dict.set("min_x", span.min_x);
            dict.set("max_x", span.max_x);
            dict.set("min_z", span.min_z);
            dict.set("max_z", span.max_z);
            dict.set("y", span.y);
            arr.push(&dict);
        }
        arr
    }

    /// Devuelve todos los tramos de pared registrados en el motor.
    #[func]
    pub fn get_wall_spans(&self) -> Array<Dictionary> {
        let mut arr = Array::new();
        for span in &self.wall_spans {
            let mut dict = Dictionary::new();
            dict.set("p0", span.p0);
            dict.set("p1", span.p1);
            dict.set("height", span.height);
            arr.push(&dict);
        }
        arr
    }

    /// Verifica si un punto está dentro o cerca de algún piso (con margen opcional).
    #[func]
    pub fn is_point_on_any_floor(&self, pos: Vector3, margin: f32) -> bool {
        for span in &self.floor_spans {
            if span.contains_xz(pos.x, pos.z, margin) {
                return true;
            }
        }
        false
    }

    /// Ancla un punto a la orilla del piso más cercano (Magnetic Edge Snapping)
    /// o a su superficie interior. Si no hay pisos o está fuera de alcance, retorna valid = false.
    #[func]
    pub fn snap_point_to_floor(&self, raw_pos: Vector3, edge_threshold: f32) -> Dictionary {
        let mut best_result: Option<FloorSnapResult> = None;
        let mut min_dist_sq = f32::MAX;
        let threshold = if edge_threshold > 0.0 { edge_threshold } else { 0.40 };

        for span in &self.floor_spans {
            let res = snap_point_to_floor_rect(
                raw_pos,
                span.min_x,
                span.max_x,
                span.min_z,
                span.max_z,
                span.y + 0.20, // Superficie superior del piso para apoyar la pared/puerta
                threshold,
                1.5,
            );

            if res.is_valid {
                let d_sq = (res.position.x - raw_pos.x).powi(2) + (res.position.z - raw_pos.z).powi(2);
                if d_sq < min_dist_sq {
                    min_dist_sq = d_sq;
                    best_result = Some(res);
                }
            }
        }

        let mut dict = Dictionary::new();
        if let Some(res) = best_result {
            dict.set("valid", true);
            dict.set("position", res.position);
            dict.set("is_on_edge", res.is_on_edge);
            dict.set("is_corner", res.is_corner);
            dict.set("edge_index", res.edge_index);
        } else {
            dict.set("valid", false);
            dict.set("position", raw_pos);
            dict.set("is_on_edge", false);
            dict.set("is_corner", false);
            dict.set("edge_index", -1);
        }
        dict
    }

    /// Ancla directamente contra un rectángulo de piso específico (p.ej. de un PlannedSite).
    #[func]
    pub fn snap_point_to_rect(
        &self,
        raw_pos: Vector3,
        min_x: f32,
        max_x: f32,
        min_z: f32,
        max_z: f32,
        floor_y: f32,
        edge_threshold: f32,
    ) -> Dictionary {
        let threshold = if edge_threshold > 0.0 { edge_threshold } else { 0.40 };
        let floor_surface_y = floor_y + 0.20; // Elevar a la cara superior del piso
        let res = snap_point_to_floor_rect(
            raw_pos,
            min_x,
            max_x,
            min_z,
            max_z,
            floor_surface_y,
            threshold,
            1.5,
        );

        let mut dict = Dictionary::new();
        dict.set("valid", res.is_valid);
        dict.set("position", res.position);
        dict.set("is_on_edge", res.is_on_edge);
        dict.set("is_corner", res.is_corner);
        dict.set("edge_index", res.edge_index);
        dict
    }

    /// Reconstruye los buffers de GPU Hardware Instancing (`MultiMeshInstance3D`).
    /// Agrupa todos los elementos por combinación (Tipo, Material) en 1 sola Draw Call por grupo.
    #[func]
    pub fn rebuild_multimeshes(&mut self) {
        // Agrupar datos de instancias por (Tipo, Material) desacoplados de self
        let mut groups: HashMap<(BuildingElementType, MaterialType), Vec<(Transform3D, u32)>> = HashMap::new();
        for elem in self.elements.values() {
            // Los vanos (DoorFrame y WindowFrame) son aperturas arquitectónicas limpias en el muro ("un cuadrado perfecto y ya").
            // La descomposición del muro perimetral ya conforma el dintel, jambas y antepecho limpios con su textura,
            // sin generar marcos cúbicos salientes que deformen o dividan la ventana en múltiples hoyos.
            if elem.element_type == BuildingElementType::DoorFrame || elem.element_type == BuildingElementType::WindowFrame {
                continue;
            }

            let mut transform = Transform3D::IDENTITY;
            if elem.rotation_deg.abs() > 0.001 {
                transform = transform.rotated(Vector3::UP, elem.rotation_deg.to_radians());
            }
            transform = transform.scaled(elem.scale);
            transform.origin = elem.world_pos;
            groups.entry((elem.element_type, elem.material_type))
                .or_default()
                .push((transform, elem.custom_paint_id));
        }

        // Limpiar a 0 instancias cualquier contenedor que no tenga elementos activos (p.ej. marcos de vanos anteriores)
        for (key, container) in &self.multimesh_containers {
            if !groups.contains_key(key) {
                if let Some(mut mm) = container.get_multimesh() {
                    mm.set_instance_count(0);
                }
            }
        }

        for ((elem_type, mat_type), instances) in groups {
            let container_opt = self.multimesh_containers.get(&(elem_type, mat_type)).cloned();

            let container = match container_opt {
                Some(c) => c,
                None => {
                    let mut new_c = MultiMeshInstance3D::new_alloc();
                    let mesh: Gd<Mesh> = match elem_type {
                        BuildingElementType::Floor | BuildingElementType::Ceiling => {
                            ConstructionMeshGenerator::create_unit_floor_mesh().upcast()
                        }
                        BuildingElementType::Wall => {
                            ConstructionMeshGenerator::create_unit_wall_mesh().upcast()
                        }
                        BuildingElementType::DoorFrame => {
                            ConstructionMeshGenerator::create_unit_door_frame_mesh().upcast()
                        }
                        BuildingElementType::WindowFrame => {
                            ConstructionMeshGenerator::create_unit_window_frame_mesh().upcast()
                        }
                    };

                    let mut mm = MultiMesh::new_gd();
                    mm.set_transform_format(godot::classes::multi_mesh::TransformFormat::TRANSFORM_3D);
                    mm.set_use_custom_data(true);
                    mm.set_mesh(&mesh);
                    new_c.set_multimesh(&mm);

                    // Material estilizado con desactivación de culling para visibilidad total
                    let mut mat = StandardMaterial3D::new_gd();
                    let (albedo, roughness) = match mat_type {
                        MaterialType::Wood => (Color::WHITE, 0.90),
                        MaterialType::Stone => (Color::from_rgb(0.50, 0.52, 0.55), 0.90),
                        MaterialType::Brick => (Color::from_rgb(0.68, 0.32, 0.22), 0.85),
                        MaterialType::Concrete => (Color::from_rgb(0.60, 0.60, 0.60), 0.90),
                        MaterialType::Metal => (Color::from_rgb(0.40, 0.42, 0.45), 0.40),
                        MaterialType::Frame => (Color::from_rgb(0.82, 0.70, 0.48), 0.75),
                    };
                    mat.set_albedo(albedo);
                    mat.set_roughness(roughness);
                    mat.set_cull_mode(godot::classes::base_material_3d::CullMode::DISABLED);

                    // Texturas de madera exclusivas cuando está construido por madera:
                    // - wood_wall.png para paredes (y marcos)
                    // - wood_floor.png para pisos y techos
                    if mat_type == MaterialType::Wood {
                        let tex_path = match elem_type {
                            BuildingElementType::Wall | BuildingElementType::DoorFrame | BuildingElementType::WindowFrame => {
                                "res://assets/building/wood_wall.png"
                            }
                            BuildingElementType::Floor | BuildingElementType::Ceiling => {
                                "res://assets/building/wood_floor.png"
                            }
                        };
                        let tex_res = try_load::<godot::classes::Texture2D>(tex_path);
                        let tex_opt: Option<Gd<godot::classes::Texture2D>> = match tex_res {
                            Ok(t) => Some(t),
                            Err(_) => {
                                let mut img = godot::classes::Image::new_gd();
                                if img.load(tex_path) == godot::global::Error::OK {
                                    godot::classes::ImageTexture::create_from_image(&img).map(|t| t.upcast())
                                } else {
                                    None
                                }
                            }
                        };
                        if let Some(tex) = tex_opt {
                            mat.set_texture(godot::classes::base_material_3d::TextureParam::ALBEDO, &tex);
                            mat.set_texture_filter(godot::classes::base_material_3d::TextureFilter::NEAREST);
                            mat.set_flag(godot::classes::base_material_3d::Flags::UV1_USE_TRIPLANAR, true);
                            mat.set_flag(godot::classes::base_material_3d::Flags::UV1_USE_WORLD_TRIPLANAR, true);
                            // Escala UV triplanar ampliada a 0.20 (~5x más grande, abarca 5 metros por repetición)
                            // para que la madera presente vetas y tablones monumentales y legibles con estética PSX pura.
                            let uv_scale = match elem_type {
                                BuildingElementType::Wall | BuildingElementType::DoorFrame | BuildingElementType::WindowFrame => {
                                    Vector3::new(0.20, 0.20, 0.20)
                                }
                                BuildingElementType::Floor | BuildingElementType::Ceiling => {
                                    Vector3::new(0.20, 0.20, 0.20)
                                }
                            };
                            mat.set_uv1_scale(uv_scale);
                        }
                    }

                    new_c.set_material_override(&mat);

                    self.base_mut().add_child(&new_c);
                    self.multimesh_containers.insert((elem_type, mat_type), new_c.clone());
                    new_c
                }
            };

            if let Some(mut mm) = container.get_multimesh() {
                mm.set_instance_count(instances.len() as i32);
                for (idx, (transform, paint_id)) in instances.iter().enumerate() {
                    mm.set_instance_transform(idx as i32, *transform);

                    // Buffer CUSTOM_DATA para recibir colores/identificadores de pintura en el futuro
                    let custom_color = Color::from_rgba(1.0, 1.0, 1.0, *paint_id as f32 / 255.0);
                    mm.set_instance_custom_data(idx as i32, custom_color);
                }
            }
        }

        // Reconstruir colisiones estáticas para que el raycast y el jugador interactúen con las estructuras
        if let Some(mut old_body) = self.collision_body.take() {
            old_body.queue_free();
        }

        if !self.elements.is_empty() {
            let mut body = StaticBody3D::new_alloc();
            body.set_collision_layer_value(1, true);

            for elem in self.elements.values() {
                let mut col = CollisionShape3D::new_alloc();
                let mut box_shape = BoxShape3D::new_gd();

                let (base_size, offset_y, has_col) = match elem.element_type {
                    BuildingElementType::Floor | BuildingElementType::Ceiling => {
                        (Vector3::new(1.0, 0.20, 1.0), 0.10, true)
                    }
                    BuildingElementType::Wall => {
                        (Vector3::new(1.0, 1.0, 0.20), 0.50 * elem.scale.y, true)
                    }
                    BuildingElementType::DoorFrame | BuildingElementType::WindowFrame => {
                        // Los vanos de puerta y ventana son huecos transitables; los muros perimetrales circundantes
                        // ya aportan la colisión física sólida alrededor del vano.
                        (Vector3::ZERO, 0.0, false)
                    }
                };

                if has_col {
                    let scaled_size = Vector3::new(
                        base_size.x * elem.scale.x,
                        base_size.y * elem.scale.y,
                        base_size.z * elem.scale.z,
                    );
                    box_shape.set_size(scaled_size);
                    col.set_shape(&box_shape);

                    let mut trans = Transform3D::IDENTITY;
                    if elem.rotation_deg.abs() > 0.001 {
                        trans = trans.rotated(Vector3::UP, elem.rotation_deg.to_radians());
                    }
                    trans.origin = elem.world_pos + Vector3::new(0.0, offset_y, 0.0);
                    col.set_transform(trans);

                    body.add_child(&col);
                }
            }

            self.base_mut().add_child(&body);
            self.collision_body = Some(body);
        }
    }
}

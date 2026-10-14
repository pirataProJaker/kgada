use godot::prelude::*;
use godot::classes::{BoxMesh, MultiMesh};
use godot::classes::multi_mesh::TransformFormat;
use super::generator::FacilityGeneratorCore;
use super::mesher::FacilityMesher;
use super::types::*;

/// Motor procedural de complejos fortificados, bases militares e instalaciones industriales en Rust.
/// Expuesto a Godot vía GDExtension como `FacilityEngine`.
/// Arquitectura 100% GPU Instanced (+0 Draw Calls por tipo de superficie).
#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct FacilityEngine {
    base: Base<Node>,
}

#[godot_api]
impl INode for FacilityEngine {
    fn ready(&mut self) {
        godot_print!("[FacilityEngine] Motor nativo de complejos e instalaciones militares (Rust GDExtension) inicializado.");
    }
}

#[godot_api]
impl FacilityEngine {
    /// Genera un complejo completo (base militar, planta nuclear, etc.) a partir de sus dimensiones
    /// en metros, el tipo de instalación y la semilla procedural.
    #[func]
    pub fn generate_facility(
        &self,
        width_m: f32,
        depth_m: f32,
        facility_type: i32,
        seed_val: i64,
    ) -> VarDictionary {
        let f_type = FacilityType::from_i32(facility_type);
        let seed = if seed_val == 0 { 54321 } else { seed_val as u64 };

        let blueprint = FacilityGeneratorCore::generate(width_m, depth_m, f_type, seed);
        let meshing = FacilityMesher::build(&blueprint);

        let ground_mm = Self::build_multimesh(&meshing.ground_boxes);
        let perimeter_mm = Self::build_multimesh(&meshing.perimeter_boxes);
        let structures_mm = Self::build_multimesh(&meshing.structure_boxes);

        // Cajas de colisión física para el StaticBody3D instantáneo
        let mut col_array = VarArray::new();
        for b in &meshing.collision_boxes {
            let mut dict = VarDictionary::new();
            dict.set("position", b.position.to_variant());
            dict.set("size", b.size.to_variant());
            col_array.push(&dict.to_variant());
        }

        // Props tácticos para instanciar mediante ObjectEngine
        let mut props_array = VarArray::new();
        for p in &blueprint.props {
            let mut dict = VarDictionary::new();
            dict.set("recipe", p.recipe_name.to_variant());
            dict.set("position", p.position.to_variant());
            dict.set("rotation_y", p.rotation_y.to_variant());
            props_array.push(&dict.to_variant());
        }

        // Estructuras colocadas
        let mut structures_array = VarArray::new();
        for s in &blueprint.structures {
            let mut dict = VarDictionary::new();
            dict.set("id", s.id.to_variant());
            dict.set("kind", (s.kind as i32).to_variant());
            dict.set("name", s.kind.display_name().to_variant());
            dict.set("position", s.world_pos.to_variant());
            dict.set("size", s.world_size.to_variant());
            dict.set("rotation_y", s.rotation_y.to_variant());
            structures_array.push(&dict.to_variant());
        }

        // Puntos de calcomanías para WallDecalSystem
        let mut decals_array = VarArray::new();
        for d in &blueprint.decals {
            let mut dict = VarDictionary::new();
            dict.set("position", d.position.to_variant());
            dict.set("normal", d.normal.to_variant());
            dict.set("size", d.size.to_variant());
            dict.set("category", d.category.to_variant());
            dict.set("style_id", (d.style_id as i32).to_variant());
            decals_array.push(&dict.to_variant());
        }

        let mut result = VarDictionary::new();
        if let Some(mm) = ground_mm {
            result.set("ground_multimesh", mm.to_variant());
        }
        if let Some(mm) = perimeter_mm {
            result.set("perimeter_multimesh", mm.to_variant());
        }
        if let Some(mm) = structures_mm {
            result.set("structures_multimesh", mm.to_variant());
        }

        result.set("collision_boxes", col_array.to_variant());
        result.set("placed_props", props_array.to_variant());
        result.set("placed_structures", structures_array.to_variant());
        result.set("decals", decals_array.to_variant());
        result.set("checkpoint_gate", blueprint.checkpoint_gate.to_variant());

        if let Some(bunker_pos) = blueprint.bunker_entrance {
            result.set("bunker_entrance", bunker_pos.to_variant());
        }

        result.set("width_m", blueprint.width_m.to_variant());
        result.set("depth_m", blueprint.depth_m.to_variant());
        result.set("facility_type", (blueprint.facility_type as i32).to_variant());

        result
    }

    /// Construye un MultiMesh de Godot a partir de una lista de InstanceBox (cubos sólidos con color).
    fn build_multimesh(boxes: &[InstanceBox]) -> Option<Gd<MultiMesh>> {
        if boxes.is_empty() {
            return None;
        }

        let mut box_mesh = BoxMesh::new_gd();
        box_mesh.set_size(Vector3::new(1.0, 1.0, 1.0));

        let mut mm = MultiMesh::new_gd();
        mm.set_transform_format(TransformFormat::TRANSFORM_3D);
        mm.set_use_colors(true);
        mm.set_mesh(&box_mesh);
        mm.set_instance_count(boxes.len() as i32);

        for (i, b) in boxes.iter().enumerate() {
            let basis = Basis::from_cols(
                Vector3::new(b.size.x, 0.0, 0.0),
                Vector3::new(0.0, b.size.y, 0.0),
                Vector3::new(0.0, 0.0, b.size.z),
            );
            let transform = Transform3D::new(basis, b.position);
            mm.set_instance_transform(i as i32, transform);
            mm.set_instance_color(i as i32, b.color);
        }

        Some(mm)
    }
}

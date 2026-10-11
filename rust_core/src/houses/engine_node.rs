use godot::prelude::*;
use godot::classes::{BoxMesh, MultiMesh};
use godot::classes::multi_mesh::TransformFormat;
use super::generator::HouseGeneratorCore;
use super::mesher::HouseMesher;
use super::types::*;

/// Motor procedural de casas en cuadrícula modular de 1m x 1m en Rust.
/// Expuesto a Godot vía GDExtension como `ProceduralHouseEngine`.
/// Arquitectura 100% GPU Instanced (MultiMeshInstance3D con cubos 3D sólidos).
#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct ProceduralHouseEngine {
    base: Base<Node>,
}

#[godot_api]
impl INode for ProceduralHouseEngine {
    fn ready(&mut self) {
        godot_print!("[ProceduralHouseEngine] Motor procedural de casas en cuadrícula de 1m (GPU Instancing) inicializado.");
    }
}

#[godot_api]
impl ProceduralHouseEngine {
    /// Genera la casa completa a partir de las dimensiones del lote en metros enteros,
    /// la tipología de zona y la semilla.
    /// Retorna los MultiMesh listos para instanciar en GPU en 1 solo Draw Call.
    #[func]
    pub fn generate_house(
        &self,
        width: i32,
        depth: i32,
        zone_type: i32,
        seed_val: i64,
        show_roofs: bool,
    ) -> VarDictionary {
        let w = (width as usize).max(4);
        let d = (depth as usize).max(6);
        let zone = HouseZoneType::from_i32(zone_type);
        let seed = if seed_val == 0 { 12345 } else { seed_val as u64 };

        let blueprint = HouseGeneratorCore::generate(w, d, zone, seed);
        let meshing = HouseMesher::build_mesh(&blueprint, show_roofs);

        let ext_walls_mm = Self::build_multimesh(&meshing.walls_ext);
        let solid_boxes = meshing.solid_interior_and_structure_boxes();
        let solid_mm = Self::build_multimesh(&solid_boxes);
        let glass_mm = Self::build_multimesh(&meshing.glass);
        let columns_mm = Self::build_multimesh(&meshing.columns);

        // Cajas de colisión física para armar el StaticBody3D instantáneo
        let mut col_array = VarArray::new();
        for b in &meshing.collision_boxes {
            let mut dict = VarDictionary::new();
            dict.set("position", b.position.to_variant());
            dict.set("size", b.size.to_variant());
            col_array.push(&dict.to_variant());
        }

        let mut result = VarDictionary::new();
        if let Some(mm) = ext_walls_mm {
            result.set("ext_walls_multimesh", mm.to_variant());
        }
        if let Some(mm) = solid_mm {
            result.set("solid_multimesh", mm.to_variant());
        }
        if let Some(mm) = glass_mm {
            result.set("glass_multimesh", mm.to_variant());
        }
        if let Some(mm) = columns_mm {
            result.set("columns_multimesh", mm.to_variant());
        }

        result.set("collision_boxes", col_array.to_variant());

        // Puertas texturizadas para instanciar como WoodenDoor en Godot
        let mut doors_array = VarArray::new();
        for d in &meshing.doors {
            let mut dict = VarDictionary::new();
            dict.set("position", d.position.to_variant());
            dict.set("size", d.size.to_variant());
            dict.set("rotation_y", d.rotation_y.to_variant());
            dict.set("style_id", (d.style_id as i32).to_variant());
            dict.set("is_main", d.is_main.to_variant());
            doors_array.push(&dict.to_variant());
        }
        result.set("doors", doors_array.to_variant());

        // Ventanas exteriores para protecciones procedurales de herrería
        let mut windows_array = VarArray::new();
        for w in &meshing.windows {
            let mut dict = VarDictionary::new();
            dict.set("position", w.position.to_variant());
            dict.set("size", w.size.to_variant());
            dict.set("normal", w.normal.to_variant());
            dict.set("floor", (w.floor as i32).to_variant());
            windows_array.push(&dict.to_variant());
        }
        result.set("windows", windows_array.to_variant());


        // Sistema centralizado de detalles y defectos de pared (WallDetailSystem)
        let mut details_array = VarArray::new();
        for d in &meshing.wall_details {
            let mut dict = VarDictionary::new();
            dict.set("category", d.category.to_variant());
            dict.set("style_id", (d.style_id as i32).to_variant());
            dict.set("position", d.position.to_variant());
            dict.set("normal", d.normal.to_variant());
            dict.set("size", d.size.to_variant());
            dict.set("layer", (d.layer as i32).to_variant());
            dict.set("tilt", d.tilt.to_variant());
            dict.set("flip_h", d.flip_h.to_variant());
            dict.set("flip_v", d.flip_v.to_variant());
            dict.set("is_small", d.is_small.to_variant());
            details_array.push(&dict.to_variant());
        }
        result.set("wall_details", details_array.to_variant());

        result.set("solid_box_count", (solid_boxes.len() as i32).to_variant());
        result.set("glass_box_count", (meshing.glass.len() as i32).to_variant());
        result.set("width", (w as f32).to_variant());
        result.set("depth", (d as f32).to_variant());
        result.set("floors", (blueprint.total_floors as i32).to_variant());
        result.set("has_terrace", blueprint.has_terrace.to_variant());
        result.set("built_cells", (blueprint.grid.built_ground_cells() as i32).to_variant());
        result.set("floor2_cells", (blueprint.grid.floor2_cells() as i32).to_variant());

        // Metadatos de Escalera Normalizada (StairData)
        if let Some(stair) = blueprint.stair {
            let mut stair_dict = VarDictionary::new();
            stair_dict.set("type", (stair.stair_type as i32).to_variant());
            stair_dict.set("x", (stair.x as f32).to_variant());
            stair_dict.set("z", (stair.z as f32).to_variant());
            stair_dict.set("width", (stair.width as f32).to_variant());
            stair_dict.set("length", (stair.length as f32).to_variant());
            stair_dict.set("orientation", (stair.orientation as i32).to_variant());
            result.set("stair", stair_dict.to_variant());
        }

        // Jerarquía de Reclamación: Habitaciones interiores reclamadas
        let mut rooms_array = VarArray::new();
        for r in &blueprint.rooms {
            let mut dict = VarDictionary::new();
            dict.set("id", (r.id as i32).to_variant());
            dict.set("name", r.room_type.name_es().to_variant());
            dict.set("floor", (r.floor as i32).to_variant());
            dict.set("x_min", (r.x_min as i32).to_variant());
            dict.set("z_min", (r.z_min as i32).to_variant());
            dict.set("x_max", (r.x_max as i32).to_variant());
            dict.set("z_max", (r.z_max as i32).to_variant());
            rooms_array.push(&dict.to_variant());
        }
        result.set("rooms", rooms_array.to_variant());

        let mut b_f1 = PackedByteArray::new();
        for &b in &blueprint.room_map_floor1 {
            b_f1.push(b);
        }
        result.set("room_map_floor1", b_f1.to_variant());

        let mut b_f2 = PackedByteArray::new();
        for &b in &blueprint.room_map_floor2 {
            b_f2.push(b);
        }
        result.set("room_map_floor2", b_f2.to_variant());

        // Paleta de colores calculada para aplicar shaders o materiales estándar
        let mut pal_dict = VarDictionary::new();
        pal_dict.set("wall_ext", blueprint.palette.wall_ext.to_variant());
        pal_dict.set("wall_int", blueprint.palette.wall_int.to_variant());
        pal_dict.set("floor", blueprint.palette.floor.to_variant());
        pal_dict.set("roof", blueprint.palette.roof.to_variant());
        pal_dict.set("trim", blueprint.palette.trim.to_variant());
        pal_dict.set("door", blueprint.palette.door.to_variant());
        pal_dict.set("window_frame", blueprint.palette.window_frame.to_variant());
        pal_dict.set("window_glass", blueprint.palette.window_glass.to_variant());
        pal_dict.set("tinaco", blueprint.palette.tinaco.to_variant());
        result.set("palette", pal_dict.to_variant());

        // Metadatos comerciales de tiendas y negocios (CommercialConvenience)
        if let Some(comm) = &blueprint.commercial_meta {
            let mut comm_dict = VarDictionary::new();

            let mut bays_arr = VarArray::new();
            for bay in &comm.parking_bays {
                let mut bd = VarDictionary::new();
                bd.set("position", bay.position.to_variant());
                bd.set("size", bay.size.to_variant());
                bd.set("rotation_y", bay.rotation_y.to_variant());
                bays_arr.push(&bd.to_variant());
            }
            comm_dict.set("parking_bays", bays_arr.to_variant());

            if let Some(totem) = &comm.totem_sign {
                let mut td = VarDictionary::new();
                td.set("position", totem.position.to_variant());
                td.set("height", totem.height.to_variant());
                td.set("rotation_y", totem.rotation_y.to_variant());
                comm_dict.set("totem_sign", td.to_variant());
            }

            let mut signs_arr = VarArray::new();
            for s in &comm.fascia_signs {
                let mut sd = VarDictionary::new();
                sd.set("position", s.position.to_variant());
                sd.set("size", s.size.to_variant());
                sd.set("rotation_y", s.rotation_y.to_variant());
                signs_arr.push(&sd.to_variant());
            }
            comm_dict.set("fascia_signs", signs_arr.to_variant());

            let mut bollards_arr = VarArray::new();
            for &bol in &comm.bollards {
                bollards_arr.push(&bol.to_variant());
            }
            comm_dict.set("bollards", bollards_arr.to_variant());

            if let Some(ice) = comm.ice_freezer {
                comm_dict.set("ice_freezer", ice.to_variant());
            }
            if let Some(trash) = comm.trash_bin {
                comm_dict.set("trash_bin", trash.to_variant());
            }

            comm_dict.set("lateral_parking_side", (comm.lateral_parking_side as i32).to_variant());
            comm_dict.set("has_lateral_showcase", comm.has_lateral_showcase.to_variant());
            comm_dict.set("entrance_type", (comm.entrance_type as i32).to_variant());

            result.set("commercial", comm_dict.to_variant());
        }

        result.set("zone_type", (blueprint.zone as i32).to_variant());

        result
    }

    /// Construye un MultiMesh de Godot a partir de una lista de InstanceBox (cubos sólidos).
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

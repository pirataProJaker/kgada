pub mod types;
pub mod generator;
pub mod mesher;
pub mod engine_node;
pub mod wall_details;

pub use engine_node::ProceduralHouseEngine;
pub use generator::{HouseBlueprint, HouseGeneratorCore};
pub use mesher::{HouseMesher, HouseMeshingResult};
pub use wall_details::*;
pub use types::*;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_stair_generation_2story() {
        let mut total_2story = 0;
        let mut with_stairs = 0;

        for seed in 1000..1050 {
            let bp = HouseGeneratorCore::generate(10, 16, HouseZoneType::ColoniaVieja, seed);
            if bp.total_floors >= 2 {
                total_2story += 1;
                if let Some(stair) = bp.stair {
                    with_stairs += 1;
                    let has_connector = bp.rooms.iter().any(|r| {
                        r.floor == 2 && (r.room_type == RoomType::Hallway || r.room_type == RoomType::LivingRoom)
                    });
                    assert!(has_connector, "Debe haber un distribuidor/sala en piso 2");
                    assert!(stair.x + stair.width <= 10);
                    assert!(stair.z + stair.length <= 16);
                }
            }
        }
        assert!(total_2story > 0);
        assert!(with_stairs > 0);
    }

    #[test]
    fn test_commercial_convenience_otxo() {
        for seed in 2000..2020 {
            // Probar lote estándar (14x16)
            let bp1 = HouseGeneratorCore::generate(14, 16, HouseZoneType::CommercialConvenience, seed);
            assert_eq!(bp1.total_floors, 1);
            assert!(bp1.commercial_meta.is_some());
            let meta1 = bp1.commercial_meta.as_ref().unwrap();
            assert!(!meta1.parking_bays.is_empty(), "Debe tener cajones de estacionamiento");
            assert!(meta1.totem_sign.is_some(), "Debe tener tótem gigante exterior");
            assert!(!meta1.fascia_signs.is_empty(), "Debe tener letrero de fachada");
            assert!(!meta1.bollards.is_empty(), "Debe tener bolardos protectores");
            assert!(bp1.rooms.iter().any(|r| r.room_type == RoomType::StoreFloor), "Debe tener piso de venta");
            assert!(bp1.rooms.iter().any(|r| r.room_type == RoomType::ColdRoom), "Debe tener cuarto frío");
            assert!(bp1.rooms.iter().any(|r| r.room_type == RoomType::Storage), "Debe tener bodega");

            let mesh1 = HouseMesher::build_mesh(&bp1, true);
            assert!(!mesh1.walls_ext.is_empty());
            assert!(!mesh1.glass.is_empty(), "Debe tener ventanales de cristal al frente");
            assert!(!mesh1.doors.is_empty(), "Debe tener puerta de acceso");

            // Probar lote grande en esquina (18x18)
            let bp2 = HouseGeneratorCore::generate(18, 18, HouseZoneType::CommercialConvenience, seed);
            assert_eq!(bp2.total_floors, 1);
            let meta2 = bp2.commercial_meta.as_ref().unwrap();
            assert!(meta2.parking_bays.len() >= 3);
            let mesh2 = HouseMesher::build_mesh(&bp2, true);
            assert!(!mesh2.walls_ext.is_empty());
        }
    }
}


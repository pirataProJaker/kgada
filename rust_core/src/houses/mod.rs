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
}

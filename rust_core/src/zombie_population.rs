use godot::prelude::*;
use std::collections::HashMap;

const DEFAULT_SECTOR_SIZE: f32 = 80.0;

#[derive(Clone, Copy, Default)]
struct SectorPopulation {
    zombies: i32,
    revision: i32,
    state: i32,
    migration: Vector2,
    noise_position: Vector3,
    noise_strength: f32,
    noise_remaining: f32,
}

#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct ZombiePopulation {
    base: Base<Node>,
    sectors: HashMap<(i32, i32), SectorPopulation>,
    sector_size: f32,
    world_seed: i32,
    revision: i32,
}

#[godot_api]
impl ZombiePopulation {
    #[func]
    fn configure(&mut self, sector_size: f32, world_seed: i32) {
        if sector_size.is_finite() && sector_size > 0.0 {
            self.sector_size = sector_size;
        }
        self.world_seed = world_seed;
    }

    #[func]
    fn get_sector_size(&self) -> f32 {
        if self.sector_size > 0.0 {
            self.sector_size
        } else {
            DEFAULT_SECTOR_SIZE
        }
    }

    #[func]
    fn world_to_sector(&self, world_position: Vector3) -> Vector2i {
        let sector_size = self.get_sector_size();
        Vector2i::new(
            (world_position.x / sector_size).floor() as i32,
            (world_position.z / sector_size).floor() as i32,
        )
    }

    #[func]
    fn set_sector_population(&mut self, sector_x: i32, sector_z: i32, count: i32) {
        let key = (sector_x, sector_z);
        let count = count.max(0);
        if count == 0 {
            self.sectors.remove(&key);
            self.next_revision();
            return;
        }

        let revision = self.next_revision();
        self.sectors.insert(
            key,
            SectorPopulation {
                zombies: count,
                revision,
                ..Default::default()
            },
        );
    }

    #[func]
    fn add_sector_population(&mut self, sector_x: i32, sector_z: i32, amount: i32) {
        if amount <= 0 {
            return;
        }

        let key = (sector_x, sector_z);
        let revision = self.next_revision();
        let sector = self.sectors.entry(key).or_default();
        sector.zombies = sector.zombies.saturating_add(amount);
        sector.revision = revision;
    }

    #[func]
    fn remove_sector_population(&mut self, sector_x: i32, sector_z: i32, amount: i32) -> i32 {
        if amount <= 0 {
            return 0;
        }

        let key = (sector_x, sector_z);
        let Some(current_count) = self.sectors.get(&key).map(|sector| sector.zombies) else {
            return 0;
        };

        let removed = current_count.min(amount);
        let revision = self.next_revision();
        let remaining = if let Some(sector) = self.sectors.get_mut(&key) {
            sector.zombies -= removed;
            sector.revision = revision;
            sector.zombies
        } else {
            return 0;
        };
        if remaining == 0 {
            self.sectors.remove(&key);
        }
        removed
    }

    #[func]
    fn get_sector_population(&self, sector_x: i32, sector_z: i32) -> i32 {
        self.sectors
            .get(&(sector_x, sector_z))
            .map_or(0, |sector| sector.zombies)
    }

    #[func]
    fn set_sector_aggregate_state(
        &mut self,
        sector_x: i32,
        sector_z: i32,
        state: i32,
        migration: Vector2,
    ) {
        let key = (sector_x, sector_z);
        let revision = self.next_revision();
        let sector = self.sectors.entry(key).or_default();
        sector.state = state;
        sector.migration = migration;
        sector.revision = revision;
    }

    #[func]
    fn report_sector_noise(
        &mut self,
        sector_x: i32,
        sector_z: i32,
        noise_position: Vector3,
        strength: f32,
        duration: f32,
    ) {
        let key = (sector_x, sector_z);
        let revision = self.next_revision();
        let sector = self.sectors.entry(key).or_default();
        sector.noise_position = noise_position;
        sector.noise_strength = sector.noise_strength.max(strength.max(0.0));
        sector.noise_remaining = sector.noise_remaining.max(duration.max(0.0));
        sector.state = 1;
        sector.revision = revision;
    }

    #[func]
    fn advance(&mut self, delta: f32) {
        let delta = delta.max(0.0);
        let mut changed = false;
        for sector in self.sectors.values_mut() {
            let previous_remaining = sector.noise_remaining;
            let previous_strength = sector.noise_strength;
            sector.noise_remaining = (sector.noise_remaining - delta).max(0.0);
            if sector.noise_remaining <= 0.0 {
                sector.noise_strength = 0.0;
            }
            changed |= (previous_remaining - sector.noise_remaining).abs() > f32::EPSILON;
            changed |= (previous_strength - sector.noise_strength).abs() > f32::EPSILON;
        }
        if changed {
            let revision = self.next_revision();
            for sector in self.sectors.values_mut() {
                sector.revision = revision;
            }
        }
    }

    #[func]
    fn get_total_population(&self) -> i32 {
        self.sectors
            .values()
            .fold(0, |total, sector| total.saturating_add(sector.zombies))
    }

    #[func]
    fn get_sector_count(&self) -> i32 {
        self.sectors.len().try_into().unwrap_or(i32::MAX)
    }

    #[func]
    fn get_sector_seed(&self, sector_x: i32, sector_z: i32) -> i32 {
        let mut hash = self.world_seed as u32;
        hash = hash.wrapping_mul(1_664_525).wrapping_add(sector_x as u32);
        hash = hash.wrapping_mul(1_664_525).wrapping_add(sector_z as u32);
        hash = hash.wrapping_mul(1_664_525).wrapping_add(1_013_904_223);
        hash as i32
    }

    #[func]
    fn get_sector_snapshot(&self, sector_x: i32, sector_z: i32) -> VarDictionary {
        let mut snapshot = VarDictionary::new();
        let sector = self.sectors.get(&(sector_x, sector_z));
        snapshot.set("sector_x", sector_x);
        snapshot.set("sector_z", sector_z);
        snapshot.set("count", sector.map_or(0, |value| value.zombies));
        snapshot.set("revision", sector.map_or(0, |value| value.revision));
        snapshot.set("seed", self.get_sector_seed(sector_x, sector_z));
        snapshot.set("sector_size", self.get_sector_size());
        snapshot.set("state", sector.map_or(0, |value| value.state));
        snapshot.set(
            "migration",
            sector.map_or(Vector2::ZERO, |value| value.migration),
        );
        snapshot.set(
            "noise_position",
            sector.map_or(Vector3::ZERO, |value| value.noise_position),
        );
        snapshot.set(
            "noise_strength",
            sector.map_or(0.0, |value| value.noise_strength),
        );
        snapshot.set(
            "noise_remaining",
            sector.map_or(0.0, |value| value.noise_remaining),
        );
        snapshot
    }

    #[func]
    fn get_revision(&self) -> i32 {
        self.revision
    }

    #[func]
    fn clear(&mut self) {
        self.sectors.clear();
        self.next_revision();
    }
}

impl ZombiePopulation {
    fn next_revision(&mut self) -> i32 {
        self.revision = self.revision.wrapping_add(1).max(1);
        self.revision
    }
}

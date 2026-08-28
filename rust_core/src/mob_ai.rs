use godot::prelude::*;
use rand::Rng;

/// IA simple de "vagabundeo" (wander) para mobs animales (perro, etc.).
/// Corre en Rust porque el plan es tener muchos mobs simultaneos en el
/// mundo y esta logica se llama una vez por frame por cada uno - GDScript
/// puro seria mas lento a gran escala.
///
/// Fase inicial: solo elige una direccion horizontal aleatoria y la
/// mantiene un rato antes de cambiar, dando un movimiento organico sin
/// pathfinding real (no evita obstaculos todavia - eso es una fase
/// posterior si se necesita). El GDScript dueño (Dog.gd) es responsable de
/// aplicar gravedad, detectar suelo y mover el CharacterBody3D con el
/// vector que devuelve `tick`.
#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct DogAi {
    base: Base<Node>,
    direction: Vector3,
    timer: f32,
    speed: f32,
}

#[godot_api]
impl DogAi {
    /// GDScript llama esto una vez despues de instanciar, antes del primer
    /// `tick`, para fijar la velocidad de vagabundeo de este mob.
    #[func]
    fn set_speed(&mut self, speed: f32) {
        self.speed = speed;
    }

    /// Se llama una vez por frame de fisica desde GDScript. Devuelve la
    /// velocidad horizontal deseada (Y siempre 0.0 - la gravedad/suelo la
    /// maneja el GDScript). Cambia de direccion cada 2-5 segundos.
    #[func]
    fn tick(&mut self, delta: f32) -> Vector3 {
        self.timer -= delta;
        if self.timer <= 0.0 {
            let mut rng = rand::thread_rng();
            self.timer = rng.gen_range(2.0..5.0);
            let angle: f32 = rng.gen_range(0.0..std::f32::consts::TAU);
            self.direction = Vector3::new(angle.cos(), 0.0, angle.sin());
        }
        self.direction * self.speed
    }
}

const ZOMBIE_IDLE: i32 = 0;
const ZOMBIE_WANDER: i32 = 1;
const ZOMBIE_INVESTIGATE: i32 = 2;
const ZOMBIE_CHASE: i32 = 3;
const ZOMBIE_ATTACK: i32 = 4;
const ZOMBIE_LAST_SEEN_MEMORY: f32 = 4.0;
const ZOMBIE_NOISE_MEMORY: f32 = 3.0;
const ZOMBIE_ATTACK_DISTANCE: f32 = 1.55;
const ZOMBIE_ATTACK_COOLDOWN: f32 = 1.6;
const ZOMBIE_ATTACK_DURATION: f32 = 0.8;
const ZOMBIE_STATE_CHANGE_COOLDOWN: f32 = 0.25;

#[derive(GodotClass)]
#[class(init, base=Node)]
pub struct ZombieAi {
    base: Base<Node>,
    speed: f32,
    state: i32,
    state_timer: f32,
    attack_cooldown: f32,
    state_change_cooldown: f32,
    direction: Vector3,
    self_position: Vector3,
    target_position: Vector3,
    target_visible: bool,
    last_seen_position: Vector3,
    last_seen_timer: f32,
    noise_position: Vector3,
    noise_timer: f32,
    random_state: u32,
}

#[godot_api]
impl ZombieAi {
    #[func]
    fn set_speed(&mut self, speed: f32) {
        self.speed = speed.max(0.0);
    }

    #[func]
    fn set_seed(&mut self, seed: i32) {
        self.random_state = (seed as u32).wrapping_add(1);
        if self.random_state == 0 {
            self.random_state = 1;
        }
        self.state = ZOMBIE_IDLE;
        self.state_timer = 0.0;
        self.state_change_cooldown = 0.0;
    }

    #[func]
    fn set_perception(
        &mut self,
        self_position: Vector3,
        target_position: Vector3,
        target_visible: bool,
        heard_noise: bool,
        noise_position: Vector3,
    ) {
        self.self_position = self_position;
        self.target_visible = target_visible;
        if target_visible {
            self.target_position = target_position;
            self.last_seen_position = target_position;
            self.last_seen_timer = ZOMBIE_LAST_SEEN_MEMORY;
        }
        if heard_noise {
            self.noise_position = noise_position;
            self.noise_timer = ZOMBIE_NOISE_MEMORY;
        }
    }

    #[func]
    fn hear_noise(&mut self, noise_position: Vector3, strength: f32) {
        if strength <= 0.05 {
            return;
        }
        self.noise_position = noise_position;
        self.noise_timer = self
            .noise_timer
            .max(ZOMBIE_NOISE_MEMORY * strength.clamp(0.25, 1.5));
    }

    #[func]
    fn force_redirect(&mut self) {
        self.state_timer = 0.0;
        if self.state == ZOMBIE_WANDER || self.state == ZOMBIE_INVESTIGATE {
            self.state = ZOMBIE_IDLE;
        }
    }

    #[func]
    fn tick(&mut self, delta: f32) -> VarDictionary {
        let delta = delta.max(0.0).min(0.25);
        self.state_timer = (self.state_timer - delta).max(0.0);
        self.attack_cooldown = (self.attack_cooldown - delta).max(0.0);
        self.state_change_cooldown = (self.state_change_cooldown - delta).max(0.0);
        self.last_seen_timer = (self.last_seen_timer - delta).max(0.0);
        self.noise_timer = (self.noise_timer - delta).max(0.0);

        let attack_animation_active = self.state == ZOMBIE_ATTACK && self.state_timer > 0.0;
        let mut attack_event = false;

        if !attack_animation_active {
            if self.target_visible {
                let target_distance = self.horizontal_distance_to(self.target_position);
                if target_distance <= ZOMBIE_ATTACK_DISTANCE {
                    self.enter_attack();
                    if self.attack_cooldown <= 0.0 {
                        self.attack_cooldown = ZOMBIE_ATTACK_COOLDOWN;
                        self.state_timer = ZOMBIE_ATTACK_DURATION;
                        attack_event = true;
                    }
                } else {
                    if self.try_transition(ZOMBIE_CHASE) {
                        self.state_timer = 0.0;
                    }
                }
            } else if self.last_seen_timer > 0.0 {
                self.try_transition(ZOMBIE_INVESTIGATE);
            } else if self.noise_timer > 0.0 {
                self.try_transition(ZOMBIE_INVESTIGATE);
            } else {
                self.choose_unalerted_state();
            }
        }

        let (velocity, animation) = match self.state {
            ZOMBIE_CHASE => (self.direction_to(self.target_position) * self.speed, "run"),
            ZOMBIE_INVESTIGATE => {
                let destination = if self.last_seen_timer > 0.0 {
                    self.last_seen_position
                } else {
                    self.noise_position
                };
                let distance = self.horizontal_distance_to(destination);
                if distance <= 1.0 {
                    self.last_seen_timer = 0.0;
                    self.noise_timer = 0.0;
                    self.try_transition(ZOMBIE_IDLE);
                    self.state_timer = self.random_range(2.0, 5.0);
                    (Vector3::ZERO, "idle")
                } else {
                    (self.direction_to(destination) * (self.speed * 0.7), "walk")
                }
            }
            ZOMBIE_WANDER => (self.direction * (self.speed * 0.45), "walk"),
            ZOMBIE_ATTACK if attack_animation_active || attack_event => (Vector3::ZERO, "attack"),
            _ => (Vector3::ZERO, "idle"),
        };

        let mut result = VarDictionary::new();
        result.set("velocity", velocity);
        result.set("anim", animation);
        result.set("state", self.state_name());
        result.set("attack", attack_event);
        result
    }
}

impl ZombieAi {
    fn choose_unalerted_state(&mut self) {
        if self.state_timer > 0.0 {
            return;
        }

        if self.random_unit() < 0.72 {
            if self.try_transition(ZOMBIE_IDLE) {
                self.state_timer = self.random_range(2.0, 6.0);
            }
        } else {
            if self.try_transition(ZOMBIE_WANDER) {
                self.state_timer = self.random_range(1.0, 2.5);
                let angle = self.random_range(0.0, std::f32::consts::TAU);
                self.direction = Vector3::new(angle.cos(), 0.0, angle.sin());
            }
        }
    }

    fn try_transition(&mut self, next_state: i32) -> bool {
        if self.state == next_state {
            return true;
        }
        if self.state_change_cooldown > 0.0 {
            return false;
        }
        self.state = next_state;
        self.state_change_cooldown = ZOMBIE_STATE_CHANGE_COOLDOWN;
        true
    }

    fn enter_attack(&mut self) {
        if self.state != ZOMBIE_ATTACK {
            self.state = ZOMBIE_ATTACK;
            self.state_change_cooldown = ZOMBIE_STATE_CHANGE_COOLDOWN;
        }
    }

    fn direction_to(&self, destination: Vector3) -> Vector3 {
        let delta = destination - self.self_position;
        Vector3::new(delta.x, 0.0, delta.z).normalized()
    }

    fn horizontal_distance_to(&self, destination: Vector3) -> f32 {
        let delta = destination - self.self_position;
        Vector2::new(delta.x, delta.z).length()
    }

    fn random_unit(&mut self) -> f32 {
        self.random_state = self
            .random_state
            .wrapping_mul(1_664_525)
            .wrapping_add(1_013_904_223);
        self.random_state as f32 / u32::MAX as f32
    }

    fn random_range(&mut self, minimum: f32, maximum: f32) -> f32 {
        minimum + (maximum - minimum) * self.random_unit()
    }

    fn state_name(&self) -> &'static str {
        match self.state {
            ZOMBIE_WANDER => "wander",
            ZOMBIE_INVESTIGATE => "investigate",
            ZOMBIE_CHASE => "chase",
            ZOMBIE_ATTACK => "attack",
            _ => "idle",
        }
    }
}

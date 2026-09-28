use godot::prelude::*;

/// Tipo de elemento estructural modular en el sistema de construcción.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum BuildingElementType {
    Floor = 0,
    Wall = 1,
    Ceiling = 2,
    DoorFrame = 3,
    WindowFrame = 4,
}

impl BuildingElementType {
    pub fn from_i32(val: i32) -> Self {
        match val {
            0 => BuildingElementType::Floor,
            1 => BuildingElementType::Wall,
            2 => BuildingElementType::Ceiling,
            3 => BuildingElementType::DoorFrame,
            4 => BuildingElementType::WindowFrame,
            _ => BuildingElementType::Floor,
        }
    }

    pub fn to_i32(self) -> i32 {
        self as i32
    }
}

/// Tipo de material de construcción (asociado a un MultiMesh específico para GPU Instancing).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MaterialType {
    Wood = 0,
    Stone = 1,
    Brick = 2,
    Concrete = 3,
    Metal = 4,
    Frame = 5,
}

impl MaterialType {
    pub fn from_i32(val: i32) -> Self {
        match val {
            0 => MaterialType::Wood,
            1 => MaterialType::Stone,
            2 => MaterialType::Brick,
            3 => MaterialType::Concrete,
            4 => MaterialType::Metal,
            5 => MaterialType::Frame,
            _ => MaterialType::Frame,
        }
    }

    pub fn to_i32(self) -> i32 {
        self as i32
    }
}

/// Coordenada entera discreta en el mundo (unidad base: 1 metro).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct GridCoord3D {
    pub x: i32,
    pub y: i32,
    pub z: i32,
}

impl GridCoord3D {
    pub fn new(x: i32, y: i32, z: i32) -> Self {
        Self { x, y, z }
    }

    pub fn from_vec3(v: Vector3) -> Self {
        Self {
            x: v.x.round() as i32,
            y: v.y.round() as i32,
            z: v.z.round() as i32,
        }
    }

    pub fn to_vec3(self) -> Vector3 {
        Vector3::new(self.x as f32, self.y as f32, self.z as f32)
    }
}

/// Elemento discreto construido en la simulación.
#[derive(Debug, Clone)]
pub struct BuildingElement {
    pub id: u64,
    pub element_type: BuildingElementType,
    pub grid_pos: GridCoord3D,
    pub world_pos: Vector3,
    pub scale: Vector3,
    pub rotation_deg: f32,
    pub material_type: MaterialType,
    pub is_built: bool,
    pub custom_paint_id: u32,
}

/// Tramo o región rectangular de piso en la simulación.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct FloorSpan {
    pub min_x: f32,
    pub max_x: f32,
    pub min_z: f32,
    pub max_z: f32,
    pub y: f32,
}

impl FloorSpan {
    pub fn new(p0: Vector3, p1: Vector3) -> Self {
        Self {
            min_x: p0.x.min(p1.x),
            max_x: p0.x.max(p1.x),
            min_z: p0.z.min(p1.z),
            max_z: p0.z.max(p1.z),
            y: p0.y,
        }
    }

    pub fn contains_xz(&self, x: f32, z: f32, margin: f32) -> bool {
        x >= (self.min_x - margin)
            && x <= (self.max_x + margin)
            && z >= (self.min_z - margin)
            && z <= (self.max_z + margin)
    }

    pub fn clamp_point(&self, p: Vector3) -> Vector3 {
        Vector3::new(
            p.x.clamp(self.min_x, self.max_x),
            self.y,
            p.z.clamp(self.min_z, self.max_z),
        )
    }
}

/// Tramo lineal de pared en la simulación.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct WallSpan {
    pub p0: Vector3,
    pub p1: Vector3,
    pub height: f32,
}

impl WallSpan {
    pub fn new(p0: Vector3, p1: Vector3, height: f32) -> Self {
        Self { p0, p1, height }
    }
}


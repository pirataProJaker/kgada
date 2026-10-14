use godot::prelude::*;

/// Tipología de instalación / complejo fortificado para el generador procedural.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FacilityType {
    /// Base militar táctica: hangares, helipuerto, barracones, armerías, nidos de ametralladora.
    MilitaryBase = 0,
    /// Planta / complejo nuclear: torres de refrigeración, cúpulas de reactor, subestación.
    NuclearPlant = 1,
    /// Estación de investigación científica clasificada: laboratorios, salas limpias, antenas.
    ResearchOutpost = 2,
    /// Prisión de máxima seguridad: bloques de celdas, patios cercados, doble muralla.
    PrisonComplex = 3,
}

impl FacilityType {
    pub fn from_i32(val: i32) -> Self {
        match val {
            1 => FacilityType::NuclearPlant,
            2 => FacilityType::ResearchOutpost,
            3 => FacilityType::PrisonComplex,
            _ => FacilityType::MilitaryBase,
        }
    }
}

/// Tipos de estructuras modulares que pueden colocarse dentro del complejo.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StructureKind {
    /// Torre de vigilancia elevada con caseta y reflector (1x1 celdas = 4x4m, altura ~12m)
    Watchtower = 0,
    /// Garita / caseta de acceso vehicular con barrera de pluma (1x1 celdas = 4x4m)
    Guardhouse = 1,
    /// Barracones de tropa o dormitorios de personal (2x5 celdas = 8x20m, 2 plantas)
    Barracks = 2,
    /// Hangar masivo para vehículos blindados o aeronaves (6x8 celdas = 24x32m)
    Hangar = 3,
    /// Edificio de Mando Central / HQ (4x6 celdas = 16x24m, 2 plantas)
    CommandHQ = 4,
    /// Helipuerto con losa de hormigón y balizas perimetrales (4x4 celdas = 16x16m)
    Helipad = 5,
    /// Depósito de combustible con tanques cilíndricos (2x2 celdas = 8x8m)
    FuelDepot = 6,
    /// Escotilla / acceso fortificado al búnker o mazmorra subterránea (2x3 celdas = 8x12m)
    BunkerEntrance = 7,
    /// Búnker de superficie / nido de ametralladora con aspilleras (1x2 celdas = 4x8m)
    MachineGunBunker = 8,
    /// Torre de refrigeración hiperbólica para complejos nucleares (6x6 celdas = 24x24m)
    CoolingTower = 9,
    /// Edificio de contención del reactor nuclear (6x6 celdas = 24x24m)
    ReactorContainment = 10,
    /// Comedor militar / casino de oficiales y tropa (3x5 celdas = 12x20m)
    MessHall = 11,
    /// Enfermería táctica / hospital de campaña (2x4 celdas = 8x16m)
    MedicalClinic = 12,
    /// Armería y polvorín de municiones blindado (2x3 celdas = 8x12m)
    Armory = 13,
    /// Taller de mantenimiento de blindados y vehículos (4x5 celdas = 16x20m)
    VehicleWorkshop = 14,
    /// Puesto de telecomunicaciones y radar militar (2x2 celdas = 8x8m)
    CommsRadarPost = 15,
}

impl StructureKind {
    /// Dimensiones estándar en celdas de cuadrícula de 1x1 metro (1 celda = 1.0 metro)
    pub fn cell_dimensions(self) -> (usize, usize) {
        match self {
            StructureKind::Watchtower => (3, 3),
            StructureKind::Guardhouse => (3, 3),
            StructureKind::MachineGunBunker => (4, 4),
            StructureKind::FuelDepot => (8, 8),
            StructureKind::CommsRadarPost => (8, 8),
            StructureKind::Armory => (8, 10),
            StructureKind::BunkerEntrance => (12, 10),
            StructureKind::MedicalClinic => (8, 10),
            StructureKind::Barracks => (6, 10),
            StructureKind::MessHall => (9, 12),
            StructureKind::VehicleWorkshop => (12, 14),
            StructureKind::Helipad => (14, 14),
            StructureKind::CommandHQ => (16, 12),
            StructureKind::Hangar => (16, 18),
            StructureKind::CoolingTower => (20, 20),
            StructureKind::ReactorContainment => (20, 20),
        }
    }

    /// Altura estándar de la estructura en metros
    pub fn height_meters(self) -> f32 {
        match self {
            StructureKind::Helipad => 0.15,
            StructureKind::Guardhouse => 3.00,
            StructureKind::MachineGunBunker => 2.80,
            StructureKind::Armory => 3.80,
            StructureKind::FuelDepot => 4.20,
            StructureKind::MedicalClinic => 3.80,
            StructureKind::BunkerEntrance => 3.60,
            StructureKind::MessHall => 4.20,
            StructureKind::Barracks => 3.60,
            StructureKind::VehicleWorkshop => 5.50,
            StructureKind::CommandHQ => 5.80,
            StructureKind::CommsRadarPost => 8.00,
            StructureKind::Hangar => 7.50,
            StructureKind::Watchtower => 8.50,
            StructureKind::ReactorContainment => 14.00,
            StructureKind::CoolingTower => 20.00,
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            StructureKind::Watchtower => "Torre de Vigilancia",
            StructureKind::Guardhouse => "Garita de Acceso",
            StructureKind::MachineGunBunker => "Nido de Ametralladora",
            StructureKind::FuelDepot => "Depósito de Combustible",
            StructureKind::BunkerEntrance => "Acceso a Búnker Subterráneo",
            StructureKind::Barracks => "Barracones de Tropa (Cuartel)",
            StructureKind::MessHall => "Comedor Militar (Mess Hall)",
            StructureKind::MedicalClinic => "Enfermería Militar",
            StructureKind::Armory => "Armería y Municiones",
            StructureKind::VehicleWorkshop => "Taller de Blindados",
            StructureKind::CommsRadarPost => "Puesto de Telecomunicaciones y Radar",
            StructureKind::Helipad => "Helipuerto Táctico",
            StructureKind::CommandHQ => "Edificio de Mando (HQ)",
            StructureKind::Hangar => "Hangar Militar",
            StructureKind::CoolingTower => "Torre de Refrigeración",
            StructureKind::ReactorContainment => "Cúpula de Contención Nuclear",
        }
    }
}

/// Estado de ocupación de una celda en la matriz 2D de la base.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FacilityCell {
    /// Terreno libre sin edificar
    Empty,
    /// Barda perimetral / muro exterior fortificado
    PerimeterWall,
    /// Calle interna de asfalto / bulevar militar
    Road,
    /// Explanada de hormigón o patio de formación
    Plaza,
    /// Ocupada por una estructura específica (con su ID)
    Structure(u32),
}

/// Estructura colocada en el mundo con coordenadas reales.
#[derive(Debug, Clone)]
pub struct PlacedStructure {
    pub id: u32,
    pub kind: StructureKind,
    pub cell_x: usize,
    pub cell_z: usize,
    pub cells_w: usize,
    pub cells_d: usize,
    pub world_pos: Vector3,
    pub world_size: Vector3,
    pub rotation_y: f32,
}

/// Prop o elemento de relleno táctico colocado mediante recetas del ObjectEngine.
#[derive(Debug, Clone)]
pub struct PlacedProp {
    pub recipe_name: String,
    pub position: Vector3,
    pub rotation_y: f32,
}

/// Punto de calcomanía en fachada para proyectar con WallDecalSystem.
#[derive(Debug, Clone)]
pub struct FacilityDecalPoint {
    pub position: Vector3,
    pub normal: Vector3,
    pub size: Vector2,
    pub category: String,
    pub style_id: u32,
}

/// Caja 3D sólida para renderizado acelerado por GPU (MultiMesh).
#[derive(Debug, Clone)]
pub struct InstanceBox {
    pub position: Vector3,
    pub size: Vector3,
    pub color: Color,
}

/// Caja de colisión física para ensamblar StaticBody3D instantáneo.
#[derive(Debug, Clone)]
pub struct CollisionBox {
    pub position: Vector3,
    pub size: Vector3,
}

/// Plano maestro completo generado para el complejo.
#[derive(Debug, Clone)]
pub struct FacilityBlueprint {
    pub facility_type: FacilityType,
    pub width_m: f32,
    pub depth_m: f32,
    pub cell_size: f32,
    pub grid_w: usize,
    pub grid_d: usize,
    pub structures: Vec<PlacedStructure>,
    pub props: Vec<PlacedProp>,
    pub decals: Vec<FacilityDecalPoint>,
    pub bunker_entrance: Option<Vector3>,
    pub checkpoint_gate: Vector3,
    pub floor_tiles: Vec<Vec<u8>>,
}

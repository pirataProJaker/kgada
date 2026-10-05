use godot::prelude::*;

/// Tipología de zonificación urbana mexicana para casas procedurales.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HouseZoneType {
    /// Barrio tradicional: casas pared con pared (100% frente del lote),
    /// muros ciegos laterales, alturas y estilos variados (1 y 2 pisos).
    ColoniaVieja = 0,

    /// Fraccionamiento / Infonavit: casas serializadas idénticas en la misma manzana,
    /// pasillo lateral exterior de servicio (1m), retiro frontal para cochera.
    ColoniaNueva = 1,

    /// Residencial de lujo: terrenos grandes, casas aisladas con jardines a 4 vientos,
    /// techos altos, ventanales panorámicos y terrazas.
    ZonaX = 2,
}

impl HouseZoneType {
    pub fn from_i32(val: i32) -> Self {
        match val {
            1 => HouseZoneType::ColoniaNueva,
            2 => HouseZoneType::ZonaX,
            _ => HouseZoneType::ColoniaVieja,
        }
    }
}

/// Nivel de altura de cada celda de 1m x 1m en la cuadrícula.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CellHeight {
    /// Terreno libre (patio, jardín, zotehuela, cochera al aire libre)
    Empty = 0,
    /// Construcción en Planta Baja (1 piso, ~2.8m de altura)
    Floor1 = 1,
    /// Construcción en Planta Alta (2 pisos, ~5.6m de altura)
    Floor2 = 2,
}

impl CellHeight {
    pub fn is_built(self) -> bool {
        self != CellHeight::Empty
    }

    pub fn floor_level(self) -> u8 {
        self as u8
    }
}

/// Tipología funcional de habitación para la Jerarquía de Reclamación interna.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RoomType {
    Empty = 0,
    /// Sala de estar / Estancia (zona social y de bienvenida en el acceso principal)
    LivingRoom = 1,
    /// Cocina (zona de servicio/convivencia adyacente a la sala)
    Kitchen = 2,
    /// Recámara / Dormitorio (zona íntima, privada al fondo o en planta alta)
    Bedroom = 3,
    /// Baño completo o medio baño (ventilación exterior requerida)
    Bathroom = 4,
    /// Pasillo distribuidor o zaguán de acceso
    Hallway = 5,
    /// Comedor formal independiente
    DiningRoom = 6,
    /// Estudio / Biblioteca / Despacho
    Studio = 7,
    /// Gimnasio privado o sala de juegos
    GymOrGames = 8,
    /// Cuarto de lavado / Zotehuela techada
    Laundry = 9,
}

impl RoomType {
    pub fn name_es(self) -> &'static str {
        match self {
            RoomType::Empty => "Exterior",
            RoomType::LivingRoom => "Sala",
            RoomType::Kitchen => "Cocina",
            RoomType::Bedroom => "Recámara",
            RoomType::Bathroom => "Baño",
            RoomType::Hallway => "Pasillo",
            RoomType::DiningRoom => "Comedor",
            RoomType::Studio => "Estudio/Biblioteca",
            RoomType::GymOrGames => "Gimnasio",
            RoomType::Laundry => "Lavandería",
        }
    }

    pub fn is_private(self) -> bool {
        matches!(self, RoomType::Bedroom | RoomType::Bathroom | RoomType::Studio)
    }

    pub fn is_social_or_circulation(self) -> bool {
        matches!(
            self,
            RoomType::LivingRoom
                | RoomType::Kitchen
                | RoomType::Hallway
                | RoomType::DiningRoom
                | RoomType::GymOrGames
                | RoomType::Laundry
        )
    }
}

/// Espacio o habitación rectangular reclamada dentro de la casa.
#[derive(Debug, Clone)]
pub struct HouseRoom {
    pub id: u8,
    pub room_type: RoomType,
    pub floor: u8,
    pub x_min: usize,
    pub z_min: usize,
    pub x_max: usize, // Exclusivo: x in [x_min, x_max)
    pub z_max: usize, // Exclusivo: z in [z_min, z_max)
}

/// Cuadrícula modular discreta de 1m x 1m para el lote de la casa.
#[derive(Debug, Clone)]
pub struct HouseGrid {
    pub width: usize,
    pub depth: usize,
    pub cells: Vec<CellHeight>,
}

impl HouseGrid {
    pub fn new(width: usize, depth: usize) -> Self {
        let size = width * depth;
        Self {
            width,
            depth,
            cells: vec![CellHeight::Empty; size],
        }
    }

    #[inline]
    pub fn idx(&self, x: usize, z: usize) -> usize {
        z * self.width + x
    }

    #[inline]
    pub fn in_bounds(&self, x: i32, z: i32) -> bool {
        x >= 0 && x < self.width as i32 && z >= 0 && z < self.depth as i32
    }

    #[inline]
    pub fn get(&self, x: usize, z: usize) -> CellHeight {
        if x < self.width && z < self.depth {
            self.cells[self.idx(x, z)]
        } else {
            CellHeight::Empty
        }
    }

    #[inline]
    pub fn get_i32(&self, x: i32, z: i32) -> CellHeight {
        if self.in_bounds(x, z) {
            self.cells[self.idx(x as usize, z as usize)]
        } else {
            CellHeight::Empty
        }
    }

    #[inline]
    pub fn set(&mut self, x: usize, z: usize, val: CellHeight) {
        if x < self.width && z < self.depth {
            let i = self.idx(x, z);
            self.cells[i] = val;
        }
    }

    /// Cuenta el número total de celdas construidas en planta baja.
    pub fn built_ground_cells(&self) -> usize {
        self.cells.iter().filter(|c| c.is_built()).count()
    }

    /// Cuenta el número de celdas en planta alta (piso 2).
    pub fn floor2_cells(&self) -> usize {
        self.cells.iter().filter(|c| **c == CellHeight::Floor2).count()
    }
}

/// Caja tridimensional sólida para instanciado GPU con MultiMeshInstance3D.
#[derive(Debug, Clone, Copy)]
pub struct InstanceBox {
    pub position: Vector3,
    pub size: Vector3,
    pub color: Color,
}

/// Instancia de puerta texturizada para casas procedurales (Atlas de 8 puertas variadas).
#[derive(Debug, Clone, Copy)]
pub struct DoorInstance {
    pub position: Vector3,
    pub size: Vector3,
    pub rotation_y: f32, // 0.0 para muros horizontales (eje X), PI/2 para muros verticales (eje Z)
    pub style_id: u8,    // 0..7 (índice en el atlas de 8 puertas de 32x64)
    pub is_main: bool,
}

/// Instancia de ventana exterior para colocar protecciones de herrería procedurales.
#[derive(Debug, Clone, Copy)]
pub struct WindowInstance {
    pub position: Vector3,
    pub size: Vector2,
    pub normal: Vector3,
    pub floor: u8,
}

/// Caja de colisión para armar el StaticBody3D físico de la casa.
#[derive(Debug, Clone)]
pub struct HouseCollisionBox {
    pub position: Vector3,
    pub size: Vector3,
}

/// Paleta de colores arquitectónicos para la casa.
#[derive(Debug, Clone)]
pub struct HousePalette {
    pub wall_ext: Color,
    pub wall_int: Color,
    pub floor: Color,
    pub roof: Color,
    pub trim: Color,
    pub door: Color,
    pub window_frame: Color,
    pub window_glass: Color,
    pub tinaco: Color,
}

/// Tipología de escalera normalizada para casas procedurales
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StairType {
    Straight = 0,
    UShape = 1,
    LShape = 2,
}

/// Datos de colocación e integración de escalera en la cuadrícula de 1m x 1m
#[derive(Debug, Clone, Copy)]
pub struct StairData {
    pub stair_type: StairType,
    pub x: usize,
    pub z: usize,
    pub width: usize,
    pub length: usize,
    pub orientation: u8, // 0: Sube hacia +Z, 1: hacia +X, 2: hacia -Z, 3: hacia -X
}

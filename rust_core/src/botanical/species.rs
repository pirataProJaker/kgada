use godot::prelude::*;

/// Tipo de follaje botánico para la especie.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FoliageType {
    /// Racimos de tarjetas de hojas caducifolias (Aliso, Roble, Abedul).
    DeciduousClusters,
    /// Cruces de agujas perennes (Pino, Abeto).
    ConiferCross,
    /// Caída en abanico pendular (Sauce).
    PendulousWillow,
}

/// "Genoma" / Perfil Botánico que define las reglas de crecimiento,
/// ramificación, morfología y estética de una especie de árbol.
///
/// Este struct está completamente desacoplado del motor de simulación.
/// Cualquier especie nueva simplemente crea una instancia de `SpeciesProfile`.
#[derive(Debug, Clone)]
pub struct SpeciesProfile {
    pub id: String,
    pub common_name: String,
    pub scientific_name: String,

    // --- Dimensiones Máximas y Crecimiento ---
    /// Altura de un brote recién nacido (en metros, e.g. 0.20m).
    pub sprout_height: f32,
    /// Altura máxima alcanzable por un árbol adulto maduro (en metros, e.g. 15.0m).
    pub max_adult_height: f32,
    /// Radio base del tronco en el brote (en metros).
    pub sprout_base_radius: f32,
    /// Radio base del tronco en el árbol adulto maduro (en metros).
    pub max_adult_base_radius: f32,

    // --- Morfología del Tronco ---
    /// Cantidad de segmentos/prismas a lo largo del tronco principal en LOD 0.
    pub trunk_segments: usize,
    /// Amplitud de la curvatura orgánica sutil del tronco (0.0 = recto como poste, 0.3 = curvado natural).
    pub trunk_curvature: f32,
    /// Tapering: reducción de radio entre la base y la punta (0.0 a 1.0).
    pub trunk_taper: f32,

    // --- Patrón de Ramificación ---
    /// Fracción de altura del tronco donde comienzan a nacer las ramas primarias (0.0 a 1.0).
    pub branch_start_ratio: f32,
    /// Dominancia apical (0.0 = arbustivo/múltiples troncos, 1.0 = monopodial estricto tipo pino).
    pub apical_dominance: f32,
    /// Ángulo promedio de inserción de las ramas respecto al tronco vertical (en grados).
    pub branch_angle_deg: f32,
    /// Variación aleatoria del ángulo de inserción (en grados).
    pub branch_angle_variance_deg: f32,
    /// Longitud de las ramas primarias como fracción de la altura del árbol.
    pub branch_length_ratio: f32,
    /// Cantidad de segmentos por cada rama primaria.
    pub branch_segments: usize,
    /// Probabilidad de que una rama primaria genere ramificaciones secundarias.
    pub secondary_branch_chance: f32,
    /// Engrosamiento del cuello de inserción de la rama en el tronco (Branch Collar, e.g. 1.45).
    pub branch_collar_factor: f32,
    /// Curvatura botánica ascendente hacia la luz (fototropismo).
    pub branch_curvature_up: f32,
    /// Cantidad típica de ramas primarias por piso/verticilo en el tronco.
    pub branches_per_whorl: usize,

    // --- Follaje y Racimos de Hojas ---
    pub foliage_type: FoliageType,
    /// Diámetro de cada racimo de hojas (en metros) a escala madura.
    pub leaf_cluster_size: f32,
    /// Cantidad de planos/tarjetas por cada racimo.
    pub cards_per_cluster: usize,

    // --- Texturas y Colores PSX ---
    pub bark_texture_path: String,
    pub leaf_texture_path: String,
    pub bark_color: Color,
    pub leaf_color_tint: Color,
}

impl SpeciesProfile {
    /// Genera el perfil botánico calibrado para el Aliso común / Aliso andino (*Alnus acuminata*).
    ///
    /// Características del Alnus acuminata:
    /// - Tronco esbelto, elegante con curvas orgánicas naturales.
    /// - Ramas primarias ascendentes a ~45 grados en dirección a la luz.
    /// - Follaje deciduo en racimos airosos que dejan filtrar la luz del cielo.
    /// - Altura adulta de ~14 a 16 metros con copa ovada abierta.
    pub fn alnus_acuminata() -> Self {
        Self {
            id: "alnus_acuminata".to_string(),
            common_name: "Aliso común / Aliso andino".to_string(),
            scientific_name: "Alnus acuminata".to_string(),

            sprout_height: 0.22,
            max_adult_height: 14.5, // Altura natural de árbol deciduo Alnus (copa ancha y frondosa)
            sprout_base_radius: 0.02,
            max_adult_base_radius: 0.38,

            trunk_segments: 16,
            trunk_curvature: 0.14, // Fuste con curvatura natural balanceada al centro
            trunk_taper: 0.65,

            branch_start_ratio: 0.20, // Fuste despejado en el primer tercio (~2.9m)
            apical_dominance: 0.45,   // Copa abierta aparasolada (NO monopodial de pino)
            branch_angle_deg: 48.0,
            branch_angle_variance_deg: 12.0, // Ángulos variados y orgánicos por rama
            branch_length_ratio: 0.36, // Envergadura de rama ~5.2m (coincide con imagen de 5m)
            branch_segments: 5,        // 5 segmentos en ramas bajas para sag continuo y suave
            secondary_branch_chance: 0.88,
            branch_collar_factor: 1.45,
            branch_curvature_up: 0.0, // Sag gravitacional gobierna la trayectoria
            branches_per_whorl: 3,

            foliage_type: FoliageType::DeciduousClusters,
            leaf_cluster_size: 0.95,
            cards_per_cluster: 2,

            bark_texture_path: "res://assets/vegetation/alnus/alnus_bark.png".to_string(),
            leaf_texture_path: "res://assets/vegetation/alnus/alnus_bough_atlas.png".to_string(),
            bark_color: Color::from_rgb(0.38, 0.35, 0.30),
            leaf_color_tint: Color::from_rgb(0.38, 0.58, 0.22),
        }
    }

    /// Roble Templado (*Quercus robur*): Tronco robusto, copa ancha y extendida, ramas gruesas.
    pub fn classic_oak() -> Self {
        Self {
            id: "classic_oak".to_string(),
            common_name: "Roble templado".to_string(),
            scientific_name: "Quercus robur".to_string(),

            sprout_height: 0.25,
            max_adult_height: 13.0,
            sprout_base_radius: 0.03,
            max_adult_base_radius: 0.48, // Tronco robusto con fuerte contrafuerte basal

            trunk_segments: 16,
            trunk_curvature: 0.10, // Tronco vertical robusto y sólido
            trunk_taper: 0.60,

            branch_start_ratio: 0.22,
            apical_dominance: 0.32, // Copa redondeada y extendida
            branch_angle_deg: 54.0,
            branch_angle_variance_deg: 14.0,
            branch_length_ratio: 0.42,
            branch_segments: 5,
            secondary_branch_chance: 0.90,
            branch_collar_factor: 1.55,
            branch_curvature_up: 0.04,
            branches_per_whorl: 4,

            foliage_type: FoliageType::DeciduousClusters,
            leaf_cluster_size: 1.05,
            cards_per_cluster: 2,

            bark_texture_path: "res://assets/vegetation/alnus/alnus_bark.png".to_string(),
            leaf_texture_path: "res://assets/vegetation/alnus/alnus_bough_atlas.png".to_string(),
            bark_color: Color::from_rgb(0.34, 0.28, 0.22),
            leaf_color_tint: Color::from_rgb(0.35, 0.55, 0.20),
        }
    }

    /// Abedul / Álamo (*Betula pendula*): Tronco esbelto y vertical, copa alta y ligera.
    pub fn autumn_birch() -> Self {
        Self {
            id: "autumn_birch".to_string(),
            common_name: "Abedul / Álamo".to_string(),
            scientific_name: "Betula pendula".to_string(),

            sprout_height: 0.20,
            max_adult_height: 15.5,
            sprout_base_radius: 0.02,
            max_adult_base_radius: 0.28, // Fuste delgado y esbelto

            trunk_segments: 16,
            trunk_curvature: 0.06, // Muy recto y esbelto
            trunk_taper: 0.68,

            branch_start_ratio: 0.28,
            apical_dominance: 0.65, // Alta dominancia apical (crecimiento vertical)
            branch_angle_deg: 36.0, // Ramas ascendentes hacia el cielo
            branch_angle_variance_deg: 8.0,
            branch_length_ratio: 0.30,
            branch_segments: 4,
            secondary_branch_chance: 0.82,
            branch_collar_factor: 1.35,
            branch_curvature_up: 0.08,
            branches_per_whorl: 3,

            foliage_type: FoliageType::DeciduousClusters,
            leaf_cluster_size: 0.90,
            cards_per_cluster: 2,

            bark_texture_path: "res://assets/vegetation/alnus/alnus_bark.png".to_string(),
            leaf_texture_path: "res://assets/vegetation/alnus/alnus_bough_atlas.png".to_string(),
            bark_color: Color::from_rgb(0.72, 0.70, 0.65), // Corteza clara
            leaf_color_tint: Color::from_rgb(0.38, 0.58, 0.22),
        }
    }

    /// Sauce Llorón (*Salix babylonica*): Ramas arqueadas colgantes, follaje frondoso en cascada.
    pub fn weeping_willow() -> Self {
        Self {
            id: "weeping_willow".to_string(),
            common_name: "Sauce llorón".to_string(),
            scientific_name: "Salix babylonica".to_string(),

            sprout_height: 0.22,
            max_adult_height: 11.5,
            sprout_base_radius: 0.03,
            max_adult_base_radius: 0.44,

            trunk_segments: 16,
            trunk_curvature: 0.20,
            trunk_taper: 0.62,

            branch_start_ratio: 0.16,
            apical_dominance: 0.25,
            branch_angle_deg: 58.0,
            branch_angle_variance_deg: 12.0,
            branch_length_ratio: 0.46,
            branch_segments: 6,
            secondary_branch_chance: 0.92,
            branch_collar_factor: 1.40,
            branch_curvature_up: -0.15, // Sag gravitacional acentuado
            branches_per_whorl: 4,

            foliage_type: FoliageType::PendulousWillow,
            leaf_cluster_size: 1.10,
            cards_per_cluster: 2,

            bark_texture_path: "res://assets/vegetation/alnus/alnus_bark.png".to_string(),
            leaf_texture_path: "res://assets/vegetation/alnus/alnus_bough_atlas.png".to_string(),
            bark_color: Color::from_rgb(0.32, 0.28, 0.22),
            leaf_color_tint: Color::from_rgb(0.34, 0.54, 0.20),
        }
    }

    /// Árbol Seco / Muerto (*Lignum mortuum*): Tronco y ramas retorcidas sin follaje.
    pub fn dead_tree() -> Self {
        Self {
            id: "dead_tree".to_string(),
            common_name: "Árbol muerto / quemado".to_string(),
            scientific_name: "Lignum mortuum".to_string(),

            sprout_height: 0.20,
            max_adult_height: 9.5,
            sprout_base_radius: 0.03,
            max_adult_base_radius: 0.36,

            trunk_segments: 14,
            trunk_curvature: 0.34, // Curvatura angular y retorcida
            trunk_taper: 0.65,

            branch_start_ratio: 0.20,
            apical_dominance: 0.35,
            branch_angle_deg: 52.0,
            branch_angle_variance_deg: 20.0,
            branch_length_ratio: 0.38,
            branch_segments: 4,
            secondary_branch_chance: 0.70,
            branch_collar_factor: 1.45,
            branch_curvature_up: 0.0,
            branches_per_whorl: 3,

            foliage_type: FoliageType::DeciduousClusters,
            leaf_cluster_size: 0.0,
            cards_per_cluster: 0, // Cero hojas

            bark_texture_path: "res://assets/vegetation/alnus/alnus_bark.png".to_string(),
            leaf_texture_path: String::new(),
            bark_color: Color::from_rgb(0.24, 0.20, 0.17),
            leaf_color_tint: Color::from_rgb(0.0, 0.0, 0.0),
        }
    }
}

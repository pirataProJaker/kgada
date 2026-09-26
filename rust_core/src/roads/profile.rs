/// Estilo o tipo de relleno del camellón central.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MedianStyle {
    None,
    Grass,
    Bushes,
    Trees,
    Stream,
    ConcreteBarrier,
}

impl MedianStyle {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "grass" | "cesped" | "pasto" => MedianStyle::Grass,
            "bushes" | "arbustos" => MedianStyle::Bushes,
            "trees" | "arboles" => MedianStyle::Trees,
            "stream" | "arroyo" | "canal" => MedianStyle::Stream,
            "concrete" | "barrera" | "muro" => MedianStyle::ConcreteBarrier,
            _ => MedianStyle::None,
        }
    }

    pub fn to_str(&self) -> &'static str {
        match self {
            MedianStyle::None => "none",
            MedianStyle::Grass => "grass",
            MedianStyle::Bushes => "bushes",
            MedianStyle::Trees => "trees",
            MedianStyle::Stream => "stream",
            MedianStyle::ConcreteBarrier => "concrete_barrier",
        }
    }
}

/// Definición modular y paramétrica de una Sección Transversal (Cross-Section) de Calle.
///
/// Gestiona la jerarquía vertical realista de ingeniería urbana:
/// - Cimentación profunda (foundation_depth) enterrada en el terreno para evitar z-fighting.
/// - Calzada elevada (road_surface_elevation) claramente por encima del terreno natural.
/// - Banqueta y bordillo elevados (curb_height) 15cm por encima del asfalto.
/// - Camellones centrales con guarniciones de concreto perimetrales y césped/árboles.
/// - Señalización horizontal de pintura vial (lane markings) en GPU instancing.
#[derive(Debug, Clone)]
pub struct RoadCrossSection {
    pub category_name: String,

    // --- Jerarquía Vertical y Cimentación ---
    pub foundation_depth: f32,          // Profundidad bajo Y=0 para enterrar la base (0.25m)
    pub road_surface_elevation: f32,    // Elevación del asfalto sobre el terreno (0.18m)
    pub curb_height: f32,               // Escalón del bordillo sobre el asfalto (0.15m)

    // --- Calzada vehicular ---
    pub lanes_per_direction: usize,
    pub is_divided: bool,               // Si es true, tiene 2 calzadas separadas por camellón
    pub lane_width: f32,                // Ancho métrico por carril (ej. 3.25m calle, 3.75m bulevar)

    // --- Camellón central / Separador ---
    pub median_width: f32,
    pub median_style: MedianStyle,
    pub has_median_curbs: bool,         // Bordillos perimetrales de concreto en el camellón

    // --- Banquetas peatonales ---
    pub has_left_sidewalk: bool,
    pub has_right_sidewalk: bool,
    pub sidewalk_width: f32,

    // --- Bordillos / Guarniciones ---
    pub has_curbs: bool,
    pub curb_width: f32,                // Ancho del bordillo (0.20m)

    // --- Señalización y Pintura ---
    pub has_lane_markings: bool,        // Rayas discontinuas divisorias de carriles
    pub lane_marking_dash_len: f32,     // Largo de raya blanca (3.0m)
    pub lane_marking_gap_len: f32,      // Separación entre rayas (6.0m)

    // --- Decoración y Vegetación ---
    pub tree_spacing: f32,              // Separación entre árboles a lo largo del camellón
}

impl Default for RoadCrossSection {
    fn default() -> Self {
        Self::residential_2lane()
    }
}

impl RoadCrossSection {
    /// Calle residencial estándar (2 carriles de 3.25m = 6.5m, banquetas elevadas a ambos lados).
    pub fn residential_2lane() -> Self {
        Self {
            category_name: "residential_2lane".to_string(),
            foundation_depth: 0.25,
            road_surface_elevation: 0.18,
            curb_height: 0.15,

            lanes_per_direction: 1,
            is_divided: false,
            lane_width: 3.25,

            median_width: 0.0,
            median_style: MedianStyle::None,
            has_median_curbs: false,

            has_left_sidewalk: true,
            has_right_sidewalk: true,
            sidewalk_width: 2.0,

            has_curbs: true,
            curb_width: 0.20,

            has_lane_markings: false,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 14.0,
        }
    }

    /// Calle residencial estrecha / privada de 1 carril (4.0m) con banqueta lateral.
    pub fn residential_narrow_1lane() -> Self {
        Self {
            category_name: "residential_narrow_1lane".to_string(),
            foundation_depth: 0.25,
            road_surface_elevation: 0.18,
            curb_height: 0.15,

            lanes_per_direction: 1,
            is_divided: false,
            lane_width: 4.0,

            median_width: 0.0,
            median_style: MedianStyle::None,
            has_median_curbs: false,

            has_left_sidewalk: true,
            has_right_sidewalk: false,
            sidewalk_width: 1.5,

            has_curbs: true,
            curb_width: 0.18,

            has_lane_markings: false,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 0.0,
        }
    }

    /// Bulevar dividido con camellón central arbolado y bordillos perimetrales de concreto.
    pub fn divided_boulevard(lanes: usize, median_width: f32, median_style: MedianStyle) -> Self {
        Self {
            category_name: "divided_boulevard".to_string(),
            foundation_depth: 0.25,
            road_surface_elevation: 0.18,
            curb_height: 0.15,

            lanes_per_direction: lanes.max(1),
            is_divided: true,
            lane_width: 3.75,

            median_width: median_width.max(2.0),
            median_style,
            has_median_curbs: true,

            has_left_sidewalk: true,
            has_right_sidewalk: true,
            sidewalk_width: 2.8,

            has_curbs: true,
            curb_width: 0.20,

            has_lane_markings: true,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 14.0,
        }
    }

    /// Bulevar con arroyo / canal pluvial natural en el camellón central.
    pub fn stream_parkway(lanes: usize, stream_width: f32) -> Self {
        Self {
            category_name: "stream_parkway".to_string(),
            foundation_depth: 0.35,
            road_surface_elevation: 0.18,
            curb_height: 0.15,

            lanes_per_direction: lanes.max(1),
            is_divided: true,
            lane_width: 3.75,

            median_width: stream_width.max(6.0),
            median_style: MedianStyle::Stream,
            has_median_curbs: true,

            has_left_sidewalk: true,
            has_right_sidewalk: true,
            sidewalk_width: 3.0,

            has_curbs: true,
            curb_width: 0.20,

            has_lane_markings: true,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 14.0,
        }
    }

    /// Avenida comercial amplia sin camellón (4 carriles continuos de 3.75m = 15m de calzada).
    pub fn commercial_avenue_4lane() -> Self {
        Self {
            category_name: "commercial_avenue_4lane".to_string(),
            foundation_depth: 0.25,
            road_surface_elevation: 0.18,
            curb_height: 0.15,

            lanes_per_direction: 2,
            is_divided: false,
            lane_width: 3.75,

            median_width: 0.0,
            median_style: MedianStyle::None,
            has_median_curbs: false,

            has_left_sidewalk: true,
            has_right_sidewalk: true,
            sidewalk_width: 3.2,

            has_curbs: true,
            curb_width: 0.20,

            has_lane_markings: true,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 16.0,
        }
    }

    /// Carretera rural simple (2 carriles de 3.5m, sin banquetas ni bordillos).
    pub fn rural_road_2lane() -> Self {
        Self {
            category_name: "rural_road_2lane".to_string(),
            foundation_depth: 0.20,
            road_surface_elevation: 0.14,
            curb_height: 0.0,

            lanes_per_direction: 1,
            is_divided: false,
            lane_width: 3.5,

            median_width: 0.0,
            median_style: MedianStyle::None,
            has_median_curbs: false,

            has_left_sidewalk: false,
            has_right_sidewalk: false,
            sidewalk_width: 0.0,

            has_curbs: false,
            curb_width: 0.0,

            has_lane_markings: false,
            lane_marking_dash_len: 3.0,
            lane_marking_gap_len: 6.0,

            tree_spacing: 0.0,
        }
    }

    /// Ancho de una sola calzada vehicular.
    pub fn single_roadway_width(&self) -> f32 {
        self.lanes_per_direction as f32 * self.lane_width
    }

    /// Ancho vehicular total (calzadas vehiculares + camellón si es vía dividida).
    pub fn total_roadway_width(&self) -> f32 {
        if self.is_divided {
            self.single_roadway_width() * 2.0 + self.median_width
        } else {
            self.single_roadway_width()
        }
    }

    /// Altura de la superficie superior de la banqueta y bordillo sobre el terreno.
    pub fn sidewalk_top_elevation(&self) -> f32 {
        self.road_surface_elevation + self.curb_height
    }

    /// Ancho total de la sección de calle de extremo a extremo (incluyendo banquetas y camellón).
    pub fn total_footprint_width(&self) -> f32 {
        let roadway_total = self.total_roadway_width();
        let sw_left = if self.has_left_sidewalk { self.sidewalk_width } else { 0.0 };
        let sw_right = if self.has_right_sidewalk { self.sidewalk_width } else { 0.0 };
        let curb_left = if self.has_curbs && self.has_left_sidewalk { self.curb_width } else { 0.0 };
        let curb_right = if self.has_curbs && self.has_right_sidewalk { self.curb_width } else { 0.0 };

        roadway_total + sw_left + sw_right + curb_left + curb_right
    }
}

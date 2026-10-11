use godot::prelude::*;
use super::types::HouseZoneType;

/// Instancia de detalle, defecto o decoración de pared generado proceduralmente.
#[derive(Debug, Clone)]
pub struct WallDetailInstance {
    pub category: String, // "graffiti", "desgaste", etc.
    pub style_id: u8,
    pub position: Vector3,
    pub normal: Vector3,
    pub size: Vector2,
    pub layer: u8,
    pub tilt: f32,
    pub flip_h: bool,
    pub flip_v: bool,
    pub is_small: bool,
}

/// Tramo de muro disponible para colocación de detalles superficiales.
#[derive(Debug, Clone)]
pub struct WallSpan {
    pub is_axis_x: bool,
    pub start: f32,
    pub end: f32,
    pub face_coord: f32,
    pub normal: Vector3,
    pub is_exterior: bool,
    pub wall_height: f32,
    pub is_blank: bool,
    pub openings: Vec<(f32, f32, f32, f32)>, // (start, end, y_bottom, y_top) de vanos a lo largo del tramo
}

impl WallSpan {
    pub fn length(&self) -> f32 {
        (self.end - self.start).abs()
    }
}

/// Generador de números pseudoaleatorios ligero y determinista por semilla.
struct DetailRng {
    state: u64,
}

impl DetailRng {
    fn new(seed: u64) -> Self {
        Self { state: seed ^ 0x5DEECE66D }
    }

    fn next_u32(&mut self) -> u32 {
        self.state = self.state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (self.state >> 32) as u32
    }

    fn next_f32(&mut self) -> f32 {
        (self.next_u32() & 0x00FFFFFF) as f32 / 16777216.0
    }

    fn range_f32(&mut self, min: f32, max: f32) -> f32 {
        min + (max - min) * self.next_f32()
    }
}

/// Sistema Centralizado de Defectos y Decoraciones de Pared (WallDetailSystem).
pub struct WallDetailSystem;

impl WallDetailSystem {
    /// Evalúa todos los tramos de pared de la casa y aplica las reglas de cada categoría registrada.
    pub fn generate_details(
        spans: &[WallSpan],
        zone: HouseZoneType,
        seed: u64,
        floor_height: f32,
    ) -> Vec<WallDetailInstance> {
        let mut details = Vec::new();
        let mut rng = DetailRng::new(seed.wrapping_add(4421));

        // --------------------------------------------------------------------
        // REGLA 1: CATEGORÍA "graffiti" (Capa / Peso 1)
        // Reglas:
        // - Solo en paredes exteriores 100% ciegas (sin ventanas ni puertas)
        // - Prioridad en paredes laterales ("a un lado de la casa")
        // - Altura media (1.2m - 2.2m)
        // - Variantes grandes y pequeñas acompañantes
        // --------------------------------------------------------------------
        Self::generate_graffiti_category(&mut details, spans, zone, &mut rng, floor_height);

        // --------------------------------------------------------------------
        // REGLA 2: CATEGORÍA "desgaste" (Capa / Peso 2)
        // Reglas:
        // - Puede colocarse en cualquier pared exterior (ciega o con vanos)
        // - Como el peso es 2, se dibuja ENCIMA del grafiti (layer 2 con normal_offset mayor)
        // - Si coincide en la misma pared, el desprendimiento tapa al grafiti
        // - 3 alturas: zócalo/salitre (inferior), media altura (humano) y pretil/alero (superior)
        // - 7 estilos con flip_h y flip_v aleatorios
        // --------------------------------------------------------------------
        Self::generate_wear_category(&mut details, spans, zone, &mut rng, floor_height);

        details
    }

    fn generate_graffiti_category(
        out: &mut Vec<WallDetailInstance>,
        spans: &[WallSpan],
        zone: HouseZoneType,
        rng: &mut DetailRng,
        floor_height: f32,
    ) {
        let graffiti_prob = match zone {
            HouseZoneType::ColoniaVieja => 0.85,
            HouseZoneType::ColoniaNueva => 0.65,
            HouseZoneType::ZonaX => 0.30,
            HouseZoneType::CommercialConvenience => 0.45,
        };

        // Filtrar tramos aptos: exteriores, 100% ciegos, longitud mínima 2.5m
        let mut candidates: Vec<&WallSpan> = spans
            .iter()
            .filter(|s| s.is_exterior && s.is_blank && s.length() >= 2.5)
            .collect();

        // Priorizar paredes laterales (!is_axis_x) y tramos largos
        candidates.sort_by(|a, b| {
            let score_a = (if !a.is_axis_x { 20 } else { 0 }) + (if a.length() >= 5.0 { 10 } else { 0 });
            let score_b = (if !b.is_axis_x { 20 } else { 0 }) + (if b.length() >= 5.0 { 10 } else { 0 });
            score_b.cmp(&score_a)
        });

        for seg in candidates {
            if rng.next_f32() > graffiti_prob {
                continue;
            }

            let _seg_len = seg.length();
            let combo_roll = rng.next_f32();

            // Layer / Peso 1 para grafiti (normal offset 0.005)
            let layer = 1;
            let offset_dist = 0.005;

            if combo_roll < 0.55 {
                // COMBO: Grafiti grande + grafiti pequeño acompañante
                let large_style = (rng.next_u32() % 5) as u8;
                let large_aspect = match large_style {
                    0 => 1.23,
                    1 => 1.28,
                    2 => 0.93,
                    3 => 1.42,
                    _ => 1.35,
                };
                let large_h = rng.range_f32(1.85, 2.30);
                let large_w = large_h * large_aspect;
                let large_y = rng.range_f32(1.35, 1.55);
                let large_tilt = rng.range_f32(-0.04, 0.04);

                let margin = rng.range_f32(0.50, 1.10);
                let center_along = (seg.start + large_w * 0.5 + margin).min(seg.end - large_w * 0.5);

                let large_pos = if seg.is_axis_x {
                    Vector3::new(center_along, large_y, seg.face_coord + seg.normal.z * offset_dist)
                } else {
                    Vector3::new(seg.face_coord + seg.normal.x * offset_dist, large_y, center_along)
                };

                out.push(WallDetailInstance {
                    category: "graffiti".to_string(),
                    style_id: large_style,
                    position: large_pos,
                    normal: seg.normal,
                    size: Vector2::new(large_w, large_h),
                    layer,
                    tilt: large_tilt,
                    flip_h: false,
                    flip_v: false,
                    is_small: false,
                });

                // Pequeño acompañante
                let small_style = (rng.next_u32() % 3) as u8;
                let small_aspect = match small_style {
                    0 => 0.70,
                    1 => 0.96,
                    _ => 0.90,
                };
                let small_h = rng.range_f32(0.55, 0.72);
                let small_w = small_h * small_aspect;
                let small_tilt = rng.range_f32(-0.07, 0.07);

                let (small_along, small_y) = if small_style == 2 {
                    // Corona: centrada arriba
                    (
                        center_along + rng.range_f32(-0.12, 0.12),
                        (large_y + large_h * 0.5 + small_h * 0.42).min(floor_height + 0.15)
                    )
                } else {
                    // Carita / estrella al costado
                    let dir = if center_along + large_w * 0.5 + small_w + 0.3 <= seg.end { 1.0 } else { -1.0 };
                    let side_along = (center_along + dir * (large_w * 0.52 + small_w * 0.55))
                        .clamp(seg.start + small_w * 0.5 + 0.2, seg.end - small_w * 0.5 - 0.2);
                    (side_along, large_y + rng.range_f32(-0.20, 0.30))
                };

                let small_pos = if seg.is_axis_x {
                    Vector3::new(small_along, small_y, seg.face_coord + seg.normal.z * offset_dist)
                } else {
                    Vector3::new(seg.face_coord + seg.normal.x * offset_dist, small_y, small_along)
                };

                out.push(WallDetailInstance {
                    category: "graffiti".to_string(),
                    style_id: small_style,
                    position: small_pos,
                    normal: seg.normal,
                    size: Vector2::new(small_w, small_h),
                    layer,
                    tilt: small_tilt,
                    flip_h: false,
                    flip_v: false,
                    is_small: true,
                });
            } else if combo_roll < 0.85 {
                // Grafiti grande solo
                let large_style = (rng.next_u32() % 5) as u8;
                let large_aspect = match large_style {
                    0 => 1.23,
                    1 => 1.28,
                    2 => 0.93,
                    3 => 1.42,
                    _ => 1.35,
                };
                let large_h = rng.range_f32(1.85, 2.30);
                let large_w = large_h * large_aspect;
                let large_y = rng.range_f32(1.35, 1.55);
                let large_tilt = rng.range_f32(-0.04, 0.04);

                let margin = rng.range_f32(0.50, 1.10);
                let center_along = (seg.start + large_w * 0.5 + margin).min(seg.end - large_w * 0.5);

                let large_pos = if seg.is_axis_x {
                    Vector3::new(center_along, large_y, seg.face_coord + seg.normal.z * offset_dist)
                } else {
                    Vector3::new(seg.face_coord + seg.normal.x * offset_dist, large_y, center_along)
                };

                out.push(WallDetailInstance {
                    category: "graffiti".to_string(),
                    style_id: large_style,
                    position: large_pos,
                    normal: seg.normal,
                    size: Vector2::new(large_w, large_h),
                    layer,
                    tilt: large_tilt,
                    flip_h: false,
                    flip_v: false,
                    is_small: false,
                });
            } else {
                // Grafiti pequeño solo
                let small_style = (rng.next_u32() % 3) as u8;
                let small_aspect = match small_style {
                    0 => 0.70,
                    1 => 0.96,
                    _ => 0.90,
                };
                let small_h = rng.range_f32(0.70, 0.95);
                let small_w = small_h * small_aspect;
                let small_y = rng.range_f32(1.20, 1.45);
                let small_tilt = rng.range_f32(-0.06, 0.06);

                let margin = rng.range_f32(0.60, 1.50);
                let center_along = (seg.start + small_w * 0.5 + margin).min(seg.end - small_w * 0.5);

                let small_pos = if seg.is_axis_x {
                    Vector3::new(center_along, small_y, seg.face_coord + seg.normal.z * offset_dist)
                } else {
                    Vector3::new(seg.face_coord + seg.normal.x * offset_dist, small_y, center_along)
                };

                out.push(WallDetailInstance {
                    category: "graffiti".to_string(),
                    style_id: small_style,
                    position: small_pos,
                    normal: seg.normal,
                    size: Vector2::new(small_w, small_h),
                    layer,
                    tilt: small_tilt,
                    flip_h: false,
                    flip_v: false,
                    is_small: true,
                });
            }
        }
    }

    fn generate_wear_category(
        out: &mut Vec<WallDetailInstance>,
        spans: &[WallSpan],
        zone: HouseZoneType,
        rng: &mut DetailRng,
        floor_height: f32,
    ) {
        // Probabilidad y densidad según la zona urbana:
        // Colonia Vieja: 90% de probabilidad (casas con mucha historia y salitre)
        // Colonia Nueva: 65% de probabilidad (desgaste moderado en esquinas/base)
        // Zona X: 25% de probabilidad (casas de lujo bien pintadas, desgaste mínimo)
        let (wear_prob, max_decals_per_span) = match zone {
            HouseZoneType::ColoniaVieja => (0.90, 3),
            HouseZoneType::ColoniaNueva => (0.65, 2),
            HouseZoneType::ZonaX => (0.25, 1),
            HouseZoneType::CommercialConvenience => (0.40, 1),
        };

        // Aspect ratios de las 7 texturas procesadas de pared desgastada:
        let aspects = [0.48, 1.09, 1.01, 1.27, 0.90, 0.56, 0.73];

        // Layer / Peso 2 para desgaste:
        // normal offset 0.008 (mayor que el 0.005 del grafiti, por lo que el desprendimiento de pintura
        // se sobrepone y oculta al grafiti si caen en la misma zona).
        let layer = 2;
        let offset_dist = 0.008;

        for seg in spans {
            if !seg.is_exterior || seg.length() < 1.6 {
                continue;
            }

            if rng.next_f32() > wear_prob {
                continue;
            }

            let num_decals = match max_decals_per_span {
                1 => 1,
                2 => if rng.next_f32() < 0.60 { 2 } else { 1 },
                _ => {
                    let r = rng.next_f32();
                    if r < 0.45 { 3 } else if r < 0.80 { 2 } else { 1 }
                }
            };

            for d_idx in 0..num_decals {
                let style_id = (rng.next_u32() % 7) as u8;
                let aspect = aspects[style_id as usize];

                let h_decal = match style_id {
                    2 | 4 => rng.range_f32(1.20, 1.75), // Parches grandes
                    1 | 3 => rng.range_f32(1.00, 1.45), // Parches medianos
                    _ => rng.range_f32(0.85, 1.30),     // Grietas / tiras verticales
                };
                let w_decal = h_decal * aspect;

                if w_decal >= seg.length() {
                    continue;
                }

                // Altura vertical Y:
                // 1. Zócalo / salitre inferior (0.40m a 0.95m)
                // 2. Media altura (1.10m a 1.70m)
                // 3. Pretil / cornisa superior (1.80m a techo)
                let y_decal = if d_idx == 0 && rng.next_f32() < 0.60 {
                    // Humedad de zócalo inferior
                    rng.range_f32(h_decal * 0.5 + 0.15, 1.00)
                } else if rng.next_f32() < 0.50 {
                    // Media altura
                    rng.range_f32(1.10, 1.70)
                } else {
                    // Pretil / parte alta
                    rng.range_f32(1.70, (floor_height - h_decal * 0.5).max(1.80))
                };

                let min_along = seg.start + w_decal * 0.5 + 0.20;
                let max_along = seg.end - w_decal * 0.5 - 0.20;
                if min_along > max_along {
                    continue;
                }
                let pos_along = rng.range_f32(min_along, max_along);

                // Si el muro tiene vanos (ventanas/puertas), asegurar que no se encime sobre el marco ni el cristal
                let d_min = pos_along - w_decal * 0.5;
                let d_max = pos_along + w_decal * 0.5;
                let d_y_min = y_decal - h_decal * 0.5;
                let d_y_max = y_decal + h_decal * 0.5;
                let safety_margin = 0.15f32; // 15cm de margen de seguridad para nunca tocar el marco blanco

                let mut collides_with_opening = false;
                for &(o_start, o_end, o_y_bot, o_y_top) in &seg.openings {
                    let overlap_h = d_max > (o_start - safety_margin) && d_min < (o_end + safety_margin);
                    let overlap_v = d_y_max > (o_y_bot - safety_margin) && d_y_min < (o_y_top + safety_margin);
                    if overlap_h && overlap_v {
                        collides_with_opening = true;
                        break;
                    }
                }
                if collides_with_opening {
                    continue;
                }

                let flip_h = rng.next_f32() < 0.50;
                let flip_v = rng.next_f32() < 0.50;

                let decal_pos = if seg.is_axis_x {
                    Vector3::new(pos_along, y_decal, seg.face_coord + seg.normal.z * offset_dist)
                } else {
                    Vector3::new(seg.face_coord + seg.normal.x * offset_dist, y_decal, pos_along)
                };

                out.push(WallDetailInstance {
                    category: "desgaste".to_string(),
                    style_id,
                    position: decal_pos,
                    normal: seg.normal,
                    size: Vector2::new(w_decal, h_decal),
                    layer,
                    tilt: 0.0,
                    flip_h,
                    flip_v,
                    is_small: false,
                });
            }
        }
    }
}

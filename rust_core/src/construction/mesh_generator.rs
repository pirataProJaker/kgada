use godot::classes::mesh::{ArrayType, PrimitiveType};
use godot::classes::ArrayMesh;
use godot::prelude::*;

/// Generador de mallas base unitarias para el sistema de GPU Hardware Instancing (`MultiMesh`).
/// Todas las mallas se generan con coordenadas UV normalizadas [0, 1] en cada cara de 1x1m,
/// listas para recibir el arte/texturas del futuro editor Paint o mapas de texturas personalizadas.
pub struct ConstructionMeshGenerator;

impl ConstructionMeshGenerator {
    /// Genera una losa de piso unitaria (1.0m x 0.20m x 1.0m) centrada en XZ con base en Y=0.
    pub fn create_unit_floor_mesh() -> Gd<ArrayMesh> {
        let hx = 0.5;
        let hy = 0.10;
        let hz = 0.5;
        Self::create_box_mesh(hx, hy, hz)
    }

    /// Genera un bloque de pared unitario (1.0m x 1.0m x 0.2m espesor) centrado en X con base en Y=0.
    pub fn create_unit_wall_mesh() -> Gd<ArrayMesh> {
        let hx = 0.5;
        let hy = 0.5;
        let hz = 0.10;
        Self::create_box_mesh(hx, hy, hz)
    }

    /// Genera un marco de puerta unitario normalizado (ancho 1.0m, alto 1.0m, espesor 0.22m acorde al muro).
    pub fn create_unit_door_frame_mesh() -> Gd<ArrayMesh> {
        let mut mesh = ArrayMesh::new_gd();
        let mut vertices = PackedVector3Array::new();
        let mut normals = PackedVector3Array::new();
        let mut uvs = PackedVector2Array::new();

        // 3 piezas de marco: jamba izquierda, jamba derecha y dintel superior. La base queda abierta al piso.
        let post_w = 0.08;
        let lintel_h = 0.06;
        let d = 0.22; // Abarca los 0.20m del muro con ligero resalte elegante de 1cm a cada lado
        let w = 1.00;
        let h = 1.00;

        // Jamba izquierda
        Self::append_box_quads(
            Vector3::new(-w * 0.5 + post_w * 0.5, h * 0.5, 0.0),
            post_w * 0.5, h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        // Jamba derecha
        Self::append_box_quads(
            Vector3::new(w * 0.5 - post_w * 0.5, h * 0.5, 0.0),
            post_w * 0.5, h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        // Dintel superior
        Self::append_box_quads(
            Vector3::new(0.0, h - lintel_h * 0.5, 0.0),
            (w - post_w * 2.0) * 0.5, lintel_h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        let mut arrays = VarArray::new();
        for _ in 0..ArrayType::MAX.ord() {
            arrays.push(&Variant::nil());
        }
        arrays.set(ArrayType::VERTEX.ord() as usize, &vertices.to_variant());
        arrays.set(ArrayType::NORMAL.ord() as usize, &normals.to_variant());
        arrays.set(ArrayType::TEX_UV.ord() as usize, &uvs.to_variant());

        mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);
        mesh
    }

    /// Genera un marco de ventana unitario normalizado (1.0m x 1.0m exterior, espesor 0.22m, con 1 solo hueco limpio central).
    pub fn create_unit_window_frame_mesh() -> Gd<ArrayMesh> {
        let mut mesh = ArrayMesh::new_gd();
        let mut vertices = PackedVector3Array::new();
        let mut normals = PackedVector3Array::new();
        let mut uvs = PackedVector2Array::new();

        let post_w = 0.06;
        let lintel_h = 0.06;
        let sill_h = 0.06;
        let d = 0.22;
        let w = 1.00;
        let h = 1.00;

        // Jamba izquierda
        Self::append_box_quads(
            Vector3::new(-w * 0.5 + post_w * 0.5, h * 0.5, 0.0),
            post_w * 0.5, h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        // Jamba derecha
        Self::append_box_quads(
            Vector3::new(w * 0.5 - post_w * 0.5, h * 0.5, 0.0),
            post_w * 0.5, h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        // Alféizar inferior
        Self::append_box_quads(
            Vector3::new(0.0, sill_h * 0.5, 0.0),
            (w - post_w * 2.0) * 0.5, sill_h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        // Dintel superior
        Self::append_box_quads(
            Vector3::new(0.0, h - lintel_h * 0.5, 0.0),
            (w - post_w * 2.0) * 0.5, lintel_h * 0.5, d * 0.5,
            &mut vertices, &mut normals, &mut uvs,
        );

        let mut arrays = VarArray::new();
        for _ in 0..ArrayType::MAX.ord() {
            arrays.push(&Variant::nil());
        }
        arrays.set(ArrayType::VERTEX.ord() as usize, &vertices.to_variant());
        arrays.set(ArrayType::NORMAL.ord() as usize, &normals.to_variant());
        arrays.set(ArrayType::TEX_UV.ord() as usize, &uvs.to_variant());

        mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);
        mesh
    }

    /// Crea un cuboide con normales y mapeo UV 0..1 por cada una de sus 6 caras.
    fn create_box_mesh(hx: f32, hy: f32, hz: f32) -> Gd<ArrayMesh> {
        let mut mesh = ArrayMesh::new_gd();
        let mut vertices = PackedVector3Array::new();
        let mut normals = PackedVector3Array::new();
        let mut uvs = PackedVector2Array::new();

        Self::append_box_quads(
            Vector3::new(0.0, hy, 0.0),
            hx, hy, hz,
            &mut vertices, &mut normals, &mut uvs,
        );

        let mut arrays = VarArray::new();
        for _ in 0..ArrayType::MAX.ord() {
            arrays.push(&Variant::nil());
        }
        arrays.set(ArrayType::VERTEX.ord() as usize, &vertices.to_variant());
        arrays.set(ArrayType::NORMAL.ord() as usize, &normals.to_variant());
        arrays.set(ArrayType::TEX_UV.ord() as usize, &uvs.to_variant());

        mesh.add_surface_from_arrays(PrimitiveType::TRIANGLES, &arrays);
        mesh
    }

    /// Helper para generar 6 caras (12 triángulos) con centro `center` y radios medios `(hx, hy, hz)`.
    fn append_box_quads(
        center: Vector3,
        hx: f32, hy: f32, hz: f32,
        verts: &mut PackedVector3Array,
        norms: &mut PackedVector3Array,
        uvs: &mut PackedVector2Array,
    ) {
        let c = center;
        // 8 esquinas
        let p0 = c + Vector3::new(-hx, -hy, -hz);
        let p1 = c + Vector3::new(hx, -hy, -hz);
        let p2 = c + Vector3::new(hx, hy, -hz);
        let p3 = c + Vector3::new(-hx, hy, -hz);
        let p4 = c + Vector3::new(-hx, -hy, hz);
        let p5 = c + Vector3::new(hx, -hy, hz);
        let p6 = c + Vector3::new(hx, hy, hz);
        let p7 = c + Vector3::new(-hx, hy, hz);

        // Cara Frontal (+Z)
        Self::add_quad(p4, p5, p6, p7, Vector3::new(0.0, 0.0, 1.0), verts, norms, uvs);
        // Cara Trasera (-Z)
        Self::add_quad(p1, p0, p3, p2, Vector3::new(0.0, 0.0, -1.0), verts, norms, uvs);
        // Cara Superior (+Y)
        Self::add_quad(p7, p6, p2, p3, Vector3::new(0.0, 1.0, 0.0), verts, norms, uvs);
        // Cara Inferior (-Y)
        Self::add_quad(p0, p1, p5, p4, Vector3::new(0.0, -1.0, 0.0), verts, norms, uvs);
        // Cara Derecha (+X)
        Self::add_quad(p5, p1, p2, p6, Vector3::new(1.0, 0.0, 0.0), verts, norms, uvs);
        // Cara Izquierda (-X)
        Self::add_quad(p0, p4, p7, p3, Vector3::new(-1.0, 0.0, 0.0), verts, norms, uvs);
    }

    fn add_quad(
        v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
        norm: Vector3,
        verts: &mut PackedVector3Array,
        norms: &mut PackedVector3Array,
        uvs: &mut PackedVector2Array,
    ) {
        // Godot 4 Clockwise Front-Face:
        // Triángulo 1: v0, v2, v1
        verts.push(v0); norms.push(norm); uvs.push(Vector2::new(0.0, 1.0));
        verts.push(v2); norms.push(norm); uvs.push(Vector2::new(1.0, 0.0));
        verts.push(v1); norms.push(norm); uvs.push(Vector2::new(1.0, 1.0));

        // Triángulo 2: v0, v3, v2
        verts.push(v0); norms.push(norm); uvs.push(Vector2::new(0.0, 1.0));
        verts.push(v3); norms.push(norm); uvs.push(Vector2::new(0.0, 0.0));
        verts.push(v2); norms.push(norm); uvs.push(Vector2::new(1.0, 0.0));
    }
}

# Directivas del Proyecto Play Sector X

## 1. Sistema de Vegetación y Árboles (Regla Estricta)

- **PROHIBIDO** usar modelos FBX para árboles y pinos (incluyendo `PSX_Forest_AssetCollection_byStarkCrafts.fbx` para árboles, `ForestModelUtils.MODEL_TREE*`, o modelos `tree01.fbx` a `tree36.fbx` de `tree_pack_1.1`).
- **TODO ÁRBOL O PINO** en el juego (bosque natural, chunks de terreno, camellones de avenidas, parques, riberas, patios o lotes baldíos) DEBE generarse única y exclusivamente utilizando el sistema procedural `ProceduralTree` (`res://world/procedural_trees/procedural_tree.gd`).
- Los modelos FBX de rocas, arbustos (`bush*.fbx`), flores o pasto pueden seguir usándose cuando sea necesario.

### Patrón Estándar de Instanciación de Árboles:
```gdscript
var tree := ProceduralTree.new()
# Perfiles disponibles: "classic_oak", "pine_boreal", "autumn_birch", "weeping_willow", "dead_tree", "shrub_sapling"
tree.profile_id = "classic_oak"
tree.tree_seed = randi()
parent_node.add_child(tree)
tree.global_position = spawn_position
```

### Características de `ProceduralTree`:
- **Hiperoptimizado:** Consume solo 2 draw calls por árbol vía `MultiMeshInstance3D` con hardware instancing.
- **LODs automáticos:** 3 niveles de detalle (`LOD0`, `LOD1`, `LOD2`) por distancia de cámara.
- **Sin problemas de pivote o rotación:** La base del tronco está perfectamente ubicada en $y=0$ local sin requerir transformaciones de Blender Z-up.
- **Colisión talable (`ChoppableTree`):** Compatible agregando un `ChoppableTree` (`StaticBody3D`) centrado en el tronco.

## 2. Sistema de Mobiliario y Props (+0 Draw Calls - Motor de Objetos)

- **PROHIBIDO** crear mallas independientes (`MeshInstance3D`) o nuevos `MultiMeshInstance3D` dedicados por cada tipo de mueble o prop nuevo.
- **TODO MUEBLE, ELECTRODOMÉSTICO Y PROP URBANO** debe crearse y renderizarse a través del **Motor de Objetos** (`res://world/object_engine/object_engine.gd`) descomponiéndose matemáticamente en primitivas geométricas base compartidas (Cubo, Cilindro, Cuña/Prisma, Esfera, Cápsula, Bisel).
- **+0 DRAW CALLS GARANTIZADO:** El mundo entero consume una cantidad fija y constante de Draw Calls para todo su mobiliario (exactamente 1 draw call por tipo de primitiva geométrica activa en escena, típicamente de 2 a 4 draw calls para miles de objetos). Agregar un mueble nuevo añade **+0 Draw Calls** al juego.
- **Atlas Inteligente (`Texture2DArray` + `INSTANCE_CUSTOM`):** 
  - La textura se gestiona a través del `Texture2DArray` unificado (`FurnitureTextureManager`).
  - El índice de capa de textura se codifica en `COLOR.r`.
  - Las coordenadas de sub-región UV (recortes para logos, rejillas, displays) se transmiten por instancia mediante `INSTANCE_CUSTOM = Rect2(uv_min, uv_size)` sin fragmentar el lote de dibujo.
- **Alcance y Exclusiones:**
  - **Árboles:** Permanecen en `ProceduralTree` debido a animación de viento por vertex shader y alpha-scissor en follaje.
  - **Carreteras/Asfalto:** Permanecen en su sistema de chunks por frustum culling y tiling UV continuo.
  - **Props de calle y mobiliario interior:** 100% gobernados por el Motor de Objetos.

### Patrón Estándar de Definición de Objeto (Receta):
```gdscript
class_name MiMuebleNuevo
extends ObjectRecipeBase

static func build(builder: ObjectBuilder, base_transform: Transform3D, params: Dictionary = {}) -> void:
    # Estructura principal usando primitivos base y capas del atlas
    builder.add_box(base_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(1.0, 1.0, 1.0), "commercial_cooler", Rect2(0.0, 0.5, 0.5, 0.5))
    builder.add_cylinder(base_transform * Transform3D(Basis.IDENTITY, Vector3(0.4, 0.1, 0.4)), 0.05, 0.2, "commercial_cooler")
```

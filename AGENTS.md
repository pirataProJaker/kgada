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

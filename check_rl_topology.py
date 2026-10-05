import bpy

blend_path = r"c:\Users\PC 1\PSX\assets\models\vehicles\sedan_80s\sedan_modular.blend"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=blend_path)

rl = bpy.data.objects['Part_Door_RL']
print("Part_Door_RL polygons:")
for f in rl.data.polygons:
    print(f"Face {f.index}: Verts={[vi for vi in f.vertices]}")
for v in rl.data.vertices:
    print(f"  v{v.index}: ({v.co.x:.3f}, {v.co.y:.3f}, {v.co.z:.3f})")

# Check which edges are shared and which are open boundary:
edge_face_count = {}
for f in rl.data.polygons:
    for e in f.edge_keys:
        edge_face_count[e] = edge_face_count.get(e, 0) + 1

open_edges = [e for e, c in edge_face_count.items() if c == 1]
print(f"Total open boundary edges: {len(open_edges)}")

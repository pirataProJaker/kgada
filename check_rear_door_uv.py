import bpy

obj = bpy.data.objects['Body']
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

print("\n--- UVs of candidate rear door faces ---")
for fi in [24, 25, 27, 54, 57, 63, 64, 69]:
    p = mesh.polygons[fi]
    print(f"Face {fi:2d}:")
    for li, vi in zip(p.loop_indices, p.vertices):
        uv = uv_layer[li].uv
        v = mesh.vertices[vi]
        print(f"  v{vi:2d} co=({v.co.x:.3f}, {v.co.y:.3f}, {v.co.z:.3f}) uv=({uv.x:.3f}, {uv.y:.3f})")

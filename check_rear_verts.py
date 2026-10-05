import bpy

# Let's inspect the vertices of Face 27 and Face 64, and see which edges they share
obj = bpy.data.objects['Body']
mesh = obj.data

print("\n--- EDGES OF REAR DOOR / QUARTER PANEL ---")
for fi in [24, 25, 27, 54, 57, 63, 64, 69, 71, 72]:
    p = mesh.polygons[fi]
    verts = [mesh.vertices[v] for v in p.vertices]
    print(f"Face {fi:2d}: center=({p.center.x:.3f}, {p.center.y:.3f}, {p.center.z:.3f}) verts={list(p.vertices)}")
    for v in verts:
        print(f"   v{v.index:2d}: ({v.co.x:.3f}, {v.co.y:.3f}, {v.co.z:.3f})")

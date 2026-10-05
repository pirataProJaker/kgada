import bpy

# Load Suspicious Car.blend
obj = bpy.data.objects['Body']
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

# Let's inspect the UVs of the left side faces and print their UV bounds and vertices
side_faces = [1, 3, 4, 8, 9, 10, 13, 17, 19, 21, 22, 23, 24, 25, 27, 29, 32, 54, 55, 56, 57, 59, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 85, 86, 87, 88]

with open(r"c:\Users\PC 1\PSX\side_uv_report.txt", "w") as f:
    for fi in side_faces:
        p = mesh.polygons[fi]
        uvs = [uv_layer[li].uv for li in p.loop_indices]
        f.write(f"Face {fi:2d}: Center=({p.center.x:.2f}, {p.center.y:.2f}, {p.center.z:.2f})\n")
        f.write(f"  Y range: [{min(mesh.vertices[v].co.y for v in p.vertices):.3f} .. {max(mesh.vertices[v].co.y for v in p.vertices):.3f}]\n")
        f.write(f"  Z range: [{min(mesh.vertices[v].co.z for v in p.vertices):.3f} .. {max(mesh.vertices[v].co.z for v in p.vertices):.3f}]\n")
        f.write(f"  U range: [{min(u.x for u in uvs):.3f} .. {max(u.x for u in uvs):.3f}]\n")
        f.write(f"  V range: [{min(u.y for u in uvs):.3f} .. {max(u.y for u in uvs):.3f}]\n")

print("Report written!")

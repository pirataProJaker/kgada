import bpy

# Load Suspicious Car.blend
# Let's inspect all polygons of 'Body' in the original file
obj = bpy.data.objects['Body']
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

# We want to inspect:
# 1. Poly index
# 2. Vertex coordinates (in original Blender coords, where front is -Y or +Y?)
# In the original file:
# Front wheels are at Y = -0.9970 (Front is -Y in original file!)
# Rear wheels are at Y = +0.6118 (Rear is +Y in original file!)
# Let's verify!

with open(r"c:\Users\PC 1\PSX\original_faces_detail.txt", "w") as f:
    f.write("ORIGINAL BODY FACES:\n")
    for i, poly in enumerate(mesh.polygons):
        v_coords = [mesh.vertices[v].co for v in poly.vertices]
        center = poly.center
        uvs = [uv_layer[loop_idx].uv for loop_idx in poly.loop_indices]
        uv_min_u = min(u.x for u in uvs)
        uv_max_u = max(u.x for u in uvs)
        uv_min_v = min(u.y for u in uvs)
        uv_max_v = max(u.y for u in uvs)
        
        f.write(f"Poly {i:3d}: Center=({center.x:6.3f}, {center.y:6.3f}, {center.z:6.3f}) Normal=({poly.normal.x:5.2f}, {poly.normal.y:5.2f}, {poly.normal.z:5.2f}) UV=({uv_min_u:.2f}..{uv_max_u:.2f}, {uv_min_v:.2f}..{uv_max_v:.2f})\n")
        for vi, uv in zip(poly.vertices, uvs):
            co = mesh.vertices[vi].co
            f.write(f"    v{vi:3d}: ({co.x:6.3f}, {co.y:6.3f}, {co.z:6.3f}) uv=({uv.x:.3f}, {uv.y:.3f})\n")

print("Detail written!")

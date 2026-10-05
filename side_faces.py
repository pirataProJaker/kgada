import bpy

obj = bpy.data.objects['Body']
mesh = obj.data
uv_layer = mesh.uv_layers.active.data

print("\n=== SIDE FACES ANALYSIS (Left side X > 0.3) ===")
for i, poly in enumerate(mesh.polygons):
    c = poly.center
    if c.x > 0.3 and poly.normal.x > 0.5:
        # Check Y range
        ys = [mesh.vertices[v].co.y for v in poly.vertices]
        zs = [mesh.vertices[v].co.z for v in poly.vertices]
        uvs = [uv_layer[loop_idx].uv for loop_idx in poly.loop_indices]
        u_mid = sum(u.x for u in uvs)/len(uvs)
        v_mid = sum(u.y for u in uvs)/len(uvs)
        print(f"Face {i:3d}: Y=[{min(ys):6.3f}..{max(ys):6.3f}] Z=[{min(zs):6.3f}..{max(zs):6.3f}] UV_center=({u_mid:.3f}, {v_mid:.3f}) VertCount={len(poly.vertices)}")


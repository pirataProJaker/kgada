import bpy

obj = bpy.data.objects['Body']
mesh = obj.data

print("\n--- LEFT SIDE FACES (X > 0.2, between Y = -1.5 and +1.4) ---")
for i, poly in enumerate(mesh.polygons):
    c = poly.center
    if c.x > 0.2:
        print(f"Face {i:3d}: Center=({c.x:6.3f}, {c.y:6.3f}, {c.z:6.3f}) Normal=({poly.normal.x:5.2f}, {poly.normal.y:5.2f}, {poly.normal.z:5.2f}) Area={poly.area:.4f}")

print("\n--- TOP / HOOD / ROOF / TRUNK FACES (|X| < 0.35, Normal.Z > 0.3) ---")
for i, poly in enumerate(mesh.polygons):
    c = poly.center
    if abs(c.x) < 0.35 and poly.normal.z > 0.3:
        print(f"Face {i:3d}: Center=({c.x:6.3f}, {c.y:6.3f}, {c.z:6.3f}) Normal=({poly.normal.x:5.2f}, {poly.normal.y:5.2f}, {poly.normal.z:5.2f}) Area={poly.area:.4f}")

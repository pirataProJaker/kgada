import bpy

# Load Suspicious Car.blend
obj = bpy.data.objects['Body']
mesh = obj.data

print("Total vertices:", len(mesh.vertices))
print("Total polygons:", len(mesh.polygons))

with open(r"c:\Users\PC 1\PSX\mesh_analysis.txt", "w") as f:
    f.write(f"Total vertices: {len(mesh.vertices)}\n")
    f.write(f"Total polygons: {len(mesh.polygons)}\n")
    for i, poly in enumerate(mesh.polygons):
        verts = [mesh.vertices[v].co for v in poly.vertices]
        center = poly.center
        f.write(f"Poly {i}: center=({center.x:.3f}, {center.y:.3f}, {center.z:.3f}) normal=({poly.normal.x:.2f}, {poly.normal.y:.2f}, {poly.normal.z:.2f}) verts={list(poly.vertices)}\n")
        for vi in poly.vertices:
            vco = mesh.vertices[vi].co
            f.write(f"    v{vi}: ({vco.x:.3f}, {vco.y:.3f}, {vco.z:.3f})\n")

print("Analysis written to mesh_analysis.txt")

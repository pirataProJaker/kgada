import bpy
import numpy as np

# Load the user-marked image
img = bpy.data.images.load(r"c:\Users\PC 1\PSX\guia_corte_marcada_usuario.png")
width, height = img.size
print(f"Image dimensions: {width} x {height}")

# In guia_corte_lateral_con_malla.png:
# cam_obj.location = (0.50, 0.70, 2.0)
# cam_data.ortho_scale = 1.0 (width in UV = 1.0, height in UV = 1.0 * height/width = 800/2000 = 0.40)
# So UV X range is [0.0, 1.0], UV Y range is [0.70 - 0.20, 0.70 + 0.20] = [0.50, 0.90]

pixels = np.array(img.pixels[:]).reshape((height, width, 4))

# Red pixels: R > 0.7, G < 0.2, B < 0.2
red_mask = (pixels[:, :, 0] > 0.6) & (pixels[:, :, 1] < 0.25) & (pixels[:, :, 2] < 0.25)
y_indices, x_indices = np.where(red_mask)

print(f"Total red pixels found: {len(x_indices)}")

# Convert to UV coordinates:
# px_x in [0, width-1] -> U in [0.0, 1.0]
# px_y in [0, height-1] -> V in [0.50, 0.90]
u_coords = x_indices / width
v_coords = 0.50 + (y_indices / height) * 0.40

# Let's group red pixels into distinct vertical/diagonal lines by X coordinate
# Front door front seam: X around 0.25 - 0.35
# B-pillar seam: X around 0.50 - 0.55
# Rear door back seam: X around 0.65 - 0.75

front_mask = (u_coords >= 0.20) & (u_coords <= 0.45)
mid_mask = (u_coords >= 0.48) & (u_coords <= 0.55)
rear_mask = (u_coords >= 0.60) & (u_coords <= 0.76)

print("\n--- FRONT DOOR RED LINE ---")
print(f"U min: {u_coords[front_mask].min():.4f}, U max: {u_coords[front_mask].max():.4f}")
print(f"V min: {v_coords[front_mask].min():.4f}, V max: {v_coords[front_mask].max():.4f}")
# Find vertical seam at bottom (V < 0.70)
front_bottom = front_mask & (v_coords < 0.70)
if np.any(front_bottom):
    print(f"Front vertical seam U average: {u_coords[front_bottom].mean():.4f} (pixel X: {x_indices[front_bottom].mean():.1f})")

print("\n--- B-PILLAR RED LINE ---")
print(f"U min: {u_coords[mid_mask].min():.4f}, U max: {u_coords[mid_mask].max():.4f}")
print(f"V min: {v_coords[mid_mask].min():.4f}, V max: {v_coords[mid_mask].max():.4f}")
b_bottom = mid_mask & (v_coords < 0.70)
if np.any(b_bottom):
    print(f"B-pillar seam U average: {u_coords[b_bottom].mean():.4f} (pixel X: {x_indices[b_bottom].mean():.1f})")

print("\n--- REAR DOOR BACK RED LINE ---")
print(f"U min: {u_coords[rear_mask].min():.4f}, U max: {u_coords[rear_mask].max():.4f}")
print(f"V min: {v_coords[rear_mask].min():.4f}, V max: {v_coords[rear_mask].max():.4f}")

# Sample the rear curve points from top (V ~ 0.85) to bottom (V ~ 0.55)
rear_pts = []
for v_slice in np.linspace(0.55, 0.85, 30):
    slice_mask = rear_mask & (np.abs(v_coords - v_slice) < 0.007)
    if np.any(slice_mask):
        u_mean = u_coords[slice_mask].mean()
        rear_pts.append((u_mean, v_slice))

print("\nRear cut curve samples (U, V):")
for u, v in rear_pts:
    print(f"  V={v:.3f} -> U={u:.4f} (texture pixel X={u*256:.1f}, Y={v*256:.1f})")

import struct
import zlib

def read_png(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    idx = 8
    idat = bytearray()
    width = height = 0
    while idx < len(data):
        length, chunk_type = struct.unpack('>I4s', data[idx:idx+8])
        chunk_data = data[idx+8:idx+8+length]
        if chunk_type == b'IHDR':
            width, height, bit_depth, color_type = struct.unpack('>IIBB', chunk_data[:10])
        elif chunk_type == b'IDAT':
            idat.extend(chunk_data)
        elif chunk_type == b'IEND':
            break
        idx += 12 + length
    raw = zlib.decompress(idat)
    # RGB or RGBA?
    bpp = 4 if color_type == 6 else 3
    stride = width * bpp
    img = []
    raw_idx = 0
    prev_row = bytearray(stride)
    for y in range(height):
        filter_type = raw[raw_idx]
        raw_idx += 1
        row = bytearray(raw[raw_idx:raw_idx+stride])
        raw_idx += stride
        # De-filter
        if filter_type == 1: # Sub
            for x in range(bpp, stride):
                row[x] = (row[x] + row[x-bpp]) & 0xFF
        elif filter_type == 2: # Up
            for x in range(stride):
                row[x] = (row[x] + prev_row[x]) & 0xFF
        elif filter_type == 3: # Average
            for x in range(stride):
                left = row[x-bpp] if x >= bpp else 0
                row[x] = (row[x] + ((left + prev_row[x]) >> 1)) & 0xFF
        elif filter_type == 4: # Paeth
            for x in range(stride):
                a = row[x-bpp] if x >= bpp else 0
                b = prev_row[x]
                c = prev_row[x-bpp] if x >= bpp else 0
                p = a + b - c
                pa = abs(p - a)
                pb = abs(p - b)
                pc = abs(p - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[x] = (row[x] + pr) & 0xFF
        prev_row = row
        img.append(row)
    return width, height, bpp, img

w, h, bpp, img = read_png("assets/textures/vehicles/sedan_80s/sedan_atlas.png")
print(f"PNG Loaded: {w}x{h}, bpp={bpp}")

def get_pixel(x, y):
    idx = x * bpp
    return tuple(img[y][idx:idx+3])

# Check side profile features:
print("\n=== SIDE PROFILE SCAN (Y: 35..100) ===")
# Arch cutouts (look for white/transparent / background near Y=75..95)
for y in [70, 75, 80, 85, 90, 95]:
    front_cutout = []
    rear_cutout = []
    for x in range(3, 253):
        r, g, b = get_pixel(x, y)
        if r > 240 and g > 240 and b > 240:
            if x < 120:
                front_cutout.append(x)
            else:
                rear_cutout.append(x)
    f_str = f"[{min(front_cutout)}, {max(front_cutout)}]" if front_cutout else "None"
    r_str = f"[{min(rear_cutout)}, {max(rear_cutout)}]" if rear_cutout else "None"
    print(f"Y={y}: Front Arch={f_str}, Rear Arch={r_str}")

# Check door cutlines and pillars at Y=60 (beltline) and Y=50 (windows)
print("\n=== TOP PROFILE SCAN (Y: 106..150) ===")
for x in range(0, 256, 16):
    r, g, b = get_pixel(x, 130)
    print(f"X={x:3d}: ({r:3d}, {g:3d}, {b:3d})")

#!/usr/bin/env python3
"""Bóc một file .glb ra thành các con số quyết định ngân sách nội dung.

Đọc chunk JSON của glTF-Binary và đối chiếu với ngân sách đã chốt cho máy
<= 4 GB RAM. Không phụ thuộc thư viện ngoài — chỉ struct + json, vì script này
sẽ được bàn giao cho đội CMS và họ không nên phải cài gì.
"""
import json
import struct
import sys

# Ngân sách đã chốt cho máy thực địa <= 4 GB.
BUDGET = {
    "triangles": 100_000,
    "texture_edge": 1024,
    "materials": 4,
    "bytes": 4 * 1024 * 1024,
}

# Số byte cho mỗi kiểu chỉ số của accessor (componentType -> bytes).
COMPONENT_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}


def read_glb(path):
    """Trả về (dict JSON của glTF, bytes của chunk BIN)."""
    with open(path, "rb") as f:
        magic, version, _ = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            sys.exit(f"{path}: không phải glTF-Binary")
        gltf, bin_chunk = None, b""
        while True:
            header = f.read(8)
            if len(header) < 8:
                break
            length, kind = struct.unpack("<II", header)
            data = f.read(length)
            if kind == 0x4E4F534A:      # 'JSON'
                gltf = json.loads(data)
            elif kind == 0x004E4942:    # 'BIN\0'
                bin_chunk = data
        return gltf, bin_chunk, version


def image_size(blob):
    """(rộng, cao) đọc từ header PNG/JPEG/KTX2/WebP, hoặc None.

    WebP là chỗ ĐÃ TỪNG bỏ lọt: gltf-transform xuất texture sang WebP
    (EXT_texture_webp), hàm này không đọc được, tổng pixel tính ra 0, và một
    model vượt trần texture ĐI QUA bài kiểm ngân sách. Một bộ kiểm im lặng cho
    qua thì tệ hơn không có bộ kiểm nào, vì nó tạo ra niềm tin sai.
    """
    # PNG
    if blob[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", blob[16:24])

    # KTX2
    if blob[:12] == b"\xabKTX 20\xbb\r\n\x1a\n":
        return struct.unpack("<II", blob[20:28])

    # WebP — RIFF....WEBP, rồi một trong ba loại chunk.
    if blob[:4] == b"RIFF" and blob[8:12] == b"WEBP":
        chunk = blob[12:16]
        if chunk == b"VP8X":          # mở rộng: khổ canvas, 24-bit trừ 1
            w = int.from_bytes(blob[24:27], "little") + 1
            h = int.from_bytes(blob[27:30], "little") + 1
            return w, h
        if chunk == b"VP8L":          # không mất dữ liệu: 14-bit trừ 1, đóng gói
            bits = int.from_bytes(blob[21:25], "little")
            return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
        if chunk == b"VP8 ":          # có mất dữ liệu
            # 8 byte header chunk + 3 byte frame tag, rồi start code 9d 01 2a
            if blob[23:26] == b"\x9d\x01\x2a":
                w = int.from_bytes(blob[26:28], "little") & 0x3FFF
                h = int.from_bytes(blob[28:30], "little") & 0x3FFF
                return w, h

    # JPEG — đi tìm marker SOF
    if blob[:2] == b"\xff\xd8":
        i = 2
        while i < len(blob) - 9:
            if blob[i] != 0xFF:
                i += 1
                continue
            marker = blob[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                          0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                h, w = struct.unpack(">HH", blob[i + 5:i + 9])
                return w, h
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            (seg,) = struct.unpack(">H", blob[i + 2:i + 4])
            i += 2 + seg
    return None

def triangles_of(gltf):
    """Tổng số tam giác, cộng theo TỪNG LẦN node dùng mesh.

    Một mesh được nhiều node tham chiếu thì GPU vẽ nó nhiều lần — đếm mesh một
    lần sẽ báo thiếu, và đó đúng là chỗ một model 'nhẹ trên giấy' hoá nặng lúc
    chạy.
    """
    per_mesh = []
    for mesh in gltf.get("meshes", []):
        total = 0
        for prim in mesh.get("primitives", []):
            mode = prim.get("mode", 4)
            if mode != 4:               # chỉ TRIANGLES mới tính là tam giác
                continue
            if "indices" in prim:
                count = gltf["accessors"][prim["indices"]]["count"]
            else:
                pos = prim.get("attributes", {}).get("POSITION")
                if pos is None:
                    continue
                count = gltf["accessors"][pos]["count"]
            total += count // 3
        per_mesh.append(total)

    uses = [0] * len(per_mesh)
    for node in gltf.get("nodes", []):
        if "mesh" in node and node["mesh"] < len(uses):
            uses[node["mesh"]] += 1
    # Mesh không node nào dùng vẫn tính 1 lần (một số scene dựng qua extension).
    drawn = sum(t * max(u, 1) for t, u in zip(per_mesh, uses))
    return drawn, sum(per_mesh)


def report(path):
    gltf, bin_chunk, version = read_glb(path)
    import os
    size = os.path.getsize(path)

    drawn, unique = triangles_of(gltf)
    materials = len(gltf.get("materials", []))
    exts = set(gltf.get("extensionsUsed", []))

    print(f"\n=== {os.path.basename(path)} ===")
    print(f"  glTF version   : {version}")
    print(f"  Dung lượng     : {size:,} B ({size / 1024 / 1024:.2f} MB)"
          f"   [trần {BUDGET['bytes'] / 1024 / 1024:.0f} MB]")
    print(f"  Tam giác vẽ    : {drawn:,}"
          f"   [trần {BUDGET['triangles']:,}]"
          + (f"   (lưới gốc {unique:,}, có instancing)" if drawn != unique else ""))
    print(f"  Mesh / node    : {len(gltf.get('meshes', []))} / {len(gltf.get('nodes', []))}")
    print(f"  Material       : {materials}   [trần {BUDGET['materials']}]")
    print(f"  Animation      : {len(gltf.get('animations', []))}")
    print(f"  Skin           : {len(gltf.get('skins', []))}")
    print(f"  Extension      : {', '.join(sorted(exts)) or '(không)'}")

    # ---- texture: nguồn tiêu thụ RAM lớn nhất lúc chạy ----
    views = gltf.get("bufferViews", [])
    total_px = 0
    print(f"  Ảnh ({len(gltf.get('images', []))}):")
    for i, img in enumerate(gltf.get("images", [])):
        mime = img.get("mimeType", "?")
        dims = None
        if "bufferView" in img:
            bv = views[img["bufferView"]]
            off = bv.get("byteOffset", 0)
            blob = bin_chunk[off:off + bv["byteLength"]]
            dims = image_size(blob)
            nbytes = bv["byteLength"]
        else:
            nbytes = 0
        if dims:
            w, h = dims
            total_px += w * h
            over = "  ⚠ VƯỢT" if max(w, h) > BUDGET["texture_edge"] else ""
            print(f"    [{i}] {w}×{h}  {mime}  {nbytes:,} B{over}")
        else:
            print(f"    [{i}] ?×?  {mime}  {nbytes:,} B  (uri ngoài?)")

    # RGBA8 chưa nén + mipmap (~1.33×) là cách GPU thật sự giữ texture.
    vram = total_px * 4 * 1.33 / 1024 / 1024
    print(f"  → VRAM texture ước tính: {vram:.1f} MB (RGBA8 + mipmap)")

    # ---- kết luận theo ngân sách ----
    fails = []
    if size > BUDGET["bytes"]:
        fails.append("dung lượng")
    if drawn > BUDGET["triangles"]:
        fails.append("tam giác")
    if materials > BUDGET["materials"]:
        fails.append("material")
    if "KHR_draco_mesh_compression" not in exts:
        fails.append("thiếu nén Draco")
    if "KHR_texture_basisu" not in exts:
        fails.append("thiếu KTX2/Basis")
    print("  KẾT LUẬN: " + ("ĐẠT" if not fails else "TRƯỢT — " + ", ".join(fails)))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        report(p)

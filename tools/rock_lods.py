"""Vertex-clustering decimation of a .rock mesh to a target triangle count (field and chip tiers).

The .rock format: uint32 vertex count, uint32 index count, then float32 positions (3), normals (3),
tangents (4), uvs (2) per vertex, then int32 indices. Clusters on a cubic grid; each cluster keeps
the attributes of the vertex nearest its mean; normals are recomputed from the kept faces."""
import struct
import sys
import numpy as np


def read(path):
    data = open(path, "rb").read()
    nv, ni = struct.unpack("<II", data[:8])
    off = 8
    def take(count, width):
        nonlocal off
        arr = np.frombuffer(data[off:off + count * width * 4], dtype="<f4").reshape(-1, width)
        off += count * width * 4
        return arr
    v = take(nv, 3); n = take(nv, 3); t = take(nv, 4); uv = take(nv, 2)
    i = np.frombuffer(data[off:off + ni * 4], dtype="<i4").reshape(-1, 3)
    return v, n, t, uv, i


def cluster(v, n, t, uv, tris, cell):
    keys = np.floor((v - v.min(0)) / cell).astype(np.int64)
    flat = keys[:, 0] * 1000003 + keys[:, 1] * 1009 + keys[:, 2]
    uniq, inverse = np.unique(flat, return_inverse=True)
    count = len(uniq)
    sums = np.zeros((count, 3)); np.add.at(sums, inverse, v)
    hits = np.bincount(inverse, minlength=count).astype(float)
    centre = sums / hits[:, None]
    dist = np.linalg.norm(v - centre[inverse], axis=1)
    order = np.lexsort((dist, inverse))
    first = np.ones(len(order), bool); first[1:] = inverse[order][1:] != inverse[order][:-1]
    rep = order[first]
    new_tris = inverse[tris]
    keep = (new_tris[:, 0] != new_tris[:, 1]) & (new_tris[:, 1] != new_tris[:, 2]) & (new_tris[:, 0] != new_tris[:, 2])
    new_tris = new_tris[keep]
    canon = np.sort(new_tris, axis=1)
    _, first_face = np.unique(canon, axis=0, return_index=True)
    new_tris = new_tris[np.sort(first_face)]
    pos = centre
    fn = np.cross(pos[new_tris[:, 1]] - pos[new_tris[:, 0]], pos[new_tris[:, 2]] - pos[new_tris[:, 0]])
    normals = np.zeros_like(pos)
    for k in range(3):
        np.add.at(normals, new_tris[:, k], fn)
    length = np.linalg.norm(normals, axis=1, keepdims=True); length[length == 0] = 1
    normals = normals / length
    # Orientation: keep the source winding (the scan's normals point out); flip faces that disagree.
    src_n = n[rep]
    face_src = src_n[new_tris].sum(axis=1)
    flip = (fn * face_src).sum(axis=1) < 0
    new_tris[flip] = new_tris[flip][:, ::-1]
    if flip.any():
        fn = np.cross(pos[new_tris[:, 1]] - pos[new_tris[:, 0]], pos[new_tris[:, 2]] - pos[new_tris[:, 0]])
        normals = np.zeros_like(pos)
        for k in range(3):
            np.add.at(normals, new_tris[:, k], fn)
        length = np.linalg.norm(normals, axis=1, keepdims=True); length[length == 0] = 1
        normals = normals / length
    used = np.unique(new_tris)
    remap = -np.ones(count, np.int64); remap[used] = np.arange(len(used))
    return (pos[used].astype("<f4"), normals[used].astype("<f4"), t[rep][used].astype("<f4"),
            uv[rep][used].astype("<f4"), remap[new_tris].astype("<i4"))


def write(path, v, n, t, uv, i):
    with open(path, "wb") as f:
        f.write(struct.pack("<II", len(v), i.size))
        for arr in (v, n, t, uv, i):
            f.write(np.ascontiguousarray(arr).tobytes())


def main():
    source, out, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
    v, n, t, uv, tris = read(source)
    lo, hi = 0.002, 0.5
    best = None
    for _ in range(40):
        cell = (lo * hi) ** 0.5
        result = cluster(v, n, t, uv, tris, cell)
        count = len(result[4])
        if best is None or abs(count - target) < abs(len(best[4]) - target):
            best = result
        if count > target:
            lo = cell
        else:
            hi = cell
    write(out, *best)
    print(f"{out}: {len(best[4])} triangles, {len(best[0])} vertices (target {target})")


main()

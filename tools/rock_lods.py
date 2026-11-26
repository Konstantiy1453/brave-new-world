"""Vertex-clustering decimation of a .rock mesh to a target triangle count (play, field and chip tiers).

The .rock format: uint32 vertex count, uint32 index count, then float32 positions (3), normals (3),
tangents (4), uvs (2) per vertex, then int32 indices. Clusters on a cubic grid, one cluster per cell
and UV island (the scan's texture seams are split vertices, so each island is a connected part of
the index graph): vertices never merge across a seam, so texture coordinates stay on their island.
Every vertex in a cell takes the cell's mean position, whatever its island, so the islands still
meet without cracks; each cluster keeps the texture coordinates and tangent of its vertex nearest
the cell's mean; normals are recomputed from the kept faces and shared across a cell's islands."""
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


def islands(count, tris):
    """The connected parts of the index graph: one id per vertex (union-find over triangle edges)."""
    parent = np.arange(count)

    def find(a):
        root = a
        while parent[root] != root:
            root = parent[root]
        while parent[a] != root:
            parent[a], a = root, parent[a]
        return root

    for a, b, c in tris:
        for x, y in ((a, b), (b, c)):
            rx, ry = find(x), find(y)
            if rx != ry:
                parent[ry] = rx
    return np.array([find(k) for k in range(count)])


def cluster(v, n, t, uv, tris, cell, island):
    keys = np.floor((v - v.min(0)) / cell).astype(np.int64)
    cell_key = keys[:, 0] * 1000003 + keys[:, 1] * 1009 + keys[:, 2]
    cells, cell_of = np.unique(cell_key, return_inverse=True)
    sums = np.zeros((len(cells), 3)); np.add.at(sums, cell_of, v)
    hits = np.bincount(cell_of, minlength=len(cells)).astype(float)
    cell_centre = sums / hits[:, None]
    _, inverse = np.unique(cell_of.astype(np.int64) * (int(island.max()) + 1) + island, return_inverse=True)
    count = int(inverse.max()) + 1
    cluster_cell = np.zeros(count, np.int64); cluster_cell[inverse] = cell_of
    dist = np.linalg.norm(v - cell_centre[cell_of], axis=1)
    order = np.lexsort((dist, inverse))
    first = np.ones(len(order), bool); first[1:] = inverse[order][1:] != inverse[order][:-1]
    rep = order[first]
    new_tris = inverse[tris]
    keep = (new_tris[:, 0] != new_tris[:, 1]) & (new_tris[:, 1] != new_tris[:, 2]) & (new_tris[:, 0] != new_tris[:, 2])
    new_tris = new_tris[keep]
    canon = np.sort(new_tris, axis=1)
    _, first_face = np.unique(canon, axis=0, return_index=True)
    new_tris = new_tris[np.sort(first_face)]
    pos = cell_centre[cluster_cell]
    fn = np.cross(pos[new_tris[:, 1]] - pos[new_tris[:, 0]], pos[new_tris[:, 2]] - pos[new_tris[:, 0]])
    # Orientation: Godot's front faces wind clockwise, so a front face's right-hand cross product
    # points into the rock, against the scan's outward normals; flip any face that disagrees.
    src_n = n[rep]
    face_src = src_n[new_tris].sum(axis=1)
    flip = (fn * face_src).sum(axis=1) > 0
    new_tris[flip] = new_tris[flip][:, ::-1]
    fn[flip] = -fn[flip]
    # Normals per cell (outward, against the winding's cross product), shared by its islands, so
    # the seams do not show in the shading.
    cell_normals = np.zeros((len(cells), 3))
    for k in range(3):
        np.add.at(cell_normals, cluster_cell[new_tris[:, k]], -fn)
    length = np.linalg.norm(cell_normals, axis=1, keepdims=True); length[length == 0] = 1
    normals = (cell_normals / length)[cluster_cell]
    # Tangents kept from the representative, made square to the new normals (handedness kept).
    tangents = t[rep].astype(float)
    along = tangents[:, :3] - normals * (tangents[:, :3] * normals).sum(axis=1, keepdims=True)
    size = np.linalg.norm(along, axis=1, keepdims=True); size[size == 0] = 1
    tangents[:, :3] = along / size
    used = np.unique(new_tris)
    remap = -np.ones(count, np.int64); remap[used] = np.arange(len(used))
    return (pos[used].astype("<f4"), normals[used].astype("<f4"), tangents[used].astype("<f4"),
            uv[rep][used].astype("<f4"), remap[new_tris].astype("<i4"))


def write(path, v, n, t, uv, i):
    with open(path, "wb") as f:
        f.write(struct.pack("<II", len(v), i.size))
        for arr in (v, n, t, uv, i):
            f.write(np.ascontiguousarray(arr).tobytes())


def main():
    source, out, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
    v, n, t, uv, tris = read(source)
    island = islands(len(v), tris)
    print(f"{source}: {len(tris)} triangles, {len(v)} vertices, {len(np.unique(island))} UV islands")
    lo, hi = 0.002, 0.5
    best = None
    for _ in range(40):
        cell = (lo * hi) ** 0.5
        result = cluster(v, n, t, uv, tris, cell, island)
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

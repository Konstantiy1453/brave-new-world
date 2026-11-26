"""Compare applied game sources and optional review captures with the accepted baseline."""

import argparse
import hashlib
import json
from pathlib import Path
import sys


def digest(path, normalize=False):
    data = path.read_bytes()
    if normalize:
        data = data.replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd(), help="repository root with game/")
    parser.add_argument("--renders", type=Path, help="directory populated by render_review.gd")
    parser.add_argument("--exact-png", action="store_true", help="require original PNG byte hashes")
    args = parser.parse_args()
    if args.exact_png and args.renders is None:
        parser.error("--exact-png requires --renders")
    package = Path(__file__).resolve().parent
    manifest = json.loads((package / "provenance.json").read_text(encoding="utf-8"))
    failures = []
    files = manifest["hashes_sha256_lf_text_binary_as_stored"]
    for name, expected in files.items():
        path = args.root / name
        if not path.is_file() or digest(path, path.suffix not in {".png", ".bin"}) != expected:
            failures.append(name)
    different_png = []
    if args.renders:
        for world in manifest["approved_worlds"]:
            seed = world["seed"]
            stem = args.renders / f"world_{seed}"
            details, png = stem.with_suffix(".json"), stem.with_suffix(".png")
            if not details.is_file() or not png.is_file():
                failures.append(f"missing capture pair for {seed}")
                continue
            info = json.loads(details.read_text(encoding="utf-8"))
            if (info.get("seed") != seed or info.get("hash") != world["world_hash"]
                or info.get("version") != "CC-GEO-2.3" or info.get("atlas") != "(1536.0, 768.0)"):
                failures.append(f"world metadata for {seed}")
            header = png.read_bytes()[:24]
            if (header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR"
                or int.from_bytes(header[16:20], "big") != 2048
                or int.from_bytes(header[20:24], "big") != 1024):
                failures.append(f"invalid PNG header or dimensions for {seed}")
            elif digest(png) != world["atlas_render_png_sha256"]:
                different_png.append(seed)
        print(f"{len(manifest['approved_worlds'])} capture pairs checked. PNG byte differences: {different_png}")
        if args.exact_png and different_png:
            failures.append("PNG byte identity")
    if failures:
        print("Mismatches:\n" + "\n".join(failures), file=sys.stderr)
        return 1
    print(f"{len(files)} applied terrain source files match the approved baseline.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

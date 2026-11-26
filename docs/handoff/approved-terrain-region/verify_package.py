"""Verify the published handoff files, including decoded Git LFS contents."""
from __future__ import annotations

from hashlib import sha256
from pathlib import Path
import json


def file_digest(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    root = Path(__file__).resolve().parent
    records = json.loads((root / "manifest.json").read_text(encoding="utf-8"))["files"]
    problems = []
    for name, record in records.items():
        path = root / name
        if not path.is_file():
            problems.append(f"missing: {name}")
        elif path.stat().st_size != record["bytes"] or file_digest(path) != record["sha256"]:
            with path.open("rb") as source:
                pointer = source.read(48).startswith(b"version https://git-lfs.github.com/spec/")
            reason = "Git LFS pointer; run git lfs pull" if pointer else "content differs"
            problems.append(f"{reason}: {name}")
    if problems:
        print("\n".join(problems))
        return 1
    print(f"Verified {len(records)} files and {sum(r['bytes'] for r in records.values()):,} bytes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

"""Packages build\\v17 and the 1.7 source into delivery\\v17, after checking the export is clean."""
from pathlib import Path
import hashlib
import json
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build" / "v17"
OUT = ROOT / "delivery" / "v17"
VERSION = "1.8.0"
GAME_ZIP = OUT / f"ColonyCharter-{VERSION}-Windows-x64.zip"
SOURCE_ZIP = OUT / f"ColonyCharter-{VERSION}-Source.zip"
# Nothing used only for testing belongs in the export.
FORBIDDEN_PREFIXES = ("tests/", "data/v16/", "data/acceptance", "data/v17/acceptance", "ui/capture_suite")
SOURCE_FOLDERS = ["game", "docs/v17", "docs/superpowers/plans"]
SOURCE_FILES = [
    "README.md",
    "CHANGELOG.md",
    "CLAUDE.md",
    ".gitattributes",
    ".gitignore",
    "docs/GODOT_LICENSE.txt",
    "docs/GODOT_COPYRIGHT.txt",
]
SKIPPED_PARTS = {".godot", "__pycache__", "_tmp"}
SKIPPED_SUFFIXES = {".tmp", ".bak"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def pck_files():
    """The paths in the PCK's directory, format 3 (Godot 4.5). The raw bytes also hold the uid
    cache, which names every script in the project, so a text search would prove nothing."""
    data = (BUILD / "ColonyCharter.pck").read_bytes()
    magic, version = struct.unpack_from("<4sI", data, 0)
    if magic != b"GDPC" or version != 3:
        raise SystemExit(f"Unexpected PCK header: {magic} {version}")
    offset = struct.unpack_from("<Q", data, 32)[0]
    count = struct.unpack_from("<I", data, offset)[0]
    offset += 4
    paths = []
    for _ in range(count):
        length = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        paths.append(data[offset : offset + length].rstrip(b"\0").decode("utf-8"))
        # Path, then offset and size (8 each), MD5 (16) and flags (4).
        offset += length + 8 + 8 + 16 + 4
    return paths


def check_pck():
    paths = [path.removeprefix("res://") for path in pck_files()]
    found = [path for path in paths if path.startswith(FORBIDDEN_PREFIXES)]
    if found:
        raise SystemExit(f"Test material inside the export: {found}")
    print(f"PCK directory: {len(paths)} files, no test material")


def keep(path):
    return not SKIPPED_PARTS.intersection(path.parts) and path.suffix not in SKIPPED_SUFFIXES


def add_folder(archive, folder):
    for path in sorted((ROOT / folder).rglob("*")):
        relative = path.relative_to(ROOT)
        if path.is_file() and keep(relative):
            archive.write(path, relative.as_posix())


def package_game():
    with zipfile.ZipFile(GAME_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(BUILD.iterdir()):
            if path.is_file() and path.suffix in {".exe", ".pck", ".txt"}:
                archive.write(path, path.name)
        archive.write(ROOT / "README.md", "中文说明.md")
        archive.write(ROOT / "CHANGELOG.md", "CHANGELOG.md")
        archive.write(ROOT / "docs" / "v17" / "PLAYTEST.md", "PLAYTEST.md")


def package_source():
    with zipfile.ZipFile(SOURCE_ZIP, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for folder in SOURCE_FOLDERS:
            add_folder(archive, folder)
        for name in SOURCE_FILES:
            if (ROOT / name).exists():
                archive.write(ROOT / name, name)
        for path in sorted((ROOT / "tools").iterdir()):
            if path.is_file() and path.suffix in {".ps1", ".py", ".gd", ".json"}:
                archive.write(path, f"tools/{path.name}")


def verify():
    for path in [GAME_ZIP, SOURCE_ZIP]:
        with zipfile.ZipFile(path) as archive:
            bad = archive.testzip()
            if bad:
                raise SystemExit(f"{path}: corrupt entry {bad}")
    with zipfile.ZipFile(GAME_ZIP) as archive:
        for name in ["ColonyCharter.exe", "ColonyCharter.pck"]:
            packed = hashlib.sha256(archive.read(name)).hexdigest().upper()
            if packed != digest(BUILD / name):
                raise SystemExit(f"{name} in the archive differs from build\\v17")


def commit_id():
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=False
    )
    return result.stdout.strip()


def identity():
    report = {
        "version": VERSION,
        "commit": commit_id(),
        "engine": "Godot 4.5.1-stable, GL Compatibility, Windows x64",
        "save_schema": 4,
        "world_generator": "CC-GEO-2.2",
        "files": {
            path.name: {"sha256": digest(path), "bytes": path.stat().st_size}
            for path in [
                BUILD / "ColonyCharter.exe",
                BUILD / "ColonyCharter.pck",
                GAME_ZIP,
                SOURCE_ZIP,
            ]
        },
    }
    (OUT / "RELEASE_IDENTITY.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=True, indent=2))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    check_pck()
    package_game()
    package_source()
    verify()
    identity()


if __name__ == "__main__":
    main()

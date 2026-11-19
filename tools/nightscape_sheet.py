"""Assemble the 1.10 nightscape sheet from `capture_nightscape.gd` output.

Reads the nine 1920x1080 captures (<stage>_<view>.png for stages landing, housing, harbour and views
globe, flat, district) and writes:

- <out>/sheet_<name>.jpg: the 3 x 3 sheet, stages across, views down, each cell a third of the
  native size, with stage and view titles;
- <out>/<name>/<stage>_<view>.webp: each native capture, lossy WebP (no PNG goes into git);
- with --clips=<folder>, <folder>/<name>_ship.mp4 and <folder>/<name>_zoom.mp4 from the clip_ship
  and clip_zoom frames (kept out of git; the review delivers them with the build).

    python tools/nightscape_sheet.py --captures <folder> --out docs/v17/bay --name labels [--clips=<folder>]
"""

import argparse
import json
import pathlib
import subprocess

from PIL import Image, ImageDraw, ImageFont

STAGES = [("landing", "Landing"), ("housing", "Housing built"), ("harbour", "Harbour working")]
VIEWS = [("globe", "Globe, default distance"), ("flat", "Flat map, closest"), ("district", "District")]
CELL = (640, 360)
MARGIN_LEFT = 230
MARGIN_TOP = 56
GAP = 6
BACKGROUND = (14, 18, 24)
INK = (226, 232, 238)
MUTED = (150, 160, 170)


def font(size: int) -> ImageFont.ImageFont:
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "C:/Windows/Fonts/segoeui.ttf",
    ]:
        if pathlib.Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def sheet(captures: pathlib.Path, out: pathlib.Path, name: str, note: str) -> pathlib.Path:
    width = MARGIN_LEFT + len(STAGES) * CELL[0] + (len(STAGES) - 1) * GAP + GAP
    height = MARGIN_TOP + len(VIEWS) * CELL[1] + (len(VIEWS) - 1) * GAP + 40
    board = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(board)
    title = font(24)
    small = font(18)
    for column, (stage, stage_title) in enumerate(STAGES):
        x = MARGIN_LEFT + column * (CELL[0] + GAP)
        draw.text((x + 8, 16), stage_title, fill=INK, font=title)
        for row, (view, _view_title) in enumerate(VIEWS):
            y = MARGIN_TOP + row * (CELL[1] + GAP)
            path = captures / f"{stage}_{view}.png"
            if not path.exists():
                draw.rectangle([x, y, x + CELL[0], y + CELL[1]], outline=MUTED)
                draw.text((x + 12, y + 12), "missing", fill=MUTED, font=small)
                continue
            shot = Image.open(path).convert("RGB")
            board.paste(shot.resize(CELL, Image.LANCZOS), (x, y))
    for row, (_view, view_title) in enumerate(VIEWS):
        y = MARGIN_TOP + row * (CELL[1] + GAP)
        draw.multiline_text((16, y + 12), view_title.replace(", ", ",\n"), fill=INK, font=small)
    draw.text((16, height - 30), note, fill=MUTED, font=small)
    target = out / f"sheet_{name}.jpg"
    board.save(target, quality=88)
    return target


def natives(captures: pathlib.Path, out: pathlib.Path, name: str) -> list:
    folder = out / name
    folder.mkdir(parents=True, exist_ok=True)
    written = []
    for stage, _ in STAGES:
        for view, _ in VIEWS:
            path = captures / f"{stage}_{view}.png"
            if path.exists():
                target = folder / f"{stage}_{view}.webp"
                Image.open(path).convert("RGB").save(target, quality=82, method=6)
                written.append(target)
    return written


def clip(frames: pathlib.Path, target: pathlib.Path) -> None:
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-framerate", "12",
            "-i", str(frames / "%03d.png"),
            "-vf", "scale=1280:720:flags=lanczos,format=yuv420p",
            "-c:v", "libx264", "-crf", "23", "-preset", "slow", "-movflags", "+faststart",
            str(target),
        ],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--captures", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument("--note", default="")
    parser.add_argument("--clips", default="")
    args = parser.parse_args()
    captures = pathlib.Path(args.captures)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    report = json.loads((captures / "report.json").read_text()) if (captures / "report.json").exists() else {}
    note = args.note or "Captured at 1920x1080, local midnight, clouds off; stages after the landing are staged."
    written = [sheet(captures, out, args.name, note)]
    written += natives(captures, out, args.name)
    if args.clips:
        clips = pathlib.Path(args.clips)
        clips.mkdir(parents=True, exist_ok=True)
        for part in ["ship", "zoom"]:
            frames = captures / f"clip_{part}"
            if frames.exists():
                target = clips / f"{args.name}_{part}.mp4"
                clip(frames, target)
                written.append(target)
    for path in written:
        print(f"{path} {path.stat().st_size // 1024} KB")
    if report:
        print("stages", json.dumps(report.get("stages", {})))


if __name__ == "__main__":
    main()

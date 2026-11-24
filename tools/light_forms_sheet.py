#!/usr/bin/env python3
"""Lay out the 1.11 G light-form captures beside the user's concept sheet.

Reads the frames and report.json written by game/tests/art/capture_light_forms.gd and writes, as
WebP (PNG is Git LFS-tracked in this repository and the session cannot reach LFS):

  forms_vs_sheet.webp   the sheet 沿海与内陆的灯光形态 above the game's forms in the same layout:
                        five stages, coastal and inland, every panel the same patch of ground
                        (fixed proportions), cut from the globe at its default distance;
  forms_crossfade.webp  the played colony's capital from each crossfade distance, the same patch
                        of ground in every panel, with the light measured over the town;
  forms_globe.webp      the played colony at the default distance, the whole frame.

  python3 tools/light_forms_sheet.py --frames=<capture folder> [--sheet=<concept sheet>]
      [--out=docs/v17/lights] [--suffix=_1080]
"""

import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

# The concept sheet's layout (1430 x 490): five panels of 258 x 170 in two rows.
SHEET_SIZE = (1430, 490)
PANEL = (258, 170)
COLUMNS = [91, 358, 625, 892, 1159]
ROWS = [122, 305]
STAGES = ["landing", "first_homes", "town", "regional_centre", "capital"]
KINDS = ["coastal", "inland"]
KIND_NAMES = {"coastal": "沿海", "inland": "内陆"}
# Every stage panel shows this much ground across, in degrees: the capital's form fills a little
# over half of it, as on the sheet.
PANEL_DEGREES = 9.0
# The crossfade panels: the ground across each one, and their size.
FADE_DEGREES = 12.0
FADE_PANEL = (300, 200)
BACKGROUND = (13, 17, 23)
TITLE = (236, 240, 245)
MUTED = (150, 158, 170)
GOLD = (240, 196, 120)
FONTS = [
    "game/assets/fonts/main_medium.ttf",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
]


def font(size):
    for path in FONTS:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def crop(frames, row, degrees, size):
    """The patch of ground `degrees` across round the town, scaled to `size`."""
    image = Image.open(os.path.join(frames, row["file"])).convert("RGB")
    width = degrees * float(row["pixels_per_degree"])
    height = width * size[1] / size[0]
    x, y = float(row["x"]), float(row["y"])
    box = (round(x - width / 2), round(y - height / 2), round(x + width / 2), round(y + height / 2))
    return image.crop(box).resize(size, Image.LANCZOS)


def stage_block(frames, report):
    block = Image.new("RGB", SHEET_SIZE, BACKGROUND)
    draw = ImageDraw.Draw(block)
    draw.text((22, 16), "游戏内的灯光形态（1.11 G）", font=font(26), fill=TITLE)
    pixels = report["stages"][0]["pixels_per_degree"] if report["stages"] else 0
    note = "地球默认距离 10.3 · %d×%d 画面局部（每格 %.0f° 地面，1° ≈ %.0f 像素）· 五个阶段固定比例 · 摆放的城镇" % (
        report["size"][0],
        report["size"][1],
        PANEL_DEGREES,
        pixels,
    )
    draw.text((22, 56), note, font=font(15), fill=MUTED)
    names = {}
    for row in report["stages"]:
        names[row["stage"]] = row["stage_name"]
    for column, stage in zip(COLUMNS, STAGES):
        draw.text((column, 90), names.get(stage, stage), font=font(17), fill=TITLE)
    for top, kind in zip(ROWS, KINDS):
        draw.text((22, top + 75), KIND_NAMES[kind], font=font(17), fill=GOLD)
        for column, stage in zip(COLUMNS, STAGES):
            found = [r for r in report["stages"] if r["kind"] == kind and r["stage"] == stage]
            if found:
                block.paste(crop(frames, found[0], PANEL_DEGREES, PANEL), (column, top))
    return block


def crossfade_block(frames, report):
    rows = report["crossfade"]
    gap = 12
    width = 22 * 2 + len(rows) * FADE_PANEL[0] + (len(rows) - 1) * gap
    block = Image.new("RGB", (width, 150 + FADE_PANEL[1] + 70), BACKGROUND)
    draw = ImageDraw.Draw(block)
    colony = report.get("colony", {})
    draw.text((22, 16), "近处的逐块灯光与远处的形态交替（1.11 G）", font=font(26), fill=TITLE)
    draw.text(
        (22, 56),
        "实际游玩：平衡机器人第 %d 天的殖民地（%d 座城镇，首府 %d 人）· 首府当地午夜 · 每格 %.0f° 地面"
        % (
            colony.get("day", 0),
            colony.get("towns", 0),
            colony.get("capital_people", 0),
            FADE_DEGREES,
        ),
        font=font(15),
        fill=MUTED,
    )
    for index, row in enumerate(rows):
        left = 22 + index * (FADE_PANEL[0] + gap)
        draw.text((left, 96), "距离 %.1f" % row["distance"], font=font(17), fill=TITLE)
        draw.text(
            (left, 120),
            "逐块 %d%% · 形态 %d%%" % (round(100 * row["plot_share"]), round(100 * row["form_share"])),
            font=font(14),
            fill=MUTED,
        )
        block.paste(crop(frames, row, FADE_DEGREES, FADE_PANEL), (left, 150))
        draw.text(
            (left, 150 + FADE_PANEL[1] + 12),
            "城镇上方的光 %.4f" % row["town_light"],
            font=font(14),
            fill=GOLD,
        )
    return block


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", required=True)
    parser.add_argument("--sheet", default="docs/v17/lights/concept_light_forms.webp")
    parser.add_argument("--out", default="docs/v17/lights")
    parser.add_argument("--suffix", default="", help="added to every file name written")
    args = parser.parse_args()
    with open(os.path.join(args.frames, "report.json"), encoding="utf-8") as handle:
        report = json.load(handle)
    os.makedirs(args.out, exist_ok=True)
    if report.get("stages"):
        sheet = Image.open(args.sheet).convert("RGB")
        both = Image.new("RGB", (SHEET_SIZE[0], sheet.height + SHEET_SIZE[1]), BACKGROUND)
        both.paste(sheet, (0, 0))
        both.paste(stage_block(args.frames, report), (0, sheet.height))
        both.save(os.path.join(args.out, "forms_vs_sheet%s.webp" % args.suffix), quality=92, method=6)
        print("wrote", os.path.join(args.out, "forms_vs_sheet%s.webp" % args.suffix))
    if report.get("crossfade"):
        block = crossfade_block(args.frames, report)
        block.save(os.path.join(args.out, "forms_crossfade%s.webp" % args.suffix), quality=92, method=6)
        print("wrote", os.path.join(args.out, "forms_crossfade%s.webp" % args.suffix))
        default = [r for r in report["crossfade"] if abs(r["distance"] - 10.3) < 0.01]
        if default:
            frame = Image.open(os.path.join(args.frames, default[0]["file"])).convert("RGB")
            frame = frame.resize((1920, round(1920 * frame.height / frame.width)), Image.LANCZOS)
            frame.save(os.path.join(args.out, "forms_globe%s.webp" % args.suffix), quality=90, method=6)
            print("wrote", os.path.join(args.out, "forms_globe%s.webp" % args.suffix))


if __name__ == "__main__":
    main()

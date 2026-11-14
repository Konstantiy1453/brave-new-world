"""Writes docs/v17/TECH_TREE.md: the whole technology tree, from the rules data.

Reads game/data/v17/techs.json, economy.json, progression.json, population.json and
events.json; changes nothing else. Run from the project root after editing technologies:

    python tools/tech_tree.py
"""

import json
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data" / "v17"
OUT = ROOT / "docs" / "v17" / "TECH_TREE.md"
TIERS = range(1, 6)


def load(name: str) -> dict:
    return json.loads((DATA / f"{name}.json").read_text(encoding="utf-8"))


def unlocks(economy: dict, progression: dict, population: dict) -> dict:
    """What each technology opens besides its own effects, as short Chinese labels."""
    found = defaultdict(list)
    buildings = economy["buildings"]
    for kind, spec in buildings.items():
        tech = spec.get("requires_tech", "")
        if tech:
            role = "巨型工程" if spec.get("megaproject") else "设施"
            found[tech].append(f"{role}「{spec['name']}」")
    for kind, levels in economy.get("upgrades", {}).items():
        name = buildings.get(kind, {}).get("name", kind)
        for step in levels:
            tech = step.get("tech", "")
            if tech:
                found[tech].append(f"「{name}」升到 {step.get('level', '?')} 级")
    for kind, steps in economy.get("road_levels", {}).items():
        if not isinstance(steps, list):
            continue
        for step in steps:
            tech = step.get("tech", "")
            if tech:
                suffix = " ×2" if kind == "sea" else ""
                found[tech].append(f"线路升级「{step['name']}{suffix}」")
    contract_tech = progression.get("research", {}).get("contract_tech", "")
    if contract_tech:
        found[contract_tech].append("科研委托")
    scientist_tech = population.get("recruitment", {}).get("scientist_tech", "")
    if scientist_tech:
        found[scientist_tech].append("招募研究团队")
    for tech, labels in found.items():
        found[tech] = list(dict.fromkeys(labels))
    return found


def gift_sources(events: dict) -> dict:
    """Which events hand over each gift technology."""
    found = defaultdict(list)
    for event_id, definition in events["definitions"].items():
        for node in definition["nodes"].values():
            for option in node["choices"]:
                if "tech_gift" in option:
                    title = definition["nodes"]["start"]["title"]
                    found[option["tech_gift"]].append(f"「{title}」(`{event_id}`)")
    return found


def mermaid(category: str, techs: dict, names: dict) -> list:
    lines = ["```mermaid", "flowchart LR"]
    members = [k for k, t in techs.items() if t["category"] == category and not t.get("gift")]
    outside = set()
    for key in members:
        for need in techs[key]["requires"]:
            if techs[need]["category"] != category:
                outside.add(need)
    for tier in TIERS:
        row = [k for k in members if int(techs[k]["tier"]) == tier]
        if not row:
            continue
        lines.append(f'  subgraph T{tier}["第 {tier} 层"]')
        for key in row:
            mark = " ★" if key in names["charter"] else ""
            lines.append(f'    {key}["{techs[key]["name"]}{mark}"]')
        lines.append("  end")
    for key in sorted(outside):
        other = names["categories"][techs[key]["category"]]
        lines.append(f'  {key}(["{techs[key]["name"]}（{other}）"])')
    for key in members:
        for need in techs[key]["requires"]:
            arrow = "-.->" if need in outside else "-->"
            lines.append(f"  {need} {arrow} {key}")
    lines.append("```")
    return lines


def table(category: str, techs: dict, opened: dict, charter: set) -> list:
    lines = [
        "| 层 | 技术 | 研究量 | 前置 | 效果 | 解锁 |",
        "|---|---|---|---|---|---|",
    ]
    rows = [k for k, t in techs.items() if t["category"] == category and not t.get("gift")]
    rows.sort(key=lambda k: (int(techs[k]["tier"]), techs[k]["name"]))
    for key in rows:
        t = techs[key]
        needs = "、".join(techs[n]["name"] for n in t["requires"]) or "—"
        mark = " ★" if key in charter else ""
        what = "；".join(opened.get(key, [])) or "—"
        lines.append(
            f"| {t['tier']} | **{t['name']}**{mark}<br>`{key}` | {t['cost']:.0f} | {needs} "
            f"| {t['description']} | {what} |"
        )
    return lines


def main() -> int:
    rules = load("techs")
    techs = rules["techs"]
    economy = load("economy")
    opened = unlocks(economy, load("progression"), load("population"))
    gifts = gift_sources(load("events"))
    charter = set(rules.get("always_dealt", []))
    categories = {k: v["name"] for k, v in rules["categories"].items()}
    names = {"charter": charter, "categories": categories}
    researchable = {k: t for k, t in techs.items() if not t.get("gift")}
    out = [
        "# 殖民契约 1.9 · Technology tree",
        "",
        "Generated by `tools/tech_tree.py` from `game/data/v17/techs.json` (and the facilities,",
        "upgrades, link levels and events that name a technology). Do not edit by hand: change the",
        "data and run the script again.",
        "",
        "## How research works",
        "",
        f"- {len(researchable)} technologies in four directions, each in tiers 1–5, plus "
        f"{len(techs) - len(researchable)} gift technologies that only events hand over.",
        f"- Each direction deals {rules['offers']} cards at a time from what its prerequisites "
        "allow (weighted by `weight`); a team works one direction at a time. Finishing a card deals "
        "that direction again. Some technologies add cards.",
        f"- Re-dealing a direction costs ¥{rules['reshuffle_cost']:.0f} + "
        f"¥{rules['reshuffle_tier_cost']:.0f} × the highest tier researched.",
        "- ★ marks what the charter cannot be finished without: it is dealt as soon as it can be "
        "started.",
        "- Research points per day follow the team size: R(n) = R10 × (n / 10)^0.737 (five teams "
        "give 60% of ten).",
        "- First cards: "
        + "、".join(
            f"{categories[c]}「{techs[k]['name']}」"
            for c, keys in rules["first_offers"].items()
            for k in keys
        )
        + ".",
        "",
        "## Size of the tree",
        "",
        "| 方向 | " + " | ".join(f"第 {t} 层" for t in TIERS) + " | 合计 |",
        "|---|" + "---|" * (len(TIERS) + 1),
    ]
    for category, name in categories.items():
        counts = [
            sum(
                1
                for t in researchable.values()
                if t["category"] == category and int(t["tier"]) == tier
            )
            for tier in TIERS
        ]
        out.append(f"| {name} | " + " | ".join(str(c) for c in counts) + f" | {sum(counts)} |")
    cross = [
        (k, n)
        for k, t in researchable.items()
        for n in t["requires"]
        if techs[n]["category"] != t["category"]
    ]
    out += [
        "",
        "Prerequisites that cross directions: "
        + "、".join(f"{techs[k]['name']} ← {techs[n]['name']}" for k, n in cross)
        + ".",
        "",
    ]
    for category, name in categories.items():
        description = rules["categories"][category]["description"]
        out += [f"## {name}（`{category}`）· {description}", ""]
        out += mermaid(category, techs, names)
        out.append("")
        out += table(category, techs, opened, charter)
        out.append("")
    out += [
        "## Gift technologies (event only)",
        "",
        "Never dealt, never researched, not counted towards the charter's technology goals. The "
        "event that offers one opens only where it makes sense (a finished road, or a pair of "
        "cargo docks) and only while the colony lacks it.",
        "",
        "| 技术 | 效果 | 来自事件 |",
        "|---|---|---|",
    ]
    for key, t in techs.items():
        if t.get("gift"):
            sources = "、".join(gifts.get(key, [])) or "—"
            out.append(f"| **{t['name']}**<br>`{key}` | {t['description']} | {sources} |")
    out.append("")
    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(techs)} technologies")
    return 0


if __name__ == "__main__":
    sys.exit(main())

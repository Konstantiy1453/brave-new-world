"""Merges the technologies (1.11 H) in game/data/v17: within each category and tier, every
technology that only adds effects becomes one technology, its effects added per key. Kept as
they are: technologies that unlock a building, an upgrade, a route or a rule (named by any rule
file other than events.json, or by game code other than the legacy save migration), gift
technologies, frozen ones (progression.json features.content) and those without effects.
A requirement on a merged part points at the merged technology (DECISIONS.md, H).

The merged technology costs the sum of its parts x merge_cost_factor; its funding is the parts'
funding weighted by cost, so a research point costs what it did; its draw weight and minimum staff
are the parts' largest. techs.json gains `merged` {old id: new id} and `merge_cost_factor`; the
events' tech_gift and research_lead, first_offers and always_dealt are remapped.

Run once from the project root: python tools/tech_merge.py [--dry-run]. It refuses to run on
data that is already merged.

Three readings of the plan's rule, for comparison (the game ships `bundles`):
- `strict`: only technologies that add effects, unlock nothing and that no other technology
  requires (125);
- `bundles`: also those other technologies require, the requirement pointed at the merged one (85);
- `unlockers`: also technologies that unlock a facility, an upgrade or a link level; the facilities,
  upgrades and link levels in economy.json then name the merged technology (55-65).
`--source=<dir>` reads techs.json and events.json from another folder (the data before the merge)
and `--out=<dir>` writes the merged techs.json, events.json and economy.json there instead of into
the game, so a reading can be built and drawn (tools/tech_tree.py --data=<dir>) without changing it."""
from pathlib import Path
import argparse
import json
import re

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "data" / "v17"
GAME = ROOT / "game"
FACTOR = 0.8
# Files whose mention of a technology does not make it an unlocker: the events (remapped here)
# and the 1.6 save migration (remapped at run time through `merged`).
SOFT_DATA = {"events.json", "techs.json"}
SOFT_CODE = {"save_migration.gd"}
NAMES = {
    ("agriculture", 1): "垦殖基础",
    ("agriculture", 2): "农业增产",
    ("agriculture", 3): "高效农业",
    ("agriculture", 4): "生态工程",
    ("agriculture", 5): "生物圈营造",
    ("construction", 1): "建设基础",
    ("construction", 2): "工程管理",
    ("construction", 3): "大型工程",
    ("construction", 4): "超级结构",
    ("construction", 5): "星球交通",
    ("industry", 1): "采选基础",
    ("industry", 2): "工业增效",
    ("industry", 3): "工业升级",
    ("industry", 4): "先进制造",
    ("industry", 5): "全面自动化",
    ("society", 1): "社区治理",
    ("society", 2): "公共事务",
    ("society", 3): "社会发展",
    ("society", 4): "社会科学",
    ("society", 5): "未来社会",
}


SOURCE = DATA


# 55-65 (`unlockers`): in each direction and tier, the technologies that open something are
# merged apart from the bonuses, so a tier holds at most one of each.
UNLOCK_NAMES = {
    ("agriculture", 1): "垦殖设施",
    ("agriculture", 2): "农业设施",
    ("agriculture", 3): "现代农场",
    ("agriculture", 4): "生态设施",
    ("agriculture", 5): "生物圈设施",
    ("construction", 1): "建设装备",
    ("construction", 2): "工程设施",
    ("construction", 3): "大型设施",
    ("construction", 4): "超级设施",
    ("construction", 5): "星球设施",
    ("industry", 1): "采选装备",
    ("industry", 2): "工业设施",
    ("industry", 3): "重工设施",
    ("industry", 4): "先进工厂",
    ("industry", 5): "自动化工厂",
    ("society", 1): "社区设施",
    ("society", 2): "公共设施",
    ("society", 3): "社会设施",
    ("society", 4): "科研设施",
    ("society", 5): "未来设施",
}


def load(name):
    folder = SOURCE if name in ("techs.json", "events.json") else DATA
    return json.loads((folder / name).read_text(encoding="utf-8"))


def references(techs, soft_data=SOFT_DATA):
    """For each technology, the files that name it (as a quoted string)."""
    found = {key: set() for key in techs}
    pattern = re.compile(r'"([a-z_0-9]+)"')
    for path in DATA.glob("*.json"):
        if path.name in soft_data:
            continue
        for word in set(pattern.findall(path.read_text(encoding="utf-8"))):
            if word in found:
                found[word].add(path.name)
    for path in GAME.rglob("*.gd"):
        if ".godot" in path.parts or "tests" in path.parts or path.name in SOFT_CODE:
            continue
        for word in set(pattern.findall(path.read_text(encoding="utf-8"))):
            if word in found:
                found[word].add(path.name)
    return found


def economy_unlocks():
    """The technologies economy.json names as what opens a facility, an upgrade or a link level."""
    economy = load("economy.json")
    found = set()
    for spec in economy["buildings"].values():
        if spec.get("requires_tech"):
            found.add(spec["requires_tech"])
    for steps in list(economy.get("upgrades", {}).values()) + list(
        economy.get("road_levels", {}).values()
    ):
        if isinstance(steps, list):
            for step in steps:
                if isinstance(step, dict) and step.get("tech"):
                    found.add(step["tech"])
    return found


def groups(data, mode="bundles"):
    techs = data["techs"]
    frozen = set()
    for content in load("progression.json")["features"].get("content", {}).values():
        frozen.update(content.get("techs", []))
    soft = SOFT_DATA | ({"economy.json"} if mode == "unlockers" else set())
    named = references(techs, soft)
    opens = economy_unlocks() if mode == "unlockers" else set()
    required = {need for tech in techs.values() for need in tech.get("requires", [])}
    merged = {}
    for key, tech in techs.items():
        if named[key] or tech.get("gift") or key in frozen:
            continue
        if not tech.get("effects") and key not in opens:
            continue
        if mode == "strict" and key in required:
            continue
        group = (tech["category"], int(tech["tier"]))
        if mode == "unlockers":
            group += ("unlock" if key in opens else "bonus",)
        merged.setdefault(group, []).append(key)
    return {group: keys for group, keys in merged.items() if len(keys) > 1}


def remap_economy(table):
    """economy.json with every facility, upgrade and link level naming the merged technology."""
    text = (DATA / "economy.json").read_text(encoding="utf-8")
    count = 0
    for key in ("requires_tech", "tech"):
        def swap(match):
            nonlocal count
            old = match.group(2)
            if old in table:
                count += 1
                return f'{match.group(1)}"{table[old]}"'
            return match.group(0)
        text = re.sub(rf'("{key}":\s*)"([a-z_0-9]+)"', swap, text)
    return text, count


def describe(parts):
    """The parts' names, then what each did, in their own words."""
    words = []
    for part in parts:
        text = str(part.get("description", "")).strip()
        if text and not text.endswith(("。", "！", "？")):
            text += "。"
        words.append(text)
    return "合并了「" + "」「".join(p["name"] for p in parts) + "」：" + "".join(words)


def merged_id(group):
    if len(group) > 2 and group[2] == "unlock":
        return f"{group[0]}_{group[1]}_unlocks"
    return f"{group[0]}_{group[1]}_merged"


def merged_name(group):
    if len(group) > 2 and group[2] == "unlock":
        return UNLOCK_NAMES[(group[0], group[1])]
    return NAMES[(group[0], group[1])]


def merge(data, plan):
    techs = data["techs"]
    table = {}
    for group, keys in sorted(plan.items()):
        for key in keys:
            table[key] = merged_id(group)
    out = {}
    for key, tech in techs.items():
        if key in table:
            continue
        out[key] = dict(tech)
    for group, keys in sorted(plan.items()):
        category, tier = group[0], group[1]
        new_id = merged_id(group)
        parts = [techs[key] for key in keys]
        cost = sum(float(p["cost"]) for p in parts)
        effects = {}
        for part in parts:
            for name, value in part.get("effects", {}).items():
                effects[name] = round(effects.get(name, 0.0) + float(value), 6)
        requires = []
        for part in parts:
            for need in part.get("requires", []):
                need = table.get(need, need)
                if need != new_id and need not in requires:
                    requires.append(need)
        out[new_id] = {
            "name": merged_name(group),
            "category": category,
            "branch": parts[0].get("branch", category),
            "tier": tier,
            "cost": round(cost * FACTOR, 1),
            "funding": round(sum(float(p["funding"]) * float(p["cost"]) for p in parts) / cost, 2),
            "weight": max(float(p.get("weight", 1.0)) for p in parts),
            "requires": requires,
            "minimum_staff": max(int(p.get("minimum_staff", 3)) for p in parts),
            "description": describe(parts),
            "effects": effects,
            "merged_from": keys,
            "part_costs": {key: float(techs[key]["cost"]) for key in keys},
        }
    for tech in out.values():
        if "requires" in tech:
            remapped = []
            for need in tech["requires"]:
                need = table.get(need, need)
                if need not in remapped:
                    remapped.append(need)
            tech["requires"] = remapped
    data["techs"] = out
    data["merged"] = table
    data["merge_cost_factor"] = FACTOR
    data["first_offers"] = {
        category: sorted({table.get(key, key) for key in keys})
        for category, keys in data["first_offers"].items()
    }
    always = []
    for key in data["always_dealt"]:
        key = table.get(key, key)
        if key not in always:
            always.append(key)
    data["always_dealt"] = always
    data["units"]["merged"] = (
        "1.11 H: a technology merged into another, old id -> new id; saves, events and bots read "
        "old ids through it"
    )
    data["units"]["merge_cost_factor"] = (
        "a merged technology costs the sum of its parts x this; its funding is their cost-weighted "
        "funding"
    )
    data["units"]["merged_from"] = "the technologies a merged one replaced, in the order merged"
    data["units"]["part_costs"] = (
        "the research points each merged part cost: a save that finished some parts keeps them as "
        "progress"
    )
    return table


def remap_events(table):
    path = SOURCE / "events.json"
    text = path.read_text(encoding="utf-8")
    count = 0
    for key in ("tech_gift", "research_lead"):
        def swap(match):
            nonlocal count
            old = match.group(2)
            if old in table:
                count += 1
                return f'{match.group(1)}"{table[old]}"'
            return match.group(0)
        text = re.sub(rf'("{key}":\s*)"([a-z_0-9]+)"', swap, text)
    return text, count


def main():
    global SOURCE
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument("--dry-run", action="store_true")
    args.add_argument("--mode", choices=["strict", "bundles", "unlockers"], default="bundles")
    args.add_argument("--source", default="")
    args.add_argument("--out", default="")
    options = args.parse_args()
    if options.source:
        SOURCE = Path(options.source)
    data = load("techs.json")
    if "merged" in data:
        raise SystemExit("techs.json is already merged")
    before = len(data["techs"])
    plan = groups(data, options.mode)
    table = merge(data, plan)
    events, swapped = remap_events(table)
    economy, repointed = remap_economy(table) if options.mode == "unlockers" else ("", 0)
    print(
        f"{options.mode}: {before} technologies -> {len(data['techs'])}; "
        f"{len(table)} merged into {len(plan)}"
    )
    for group, keys in sorted(plan.items()):
        print(f"  {' '.join(str(part) for part in group)}: {merged_name(group)} <- {', '.join(keys)}")
    print(f"events remapped: {swapped}; facilities, upgrades and link levels re-pointed: {repointed}")
    if options.dry_run:
        return
    out = Path(options.out) if options.out else DATA
    out.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    (out / "techs.json").write_text(text, encoding="utf-8")
    (out / "events.json").write_text(events, encoding="utf-8")
    if economy:
        (out / "economy.json").write_text(economy, encoding="utf-8")


if __name__ == "__main__":
    main()

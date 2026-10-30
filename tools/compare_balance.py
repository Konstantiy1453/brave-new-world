"""Compare the per-run records of two balance reports. Exit 0 only when they are identical.

Usage: python tools/compare_balance.py evidence/v17/balance/A.json evidence/v17/balance/B.json
"""
import json
import sys
from pathlib import Path


GOODS = {"铁矿": "ore", "铜矿": "copper", "工业晶体": "crystal", "食品": "food", "建材": "materials", "机械部件": "parts"}


def key(run):
    return (run["bot"], run["difficulty"], run["opening"], run["seed"])


def normalized(run):
    """Export revenue was keyed by display name before Phase 2."""
    run["export_revenue"] = {GOODS.get(k, k): v for k, v in run.get("export_revenue", {}).items()}
    return run


def main():
    first, second = (json.loads(Path(p).read_text(encoding="utf-8")) for p in sys.argv[1:3])
    runs_a = {key(r): normalized(r) for r in first["runs"]}
    runs_b = {key(r): normalized(r) for r in second["runs"]}
    if set(runs_a) != set(runs_b):
        print(f"DIFFERENT case sets: {len(runs_a)} vs {len(runs_b)}")
        return 1
    different = 0
    for case, run in sorted(runs_a.items(), key=str):
        if run != runs_b[case]:
            different += 1
            if different <= 5:
                fields = [k for k in run if run[k] != runs_b[case].get(k)]
                print("DIFF", case, fields[:6])
    print(f"compared {len(runs_a)} runs: {different} differ")
    print(f"determinism: {first['extras'].get('determinism')} / {second['extras'].get('determinism')}")
    return 1 if different else 0


if __name__ == "__main__":
    sys.exit(main())

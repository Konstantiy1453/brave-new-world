"""Chooses the contract's tier milestones (1.11 H) from two calibration recordings of
game/tests/balance/calibrate_techs.gd: one on the tree before the merge (the days the old
technology counts were reached) and one on the merged tree with those goals off (the day each
"n technologies at tier t or above" was reached). For each old count it picks the (t, n) whose
median day is nearest; within 30 days of the best, the higher tier wins.

    python tools/calibrate_tech_goals.py <before.json[,part...]> <after.json[,part...]>
"""
import json
import statistics
import sys

OLD_COUNTS = [5, 14, 24, 40]
TIERS = [1, 2, 3, 4]
MAX_COUNT = 40
CLOSE_DAYS = 30


def load(paths):
    """One recording, or its parts (calibrate_techs.gd --part=k/K) separated by commas."""
    runs = []
    for path in paths.split(","):
        with open(path, encoding="utf-8") as handle:
            runs.extend(json.load(handle)["runs"])
    return runs


def day_reached(techs, count, tier=1):
    seen = 0
    for day, level, _key in techs:
        if int(level) >= tier:
            seen += 1
            if seen >= count:
                return int(day)
    return None


def median_day(runs, count, tier=1):
    days = [day_reached(run["techs"], count, tier) for run in runs]
    reached = [day for day in days if day is not None]
    if len(reached) * 2 < len(runs):
        return None, len(reached)
    return statistics.median(reached), len(reached)


def main():
    before = load(sys.argv[1])
    after = load(sys.argv[2])
    print(f"runs: before {len(before)}, after {len(after)}")
    for count in OLD_COUNTS:
        old_day, old_n = median_day(before, count)
        if old_day is None:
            print(f"{count} technologies: reached in only {old_n} runs before the merge")
            continue
        best = None
        options = []
        for tier in TIERS:
            for n in range(1, MAX_COUNT + 1):
                day, reached = median_day(after, n, tier)
                if day is None:
                    break
                options.append((abs(day - old_day), tier, n, day, reached))
        options.sort()
        best = options[0]
        close = [o for o in options if o[0] <= best[0] + CLOSE_DAYS]
        close.sort(key=lambda o: (-o[1], o[0]))
        pick = close[0]
        print(
            f"{count} technologies: day {old_day:.0f} ({old_n}/{len(before)} runs) -> "
            f"techs_tier_{pick[1]} {pick[2]} at day {pick[3]:.0f} ({pick[4]}/{len(after)} runs); "
            f"nearest overall tier {best[1]} x{best[2]} at {best[3]:.0f}"
        )
    totals = sorted(len(run["techs"]) for run in after)
    print(f"technologies by the end, after the merge: {totals}")
    awards = [run["award"] for run in after if run["award"] >= 0]
    print(f"awards after the merge (goals off): {sorted(awards)}")


if __name__ == "__main__":
    main()

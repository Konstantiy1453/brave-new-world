#!/usr/bin/env python3
"""Runs Colony Charter test suites on Linux or macOS, each in its own Godot process.

The same rules as tools/run_tests.ps1: suites come from tools/test_suites.json, every run gets an
isolated user-data folder under evidence/v17/userdata_tests/<suite> and a log at
evidence/v17/tests/<suite>.log. A suite fails on a non-zero exit, a timeout, SCRIPT ERROR, its
failure marker, or a missing success marker. Exits non-zero when anything failed.

Window suites need a display; on a machine without one, run this script under xvfb-run:

    xvfb-run -a -s "-screen 0 1920x1080x24" python3 tools/run_tests.py --window

The engine is --engine, else $GODOT, else tools/godot-4.5.1/Godot_v4.5.1-stable_linux.x86_64.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
LOG_DIR = ROOT / "evidence" / "v17" / "tests"
USER_ROOT = ROOT / "evidence" / "v17" / "userdata_tests"


def find_engine(given: str) -> str:
    for candidate in (given, os.environ.get("GODOT", "")):
        if candidate:
            return candidate
    return str(ROOT / "tools" / "godot-4.5.1" / "Godot_v4.5.1-stable_linux.x86_64")


def start(engine: str, suite: dict, default_timeout: int) -> dict:
    user_data = USER_ROOT / suite["name"]
    if user_data.exists():
        shutil.rmtree(user_data)
    user_data.mkdir(parents=True)
    env = dict(os.environ)
    # Godot keeps user:// under $XDG_DATA_HOME on Linux and $APPDATA on Windows.
    env["XDG_DATA_HOME"] = str(user_data)
    env["APPDATA"] = str(user_data)
    arguments = [engine]
    if not suite.get("window"):
        arguments.append("--headless")
    arguments += ["--path", str(GAME)]
    if suite.get("window"):
        arguments += ["--rendering-method", "gl_compatibility"]
    arguments += ["--script", suite["script"]]
    if suite.get("args"):
        arguments += ["--"] + list(suite["args"])
    log_path = LOG_DIR / (suite["name"] + ".log")
    log = open(log_path, "w", encoding="utf-8", errors="replace")
    process = subprocess.Popen(
        arguments, cwd=str(ROOT), env=env, stdout=log, stderr=subprocess.STDOUT
    )
    return {
        "suite": suite,
        "process": process,
        "log": log,
        "log_path": log_path,
        "started": time.time(),
        "timeout": int(suite.get("timeout", default_timeout)),
        "timed_out": False,
    }


def finish(run: dict, config: dict) -> dict:
    suite = run["suite"]
    run["log"].close()
    output = run["log_path"].read_text(encoding="utf-8", errors="replace")
    reasons = []
    code = run["process"].returncode
    if run["timed_out"]:
        reasons.append("timeout after %d s" % run["timeout"])
    elif code != 0:
        reasons.append("exit code %d" % code)
    if not suite.get("allow_script_errors") and re.search(config["script_errors"], output):
        reasons.append("script error in log")
    failure = suite.get("failure", config["default_failure"])
    if failure and re.search(failure, output):
        reasons.append("failure marker in log")
    if suite.get("success") and not re.search(suite["success"], output):
        reasons.append("success marker missing")
    return {
        "suite": suite["name"],
        "result": "FAIL" if reasons else "PASS",
        "seconds": round(time.time() - run["started"], 1),
        "exit": code,
        "reason": "; ".join(reasons),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--only", default="", help="comma-separated suite names")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--window", action="store_true", help="also run suites that need a window")
    parser.add_argument("--timeout", type=int, default=600)
    parser.add_argument("--engine", default="")
    options = parser.parse_args()
    engine = find_engine(options.engine)
    if not Path(engine).exists():
        print("RUNNER: engine not found: " + engine, file=sys.stderr)
        return 2
    config = json.loads((ROOT / "tools" / "test_suites.json").read_text(encoding="utf-8"))
    only = [name for name in options.only.split(",") if name]
    selected = []
    for suite in config["suites"]:
        if only:
            if suite["name"] in only:
                selected.append(suite)
        elif suite.get("window") and not options.window:
            continue
        elif not suite.get("disabled"):
            selected.append(suite)
    if not selected:
        print("RUNNER: no suites selected", file=sys.stderr)
        return 2
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    USER_ROOT.mkdir(parents=True, exist_ok=True)
    queue = list(selected)
    running = []
    results = []
    while queue or running:
        while queue and len(running) < options.jobs:
            upcoming = queue[0]
            # A window suite measures real frames: it never shares the machine with other suites.
            if upcoming.get("window") and running:
                break
            running.append(start(engine, queue.pop(0), options.timeout))
            if upcoming.get("window"):
                break
        time.sleep(0.2)
        for run in list(running):
            process = run["process"]
            if process.poll() is None and time.time() - run["started"] > run["timeout"]:
                run["timed_out"] = True
                process.kill()
                process.wait(10)
            if process.poll() is not None:
                result = finish(run, config)
                results.append(result)
                running.remove(run)
                print(
                    "%-4s %-34s %7.1fs  %s"
                    % (result["result"], result["suite"], result["seconds"], result["reason"]),
                    flush=True,
                )
    failed = [result for result in results if result["result"] == "FAIL"]
    print("RUNNER: %d passed, %d failed" % (len(results) - len(failed), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())

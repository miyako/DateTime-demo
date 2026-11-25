#!/usr/bin/env python3
"""Headless acceptance for the DateTime demo.

Runs Demo_SelfTest through tool4d against the real staged component and asserts
the facts the UI relies on. This is interpreted runtime evidence; it does not
replace compiling the project in the 4D IDE.

Usage:
    python3 scripts/verify.py [--tool4d PATH]
"""
import argparse
import glob
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

CHECKS = []


def check(label, condition, detail=""):
    CHECKS.append((label, bool(condition), detail))
    print(("PASS  " if condition else "FAIL  ") + label + ((" — " + detail) if detail else ""))
    return bool(condition)


def find_tool4d(explicit):
    candidates = [explicit, os.environ.get("TOOL4D_PATH")]
    candidates += sorted(glob.glob("/Applications/4D 21.2 LTS*/tool4d.app/Contents/MacOS/tool4d"), reverse=True)
    candidates += sorted(glob.glob("/Applications/4D 21 R*/tool4d.app/Contents/MacOS/tool4d"), reverse=True)
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool4d")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    component = root / "Components/DateTime.4dbase/DateTime.4DZ"
    if not component.is_file():
        print("component not staged; run: python3 scripts/fetch_dependency.py", file=sys.stderr)
        return 2

    tool4d = find_tool4d(args.tool4d)
    if tool4d is None:
        print("tool4d not found; pass --tool4d or set TOOL4D_PATH", file=sys.stderr)
        return 2

    version = subprocess.run([str(tool4d), "--version"], capture_output=True, text=True).stdout.strip()
    print(f"tool4d   {version}")
    print(f"component {component.relative_to(root)}")

    report_path = Path(tempfile.gettempdir()) / "datetime-demo-selftest.json"
    report_path.unlink(missing_ok=True)
    run = subprocess.run([
        str(tool4d),
        "--project", str(root / "Project/DateTime-demo.4DProject"),
        "--skip-onstartup",
        "--startup-method=Demo_SelfTest",
        "--user-param=" + str(report_path),
        "--dataless",
    ], capture_output=True, text=True, timeout=180)
    if not report_path.is_file():
        print(run.stdout, run.stderr, sep="\n", file=sys.stderr)
        print("Demo_SelfTest produced no report", file=sys.stderr)
        return 1

    report = json.loads(report_path.read_text())
    check("report finished", report.get("finished") is True)
    check("component version line", "miyako/DateTime 0.1.3" in report.get("component", ""), report.get("component", ""))

    single = report["single"]
    check("Kathmandu conversion", single["local"] == "2026-01-15T17:45:00.123+05:45"
          and single["offset"].startswith("+05:45"), single["local"])

    check("DST offset before the gap", report["dstBefore"]["offset"].startswith("+01:00"), report["dstBefore"]["local"])
    check("DST offset after the gap", report["dstAfter"]["offset"].startswith("+02:00"), report["dstAfter"]["local"])

    rejected = report["rejected"]
    check("invalid instant is rejected", rejected["kind"] == "error"
          and "invalid_instant" in rejected["status"] and rejected["exitCode"] == 2, rejected["status"])
    check("rejection carries JSON evidence", rejected["raw"].lstrip().startswith("{"), rejected["raw"][:60])

    check("demo batch has 5 ok / 3 failures", report["batchOk"] == 5 and report["batchFail"] == 3, report["batchNote"])
    check("stress batch keeps 256 rows", report["stressRows"] == 256, report["stressNote"])
    check("stress batch reports 200 ok / 56 item errors",
          "200 ok" in report["stressNote"] and "56 item errors" in report["stressNote"], report["stressNote"])

    failed = [label for label, ok, _ in CHECKS if not ok]
    if failed:
        print(f"\n{len(failed)} check(s) failed")
        return 1
    print(f"\nall {len(CHECKS)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())

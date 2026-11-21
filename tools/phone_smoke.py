#!/usr/bin/env python3
"""Smoke-test an APK on a USB-connected Android phone.

Installs the APK over the existing app (progress is kept: same signing key), launches it, waits,
then checks that the game process is still alive, that Godot logged no script errors, and saves a
screenshot. Exit code 0 = pass.

    python tools/phone_smoke.py [path/to/NihongoNoSekai.apk] [--seconds 12] [--shot out.png]

Needs adb (Android SDK platform-tools) on PATH or in %LOCALAPPDATA%/Android/Sdk/platform-tools.
Paths with non-ASCII characters break `adb install` on Windows, so the APK is copied to the
system temp directory first.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

PACKAGE = "io.github.tamanegininja25.nihongonosekai"
ACTIVITY = f"{PACKAGE}/com.godot.game.GodotAppLauncher"
ROOT = Path(__file__).resolve().parent.parent


def adb_path() -> str:
    found = shutil.which("adb")
    if found:
        return found
    local = Path(os.environ.get("LOCALAPPDATA", "")) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
    if local.exists():
        return str(local)
    sys.exit("adb not found: install Android platform-tools")


def run(adb: str, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run([adb, *args], capture_output=True, check=check)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("apk", nargs="?", default=str(ROOT / "build" / "android" / "NihongoNoSekai.apk"))
    ap.add_argument("--seconds", type=float, default=12.0, help="how long the game must stay up")
    ap.add_argument("--shot", default=str(ROOT / "build" / "phone_smoke.png"))
    args = ap.parse_args(argv)
    adb = adb_path()

    devices = [line.split("\t")[0] for line in run(adb, "devices").stdout.decode().splitlines()[1:] if line.strip().endswith("device")]
    if not devices:
        print("FAIL no phone connected (enable USB debugging and accept the prompt)")
        return 1
    print(f"phone: {devices[0]}")

    apk = Path(tempfile.gettempdir()) / "nihongo_smoke.apk"
    shutil.copyfile(args.apk, apk)
    result = run(adb, "install", "-r", str(apk), check=False)
    if b"Success" not in result.stdout:
        print("FAIL install:", (result.stdout + result.stderr).decode(errors="replace").strip())
        return 1
    print("installed")

    run(adb, "logcat", "-c", check=False)
    run(adb, "shell", "am", "force-stop", PACKAGE, check=False)
    run(adb, "shell", "am", "start", "-n", ACTIVITY)
    time.sleep(args.seconds)

    pid = run(adb, "shell", "pidof", PACKAGE, check=False).stdout.decode().strip()
    log = run(adb, "logcat", "-d", "-s", "godot:E", "godot:W", check=False).stdout.decode(errors="replace")
    errors = [line for line in log.splitlines() if "SCRIPT ERROR" in line or "Parse Error" in line]
    shot = run(adb, "exec-out", "screencap", "-p", check=False).stdout
    Path(args.shot).parent.mkdir(parents=True, exist_ok=True)
    Path(args.shot).write_bytes(shot)
    print(f"screenshot: {args.shot}")

    ok = True
    if not pid:
        print("FAIL the game is not running (crashed or closed)")
        ok = False
    else:
        print(f"running (pid {pid})")
    if errors:
        print(f"FAIL {len(errors)} script error(s):")
        for line in errors[:10]:
            print("  " + line)
        ok = False
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

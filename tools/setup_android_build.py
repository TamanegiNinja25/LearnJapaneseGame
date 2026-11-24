#!/usr/bin/env python3
"""Prepare game/android/build, the Gradle project both Android presets build from.

1. Unpack Godot's android_source.zip export template into game/android/build (git-ignored).
2. Copy the project's Java plugins (tools/android/speech_plugin/) into it.
3. Register them in src/main/AndroidManifest.xml (Godot writes its own settings into the
   src/debug and src/release overlays, so the main manifest is ours) and let the app see the
   phone's speech-recognition service (Android 11+ package visibility).

    python tools/setup_android_build.py [--templates DIR] [--version 4.7.2.stable]

Run it once per fresh checkout and again after updating Godot. CI runs it before exporting.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "game" / "android" / "build"
PLUGIN_SRC = ROOT / "tools" / "android" / "speech_plugin"
PLUGINS = {"NihongoSpeech": "io.github.tamanegininja25.speech.SpeechInputPlugin"}
MARKER = "<!-- nihongo-plugins -->"


def default_templates(version: str) -> Path:
    if sys.platform.startswith("win"):
        base = Path(os.environ.get("APPDATA", "")) / "Godot" / "export_templates"
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support" / "Godot" / "export_templates"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot" / "export_templates"
    return base / version


def patch_manifest(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    if MARKER in text:
        return
    queries = (f"    {MARKER}\n    <queries>\n        <intent>\n"
               "            <action android:name=\"android.speech.RecognitionService\" />\n"
               "        </intent>\n    </queries>\n\n")
    meta = "".join(f"        <meta-data\n            android:name=\"org.godotengine.plugin.v2.{name}\"\n"
                   f"            android:value=\"{cls}\" />\n" for name, cls in PLUGINS.items())
    text = text.replace("    <application", queries + "    <application", 1)
    text = text.replace("    </application>", meta + "\n    </application>", 1)
    path.write_text(text, encoding="utf-8", newline="\n")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--version", default="4.7.2.stable")
    ap.add_argument("--templates", help="export templates folder (default: Godot's user folder)")
    args = ap.parse_args(argv)
    templates = Path(args.templates) if args.templates else default_templates(args.version)
    source = templates / "android_source.zip"
    if not source.exists():
        print(f"missing {source}: install Godot's export templates first", file=sys.stderr)
        return 1
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)
    with zipfile.ZipFile(source) as z:
        z.extractall(BUILD)
    (BUILD.parent / ".build_version").write_text(args.version, encoding="utf-8")
    (BUILD / ".gdignore").write_text("", encoding="utf-8")
    java = BUILD / "src" / "main" / "java"
    for f in PLUGIN_SRC.rglob("*.java"):
        dest = java / f.relative_to(PLUGIN_SRC)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(f, dest)
    patch_manifest(BUILD / "src" / "main" / "AndroidManifest.xml")
    print(f"Android build ready in {BUILD.relative_to(ROOT)} (plugins: {', '.join(PLUGINS)})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

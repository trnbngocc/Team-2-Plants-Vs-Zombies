#!/usr/bin/env python3
"""Builds the separate submission ZIP (nothing in the working repository is changed or deleted).

  python tools/make_submission_zip.py <output.zip>

Includes the README, C++ sources + tests, godot-cpp sources (no build output), the Godot project with every asset the
game loads, the source sheets / references needed to reproduce the processed art, the tools and the compiled debug DLL.
Excludes .git, .godot caches, object files, logs, build output, editor temp files and assets that nothing loads and no
tool needs (listed in EXCLUDE_ASSETS and documented in README section H).
"""
import os
import sys
import zipfile

REPO = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ROOT_NAME = "Team-2-Plants-Vs-Zombies"
GAME = "plants-vs-zombies"

# Directories that are never packaged (relative to the repo root, forward slashes).
SKIP_DIRS = {
    ".git", ".github", ".godot", ".claude", ".graphify", ".vscode", "build", "__pycache__",
    "extern/godot-cpp/bin", "extern/godot-cpp/gen", "extern/godot-cpp/.git", "extern/godot-cpp/test",
    "extern/godot-cpp/cmake", "extern/godot-cpp/doc_classes",
}
SKIP_SUFFIX = (".o", ".obj", ".os", ".a", ".lib", ".exp", ".pdb", ".log", ".tmp", ".pyc", ".sconsign.dblite", ".dblite")
SKIP_NAMES = {".git", ".gitattributes", ".git-blame-ignore-revs", "msvc_capture.log", "compile_commands.json", "Thumbs.db", "desktop.ini", ".DS_Store"}
# Unreferenced, no tool reads them: older / duplicate files (see README H).
EXCLUDE_ASSETS = {
    f"{GAME}/assets/{n}" for n in ("168191.png", "chilli.png", "pea.png", "sunflower (1).png", "wallnut (1).png")
} | {
    f"{GAME}/assets/lawn/lawn_game.jpg",
    f"{GAME}/assets/env/lawn_mower/lawn_mower.png",
    f"{GAME}/assets/audio/brainzzz.mp3",
    f"{GAME}/assets/audio/choose_plant.m4a",
    f"{GAME}/assets/audio/zombie_falling_1.ogg",
}
EXCLUDE_DIRS = {f"{GAME}/assets/zombies"}      # older generated zombie sheets (nothing loads them)


def skipped(rel):
    parts = rel.split("/")
    if any(p in SKIP_DIRS or "/".join(parts[: i + 1]) in SKIP_DIRS for i, p in enumerate(parts[:-1])):
        return True
    name = parts[-1]
    if name in SKIP_NAMES or name.endswith(SKIP_SUFFIX) or name.startswith("~"):
        return True
    base = name[:-7] if name.endswith(".import") else name
    full = "/".join(parts[:-1] + [base])
    if full in EXCLUDE_ASSETS or any(full.startswith(d + "/") for d in EXCLUDE_DIRS):
        return True
    return False


def main(out):
    files = []
    for top, dirs, names in os.walk(REPO):
        rel_top = os.path.relpath(top, REPO).replace(os.sep, "/")
        rel_top = "" if rel_top == "." else rel_top
        dirs[:] = [d for d in dirs if not skipped((rel_top + "/" if rel_top else "") + d + "/x")]
        for n in names:
            rel = (rel_top + "/" if rel_top else "") + n
            if not skipped(rel):
                files.append(rel)
    # the DLL is a generated file but the lecturer needs it to run without building
    dll = f"{GAME}/bin/libpvz.windows.template_debug.x86_64.dll"
    if not os.path.exists(os.path.join(REPO, dll)):
        sys.exit("missing " + dll + " - run scons first")
    if dll not in files:
        files.append(dll)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel in sorted(files):
            z.write(os.path.join(REPO, rel), f"{ROOT_NAME}/{rel}")
    print(len(files), "files ->", out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "..", ROOT_NAME + "_submission.zip"))

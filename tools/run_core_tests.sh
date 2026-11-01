#!/usr/bin/env bash
# Builds and runs the standalone C++ unit tests in test/ (no Godot needed).
# Usage: bash tools/run_core_tests.sh [build_dir]        (default build dir: build/tests, git-ignored)
# See test/README.md for what each test covers.
set -e
cd "$(dirname "$0")/.."
B="${1:-build/tests}"
mkdir -p "$B"
rm -f "$B"/*.exe

# Game sources that include "game_controller.hpp" with quotes would pick the REAL one in src/ (it needs Godot).
# So they are compiled from copies in $B, with -iquote test/stubs making the stub win.
cp src/wave_manager.cpp src/gargantuar.cpp src/squash.cpp src/jalapeno.cpp "$B/"
CORE="src/imp.cpp src/zombie.cpp src/entity.cpp src/grid.cpp src/plant.cpp"
STUB="-iquote test/stubs -I src"
CXX="g++ -std=c++17"

# tests that use the stub GameController
$CXX $STUB test/wave_manager_test.cpp "$B/wave_manager.cpp" "$B/gargantuar.cpp" $CORE -o "$B/wave_manager_test.exe"
$CXX $STUB test/squash_test.cpp "$B/squash.cpp" "$B/wave_manager.cpp" "$B/gargantuar.cpp" $CORE -o "$B/squash_test.exe"
$CXX $STUB test/jalapeno_test.cpp "$B/jalapeno.cpp" "$B/gargantuar.cpp" $CORE -o "$B/jalapeno_test.exe"
# tests that only need the core classes
$CXX -I src test/zombie_movement_test.cpp $CORE -o "$B/zombie_movement_test.exe"
$CXX -I src test/zombie_visual_state_test.cpp $CORE -o "$B/zombie_visual_state_test.exe"

# Per-file compile flags for editors (VS Code's C/C++ extension reads this through "compileCommands" in
# .vscode/c_cpp_properties.json): the test files are analysed with exactly the flags used above, in particular WITHOUT
# NDEBUG (the extension's default GDExtension configuration defines it, which trips the guard in every test).
ROOT="$(pwd -W 2>/dev/null || pwd)"      # Windows-style path under Git Bash, plain pwd elsewhere
entry() {   # entry <test name> <extra g++ flags...>
    local t="$1"; shift
    local args=""
    for a in "$@"; do args="$args, \"$a\""; done
    printf '  {"directory": "%s", "file": "%s/test/%s_test.cpp", "arguments": ["g++", "-std=c++17", "-UNDEBUG"%s, "test/%s_test.cpp"]}'         "$ROOT" "$ROOT" "$t" "$args" "$t"
}
{
    echo "["
    entry wave_manager -iquote test/stubs -I src; echo ","
    entry squash       -iquote test/stubs -I src; echo ","
    entry jalapeno     -iquote test/stubs -I src; echo ","
    entry zombie_movement      -I src; echo ","
    entry zombie_visual_state  -I src; echo
    echo "]"
} > "$B/compile_commands.json"

n=0
for t in wave_manager squash jalapeno zombie_movement zombie_visual_state; do
    "$B/${t}_test.exe"
    n=$((n + 1))
done
echo "All $n C++ test programs passed."

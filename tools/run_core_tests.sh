#!/usr/bin/env bash
# Builds and runs the standalone C++ unit tests (no Godot needed).
# Usage: bash tools/run_core_tests.sh [build_dir]
set -e
cd "$(dirname "$0")/.."
B="${1:-build/tests}"
mkdir -p "$B"
rm -f "$B"/*.exe
# These .cpp files include "game_controller.hpp" with quotes, so the compiler would pick the
# real one in src/. Compile copies instead so test/stubs/game_controller.hpp is used.
cp src/wave_manager.cpp src/gargantuar.cpp src/squash.cpp src/jalapeno.cpp "$B/"
CORE="src/imp.cpp src/zombie.cpp src/entity.cpp src/grid.cpp src/plant.cpp"
STUB="-iquote test/stubs -I src"
g++ -std=c++17 $STUB test/wave_manager_test.cpp "$B/wave_manager.cpp" "$B/gargantuar.cpp" $CORE -o "$B/wave.exe"
g++ -std=c++17 $STUB test/squash_test.cpp "$B/squash.cpp" "$B/wave_manager.cpp" "$B/gargantuar.cpp" $CORE -o "$B/squash.exe"
g++ -std=c++17 $STUB test/jalapeno_test.cpp "$B/jalapeno.cpp" "$B/gargantuar.cpp" $CORE -o "$B/jalapeno.exe"
g++ -std=c++17 -I src test/zombie_movement_test.cpp $CORE -o "$B/move.exe"
g++ -std=c++17 -I src test/zombie_visual_state_test.cpp $CORE -o "$B/visual.exe"
for t in wave squash jalapeno move visual; do "$B/$t.exe"; done

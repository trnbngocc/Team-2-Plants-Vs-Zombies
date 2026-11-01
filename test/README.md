# C++ unit tests

Stand-alone tests of the C++ game core. They need only `g++` (C++17), not Godot.

```
bash tools/run_core_tests.sh        # builds into build/tests/ (git-ignored) and runs all five programs
```

Each test is one program with plain `assert()` checks (they refuse to compile with `NDEBUG`, which would turn every
check off) and prints one "... test passed." line.

| File | Covers | Needs the stub |
|---|---|---|
| `wave_manager_test.cpp` | per-type zombie stats, armor-then-body damage order, nothing spawns before the start, the 30 s preparation, the full 3+5+7+10 = 25 timeline, random types, announcement events, Gargantuar throwing one Imp (stands still while throwing) | yes |
| `squash_test.cpp` | Squash stats, jump / smash once, damage vs armor and Gargantuar, single use, the "zombie approaching" alert / cancel event, other rows | yes |
| `jalapeno_test.cpp` | Jalapeno stats, 2 s fuse, 900 damage to its row only, armor first, Gargantuar survives | yes |
| `zombie_movement_test.cpp` | spawn row / column, continuous movement, stopping to eat a plant and its damage | no |
| `zombie_visual_state_test.cpp` | the visual state switching to "one arm lost" at half health | no |
| `stubs/game_controller.hpp` | not a test: the stand-in for `GameController` (see below) | |

## The stub

The real `GameController` (`src/game_controller.hpp`) derives from a Godot `Node`, so it cannot be built without the
engine. `stubs/game_controller.hpp` provides just the functions the game classes call, and records the events they raise
(`jalapeno_events`, `squash_smash_events`, `squash_alert_events`, `imp_throw_events`, ...), so tests can assert on them.

- The three stub-based tests include it explicitly as `#include "stubs/game_controller.hpp"`.
- Game sources that include `"game_controller.hpp"` (`wave_manager.cpp`, `gargantuar.cpp`, `squash.cpp`,
  `jalapeno.cpp`) would find the real header in `src/` first, so the script compiles copies of them with
  `-iquote test/stubs`.

### Editor (VS Code) note

Two things can make the C/C++ extension show false errors in these tests, and both are handled:

1. A plain `"game_controller.hpp"` resolves to the real Godot header when the include path is `src/`. The tests therefore
   include the stub by its explicit path (`"stubs/game_controller.hpp"`).
2. The extension's default configuration (`.vscode/c_cpp_properties.json`, written for the GDExtension build) defines
   `NDEBUG`, which trips the `#error` guard in every test and makes `assert()` look like a no-op. `tools/run_core_tests.sh`
   writes `build/tests/compile_commands.json` with the exact per-file flags of the real test build (`-UNDEBUG`,
   `-iquote test/stubs`, ...), and the configuration points at it:

   ```json
   "compileCommands": ["${workspaceFolder}/build/tests/compile_commands.json"]
   ```

   The extension then uses those flags for the five test files and the normal settings for everything else. Run the
   script once after a fresh checkout (`build/` is git-ignored, and `.vscode/` is a personal folder, so add the line
   above to your own `c_cpp_properties.json`). Until the file exists the extension falls back to the default
   configuration and shows the `#error`.

`tools/run_core_tests.sh` remains the source of truth.

## Adding a test

Name it `<subject>_test.cpp`, put it in this folder, include the stub as above if it needs a `GameController`, and add one
`$CXX` line plus its name in the `for` loop of `tools/run_core_tests.sh`. The Godot-side tests live in
`plants-vs-zombies/tests/` (see the main README, section J).

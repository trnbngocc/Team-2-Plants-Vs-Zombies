#pragma once

// Stub GameController for the C++ unit tests, so they run without Godot.
//
// The real GameController derives from godot::Node and cannot exist without the engine. This stub implements only what
// the game classes call (add_zombie, get_zombies_in_row, notify_*) and RECORDS the presentation events they raise
// (jalapeno_events, squash_smash_events, squash_alert_events, imp_throw_events ...) so tests can assert on them.
//
// Who sees it: the tests include it as "stubs/game_controller.hpp". The game sources that include
// "game_controller.hpp" (wave_manager.cpp, gargantuar.cpp, squash.cpp, jalapeno.cpp) would find the REAL one in src/
// first, so tools/run_core_tests.sh compiles copies of them with `-iquote test/stubs`.
// Build and run everything with:  bash tools/run_core_tests.sh   (see test/README.md)

#include <memory>
#include <vector>

#include "zombie.hpp"

namespace godot {

class GameController {
public:
    void add_zombie(std::unique_ptr<pvz::Zombie> zombie) {
        zombies.push_back(std::move(zombie));
    }

    void notify_imp_thrown(int row, float from_column, float to_column) {
        ++imp_throw_events;
        last_imp_row = row;
        last_imp_from = from_column;
        last_imp_to = to_column;
    }

    // Used by Squash::act(): live Zombies of one row, like the real controller.
    std::vector<pvz::Zombie*> get_zombies_in_row(int row) const {
        std::vector<pvz::Zombie*> result;
        for (const auto& z : zombies) {
            if (z->is_alive() && z->get_position().row == row) {
                result.push_back(z.get());
            }
        }
        return result;
    }

    void notify_squash_alert(int row, int column) {
        ++squash_alert_events;
        last_alert_row = row;
        last_alert_column = column;
    }

    void notify_squash_alert_cancelled(int, int) { ++squash_cancel_events; }

    void notify_squash_smashed(int row, float column, int hit_count) {
        ++squash_smash_events;
        last_squash_row = row;
        last_squash_column = column;
        last_squash_hits = hit_count;
    }

    void notify_jalapeno_exploded(pvz::GridPosition pos) {
        ++jalapeno_events;
        last_jalapeno_row = pos.row;
    }

    std::vector<std::unique_ptr<pvz::Zombie>> zombies;

    int jalapeno_events = 0;
    int last_jalapeno_row = -1;
    int squash_smash_events = 0;
    int squash_alert_events = 0;
    int squash_cancel_events = 0;
    int last_alert_row = -1;
    int last_alert_column = -1;
    int last_squash_row = -1;
    float last_squash_column = 0.0f;
    int last_squash_hits = 0;

    int imp_throw_events = 0;
    int last_imp_row = -1;
    float last_imp_from = 0.0f;
    float last_imp_to = 0.0f;
};

} // namespace godot

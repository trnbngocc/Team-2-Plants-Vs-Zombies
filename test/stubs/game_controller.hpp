#pragma once

// Stub GameController for testing WaveManager / Gargantuar outside Godot.
//
// The real GameController derives from godot::Node, so it cannot be created
// without the engine. This stub only records the Zombies that get spawned and
// the presentation events they raise.
//
// src/wave_manager.cpp and src/gargantuar.cpp include "game_controller.hpp" with
// quotes, so the compiler always looks in src/ first. Therefore copy those
// files to a build directory and compile the copies:
//     cp src/wave_manager.cpp src/gargantuar.cpp build/
//     g++ -std=c++17 -iquote test/stubs -I src
//         test/wave_manager_test.cpp build/wave_manager.cpp build/gargantuar.cpp
//         src/imp.cpp src/zombie.cpp src/entity.cpp src/grid.cpp

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

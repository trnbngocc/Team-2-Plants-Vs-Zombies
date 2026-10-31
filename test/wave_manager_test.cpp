#include <cassert>
#include <cmath>
#include <iostream>
#include <set>
#include <vector>

// Resolves to test/stubs/game_controller.hpp (see build note there).
#include "game_controller.hpp"
#include "wave_manager.hpp"

namespace {

constexpr double STEP = 1.0 / 60.0;   // same frame step as the game

using godot::WaveManager;
using Armor = pvz::Zombie::ArmorType;

struct SpawnEvent {
    double time;
    int wave;
    Armor armor;
};

// Runs a full game from begin_preparation() and records every spawn.
std::vector<SpawnEvent> run_full_game(
    godot::GameController& controller,
    WaveManager& waves,
    double max_seconds = 300.0
) {
    std::vector<SpawnEvent> events;
    double t = 0.0;

    waves.begin_preparation();

    while (!waves.is_finished() && t < max_seconds) {
        waves.update(STEP);
        t += STEP;

        while (events.size() < controller.zombies.size()) {
            const auto& z = *controller.zombies[events.size()];
            events.push_back({t, waves.get_current_wave(), z.get_armor_type()});
        }
    }

    return events;
}

bool near(double a, double b, double tol = 2 * STEP) {
    return std::fabs(a - b) <= tol;
}

} // namespace

int main() {
    // ==========================================
    // 1. SPAWN FUNCTIONS: stats per Zombie type
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);

        waves.spawn_regular(0, 8.0f);
        waves.spawn_conehead(1, 8.0f);
        waves.spawn_buckethead(2, 8.0f);

        assert(controller.zombies.size() == 3);

        const auto& regular = *controller.zombies[0];
        const auto& cone = *controller.zombies[1];
        const auto& bucket = *controller.zombies[2];

        assert(regular.get_position().row == 0);
        assert(regular.get_column_position() == 8.0f);
        assert(regular.get_health() == 200);
        assert(regular.get_armor_type() == Armor::NONE);
        assert(regular.get_armor_health() == 0);

        assert(cone.get_health() == 200);
        assert(cone.get_armor_type() == Armor::CONE);
        assert(cone.get_armor_health() == 200);

        assert(bucket.get_health() == 200);
        assert(bucket.get_armor_type() == Armor::BUCKET);
        assert(bucket.get_armor_health() == 300);

        // Same speed for every type: one column per 4.7 seconds.
        for (const auto& z : controller.zombies) {
            assert(std::fabs(1.0 / z->get_speed() - 4.7) < 1e-4);
            assert(z->get_damage() == 10);
        }

        // Spawning directly is not a wave.
        assert(!waves.is_finished());
    }

    // ==========================================
    // 2. NOT STARTED -> nothing spawns
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);

        waves.update(100.0);

        assert(controller.zombies.empty());
        assert(waves.get_current_wave() == 0);
        assert(waves.get_preparation_time_left() == 0.0);
        assert(!waves.is_finished());

        // Out-of-range waves are ignored.
        waves.start_wave(0);
        waves.start_wave(WaveManager::TOTAL_WAVES + 1);
        assert(waves.get_current_wave() == 0);
    }

    // ==========================================
    // 3. PREPARATION: 30 s without Zombies
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);

        waves.begin_preparation();
        assert(waves.get_preparation_time_left() == 30.0);
        assert(waves.get_current_wave() == 0);

        double t = 0.0;
        while (t < 29.9) {
            waves.update(STEP);
            t += STEP;
            assert(controller.zombies.empty());
            assert(near(waves.get_preparation_time_left(), 30.0 - t, 1e-6));
            assert(!waves.is_finished());
        }

        // Pausing = no update() calls: the countdown does not move.
        const double left = waves.get_preparation_time_left();
        assert(near(waves.get_preparation_time_left(), left, 0.0));

        while (controller.zombies.empty() && t < 31.0) {
            waves.update(STEP);
            t += STEP;
        }

        assert(controller.zombies.size() == 1);
        assert(near(t, 30.0));
        assert(waves.get_current_wave() == 1);
        assert(waves.get_preparation_time_left() == 0.0);
    }

    // ==========================================
    // 4. FULL TIMELINE: 3 + 5 + 7 = 15 Zombies
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);

        const auto events = run_full_game(controller, waves);

        assert(waves.is_finished());
        assert(events.size() == 15);

        std::vector<SpawnEvent> per_wave[4];
        for (const auto& e : events) {
            assert(e.wave >= 1 && e.wave <= 3);
            per_wave[e.wave].push_back(e);
        }

        assert(per_wave[1].size() == 3);
        assert(per_wave[2].size() == 5);
        assert(per_wave[3].size() == 7);

        // Wave 1: regular only, at 30 / 40 / 50 s.
        for (std::size_t i = 0; i < per_wave[1].size(); ++i) {
            assert(per_wave[1][i].armor == Armor::NONE);
            assert(near(per_wave[1][i].time, 30.0 + 10.0 * static_cast<double>(i)));
        }

        // Wave 2: regular or Conehead, 5 s apart.
        for (std::size_t i = 0; i < per_wave[2].size(); ++i) {
            assert(per_wave[2][i].armor == Armor::NONE ||
                   per_wave[2][i].armor == Armor::CONE);
            if (i > 0) {
                assert(near(per_wave[2][i].time - per_wave[2][i - 1].time, 5.0));
            }
        }

        // Wave 3: any type, 5 s apart.
        for (std::size_t i = 1; i < per_wave[3].size(); ++i) {
            assert(near(per_wave[3][i].time - per_wave[3][i - 1].time, 5.0));
        }

        // Breaks: the next wave's first Zombie comes WAVE_BREAK_SECONDS
        // after the previous wave's last Zombie.
        assert(near(per_wave[2][0].time - per_wave[1].back().time,
                    WaveManager::WAVE_BREAK_SECONDS));
        assert(near(per_wave[3][0].time - per_wave[2].back().time,
                    WaveManager::WAVE_BREAK_SECONDS));

        // Expected schedule: 30,40,50 | 53..73 | 76..106.
        assert(near(per_wave[2][0].time, 53.0));
        assert(near(per_wave[3][0].time, 76.0));
        assert(near(events.back().time, 106.0));

        // ==========================================
        // 5. FINISHED: stable, no wave repeats
        // ==========================================
        waves.update(1000.0);
        waves.update(1000.0);
        assert(waves.is_finished());
        assert(waves.get_current_wave() == WaveManager::TOTAL_WAVES);
        assert(controller.zombies.size() == 15);
    }

    // ==========================================
    // 6. RANDOM TYPES: only allowed types, all reachable
    // ==========================================
    {
        std::set<Armor> wave2_types;
        std::set<Armor> wave3_types;

        for (int run = 0; run < 60; ++run) {
            godot::GameController controller;
            WaveManager waves(&controller);
            const auto events = run_full_game(controller, waves);
            assert(events.size() == 15);

            for (const auto& e : events) {
                if (e.wave == 1) assert(e.armor == Armor::NONE);
                if (e.wave == 2) {
                    assert(e.armor != Armor::BUCKET);
                    wave2_types.insert(e.armor);
                }
                if (e.wave == 3) wave3_types.insert(e.armor);
            }

            for (const auto& z : controller.zombies) {
                assert(z->get_health() == 200);
                const int armor = z->get_armor_health();
                switch (z->get_armor_type()) {
                    case Armor::NONE: assert(armor == 0); break;
                    case Armor::CONE: assert(armor == 200); break;
                    case Armor::BUCKET: assert(armor == 300); break;
                }
            }
        }

        assert(wave2_types.size() == 2);
        assert(wave3_types.size() == 3);
    }

    std::cout << "WaveManager test passed.\n";

    return 0;
}

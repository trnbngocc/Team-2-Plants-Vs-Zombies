// These tests rely on assert(): refuse to build them with NDEBUG, which would silently turn every check off.
#ifdef NDEBUG
#error "build the unit tests without NDEBUG (tools/run_core_tests.sh does)"
#endif

#include <cassert>
#include <cmath>
#include <iostream>
#include <set>
#include <vector>

// The stub (test/stubs/game_controller.hpp), named explicitly so editors / IntelliSense do not pick the
// real Godot-based src/game_controller.hpp.
#include "stubs/game_controller.hpp"
#include "wave_manager.hpp"
#include "gargantuar.hpp"
#include "imp.hpp"

namespace {

constexpr double STEP = 1.0 / 60.0;   // same frame step as the game

using godot::WaveManager;
using Armor = pvz::Zombie::ArmorType;
using Kind = pvz::Zombie::Kind;

struct SpawnEvent {
    double time;
    int wave;
    Armor armor;
    Kind kind;
};

// Runs a full game from begin_preparation() and records every spawn.
std::vector<SpawnEvent> run_full_game(
    godot::GameController& controller,
    WaveManager& waves,
    double max_seconds = 400.0
) {
    std::vector<SpawnEvent> events;
    double t = 0.0;

    waves.begin_preparation();

    while (!waves.is_finished() && t < max_seconds) {
        waves.update(STEP);
        t += STEP;

        while (events.size() < controller.zombies.size()) {
            const auto& z = *controller.zombies[events.size()];
            events.push_back({
                t, waves.get_current_wave(), z.get_armor_type(), z.get_kind()
            });
        }
    }

    return events;
}

bool near(double a, double b, double tol = 2 * STEP) {
    return std::fabs(a - b) <= tol;
}

// One frame of the Gargantuar as GameController runs it: update, then act.
void tick(pvz::Gargantuar& boss, godot::GameController& controller, double dt = STEP) {
    boss.update(dt);
    boss.act(controller);
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

        // Regular 200, Conehead 370 + 200 = 570, Buckethead 1100 + 200 = 1300.
        assert(cone.get_health() == 200);
        assert(cone.get_armor_type() == Armor::CONE);
        assert(cone.get_armor_health() == 370);
        assert(cone.get_health() + cone.get_armor_health() == 570);

        assert(bucket.get_health() == 200);
        assert(bucket.get_armor_type() == Armor::BUCKET);
        assert(bucket.get_armor_health() == 1100);
        assert(bucket.get_health() + bucket.get_armor_health() == 1300);

        // Same speed for every ordinary type: one column per 4.7 seconds.
        for (const auto& z : controller.zombies) {
            assert(std::fabs(1.0 / z->get_speed() - 4.7) < 1e-4);
            assert(z->get_damage() == 10);
            assert(z->get_kind() == Kind::ORDINARY);
        }

        // Spawning directly is not a wave.
        assert(!waves.is_finished());
        assert(waves.get_enemies_spawned() == 0);
    }

    // ==========================================
    // 1b. DAMAGE ORDER: armor first, then body HP
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);
        waves.spawn_conehead(0, 8.0f);
        waves.spawn_buckethead(1, 8.0f);
        waves.spawn_regular(2, 8.0f);

        auto& cone = *controller.zombies[0];
        auto& bucket = *controller.zombies[1];
        auto& regular = *controller.zombies[2];

        // The spec example: 400 damage on a Conehead = 370 armor + 30 body HP.
        cone.take_damage(400);
        assert(cone.get_armor_health() == 0);
        assert(!cone.has_armor());
        assert(cone.get_armor_type() == Armor::NONE);
        assert(cone.get_health() == 170);
        assert(cone.is_alive());

        // Armor absorbs everything while it lasts; body untouched.
        bucket.take_damage(1000);
        assert(bucket.get_armor_health() == 100);
        assert(bucket.get_health() == 200);
        bucket.take_damage(150);
        assert(bucket.get_armor_health() == 0);
        assert(bucket.get_health() == 150);

        regular.take_damage(200);
        assert(!regular.is_alive());

        // Jalapeno's 900 kills a 570-HP Conehead but not a 1300-HP Buckethead.
        godot::GameController c2;
        WaveManager w2(&c2);
        w2.spawn_conehead(0, 8.0f);
        w2.spawn_buckethead(0, 8.0f);
        c2.zombies[0]->take_damage(900);
        c2.zombies[1]->take_damage(900);
        assert(!c2.zombies[0]->is_alive());
        assert(c2.zombies[1]->is_alive());
        assert(c2.zombies[1]->get_armor_health() == 200);
        assert(c2.zombies[1]->get_health() == 200);
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
    // 4. FULL TIMELINE: 3 + 5 + 7 + 10 = 25 enemies
    // ==========================================
    {
        static_assert(WaveManager::TOTAL_WAVES == 4, "four waves");
        static_assert(WaveManager::TOTAL_ENEMIES == 25, "25 enemies");

        godot::GameController controller;
        WaveManager waves(&controller);

        const auto events = run_full_game(controller, waves);

        assert(waves.is_finished());
        assert(events.size() == 25);
        assert(waves.get_enemies_spawned() == 25);
        assert(waves.get_enemies_queued() == 0);

        std::vector<SpawnEvent> per_wave[5];
        for (const auto& e : events) {
            assert(e.wave >= 1 && e.wave <= 4);
            per_wave[e.wave].push_back(e);
        }

        assert(per_wave[1].size() == 3);
        assert(per_wave[2].size() == 5);
        assert(per_wave[3].size() == 7);
        assert(per_wave[4].size() == 10);

        // Wave 1: regular only, at 30 / 40 / 50 s.
        for (std::size_t i = 0; i < per_wave[1].size(); ++i) {
            assert(per_wave[1][i].armor == Armor::NONE);
            assert(per_wave[1][i].kind == Kind::ORDINARY);
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

        // Waves 3 and 4: 5 s apart.
        for (int w = 3; w <= 4; ++w) {
            for (std::size_t i = 1; i < per_wave[w].size(); ++i) {
                assert(near(per_wave[w][i].time - per_wave[w][i - 1].time, 5.0));
            }
        }

        // Breaks: the next wave's first enemy comes WAVE_BREAK_SECONDS
        // after the previous wave's last enemy.
        for (int w = 2; w <= 4; ++w) {
            const double expected = (w == 4) ? WaveManager::FINAL_WAVE_BREAK_SECONDS
                                             : WaveManager::WAVE_BREAK_SECONDS;
            assert(near(per_wave[w][0].time - per_wave[w - 1].back().time, expected));
        }

        // Expected schedule: 30,40,50 | 53..73 | 76..106 | 113..158
        // (the pause before the final wave is FINAL_WAVE_BREAK_SECONDS).
        assert(near(per_wave[2][0].time, 53.0));
        assert(near(per_wave[3][0].time, 76.0));
        assert(near(per_wave[4][0].time, 113.0));
        assert(near(events.back().time, 158.0));

        // ==========================================
        // 4b. FINAL WAVE: 4 Regular + 3 Cone + 2 Bucket + 1 Gargantuar,
        //     first 3 ordinary, then the Gargantuar, then the other 6.
        // ==========================================
        int regulars = 0, cones = 0, buckets = 0, bosses = 0;
        for (std::size_t i = 0; i < per_wave[4].size(); ++i) {
            const auto& e = per_wave[4][i];
            if (e.kind == Kind::GARGANTUAR) {
                ++bosses;
                assert(i == 3);   // after exactly three ordinary Zombies
            } else {
                assert(e.kind == Kind::ORDINARY);
                if (e.armor == Armor::NONE) ++regulars;
                if (e.armor == Armor::CONE) ++cones;
                if (e.armor == Armor::BUCKET) ++buckets;
            }
        }
        assert(regulars == 4);
        assert(cones == 3);
        assert(buckets == 2);
        assert(bosses == 1);

        // The boss has 2000 HP, no armor.
        for (const auto& z : controller.zombies) {
            if (z->get_kind() == Kind::GARGANTUAR) {
                assert(z->get_health() == 2000);
                assert(z->get_armor_type() == Armor::NONE);
                assert(1.0 / z->get_speed() > 4.7);   // slower than ordinary Zombies
            }
        }

        // ==========================================
        // 5. FINISHED: stable, no wave repeats
        // ==========================================
        waves.update(1000.0);
        waves.update(1000.0);
        assert(waves.is_finished());
        assert(waves.get_current_wave() == WaveManager::TOTAL_WAVES);
        assert(controller.zombies.size() == 25);
        assert(waves.get_enemies_spawned() == 25);
    }

    // ==========================================
    // 6. RANDOM TYPES: only allowed types, exact totals, every run
    // ==========================================
    {
        std::set<Armor> wave2_types;
        std::set<Armor> wave3_types;

        for (int run = 0; run < 60; ++run) {
            godot::GameController controller;
            WaveManager waves(&controller);
            const auto events = run_full_game(controller, waves);
            assert(events.size() == 25);

            int final_regulars = 0, final_cones = 0, final_buckets = 0, final_bosses = 0;

            for (const auto& e : events) {
                if (e.wave == 1) assert(e.armor == Armor::NONE);
                if (e.wave == 2) {
                    assert(e.armor != Armor::BUCKET);
                    wave2_types.insert(e.armor);
                }
                if (e.wave == 3) wave3_types.insert(e.armor);
                if (e.wave == 4) {
                    if (e.kind == Kind::GARGANTUAR) ++final_bosses;
                    else if (e.armor == Armor::NONE) ++final_regulars;
                    else if (e.armor == Armor::CONE) ++final_cones;
                    else ++final_buckets;
                }
            }

            assert(final_regulars == 4 && final_cones == 3 &&
                   final_buckets == 2 && final_bosses == 1);

            for (const auto& z : controller.zombies) {
                if (z->get_kind() == Kind::GARGANTUAR) continue;
                assert(z->get_health() == 200);
                const int armor = z->get_armor_health();
                switch (z->get_armor_type()) {
                    case Armor::NONE: assert(armor == 0); break;
                    case Armor::CONE: assert(armor == 370); break;
                    case Armor::BUCKET: assert(armor == 1100); break;
                }
            }
        }

        assert(wave2_types.size() == 2);
        assert(wave3_types.size() == 3);
    }

    // ==========================================
    // 6b. ANNOUNCEMENT EVENTS: warning once before wave 4, wave_started once per wave
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);
        waves.begin_preparation();

        int warnings = 0;
        int final_banners = 0;
        int started[5] = {0, 0, 0, 0, 0};
        double warning_time = -1.0, final_banner_time = -1.0, final_start_time = -1.0;
        double first_wave4_spawn = -1.0;
        std::size_t seen_zombies = 0;
        double t = 0.0;
        bool order_ok = true;

        while (!waves.is_finished() && t < 400.0) {
            waves.update(STEP);
            t += STEP;
            if (waves.consume_huge_wave_warning()) {
                ++warnings;
                warning_time = t;
                if (started[4] != 0) order_ok = false;   // warning must precede Wave 4
            }
            if (waves.consume_final_wave_banner()) {
                ++final_banners;
                final_banner_time = t;
                if (started[4] != 0) order_ok = false;   // banner 2 must precede Wave 4
                if (warnings != 1) order_ok = false;     // ...and follow banner 1
            }
            const int w = waves.consume_wave_started();
            if (w > 0) {
                ++started[w];
                if (w == 4) final_start_time = t;
            }
            if (controller.zombies.size() > seen_zombies) {
                seen_zombies = controller.zombies.size();
                if (started[4] != 0 && first_wave4_spawn < 0.0) first_wave4_spawn = t;
            }
        }

        assert(warnings == 1);
        assert(final_banners == 1);
        for (int w = 1; w <= 4; ++w) assert(started[w] == 1);
        assert(order_ok);

        // Sequence: banner 1 -> (its slot) -> banner 2 -> (its slot) -> wave 4 + first zombie.
        assert(near(final_banner_time - warning_time, WaveManager::HUGE_WAVE_BANNER_SECONDS));
        assert(near(final_start_time - final_banner_time, WaveManager::FINAL_WAVE_BANNER_SECONDS));
        assert(near(final_start_time - warning_time, WaveManager::FINAL_WAVE_BREAK_SECONDS));
        // No wave-4 zombie appears before both banner slots are over.
        assert(first_wave4_spawn >= final_start_time - 0.01);
        assert(first_wave4_spawn <= final_start_time + 2 * STEP);
        // The warning is a distinct, earlier moment: the full final-wave break before Wave 4.
        assert(final_start_time - warning_time >= WaveManager::FINAL_WAVE_BREAK_SECONDS - 0.1);

        // Nothing is re-fired afterwards, however long we keep updating.
        waves.update(1000.0);
        assert(!waves.consume_huge_wave_warning());
        assert(!waves.consume_final_wave_banner());
        assert(waves.consume_wave_started() == 0);
    }

    // ==========================================
    // 7. GARGANTUAR: one Imp at <= 1000 HP, and only one
    // ==========================================
    {
        godot::GameController controller;
        pvz::Gargantuar boss(pvz::GridPosition{2, 8});
        boss.set_grid(nullptr);

        assert(boss.get_health() == 2000);
        assert(boss.get_kind() == Kind::GARGANTUAR);

        // Above the threshold: no Imp, even after many frames.
        for (int i = 0; i < 120; ++i) tick(boss, controller);
        boss.take_damage(900);                 // e.g. a Jalapeno explosion
        assert(boss.is_alive());               // NOT killed by 900
        assert(boss.get_health() == 1100);
        for (int i = 0; i < 120; ++i) tick(boss, controller);
        assert(controller.imp_throw_events == 0);
        assert(controller.zombies.empty());
        assert(!boss.has_thrown_imp());

        // Reaches exactly 1000 -> throws.
        boss.take_damage(100);
        assert(boss.get_health() == 1000);
        tick(boss, controller);
        assert(boss.has_thrown_imp());
        assert(controller.imp_throw_events == 1);
        assert(controller.zombies.size() == 1);
        assert(controller.zombies[0]->get_kind() == Kind::IMP);
        assert(controller.zombies[0]->get_health() == pvz::Imp::HEALTH);
        assert(controller.last_imp_row == 2);

        // Staying at / below the threshold, or taking more damage, never throws again.
        boss.take_damage(300);
        for (int i = 0; i < 600; ++i) tick(boss, controller);
        assert(boss.is_alive());
        assert(controller.imp_throw_events == 1);
        assert(controller.zombies.size() == 1);
    }

    // ==========================================
    // 7b. GARGANTUAR: a single big hit that jumps over 1000 still throws
    // ==========================================
    {
        godot::GameController controller;
        pvz::Gargantuar boss(pvz::GridPosition{0, 8});

        boss.take_damage(1500);                // 2000 -> 500, skipping 1000 exactly
        assert(boss.is_alive());
        assert(boss.get_health() == 500);
        tick(boss, controller);
        assert(controller.imp_throw_events == 1);
        assert(controller.zombies.size() == 1);
    }

    // ==========================================
    // 7c. GARGANTUAR: stands still while throwing, walks afterwards
    // ==========================================
    {
        godot::GameController controller;
        pvz::Gargantuar boss(pvz::GridPosition{1, 8});
        // default_update() needs a Grid to move; give it an empty one.
        pvz::Grid grid;
        boss.set_grid(&grid);

        boss.take_damage(1100);                // 900 HP: below threshold
        tick(boss, controller);                // detects, starts throwing
        assert(boss.get_action_state() == pvz::Gargantuar::ACTION_THROWING);

        const float before = boss.get_column_position();
        for (int i = 0; i < 30; ++i) tick(boss, controller);   // 0.5 s: still throwing
        assert(boss.get_column_position() == before);

        for (int i = 0; i < 60; ++i) tick(boss, controller);   // past 1 s
        assert(boss.get_action_state() == pvz::Gargantuar::ACTION_NORMAL);
        assert(boss.get_column_position() < before);           // walking again
        assert(controller.imp_throw_events == 1);
    }

    // ==========================================
    // 7d. GARGANTUAR dying in one go never throws
    // ==========================================
    {
        godot::GameController controller;
        pvz::Gargantuar boss(pvz::GridPosition{0, 8});
        boss.take_damage(5000);
        assert(!boss.is_alive());
        tick(boss, controller);
        assert(controller.imp_throw_events == 0);
    }

    // ==========================================
    // 8. KNOCKBACK: pushes right, clamps at the spawn edge
    // ==========================================
    {
        godot::GameController controller;
        WaveManager waves(&controller);
        waves.spawn_regular(0, 3.0f);
        auto& z = *controller.zombies[0];

        z.knock_back(2.0f);
        assert(near(z.get_column_position(), 5.0f, 1e-4));
        assert(z.get_position().column == 5);

        z.knock_back(100.0f);
        assert(z.get_column_position() < 9.0f);
    }

    std::cout << "WaveManager test passed.\n";

    return 0;
}

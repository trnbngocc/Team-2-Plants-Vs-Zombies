// These tests rely on assert(): refuse to build them with NDEBUG, which would silently turn every check off.
#ifdef NDEBUG
#error "build the unit tests without NDEBUG (tools/run_core_tests.sh does)"
#endif

#include <cassert>
#include <iostream>
#include <memory>

// The stub (test/stubs/game_controller.hpp), named explicitly so editors / IntelliSense do not pick the
// real Godot-based src/game_controller.hpp.
#include "stubs/game_controller.hpp"
#include "jalapeno.hpp"
#include "gargantuar.hpp"

// Build and run: bash tools/run_core_tests.sh   (see test/README.md)

namespace {
constexpr double STEP = 1.0 / 60.0;
using Armor = pvz::Zombie::ArmorType;

pvz::Zombie* add(godot::GameController& c, Armor a, int armor_hp, int row, float col) {
    c.add_zombie(std::make_unique<pvz::Zombie>(
        pvz::GridPosition{row, static_cast<int>(col)}, 200, 10, 0.2f, a, armor_hp));
    return c.zombies.back().get();
}
}

int main() {
    // Stats and the 2 s fuse: nothing happens before it burns out.
    {
        godot::GameController c;
        pvz::Jalapeno j(pvz::GridPosition{2, 3});
        assert(j.get_health() == 300);
        assert(j.get_cost() == 125);

        auto* z = add(c, Armor::NONE, 0, 2, 6.0f);
        for (double t = 0.0; t < 1.9; t += STEP) { j.update(STEP); j.act(c); }
        assert(c.jalapeno_events == 0);
        assert(z->is_alive());

        for (double t = 0.0; t < 0.3; t += STEP) { j.update(STEP); j.act(c); }
        assert(c.jalapeno_events == 1);       // exploded exactly once
        assert(c.last_jalapeno_row == 2);
        assert(!z->is_alive());
        assert(!j.is_alive());                // consumed

        for (int i = 0; i < 300; ++i) { j.update(STEP); j.act(c); }
        assert(c.jalapeno_events == 1);       // never explodes twice
    }

    // 900 damage hits the whole row only; armor first; Buckethead survives with 400 left.
    {
        godot::GameController c;
        auto* regular = add(c, Armor::NONE, 0, 1, 7.0f);
        auto* cone = add(c, Armor::CONE, 370, 1, 5.0f);
        auto* bucket = add(c, Armor::BUCKET, 1100, 1, 4.0f);
        auto* other_row = add(c, Armor::NONE, 0, 3, 5.0f);

        pvz::Jalapeno j(pvz::GridPosition{1, 0});
        for (double t = 0.0; t < 2.2; t += STEP) { j.update(STEP); j.act(c); }

        assert(!regular->is_alive());
        assert(!cone->is_alive());                 // 570 < 900
        assert(bucket->is_alive());                // 1300 - 900 = 400
        assert(bucket->get_armor_health() == 200);
        assert(bucket->get_health() == 200);
        assert(other_row->is_alive());             // different row untouched
    }

    // Gargantuar is NOT killed by 900 and still throws exactly one Imp afterwards.
    {
        godot::GameController c;
        c.add_zombie(std::make_unique<pvz::Gargantuar>(pvz::GridPosition{0, 6}));
        auto* g = c.zombies.back().get();

        pvz::Jalapeno j(pvz::GridPosition{0, 1});
        for (double t = 0.0; t < 2.2; t += STEP) { j.update(STEP); j.act(c); }

        assert(g->is_alive());
        assert(g->get_health() == 1100);           // 2000 - 900
        for (int i = 0; i < 60; ++i) { g->update(STEP); g->act(c); }
        assert(c.imp_throw_events == 0);           // 1100 > 1000: no Imp yet

        g->take_damage(100);                       // reaches exactly 1000
        for (int i = 0; i < 600; ++i) { g->update(STEP); g->act(c); }
        assert(c.imp_throw_events == 1);
        assert(c.zombies.size() == 2);
    }

    std::cout << "Jalapeno test passed.\n";
    return 0;
}

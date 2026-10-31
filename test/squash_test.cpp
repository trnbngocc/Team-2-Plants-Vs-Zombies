#include <cassert>
#include <cmath>
#include <iostream>
#include <memory>

// Resolves to test/stubs/game_controller.hpp (see build note there).
#include "game_controller.hpp"
#include "squash.hpp"
#include "gargantuar.hpp"
#include "lawn_mower.hpp"
#include "wave_manager.hpp"

// Build (copy the .cpp files that include "game_controller.hpp" first):
//     cp src/squash.cpp src/wave_manager.cpp src/gargantuar.cpp build/
//     g++ -std=c++17 -iquote test/stubs -I src test/squash_test.cpp
//         build/squash.cpp build/wave_manager.cpp build/gargantuar.cpp
//         src/imp.cpp src/zombie.cpp src/entity.cpp src/grid.cpp src/plant.cpp

namespace {

constexpr double STEP = 1.0 / 60.0;
using Armor = pvz::Zombie::ArmorType;

// One frame as GameController runs it: update, then act.
void tick(pvz::Squash& s, godot::GameController& c, double dt = STEP) {
    s.update(dt);
    s.act(c);
}

void run(pvz::Squash& s, godot::GameController& c, double seconds) {
    for (double t = 0.0; t < seconds; t += STEP) tick(s, c);
}

// Lets the test place a Zombie at an exact (fractional) column.
struct Mover : pvz::Zombie {
    using pvz::Zombie::Zombie;
    using pvz::Zombie::set_column_position;
};

void move_to(pvz::Zombie* z, float column) { static_cast<Mover*>(z)->set_column_position(column); }

pvz::Zombie* add_zombie(godot::GameController& c, Armor armor, int armor_hp,
                        int row, float column) {
    c.add_zombie(std::make_unique<Mover>(
        pvz::GridPosition{row, static_cast<int>(column)}, 200, 10, 0.2f, armor, armor_hp));
    return c.zombies.back().get();
}

} // namespace

int main() {
    // Alert (preparation sound) is separate from the attack: one cell earlier, once, cancellable, same row only.
    {
        godot::GameController c;
        pvz::Squash s(pvz::GridPosition{1, 3});
        tick(s, c);
        assert(c.squash_alert_events == 0);                 // planted, nothing near: silent
        add_zombie(c, Armor::NONE, 0, 0, 4.0f);             // other row
        tick(s, c);
        assert(c.squash_alert_events == 0);
        auto* z = add_zombie(c, Armor::NONE, 0, 1, 5.3f);
        move_to(z, 5.3f);   // in detection range (<= 5.5), outside attack range (> 4.5)
        tick(s, c);
        assert(c.squash_alert_events == 1 && c.last_alert_row == 1 && c.last_alert_column == 3);
        assert(s.get_state() == pvz::Squash::STATE_IDLE);   // not attacking yet
        run(s, c, 1.0);
        assert(c.squash_alert_events == 1);                 // not re-sent every tick
        move_to(z, 7.0f);                       // leaves before attacking
        tick(s, c);
        assert(c.squash_cancel_events == 1 && s.get_state() == pvz::Squash::STATE_IDLE && c.squash_smash_events == 0);
        move_to(z, 5.0f);                       // approaches again: a new alert
        tick(s, c);
        assert(c.squash_alert_events == 2);
        move_to(z, 4.2f);                       // enters the attack range
        tick(s, c);
        assert(s.get_state() == pvz::Squash::STATE_JUMPING && c.squash_alert_events == 2 && c.squash_cancel_events == 1);
        run(s, c, 0.6);
        assert(c.squash_smash_events == 1 && c.squash_cancel_events == 1);
    }

    // Squash stats come from the design: 300 HP, 50 Sun.
    {
        pvz::Squash s(pvz::GridPosition{0, 3});
        assert(s.get_health() == 300);
        assert(s.get_cost() == 50);
        assert(s.get_state() == pvz::Squash::STATE_IDLE);
    }

    // Nothing in range -> it waits, never smashes.
    {
        godot::GameController c;
        add_zombie(c, Armor::NONE, 0, 1, 8.0f);   // far away
        add_zombie(c, Armor::NONE, 0, 2, 4.0f);   // right column, wrong row
        pvz::Squash s(pvz::GridPosition{1, 3});
        run(s, c, 5.0);
        assert(s.is_alive());
        assert(c.squash_smash_events == 0);
        assert(s.get_state() == pvz::Squash::STATE_IDLE);
    }

    // Regular zombie in range: jumps, then smashes exactly once, then is consumed.
    {
        godot::GameController c;
        auto* z = add_zombie(c, Armor::NONE, 0, 1, 4.2f);
        pvz::Squash s(pvz::GridPosition{1, 3});

        tick(s, c);
        assert(s.get_state() == pvz::Squash::STATE_JUMPING);
        assert(c.squash_smash_events == 0);     // nothing at "planting"/trigger time
        assert(z->is_alive());

        run(s, c, 0.3);
        assert(c.squash_smash_events == 0);     // still in the air

        run(s, c, 0.5);                          // lands
        assert(c.squash_smash_events == 1);
        assert(c.last_squash_hits == 1);
        assert(c.last_squash_row == 1);
        assert(!z->is_alive());
        assert(!s.is_alive());                   // single use

        run(s, c, 2.0);                          // dead plant never smashes again
        assert(c.squash_smash_events == 1);
    }

    // 1800 damage vs every type: armor first, then body.
    {
        godot::GameController c;
        auto* cone = add_zombie(c, Armor::CONE, 370, 0, 4.0f);
        auto* bucket = add_zombie(c, Armor::BUCKET, 1100, 1, 4.0f);

        pvz::Squash s1(pvz::GridPosition{0, 3});
        pvz::Squash s2(pvz::GridPosition{1, 3});
        run(s1, c, 1.0);
        run(s2, c, 1.0);

        assert(!cone->is_alive());     // 570 HP < 1800
        assert(!bucket->is_alive());   // 1300 HP < 1800
        assert(c.squash_smash_events == 2);
    }

    // Gargantuar: 1800 does NOT kill a full-health boss (2000 HP), and the
    // boss still throws its one Imp afterwards.
    {
        godot::GameController c;
        pvz::Gargantuar boss(pvz::GridPosition{2, 4});
        // Register the boss with the stub controller so Squash can see it.
        // (Stub owns Zombies via unique_ptr; build one and keep a raw pointer.)
        c.add_zombie(std::make_unique<pvz::Gargantuar>(pvz::GridPosition{2, 4}));
        auto* g = c.zombies.back().get();

        pvz::Squash s(pvz::GridPosition{2, 3});
        run(s, c, 1.0);

        assert(c.squash_smash_events == 1);
        assert(c.last_squash_hits == 1);
        assert(g->is_alive());
        assert(g->get_health() == 200);

        // Next frames: threshold crossed -> exactly one Imp.
        g->update(STEP);
        g->act(c);
        g->update(STEP);
        g->act(c);
        assert(c.imp_throw_events == 1);
        (void)boss;
    }

    // Two squashes on one zombie: the second one finds an empty row afterwards.
    {
        godot::GameController c;
        add_zombie(c, Armor::NONE, 0, 0, 4.0f);
        pvz::Squash a(pvz::GridPosition{0, 3});
        pvz::Squash b(pvz::GridPosition{0, 2});
        run(a, c, 1.0);
        assert(!a.is_alive());
        run(b, c, 1.0);
        assert(b.is_alive());                     // nothing left to smash
        assert(c.squash_smash_events == 1);
    }

    // Lawn mower: one use only.
    {
        pvz::LawnMower m(3);
        assert(m.get_state() == pvz::LawnMower::State::READY);
        m.update(1.0);                            // READY mowers do not move
        assert(m.get_column() == pvz::LawnMower::START_COLUMN);

        m.activate();
        assert(m.get_state() == pvz::LawnMower::State::RUNNING);
        for (int i = 0; i < 60 * 3; ++i) m.update(STEP);
        assert(m.get_state() == pvz::LawnMower::State::USED);

        m.activate();                              // cannot be re-armed
        assert(m.get_state() == pvz::LawnMower::State::USED);
    }

    std::cout << "Squash / LawnMower test passed.\n";
    return 0;
}

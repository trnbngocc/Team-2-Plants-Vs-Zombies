#include <cassert>
#include <iostream>

#include "zombie.hpp"

int main() {
    pvz::Zombie zombie(
        {0, 5},
        100,
        20,
        1.0f
    );

    // HP = 100 -> NORMAL
    assert(
        zombie.get_visual_state() ==
        pvz::Zombie::VisualState::NORMAL
    );

    // 49 damage -> HP = 51 -> NORMAL
    zombie.take_damage(49);

    assert(zombie.get_health() == 51);

    assert(
        zombie.get_visual_state() ==
        pvz::Zombie::VisualState::NORMAL
    );

    // 1 damage -> HP = 50 -> ONE_ARM_LOST
    zombie.take_damage(1);

    assert(zombie.get_health() == 50);

    assert(
        zombie.get_visual_state() ==
        pvz::Zombie::VisualState::ONE_ARM_LOST
    );

    // 49 damage -> HP = 1 -> ONE_ARM_LOST
    zombie.take_damage(49);

    assert(zombie.get_health() == 1);

    assert(
        zombie.get_visual_state() ==
        pvz::Zombie::VisualState::ONE_ARM_LOST
    );

    // 1 damage -> HP = 0 -> DEAD
    zombie.take_damage(1);

    assert(zombie.get_health() == 0);
    assert(!zombie.is_alive());

    assert(
        zombie.get_visual_state() ==
        pvz::Zombie::VisualState::DEAD
    );

    std::cout << "Zombie visual state test passed.\n";

    return 0;
}
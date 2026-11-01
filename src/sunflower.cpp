#include "sunflower.hpp"
#include "game_controller.hpp"

#include <random>

namespace pvz {

Sunflower::Sunflower(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

void Sunflower::update(double delta_seconds) {
    if (!is_alive()) return;
    timer += delta_seconds;
    if (timer >= INTERVAL) {
        timer -= INTERVAL;
        ready = true;
    }
}

void Sunflower::act(godot::GameController& controller) {
    if (!ready) return;
    ready = false;

    // Sun rơi từ trên cao xuống một điểm ngẫu nhiên trên bãi cỏ (SunEconomy),
    // người chơi click để nhặt. Giá trị (25) và nhịp (5 s) không đổi.
    static std::mt19937 rng{std::random_device{}()};
    std::uniform_int_distribution<int> row_dist(0, Grid::ROWS - 1);
    std::uniform_real_distribution<float> column_dist(
        0.0f,
        static_cast<float>(Grid::COLUMNS - 1)
    );

    controller.spawn_falling_sun(
        row_dist(rng),
        column_dist(rng),
        GOLD_SUN_VALUE,
        FALL_DURATION
    );
}

} // namespace pvz
#include "sunflower.hpp"
#include "game_controller.hpp"

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

    // Sun rơi ra bản đồ (SunEconomy), người chơi click để nhặt.
    // Cần GameController::spawn_sun() — Core tích hợp sau khi nhận sun_economy.*.
    controller.spawn_sun(get_position(), GOLD_SUN_VALUE);
}

} // namespace pvz
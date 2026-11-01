#include "peashooter.hpp"
#include "game_controller.hpp"

namespace pvz {

Peashooter::Peashooter(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

void Peashooter::update(double delta_seconds) {
    if (!is_alive()) return;
    timer += delta_seconds;
    if (timer >= INTERVAL) {
        timer -= INTERVAL;
        ready = true;
    }
}

void Peashooter::act(godot::GameController& controller) {
    if (!ready) return;
    ready = false;

    GridPosition pos = get_position();

    // Fix "bắn ngược": chỉ bắn khi có Zombie ở phía trước (column >= pos.column).
    // Trước đây has_zombie_in_row(row) xét cả Zombie đã vượt qua Peashooter (đã ở
    // phía sau), khiến cây bắn vô ích vì đạn bay về phía trước, không bao giờ
    // trúng Zombie đã ở phía sau.
    if (!controller.has_zombie_in_row(pos.row, static_cast<float>(pos.column))) {
        return;
    }

    // Đạn xuất phát ngay tại miệng Peashooter (+0.2f thay vì +1.0f) để có thể
    // bắn trúng cả Zombie đang áp sát cắn cây.
    controller.spawn_bullet(
        pos.row,
        static_cast<float>(pos.column) + 0.2f,
        BASE_DAMAGE
    );
}

} // namespace pvz
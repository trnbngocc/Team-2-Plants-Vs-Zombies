#include "peashooter.hpp"
#include "game_controller.hpp"

#include <random>

namespace pvz {

Peashooter::Peashooter(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

bool Peashooter::roll_critical() {
    // Một bộ sinh số ngẫu nhiên dùng chung cho mọi Peashooter, seed một lần.
    // Tốt hơn rand() vì không phụ thuộc srand() và phân bố đều hơn (% 100).
    static std::mt19937 rng{std::random_device{}()};
    std::uniform_int_distribution<int> dice(0, 99);
    return dice(rng) < CRIT_CHANCE_PERCENT;
}

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

    // Chỉ gieo xác suất khi thật sự bắn, để không "lãng phí" lượt roll.
    const int current_damage =
        roll_critical() ? BASE_DAMAGE * CRIT_MULTIPLIER : BASE_DAMAGE;

    // Đạn xuất phát ngay tại miệng Peashooter (+0.2f thay vì +1.0f) để có thể
    // bắn trúng cả Zombie đang áp sát cắn cây.
    controller.spawn_bullet(
        pos.row,
        static_cast<float>(pos.column) + 0.2f,
        current_damage
    );
}

} // namespace pvz
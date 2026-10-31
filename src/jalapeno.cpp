#include "jalapeno.hpp"
#include "game_controller.hpp"
#include "zombie.hpp"

namespace pvz {

Jalapeno::Jalapeno(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

void Jalapeno::update(double delta_seconds) {
    if (!is_alive() || fuse_finished) {
        return;
    }

    fuse_timer += delta_seconds;
    if (fuse_timer >= FUSE_TIME) {
        fuse_finished = true;
    }
}

void Jalapeno::act(godot::GameController& controller) {
    // Chưa hết ngòi hoặc đã nổ rồi -> không làm gì.
    if (!fuse_finished || exploded) {
        return;
    }
    exploded = true;

    const GridPosition center = get_position();

    // Chỉ báo cho UI (âm thanh + hiệu ứng lửa); damage bên dưới không đổi.
    controller.notify_jalapeno_exploded(center);

    // Quét toàn bộ Zombie cùng hàng.
    for (Zombie* z : controller.get_zombies_in_row(center.row)) {
        // Giai đoạn 2: Instant Damage. EXPLOSION_DAMAGE lớn hơn tổng máu + giáp
        // của mọi Zombie hiện có nên chúng chết ngay, không cần DoT.
        z->take_damage(EXPLOSION_DAMAGE);
    }

    // Tự huỷ; GameController::cleanup_dead_entities() sẽ gỡ khỏi Grid và entities.
    take_damage(get_health());
}

} // namespace pvz
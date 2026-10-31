#include "gargantuar.hpp"
#include "game_controller.hpp"
#include "imp.hpp"

#include <algorithm>
#include <memory>

namespace pvz {

Gargantuar::Gargantuar(GridPosition initial_position)
    : Zombie(initial_position, HEALTH, SMASH_DAMAGE, SPEED) {
    attack_interval = SMASH_INTERVAL;
}

int Gargantuar::get_action_state() const {
    return throwing ? ACTION_THROWING : ACTION_NORMAL;
}

void Gargantuar::update(double delta_seconds) {
    if (!is_alive()) {
        return;
    }

    // Ngưỡng được kiểm tra mỗi frame (không phải "lúc nhận đòn"), nên một đòn
    // lớn như Jalapeno / Squash đẩy HP xuống dưới ngưỡng mà boss vẫn sống
    // cũng không làm mất lần ném Imp. Cờ imp_thrown đảm bảo chỉ ném một lần.
    if (!imp_thrown && get_health() <= THROW_HP_THRESHOLD) {
        imp_thrown = true;
        imp_pending = true;
        throwing = true;
        throw_timer = 0.0;
    }

    if (throwing) {
        eating = false;
        throw_timer += delta_seconds;
        if (throw_timer >= THROW_DURATION) {
            throwing = false;
        }
        return;
    }

    default_update(delta_seconds);
}

void Gargantuar::act(godot::GameController& controller) {
    if (!imp_pending) {
        return;
    }
    imp_pending = false;

    const float from_column = get_column_position();
    // Imp rơi phía trước (bên trái) Gargantuar, trong phạm vi Grid.
    const float to_column = std::max(0.5f, from_column - IMP_THROW_DISTANCE);
    const int row = get_position().row;

    controller.add_zombie(std::make_unique<Imp>(
        GridPosition{row, static_cast<int>(to_column)},
        to_column
    ));
    controller.notify_imp_thrown(row, from_column, to_column);
}

} // namespace pvz

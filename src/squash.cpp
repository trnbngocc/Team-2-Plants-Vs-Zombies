#include "squash.hpp"
#include "game_controller.hpp"
#include "zombie.hpp"

#include <cmath>

namespace pvz {

Squash::Squash(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

void Squash::update(double delta_seconds) {
    if (!is_alive() || state != STATE_JUMPING) {
        return;
    }

    jump_timer += delta_seconds;
}

void Squash::act(godot::GameController& controller) {
    if (!is_alive() || smashed) {
        return;
    }

    const GridPosition pos = get_position();
    const float left_edge = static_cast<float>(pos.column);

    if (state == STATE_IDLE) {
        // Chọn Zombie gần nhất trong tầm: cùng hàng, từ mép trái ô (trừ một chút)
        // tới TRIGGER_AHEAD phía trước.
        const pvz::Zombie* nearest = nullptr;
        bool detected = false;

        for (pvz::Zombie* z : controller.get_zombies_in_row(pos.row)) {
            const float zc = z->get_column_position();
            if (zc >= left_edge - TRIGGER_BEHIND &&
                zc <= left_edge + DETECT_AHEAD) {
                detected = true;
            }
            if (zc < left_edge - TRIGGER_BEHIND ||
                zc > left_edge + TRIGGER_AHEAD) {
                continue;
            }
            if (nearest == nullptr || zc < nearest->get_column_position()) {
                nearest = z;
            }
        }

        // Zombie tới gần (cùng hàng): báo đúng một lần; rời đi trước khi nhảy thì huỷ.
        if (detected && !alerted) {
            alerted = true;
            controller.notify_squash_alert(pos.row, pos.column);
        } else if (!detected && alerted) {
            alerted = false;
            controller.notify_squash_alert_cancelled(pos.row, pos.column);
        }

        if (nearest != nullptr) {
            state = STATE_JUMPING;
            jump_timer = 0.0;
            target_column = nearest->get_column_position();
        }
        return;
    }

    // STATE_JUMPING: đợi hạ cánh.
    if (jump_timer < JUMP_DURATION) {
        return;
    }

    smashed = true;
    alerted = false;

    int hit_count = 0;
    for (pvz::Zombie* z : controller.get_zombies_in_row(pos.row)) {
        if (std::fabs(z->get_column_position() - target_column) <= SMASH_RADIUS) {
            z->take_damage(SMASH_DAMAGE);
            ++hit_count;
        }
    }

    // Đúng một lần mỗi cú đập, ngay tại thời điểm hạ cánh (không phải lúc trồng).
    controller.notify_squash_smashed(pos.row, target_column, hit_count);

    // Dùng một lần: tự huỷ; cleanup_dead_entities() gỡ khỏi Grid.
    take_damage(get_health());
}

} // namespace pvz

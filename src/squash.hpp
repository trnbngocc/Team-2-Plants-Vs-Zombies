#pragma once
#include "plant.hpp"

namespace pvz {

// Squash: cây dùng một lần. Khi có Zombie cùng hàng, đứng trước mặt trong tầm
// TRIGGER_RANGE, nó nhảy lên (JUMP_DURATION giây), đập xuống gây SMASH_DAMAGE
// lên mọi Zombie quanh điểm hạ cánh rồi tự huỷ.
// Sát thương đi qua take_damage() như mọi đòn khác (armor trước, rồi HP), nên
// Gargantuar chịu 1800 chứ không bị giết tức thì.
class Squash : public Plant {
public:
    enum State {
        STATE_IDLE = 0,
        STATE_JUMPING = 1
    };

    explicit Squash(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override;
    void act(godot::GameController& controller) override;

    int get_state() const { return state; }
    // Cột (float) Squash sẽ hạ cánh; chỉ có nghĩa khi đang nhảy. UI dùng để vẽ.
    float get_target_column() const { return target_column; }

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH             = 300;
    static constexpr int    COST               = 50;
    static constexpr int    SMASH_DAMAGE       = 1800;
    static constexpr float  TRIGGER_BEHIND     = 0.3f;  // Zombie vừa lướt qua mép trái ô vẫn bị bắt
    static constexpr float  TRIGGER_AHEAD      = 1.5f;  // tính từ mép trái ô của Squash
    // Âm thanh chuẩn bị: Zombie cách tầm nhảy khoảng một ô (chỉ để phát tiếng, không đổi tầm đánh / sát thương).
    static constexpr float  DETECT_AHEAD       = 2.5f;
    static constexpr double JUMP_DURATION      = 0.5;   // giây từ lúc nhảy tới lúc đập
    static constexpr float  SMASH_RADIUS       = 0.8f;  // cột, quanh điểm hạ cánh

    State  state = STATE_IDLE;
    double jump_timer = 0.0;
    float  target_column = 0.0f;
    bool   smashed = false;   // chỉ đập đúng một lần
    bool   alerted = false;   // đã báo "có Zombie tới gần" (một lần mỗi lần tới gần)
};

} // namespace pvz

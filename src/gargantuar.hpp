#pragma once
#include "zombie.hpp"

namespace pvz {

// Gargantuar: boss của wave cuối.
//   - 2000 HP, không armor, đi chậm, mỗi cú đập mạnh hơn Zombie thường.
//   - Khi HP <= THROW_HP_THRESHOLD (kể cả bị Jalapeno / Squash đẩy xuống dưới
//     ngưỡng trong một đòn mà vẫn sống) ném ĐÚNG MỘT Imp rồi đứng yên
//     THROW_DURATION giây (animation ném).
//   - Mọi sát thương đi qua Entity::take_damage như Zombie khác; Gargantuar
//     chỉ chết khi HP thật sự về 0.
class Gargantuar : public Zombie {
public:
    enum Action {
        ACTION_NORMAL = 0,
        ACTION_THROWING = 1
    };

    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH              = 2000;
    static constexpr int    THROW_HP_THRESHOLD  = 1000;
    static constexpr int    SMASH_DAMAGE        = 300;     // mỗi cú đập vào Plant
    static constexpr double SMASH_INTERVAL      = 1.5;     // giây giữa hai cú đập
    static constexpr float  SPEED               = 1.0f / 9.4f; // 1 cột / 9.4 s (chậm bằng nửa Zombie thường)
    static constexpr double THROW_DURATION      = 1.0;     // giây đứng yên khi ném
    static constexpr float  IMP_THROW_DISTANCE  = 3.0f;    // Imp rơi cách Gargantuar bao nhiêu cột về bên trái

    explicit Gargantuar(GridPosition initial_position);

    Kind get_kind() const override { return Kind::GARGANTUAR; }
    int get_action_state() const override;

    void update(double delta_seconds) override;
    void act(godot::GameController& controller) override;

    bool has_thrown_imp() const { return imp_thrown; }

private:
    bool   imp_thrown = false;   // đã quyết định ném (chỉ đặt true một lần)
    bool   imp_pending = false;  // act() sẽ tạo Imp
    bool   throwing = false;
    double throw_timer = 0.0;
};

} // namespace pvz

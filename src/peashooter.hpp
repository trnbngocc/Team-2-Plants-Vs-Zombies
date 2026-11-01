#pragma once
#include "plant.hpp"

namespace pvz {

// Peashooter: bắn đều mỗi INTERVAL giây khi có Zombie cùng hàng VÀ ở phía trước
// (column >= vị trí Peashooter). Mỗi viên đạn luôn gây đúng BASE_DAMAGE.
class Peashooter : public Plant {
public:
    explicit Peashooter(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override;
    void act(godot::GameController& controller) override;

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH              = 300;
    static constexpr int    COST                = 100;
    static constexpr double INTERVAL            = 1.4;  // giây giữa hai phát bắn
    static constexpr int    BASE_DAMAGE         = 20;

    double timer = 0.0;
    bool ready = false;
};

} // namespace pvz
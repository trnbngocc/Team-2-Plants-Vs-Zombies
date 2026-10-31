#pragma once
#include "plant.hpp"

namespace pvz {

// Sunflower: mỗi INTERVAL giây rớt một "Mặt trời vàng" (GOLD_SUN_VALUE Sun).
class Sunflower : public Plant {
public:
    explicit Sunflower(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override;
    void act(godot::GameController& controller) override;

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH                = 100;
    static constexpr int    COST                  = 50;
    static constexpr double INTERVAL              = 5.0;  // giây giữa hai lần rớt Sun (game time)
    static constexpr int    GOLD_SUN_VALUE        = 25;   // Mặt trời vàng
    static constexpr double FALL_DURATION         = 1.2;  // giây Sun rơi từ trên xuống bãi cỏ (chỉ hiển thị)

    double timer = 0.0;
    bool ready = false;
};

} // namespace pvz
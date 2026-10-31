#pragma once
#include "plant.hpp"

namespace pvz {

// Wall-nut: bức tường máu cao, có kỹ năng "Tử thủ" (Last Stand).
// Khi HP <= 25% HP tối đa, tự gắn SHIELDED (giảm 50% damage trong 5 giây).
// Chỉ kích hoạt đúng 1 lần trong vòng đời.
class WallNut : public Plant {
public:
    explicit WallNut(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override; // theo dõi HP, kích hoạt khiên
    // act() dùng bản mặc định của Plant (không làm gì) — không cần override

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH           = 600;
    static constexpr int    COST             = 50;
    static constexpr int    LAST_STAND_PERCENT = 25;   // ngưỡng kích hoạt: HP <= 25% max
    static constexpr float  SHIELD_REDUCTION = 0.5f;   // giảm 50% damage
    static constexpr double SHIELD_DURATION  = 5.0;    // giây

    bool last_stand_used = false; // đảm bảo chỉ kích hoạt 1 lần
};

} // namespace pvz
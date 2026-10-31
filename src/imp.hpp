#pragma once
#include "zombie.hpp"

namespace pvz {

// Imp: Zombie nhỏ, nhanh, máu thấp, do Gargantuar ném ra.
// Là một Zombie đầy đủ (HP, di chuyển, va chạm, cắn Plant) nên Bullet / Squash /
// Jalapeno / Lawn Mower đều xử lý như mọi Zombie, và nó được tính vào điều kiện thắng.
class Imp : public Zombie {
public:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int   HEALTH = 100;
    static constexpr int   DAMAGE = 10;
    static constexpr float SPEED  = 1.0f / 2.8f; // 1 cột / 2.8 s

    // landing_column: vị trí cột (float) nơi Imp rơi xuống.
    Imp(GridPosition initial_position, float landing_column);

    Kind get_kind() const override { return Kind::IMP; }
};

} // namespace pvz

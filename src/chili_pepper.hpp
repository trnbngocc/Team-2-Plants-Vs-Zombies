#pragma once
#include "plant.hpp"

namespace pvz {

// Chili Pepper: bom nổ chậm, thiêu đốt cả một hàng ngang.
//   Giai đoạn 1: đếm ngược FUSE_TIME giây (là một Plant bình thường, có thể bị Zombie cắn chết).
//   Giai đoạn 2: nổ, gây Instant Damage lên mọi Zombie cùng hàng.
//   Giai đoạn 3: Zombie còn sống bị gắn BURNING (DoT), rồi Chili Pepper tự huỷ.
class ChiliPepper : public Plant {
public:
    explicit ChiliPepper(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override; // đếm ngược ngòi nổ
    void act(godot::GameController& controller) override; // nổ khi ngòi hết giờ

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH            = 300;   // máu cơ bản, có thể bị Zombie cắn chết trước khi nổ
    static constexpr int    COST              = 125;
    static constexpr double FUSE_TIME         = 2.0;   // giây đếm ngược
    // Balance: 900 Instant Damage. Zombie mạnh nhất hiện có (Buckethead) có tổng
    // 300 armor + 200 HP = 500, nên không Zombie nào sống sót sau nổ -> BURNING
    // (chỉ gắn cho Zombie còn sống) không bao giờ kích hoạt; tổng damage <= 900.
    static constexpr int    EXPLOSION_DAMAGE  = 900;   // Instant Damage
    static constexpr double BURN_DURATION     = 3.0;   // giây
    static constexpr double BURN_TICK_INTERVAL = 0.5;  // giây / lần rút máu
    static constexpr int    BURN_TICK_DAMAGE  = 20;    // 6 tick x 20 = 120 damage

    double fuse_timer = 0.0;
    bool   fuse_finished = false; // ngòi đã cháy hết, chờ act() để nổ
    bool   exploded = false;      // đảm bảo chỉ nổ đúng 1 lần
};

} // namespace pvz
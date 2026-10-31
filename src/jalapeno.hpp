#pragma once
#include "plant.hpp"

namespace pvz {

// Jalapeno: bom nổ chậm, thiêu đốt cả một hàng ngang.
//   Giai đoạn 1: đếm ngược FUSE_TIME giây (là một Plant bình thường, có thể bị Zombie cắn chết).
//   Giai đoạn 2: nổ, gây Instant Damage lên mọi Zombie cùng hàng.
//   Giai đoạn 3: Jalapeno tự huỷ.
class Jalapeno : public Plant {
public:
    explicit Jalapeno(GridPosition pos);

    EntityType get_type() const override { return EntityType::PLANT; }
    void update(double delta_seconds) override; // đếm ngược ngòi nổ
    void act(godot::GameController& controller) override; // nổ khi ngòi hết giờ

private:
    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr int    HEALTH            = 300;   // máu cơ bản, có thể bị Zombie cắn chết trước khi nổ
    static constexpr int    COST              = 125;
    static constexpr double FUSE_TIME         = 2.0;   // giây đếm ngược
    // Balance: 900 Instant Damage. Zombie mạnh nhất hiện có (Buckethead) có tổng
    // 300 armor + 200 HP = 500, nên mọi Zombie cùng hàng chết ngay sau nổ.
    // Nếu sau này thêm Zombie có tổng máu + giáp > 900 thì cần tăng damage hoặc
    // thêm lại hiệu ứng BURNING (StatusEffectType::BURNING vẫn còn trong Entity).
    static constexpr int    EXPLOSION_DAMAGE  = 900;   // Instant Damage

    double fuse_timer = 0.0;
    bool   fuse_finished = false; // ngòi đã cháy hết, chờ act() để nổ
    bool   exploded = false;      // đảm bảo chỉ nổ đúng 1 lần
};

} // namespace pvz
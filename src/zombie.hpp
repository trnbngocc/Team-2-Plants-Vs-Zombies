#pragma once

#include "entity.hpp"
#include "grid.hpp"

namespace godot { class GameController; } // forward declare, tránh include vòng lặp

namespace pvz {

class Zombie : public Entity {
public:
    enum class ArmorType {
        NONE,
        CONE,
        BUCKET
    };

    // State dùng cho animation / sprite của Zombie.
    //
    // NORMAL:
    //     HP > 50%
    //
    // ONE_ARM_LOST:
    //     HP > 0 và HP <= 50%
    //
    // DEAD:
    //     HP == 0
    //
    // State này chỉ mô tả visual.
    // Không thay đổi damage, tốc độ hoặc logic attack.
    enum class VisualState {
        NORMAL,
        ONE_ARM_LOST,
        DEAD
    };

    // Loại Zombie dùng cho UI chọn hình / animation và cho luật riêng (boss, mower).
    enum class Kind {
        ORDINARY,   // Regular / Conehead / Buckethead (phân biệt bằng ArmorType)
        GARGANTUAR, // boss
        IMP         // do Gargantuar ném ra
    };

    Zombie(
        GridPosition initial_position,
        int initial_health,
        int initial_damage,
        float initial_speed,
        ArmorType initial_armor = ArmorType::NONE,
        int initial_armor_health = 0
    );

    EntityType get_type() const override;
    void update(double delta_seconds) override;

    virtual Kind get_kind() const { return Kind::ORDINARY; }

    // GameController gọi mỗi frame sau update(), giống Plant::act().
    // Mặc định không làm gì; Gargantuar override để ném Imp.
    virtual void act(godot::GameController& controller) {}

    // 0 = bình thường (đi / ăn). Giá trị khác do lớp con định nghĩa (UI chọn animation).
    virtual int get_action_state() const { return 0; }

    // Đẩy Zombie lùi về bên phải (tăng column) - Lawn Mower dùng cho boss.
    void knock_back(float columns);

    int get_damage() const;
    float get_speed() const;

    // Vị trí cột liên tục (float) của Zombie.
    // Cột c chiếm khoảng [c, c + 1); mép trái Grid là 0.0.
    // get_position().column chỉ là ô nguyên chứa vị trí này.
    float get_column_position() const;

    // True khi Zombie đã đi qua mép trái Grid (column_position < 0).
    bool has_reached_house() const;

    ArmorType get_armor_type() const;
    int get_armor_health() const;
    int get_max_armor_health() const;   // giáp lúc tạo (UI chọn hình nón / xô nứt theo tỉ lệ)
    bool has_armor() const;

    // HP thân tối đa (giá trị lúc tạo). UI dùng để vẽ thanh máu; không đổi gameplay.
    int get_max_health() const;

    // Trả về trạng thái visual hiện tại của Zombie.
    //
    // Boss Zombie có thể override hàm này để dùng
    // hệ thống visual state riêng mà không phải sửa
    // GameController / Plant / Grid.
    virtual VisualState get_visual_state() const;

    void receive_damage(int amount) override;

    // Id duy nhất, cấp lúc tạo Zombie. UI dùng để theo dõi từng Zombie
    // qua các frame (hurt / death animation). Không ảnh hưởng gameplay.
    int get_id() const;

    // True khi frame update gần nhất Zombie đang ăn Plant (đứng yên).
    // Chỉ để UI chọn animation; không thay đổi logic attack.
    bool is_eating() const;

    // GameController gọi ngay khi spawn Zombie,
    // để Zombie có thể tự truy cập Grid trong update().
    void set_grid(Grid* grid_ref);

protected:
    // Logic di chuyển / tấn công dùng chung cho Zombie.
    void default_update(double delta_seconds);

    // Đặt vị trí cột liên tục (và ô nguyên tương ứng). Dùng khi spawn tại vị trí lẻ.
    void set_column_position(float column);

    int damage;
    float speed;

    Grid* grid = nullptr;

    // Giây giữa hai lần cắn / đập. Lớp con (boss) có thể đổi.
    double attack_interval = 1.0;

    // True khi frame update gần nhất Zombie đang ăn Plant.
    bool eating = false;

private:
    double attack_cooldown = 0.0;

    ArmorType armor_type;
    int armor_health;
    int max_armor_health;

    float column_position = 0.0f;

    // HP tối đa của Zombie, được lấy từ initial_health.
    //
    // Không dùng get_health() để suy ra max HP vì health giảm
    // theo thời gian. Biến này giữ nguyên suốt vòng đời Zombie.
    int max_health;

    int id;
};

} // namespace pvz
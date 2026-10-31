#pragma once

#include "entity.hpp"

namespace godot { class GameController; } // forward declare, tránh include vòng lặp

namespace pvz {

class Plant : public Entity {
public:
    Plant(
        GridPosition initial_position,
        int initial_health,
        int initial_cost
    );

    int get_cost() const;

    // MỚI: GameController gọi hàm này mỗi frame, SAU update(). Mặc định không
    // làm gì (Wall-nut dùng nguyên bản này). Sunflower/Peashooter/ChiliPepper
    // override — tự đếm giờ nội bộ trong update() của chính mình (thêm biến
    // private trong class con, Plant base không cung cấp sẵn cooldown).
    virtual void act(godot::GameController& controller) {}

protected:
    int cost;
};

} // namespace pvz

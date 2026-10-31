#pragma once

#include "grid.hpp"

#include <vector>

namespace pvz {

// Một cục Sun đang nằm trên bản đồ, chờ người chơi click nhặt.
struct SunDrop {
    int id;             // định danh duy nhất, UI dùng để báo "tôi nhặt cục này"
    int value;          // 25 (vàng) hoặc 37 (tím) — UI dựa vào đây để chọn sprite
    int row;
    float column;       // float để sau này Sun có thể rơi/di chuyển mượt
    double time_left;   // giây còn lại trước khi biến mất
};

// Quản lý các cục Sun đang rơi trên bản đồ.
// C++ thuần (không dính Godot). GameController giữ một thành viên SunEconomy
// và gọi update() mỗi frame.
class SunEconomy {
public:
    // Thời gian một cục Sun tồn tại nếu không được nhặt. TODO: cân bằng.
    static constexpr double SUN_LIFETIME = 10.0;

    // Tạo một cục Sun tại vị trí pos. Trả về id (> 0),
    // hoặc -1 nếu value <= 0 hoặc pos nằm ngoài Grid.
    int spawn_sun(GridPosition pos, int value);

    // Nhặt Sun theo id. Trả về giá trị Sun (để GameController cộng vào kho),
    // hoặc 0 nếu id không tồn tại / đã hết hạn / đã được nhặt rồi.
    int collect_sun(int id);

    // Trừ thời gian, xoá các Sun đã hết hạn.
    void update(double delta_seconds);

    // Danh sách Sun hiện có, cho UI vẽ.
    const std::vector<SunDrop>& get_suns() const;

    // Xoá toàn bộ Sun và reset bộ đếm id (dùng khi bắt đầu ván mới / load game).
    void clear();

private:
    std::vector<SunDrop> suns;
    int next_id = 1;
};

} // namespace pvz

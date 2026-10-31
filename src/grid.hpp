#pragma once

#include <array>

namespace pvz {

struct GridPosition {
    int row;
    int column;
};

// Forward declaration.
// Grid chỉ lưu con trỏ tới Plant, không sở hữu Plant.
class Plant;

class Grid {
public:
    static constexpr int ROWS = 5;
    static constexpr int COLUMNS = 9;

    // Kiểm tra vị trí có nằm trong Grid hay không
    bool is_valid(GridPosition position) const;

    // Kiểm tra ô đã bị chiếm hay chưa
    bool is_occupied(GridPosition position) const;

    // Đánh dấu một ô là đã bị chiếm
    bool occupy(GridPosition position);

    // Giải phóng một ô
    void release(GridPosition position);

    // Xóa toàn bộ trạng thái Grid
    void clear();

    // Lấy Plant đang nằm tại một ô
    Plant* get_plant_at(GridPosition position) const;

    // Đặt một Plant vào một ô
    bool place_plant(GridPosition position, Plant* plant);

    // Xóa Plant khỏi một ô
    void remove_plant(GridPosition position);

private:
    // Trạng thái ô: true = đang bị chiếm, false = trống
    std::array<std::array<bool, COLUMNS>, ROWS> occupied_cells{};

    // Plant đang nằm ở từng ô.
    // nullptr = không có Plant.
    std::array<std::array<Plant*, COLUMNS>, ROWS> plant_at{};
};

} // namespace pvz
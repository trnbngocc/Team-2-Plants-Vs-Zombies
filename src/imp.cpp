#include "imp.hpp"

namespace pvz {

Imp::Imp(GridPosition initial_position, float landing_column)
    : Zombie(initial_position, HEALTH, DAMAGE, SPEED) {
    // Zombie đặt column_position theo ô nguyên; đưa về đúng cột rơi (float).
    set_column_position(landing_column);
}

} // namespace pvz

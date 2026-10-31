#include "bullet.hpp"

namespace pvz {

Bullet::Bullet(
    int row,
    float start_column,
    int damage,
    float speed_cells_per_second
)
    : Entity(
        GridPosition{row, static_cast<int>(start_column)},
        1
    ),
      column_position(start_column),
      damage(damage),
      speed(speed_cells_per_second) {
}

EntityType Bullet::get_type() const {
    return EntityType::BULLET;
}

void Bullet::update(double delta_seconds) {
    if (!active) {
        return;
    }

    column_position += speed * static_cast<float>(delta_seconds);
    position.column = static_cast<int>(column_position);

    if (column_position >= Grid::COLUMNS) {
        active = false;
    }
}

int Bullet::get_damage() const {
    return damage;
}

float Bullet::get_column() const {
    return column_position;
}

} // namespace pvz
#pragma once

#include "entity.hpp"

namespace pvz {

class Bullet : public Entity {
public:
    Bullet(
        int row,
        float start_column,
        int damage,
        float speed_cells_per_second = 5.0F
    );

    EntityType get_type() const override;
    void update(double delta_seconds) override;

    int get_damage() const;
    float get_column() const;

private:
    float column_position;
    int damage;
    float speed;
};

} // namespace pvz
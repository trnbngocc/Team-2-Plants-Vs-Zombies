#include "plant.hpp"

namespace pvz {

Plant::Plant(
    GridPosition initial_position,
    int initial_health,
    int initial_cost
)
    : Entity(initial_position, initial_health),
      cost(initial_cost) {
}

int Plant::get_cost() const {
    return cost;
}

} // namespace pvz
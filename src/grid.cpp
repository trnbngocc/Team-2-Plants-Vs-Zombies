#include "grid.hpp"

namespace pvz {

bool Grid::is_valid(GridPosition position) const {
    return position.row >= 0 && position.row < ROWS
        && position.column >= 0 && position.column < COLUMNS;
}

bool Grid::is_occupied(GridPosition position) const {
    return is_valid(position)
        && occupied_cells[position.row][position.column];
}

bool Grid::occupy(GridPosition position) {
    if (!is_valid(position) || is_occupied(position)) {
        return false;
    }

    occupied_cells[position.row][position.column] = true;
    return true;
}

void Grid::release(GridPosition position) {
    if (is_valid(position)) {
        occupied_cells[position.row][position.column] = false;
        plant_at[position.row][position.column] = nullptr;
    }
}

void Grid::clear() {
    for (auto& row : occupied_cells) {
        row.fill(false);
    }

    for (auto& row : plant_at) {
        row.fill(nullptr);
    }
}

Plant* Grid::get_plant_at(GridPosition position) const {
    if (!is_valid(position)) {
        return nullptr;
    }

    return plant_at[position.row][position.column];
}

bool Grid::place_plant(GridPosition position, Plant* plant) {
    if (!is_valid(position) || plant == nullptr || is_occupied(position)) {
        return false;
    }

    occupied_cells[position.row][position.column] = true;
    plant_at[position.row][position.column] = plant;

    return true;
}

void Grid::remove_plant(GridPosition position) {
    if (!is_valid(position)) {
        return;
    }

    plant_at[position.row][position.column] = nullptr;
    occupied_cells[position.row][position.column] = false;
}

} // namespace pvz
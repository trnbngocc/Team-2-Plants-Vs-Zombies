#include "sun_economy.hpp"

#include <algorithm>

namespace pvz {

int SunEconomy::spawn_sun(GridPosition pos, int value) {
    if (value <= 0) {
        return -1;
    }
    if (pos.row < 0 || pos.row >= Grid::ROWS ||
        pos.column < 0 || pos.column >= Grid::COLUMNS) {
        return -1;
    }

    SunDrop drop;
    drop.id = next_id++;
    drop.value = value;
    drop.row = pos.row;
    drop.column = static_cast<float>(pos.column);
    drop.time_left = SUN_LIFETIME;

    suns.push_back(drop);
    return drop.id;
}

int SunEconomy::collect_sun(int id) {
    for (auto it = suns.begin(); it != suns.end(); ++it) {
        if (it->id == id) {
            const int value = it->value;
            suns.erase(it);
            return value;
        }
    }
    return 0; // id không hợp lệ, đã hết hạn hoặc đã nhặt rồi
}

void SunEconomy::update(double delta_seconds) {
    if (delta_seconds <= 0.0) {
        return;
    }

    for (SunDrop& s : suns) {
        s.time_left -= delta_seconds;
    }

    suns.erase(
        std::remove_if(
            suns.begin(),
            suns.end(),
            [](const SunDrop& s) { return s.time_left <= 0.0; }
        ),
        suns.end()
    );
}

const std::vector<SunDrop>& SunEconomy::get_suns() const {
    return suns;
}

void SunEconomy::clear() {
    suns.clear();
    next_id = 1;
}

} // namespace pvz

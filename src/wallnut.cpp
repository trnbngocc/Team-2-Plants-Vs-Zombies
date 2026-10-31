#include "wallnut.hpp"

namespace pvz {

WallNut::WallNut(GridPosition pos)
    : Plant(pos, HEALTH, COST) {}

void WallNut::update(double /*delta_seconds*/) {
    if (last_stand_used || !is_alive()) {
        return;
    }

    // HP <= 25% max  <=>  hp * 100 <= max * 25 (tránh chia số nguyên).
    if (get_health() * 100 <= HEALTH * LAST_STAND_PERCENT) {
        last_stand_used = true;

        StatusEffect shield;
        shield.type = StatusEffectType::SHIELDED;
        shield.remaining_duration = SHIELD_DURATION;
        shield.damage_reduction = SHIELD_REDUCTION;
        apply_status(shield);
        // Thời gian khiên do Core tự trừ qua tick_status_effects(),
        // damage được giảm tự động qua modify_damage_by_status().
    }
}

} // namespace pvz
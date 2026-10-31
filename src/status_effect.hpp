#pragma once

namespace pvz {

enum class StatusEffectType {
    BURNING,
    SHIELDED,
    SLOWED,
    STUNNED,
    POISONED
};

struct StatusEffect {
    StatusEffectType type;

    // Thời gian còn lại của effect [s].
    double remaining_duration = 0.0;

    // Burning
    int damage_per_tick = 0;
    double tick_interval = 1.0;
    double tick_timer = 0.0;

    // Shielded
    // 0.5f = giảm 50% damage nhận vào.
    float damage_reduction = 0.0f;

    // Slowed
    // 0.5f = tốc độ còn 50% bình thường.
    float speed_multiplier = 1.0f;
};

} // namespace pvz
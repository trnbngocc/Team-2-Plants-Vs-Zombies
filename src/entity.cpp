#include "entity.hpp"

#include <algorithm>

namespace pvz {

Entity::Entity(GridPosition initial_position, int initial_health)
    : position(initial_position), health(initial_health) {
}

void Entity::take_damage(int amount) {
    if (amount <= 0 || !active) return;

    int modified_damage = modify_damage_by_status(amount);

    if (modified_damage <= 0) return;

    receive_damage(modified_damage);
}

void Entity::receive_damage(int amount) {
    health = std::max(0, health - amount);
    active = health > 0;
}

int Entity::modify_damage_by_status(int amount) const {
    int modified_damage = amount;

    for (const StatusEffect& effect : status_effects) {
        if (effect.type == StatusEffectType::SHIELDED) {
            modified_damage = static_cast<int>(
                modified_damage * (1.0f - effect.damage_reduction)
            );
        }
    }

    return std::max(0, modified_damage);
}

bool Entity::is_alive() const {
    return active;
}

int Entity::get_health() const {
    return health;
}

GridPosition Entity::get_position() const {
    return position;
}

void Entity::set_position(GridPosition new_position) {
    position = new_position;
}

void Entity::apply_status(StatusEffect effect) {
    if (effect.remaining_duration <= 0.0) return;

    if (effect.type == StatusEffectType::BURNING) {
        if (effect.damage_per_tick <= 0 || effect.tick_interval <= 0.0) {
            return;
        }
    }

    if (effect.type == StatusEffectType::SHIELDED) {
        if (effect.damage_reduction < 0.0f ||
            effect.damage_reduction > 1.0f) {
            return;
        }
    }

    if (effect.type == StatusEffectType::SLOWED) {
        if (effect.speed_multiplier < 0.0f ||
            effect.speed_multiplier > 1.0f) {
            return;
        }
    }

    for (StatusEffect& existing : status_effects) {
        if (existing.type == effect.type) {
            existing = effect;
            existing.tick_timer = 0.0;
            return;
        }
    }

    status_effects.push_back(effect);
}

bool Entity::has_status(StatusEffectType type) const {
    for (const StatusEffect& effect : status_effects) {
        if (effect.type == type && effect.remaining_duration > 0.0) {
            return true;
        }
    }

    return false;
}

void Entity::tick_status_effects(double delta_seconds) {
    if (delta_seconds <= 0.0 || !active) return;

    for (StatusEffect& effect : status_effects) {
        if (effect.remaining_duration <= 0.0) continue;

        double elapsed = std::min(delta_seconds, effect.remaining_duration);

        if (effect.type == StatusEffectType::BURNING) {
            effect.tick_timer += elapsed;

            while (effect.tick_timer >= effect.tick_interval) {
                effect.tick_timer -= effect.tick_interval;

                take_damage(effect.damage_per_tick);

                if (!active) break;
            }
        }

        effect.remaining_duration -= elapsed;

        if (!active) break;
    }

    status_effects.erase(
        std::remove_if(
            status_effects.begin(),
            status_effects.end(),
            [](const StatusEffect& effect) {
                return effect.remaining_duration <= 0.0;
            }
        ),
        status_effects.end()
    );
}

} // namespace pvz
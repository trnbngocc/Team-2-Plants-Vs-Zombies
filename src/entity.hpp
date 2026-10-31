#pragma once

#include "grid.hpp"
#include "status_effect.hpp"

#include <vector>

namespace pvz {

enum class EntityType {
    PLANT,
    ZOMBIE,
    BULLET
};

class Entity {
public:
    Entity(GridPosition initial_position, int initial_health);
    virtual ~Entity() = default;

    virtual EntityType get_type() const = 0;
    virtual void update(double delta_seconds) = 0;

    // Nhận damage thông qua một điểm xử lý chung.
    // Status Effect sẽ được áp dụng trước khi damage đi vào Entity cụ thể.
    void take_damage(int amount);

    bool is_alive() const;
    int get_health() const;

    GridPosition get_position() const;
    void set_position(GridPosition new_position);

    // Status Effect
    void apply_status(StatusEffect effect);
    bool has_status(StatusEffectType type) const;
    void tick_status_effects(double delta_seconds);

protected:
    // Hook cho Entity con xử lý damage đặc biệt.
    // Ví dụ: Zombie cần xử lý armor trước khi trừ HP.
    virtual void receive_damage(int amount);

    // Áp dụng các modifier từ Status Effect lên damage.
    int modify_damage_by_status(int amount) const;

    GridPosition position;
    int health;
    bool active = true;

private:
    std::vector<StatusEffect> status_effects;
};

} // namespace pvz
#include "zombie.hpp"
#include "plant.hpp"

#include <algorithm>
#include <cmath>

namespace pvz {

namespace {
    int next_zombie_id = 1;
}

Zombie::Zombie(
    GridPosition initial_position,
    int initial_health,
    int initial_damage,
    float initial_speed,
    ArmorType initial_armor,
    int initial_armor_health
)
    : Entity(initial_position, initial_health),
      damage(initial_damage),
      speed(initial_speed),
      armor_type(initial_armor),
      armor_health(std::max(0, initial_armor_health)),
      max_armor_health(std::max(0, initial_armor_health)),
      column_position(static_cast<float>(initial_position.column)),
      max_health(std::max(0, initial_health)),
      id(next_zombie_id++) {
}

EntityType Zombie::get_type() const {
    return EntityType::ZOMBIE;
}

void Zombie::update(double delta_seconds) {
    default_update(delta_seconds);
}

int Zombie::get_damage() const {
    return damage;
}

float Zombie::get_speed() const {
    return speed;
}

float Zombie::get_column_position() const {
    return column_position;
}

bool Zombie::has_reached_house() const {
    return column_position < 0.0f;
}

Zombie::ArmorType Zombie::get_armor_type() const {
    return armor_type;
}

int Zombie::get_max_armor_health() const {
    return max_armor_health;
}

int Zombie::get_armor_health() const {
    return armor_health;
}

int Zombie::get_max_health() const {
    return max_health;
}

bool Zombie::has_armor() const {
    return armor_type != ArmorType::NONE && armor_health > 0;
}

Zombie::VisualState Zombie::get_visual_state() const {
    // Zombie đã chết.
    if (!is_alive() || get_health() <= 0) {
        return VisualState::DEAD;
    }

    // Zombie còn sống nhưng HP <= 50% HP tối đa.
    //
    // Dùng phép nhân để tránh vấn đề chia số nguyên:
    //     health * 2 <= max_health
    //
    // Ví dụ:
    //     max = 100, hp = 50  -> ONE_ARM_LOST
    //     max = 100, hp = 51  -> NORMAL
    //     max = 101, hp = 50  -> ONE_ARM_LOST
    //     max = 101, hp = 51  -> ONE_ARM_LOST
    if (max_health > 0 &&
        get_health() * 2 <= max_health) {
        return VisualState::ONE_ARM_LOST;
    }

    return VisualState::NORMAL;
}

void Zombie::receive_damage(int amount) {
    if (amount <= 0 || !active) {
        return;
    }

    // Armor hấp thụ damage trước.
    if (has_armor()) {
        const int absorbed = std::min(armor_health, amount);
        armor_health -= absorbed;
        amount -= absorbed;

        if (armor_health == 0) {
            armor_type = ArmorType::NONE;
        }

        // Phần damage vượt quá armor còn lại đi tiếp vào HP.
        if (amount <= 0) {
            return;
        }
    }

    Entity::receive_damage(amount);
}

int Zombie::get_id() const {
    return id;
}

bool Zombie::is_eating() const {
    return eating;
}

void Zombie::set_grid(Grid* grid_ref) {
    grid = grid_ref;
}

void Zombie::set_column_position(float column) {
    column_position = column;

    set_position(
        GridPosition{
            get_position().row,
            static_cast<int>(std::floor(column_position))
        }
    );
}

void Zombie::knock_back(float columns) {
    if (!is_alive() || columns <= 0.0f) {
        return;
    }

    // Không đẩy ra ngoài mép phải của Grid (cột spawn).
    set_column_position(std::min(
        column_position + columns,
        static_cast<float>(Grid::COLUMNS) - 0.01f
    ));
}

void Zombie::default_update(double delta_seconds) {
    if (!is_alive() || grid == nullptr) {
        return;
    }

    GridPosition current = get_position();

    Plant* blocker = grid->get_plant_at(current);

    eating = blocker != nullptr && blocker->is_alive();

    // Có Plant trong cùng ô -> Zombie ăn Plant.
    //
    // ONE_ARM_LOST không ảnh hưởng damage hoặc attack interval.
    // Zombie vẫn sử dụng đúng một logic attack duy nhất.
    if (blocker != nullptr && blocker->is_alive()) {
        attack_cooldown += delta_seconds;

        if (attack_cooldown >= attack_interval) {
            attack_cooldown -= attack_interval;
            blocker->take_damage(damage);
        }
    }
    else {
        // Không có Plant -> Zombie tiếp tục đi sang trái.
        column_position -= speed * static_cast<float>(delta_seconds);

        // Dùng floor thay vì cắt về 0: vị trí trong (-1, 0)
        // phải thuộc ô -1 (ngoài Grid), không phải ô 0.
        set_position(
            GridPosition{
                current.row,
                static_cast<int>(std::floor(column_position))
            }
        );

        // Không tự báo thua ở đây: GameController kiểm tra
        // has_reached_house() sau mỗi frame.
    }
}

} // namespace pvz
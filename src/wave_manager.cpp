#include "wave_manager.hpp"
#include "game_controller.hpp"

#include <memory>
#include <random>

namespace godot {

WaveManager::WaveManager(GameController* game_controller_ref)
    : game_controller(game_controller_ref) {
}

namespace {
    std::random_device random_device;
    std::mt19937 random_engine(random_device());

    int random_int(int min_value, int max_value) {
        std::uniform_int_distribution<int> distribution(
            min_value,
            max_value
        );

        return distribution(random_engine);
    }

    // Summing frame deltas (e.g. 1/60) leaves totals a hair below 30.0 / 5.0;
    // without this tolerance every timer would fire one frame late.
    constexpr double TIME_EPSILON = 1e-6;
}
void WaveManager::spawn_zombie(
    pvz::Zombie::ArmorType armor_type,
    int row,
    float column
) {
    if (game_controller == nullptr) {
        return;
    }

    int health = ZOMBIE_HEALTH;
    int damage = ZOMBIE_DAMAGE;
    float speed = ZOMBIE_SPEED;
    int armor_health = 0;

    switch (armor_type) {
        case pvz::Zombie::ArmorType::NONE:
            break;

        case pvz::Zombie::ArmorType::CONE:
            armor_health = CONE_ARMOR;
            break;

        case pvz::Zombie::ArmorType::BUCKET:
            armor_health = BUCKET_ARMOR;
            break;
    }

    auto zombie = std::make_unique<pvz::Zombie>(
        pvz::GridPosition{
            row,
            static_cast<int>(column)
        },
        health,
        damage,
        speed,
        armor_type,
        armor_health
    );

    game_controller->add_zombie(std::move(zombie));
}


void WaveManager::spawn_regular(int row, float column) {
    spawn_zombie(
        pvz::Zombie::ArmorType::NONE,
        row,
        column
    );
}


void WaveManager::spawn_conehead(int row, float column) {
    spawn_zombie(
        pvz::Zombie::ArmorType::CONE,
        row,
        column
    );
}


void WaveManager::spawn_buckethead(int row, float column) {
    spawn_zombie(
        pvz::Zombie::ArmorType::BUCKET,
        row,
        column
    );
}


void WaveManager::start_wave(int wave_number) {
    if (wave_number <= 0 || wave_number > TOTAL_WAVES) {
        return;
    }

    preparation_left = 0.0;
    current_wave = wave_number;
    zombies_to_spawn = WAVES[wave_number - 1].zombie_count;

    // Zombie đầu tiên của wave xuất hiện ngay ở lần update kế tiếp.
    spawn_timer = 0.0;
    next_spawn_delay = 0.0;
    wave_break_timer = 0.0;
}

void WaveManager::begin_preparation(double seconds) {
    preparation_left = seconds > 0.0 ? seconds : 0.0;
    current_wave = 0;
    zombies_to_spawn = 0;
    spawn_timer = 0.0;
    next_spawn_delay = 0.0;
    wave_break_timer = 0.0;

    if (preparation_left <= 0.0) {
        start_wave(1);
    }
}

int WaveManager::get_current_wave() const {
    return current_wave;
}

double WaveManager::get_preparation_time_left() const {
    return preparation_left;
}

bool WaveManager::is_finished() const {
    return current_wave >= TOTAL_WAVES && zombies_to_spawn <= 0;
}

void WaveManager::update(double delta_seconds) {
    if (game_controller == nullptr || delta_seconds <= 0.0) {
        return;
    }

    // Giai đoạn chuẩn bị: không spawn Zombie nào.
    if (preparation_left > 0.0) {
        preparation_left -= delta_seconds;

        if (preparation_left > TIME_EPSILON) {
            return;
        }

        start_wave(1);
    }

    if (zombies_to_spawn <= 0) {
        // Chưa bắt đầu wave nào, hoặc đã xong wave cuối.
        if (current_wave <= 0 || is_finished()) {
            return;
        }

        // Wave hiện tại đã spawn xong -> nghỉ rồi sang wave kế.
        wave_break_timer += delta_seconds;

        if (wave_break_timer < WAVE_BREAK_SECONDS - TIME_EPSILON) {
            return;
        }

        start_wave(current_wave + 1);
    }

    // Check before accumulating: the first Zombie of a wave spawns in the
    // frame the wave starts, and later ones exactly spawn_interval apart.
    if (spawn_timer < next_spawn_delay - TIME_EPSILON) {
        spawn_timer += delta_seconds;
        return;
    }

    const WaveConfig& config = WAVES[current_wave - 1];

    // Random row from 0 to 4
    int row = random_int(0, 4);

    // Random zombie type, limited to the types allowed in this wave.
    int zombie_type = random_int(0, static_cast<int>(config.max_armor));

    if (zombie_type == 0) {
        spawn_regular(row, SPAWN_COLUMN);
    }
    else if (zombie_type == 1) {
        spawn_conehead(row, SPAWN_COLUMN);
    }
    else {
        spawn_buckethead(row, SPAWN_COLUMN);
    }

    zombies_to_spawn--;

    // Keep the leftover time so the cadence stays exact (not frame-rounded).
    spawn_timer -= next_spawn_delay;
    next_spawn_delay = config.spawn_interval;
    spawn_timer += delta_seconds;
}

} // namespace godot
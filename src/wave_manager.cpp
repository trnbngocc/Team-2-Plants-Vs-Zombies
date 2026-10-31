#include "wave_manager.hpp"
#include "game_controller.hpp"
#include "gargantuar.hpp"

#include <algorithm>
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


void WaveManager::spawn_gargantuar(int row, float column) {
    if (game_controller == nullptr) {
        return;
    }

    auto boss = std::make_unique<pvz::Gargantuar>(
        pvz::GridPosition{
            row,
            static_cast<int>(column)
        }
    );

    game_controller->add_zombie(std::move(boss));
}


void WaveManager::spawn_kind(SpawnKind kind, int row, float column) {
    switch (kind) {
        case SpawnKind::REGULAR:
            spawn_regular(row, column);
            break;
        case SpawnKind::CONEHEAD:
            spawn_conehead(row, column);
            break;
        case SpawnKind::BUCKETHEAD:
            spawn_buckethead(row, column);
            break;
        case SpawnKind::GARGANTUAR:
            spawn_gargantuar(row, column);
            break;
    }
}


std::vector<WaveManager::SpawnKind> WaveManager::build_queue(int wave_number) {
    std::vector<SpawnKind> queue;

    if (wave_number <= 0 || wave_number > TOTAL_WAVES) {
        return queue;
    }

    const WaveConfig& config = WAVES[wave_number - 1];

    if (wave_number < TOTAL_WAVES) {
        // Waves 1..3: loại ngẫu nhiên, giới hạn bởi max_armor của wave.
        for (int i = 0; i < config.enemy_count; ++i) {
            switch (random_int(0, static_cast<int>(config.max_armor))) {
                case 0:  queue.push_back(SpawnKind::REGULAR); break;
                case 1:  queue.push_back(SpawnKind::CONEHEAD); break;
                default: queue.push_back(SpawnKind::BUCKETHEAD); break;
            }
        }
        return queue;
    }

    // Wave cuối: đúng 4 Regular + 3 Conehead + 2 Buckethead + 1 Gargantuar.
    // Thứ tự Zombie thường được xáo trộn; Gargantuar luôn xuất hiện sau
    // FINAL_WAVE_ORDINARY_BEFORE_BOSS Zombie thường đầu tiên, phần còn lại theo sau.
    std::vector<SpawnKind> ordinary;
    ordinary.insert(ordinary.end(), FINAL_WAVE_REGULARS, SpawnKind::REGULAR);
    ordinary.insert(ordinary.end(), FINAL_WAVE_CONEHEADS, SpawnKind::CONEHEAD);
    ordinary.insert(ordinary.end(), FINAL_WAVE_BUCKETHEADS, SpawnKind::BUCKETHEAD);
    std::shuffle(ordinary.begin(), ordinary.end(), random_engine);

    for (std::size_t i = 0; i < ordinary.size(); ++i) {
        if (static_cast<int>(i) == FINAL_WAVE_ORDINARY_BEFORE_BOSS) {
            queue.insert(queue.end(), FINAL_WAVE_GARGANTUARS, SpawnKind::GARGANTUAR);
        }
        queue.push_back(ordinary[i]);
    }

    return queue;
}


void WaveManager::start_wave(int wave_number) {
    if (wave_number <= 0 || wave_number > TOTAL_WAVES) {
        return;
    }

    preparation_left = 0.0;
    current_wave = wave_number;
    spawn_queue = build_queue(wave_number);
    queue_index = 0;
    wave_started_event = wave_number;

    // Kẻ địch đầu tiên của wave xuất hiện ngay ở lần update kế tiếp.
    spawn_timer = 0.0;
    next_spawn_delay = 0.0;
    wave_break_timer = 0.0;
}

void WaveManager::begin_preparation(double seconds) {
    preparation_left = seconds > 0.0 ? seconds : 0.0;
    current_wave = 0;
    spawn_queue.clear();
    queue_index = 0;
    enemies_spawned = 0;
    wave_started_event = 0;
    warning_event = false;
    warning_fired = false;
    final_banner_event = false;
    final_banner_fired = false;
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

int WaveManager::consume_wave_started() {
    const int wave = wave_started_event;
    wave_started_event = 0;
    return wave;
}

bool WaveManager::consume_final_wave_banner() {
    const bool fired = final_banner_event;
    final_banner_event = false;
    return fired;
}

bool WaveManager::consume_huge_wave_warning() {
    const bool fired = warning_event;
    warning_event = false;
    return fired;
}

int WaveManager::get_enemies_spawned() const {
    return enemies_spawned;
}

int WaveManager::get_enemies_queued() const {
    return static_cast<int>(spawn_queue.size() - queue_index);
}

bool WaveManager::is_finished() const {
    return current_wave >= TOTAL_WAVES && queue_index >= spawn_queue.size();
}

void WaveManager::update(double delta_seconds) {
    if (game_controller == nullptr || delta_seconds <= 0.0) {
        return;
    }

    // Giai đoạn chuẩn bị: không spawn gì.
    if (preparation_left > 0.0) {
        preparation_left -= delta_seconds;

        if (preparation_left > TIME_EPSILON) {
            return;
        }

        start_wave(1);
    }

    if (queue_index >= spawn_queue.size()) {
        // Chưa bắt đầu wave nào, hoặc đã xong wave cuối.
        if (current_wave <= 0 || is_finished()) {
            return;
        }

        // Wave hiện tại đã spawn xong -> nghỉ rồi sang wave kế.
        const bool next_is_final = current_wave + 1 == TOTAL_WAVES;

        // Cảnh báo wave cuối: đúng một lần, ngay khi khoảng nghỉ trước wave cuối bắt đầu.
        if (next_is_final && !warning_fired) {
            warning_fired = true;
            warning_event = true;
        }

        wave_break_timer += delta_seconds;

        // Banner thứ hai ("Final Wave") bắt đầu ngay khi banner thứ nhất hết slot của nó.
        if (next_is_final && !final_banner_fired &&
            wave_break_timer >= HUGE_WAVE_BANNER_SECONDS - TIME_EPSILON) {
            final_banner_fired = true;
            final_banner_event = true;
        }

        const double break_seconds =
            next_is_final ? FINAL_WAVE_BREAK_SECONDS : WAVE_BREAK_SECONDS;

        if (wave_break_timer < break_seconds - TIME_EPSILON) {
            return;
        }

        start_wave(current_wave + 1);
    }

    // Check before accumulating: the first enemy of a wave spawns in the
    // frame the wave starts, and later ones exactly spawn_interval apart.
    if (spawn_timer < next_spawn_delay - TIME_EPSILON) {
        spawn_timer += delta_seconds;
        return;
    }

    const WaveConfig& config = WAVES[current_wave - 1];

    // Random row from 0 to 4
    const int row = random_int(0, 4);

    spawn_kind(spawn_queue[queue_index], row, SPAWN_COLUMN);
    ++queue_index;
    ++enemies_spawned;

    // Keep the leftover time so the cadence stays exact (not frame-rounded).
    spawn_timer -= next_spawn_delay;
    next_spawn_delay = config.spawn_interval;
    spawn_timer += delta_seconds;
}

} // namespace godot

#pragma once

#include "zombie.hpp"

namespace godot {

class GameController;

class WaveManager {
public:
    static constexpr int TOTAL_WAVES = 3;

    // Thời gian chuẩn bị trước khi wave 1 bắt đầu (game time, dừng khi Pause).
    static constexpr double PREPARATION_SECONDS = 30.0;

    // Nghỉ giữa hai wave, tính từ lúc wave trước spawn xong.
    static constexpr double WAVE_BREAK_SECONDS = 3.0;

    // Cấu hình từng wave: số Zombie, khoảng cách giữa hai lần spawn, và loại
    // Zombie mạnh nhất được phép (mỗi Zombie chọn ngẫu nhiên NONE..max_armor).
    // Zombie đầu tiên của mỗi wave xuất hiện ngay khi wave bắt đầu.
    struct WaveConfig {
        int zombie_count;
        double spawn_interval;
        pvz::Zombie::ArmorType max_armor;
    };

    static constexpr WaveConfig WAVES[TOTAL_WAVES] = {
        {3, 10.0, pvz::Zombie::ArmorType::NONE},   // chỉ Zombie thường
        {5, 5.0, pvz::Zombie::ArmorType::CONE},    // thường / Conehead
        {7, 5.0, pvz::Zombie::ArmorType::BUCKET},  // thường / Conehead / Buckethead
    };

    // Chỉ số Zombie. Tốc độ như nhau cho mọi loại: 1 cột mỗi 4.7 giây.
    static constexpr int ZOMBIE_HEALTH = 200;
    static constexpr int ZOMBIE_DAMAGE = 10;
    static constexpr float ZOMBIE_SPEED = 1.0f / 4.7f;
    static constexpr int CONE_ARMOR = 200;
    static constexpr int BUCKET_ARMOR = 300;

    // Cột spawn: ô ngay ngoài mép phải Grid (cột 0..8), để Zombie
    // xuất hiện ngoài bãi cỏ rồi mới đi vào.
    static constexpr float SPAWN_COLUMN = 9.0f;

    explicit WaveManager(GameController* game_controller);

    void spawn_regular(int row, float column);
    void spawn_conehead(int row, float column);
    void spawn_buckethead(int row, float column);

    // Bắt đầu đếm ngược chuẩn bị; wave 1 bắt đầu khi hết thời gian.
    void begin_preparation(double seconds = PREPARATION_SECONDS);

    void start_wave(int wave_number);

    // Update wave timing
    void update(double delta_seconds);

    int get_current_wave() const;

    // Số giây chuẩn bị còn lại (0 khi không còn trong giai đoạn chuẩn bị).
    double get_preparation_time_left() const;

    // True chỉ khi wave cuối (TOTAL_WAVES) đã spawn hết Zombie.
    // Không xét Zombie còn sống trên sân.
    bool is_finished() const;

private:
    void spawn_zombie(
        pvz::Zombie::ArmorType armor_type,
        int row,
        float column
    );

    GameController* game_controller = nullptr;

    // Wave state
    double preparation_left = 0.0;
    int current_wave = 0;
    int zombies_to_spawn = 0;

    // Timer for next zombie
    double spawn_timer = 0.0;
    double next_spawn_delay = 0.0;

    // Timer for break between waves
    double wave_break_timer = 0.0;
};

} // namespace godot
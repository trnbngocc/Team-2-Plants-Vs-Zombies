#pragma once

#include <vector>

#include "zombie.hpp"

namespace godot {

class GameController;

class WaveManager {
public:
    static constexpr int TOTAL_WAVES = 4;

    // Thời gian chuẩn bị trước khi wave 1 bắt đầu (game time, dừng khi Pause).
    static constexpr double PREPARATION_SECONDS = 30.0;

    // Nghỉ giữa hai wave, tính từ lúc wave trước spawn xong.
    static constexpr double WAVE_BREAK_SECONDS = 3.0;

    // Chuỗi trước wave cuối (tính từ lúc wave 3 spawn xong, đồng hồ game nên Pause dừng lại):
    //   0 s                         : "A huge wave is approaching" bắt đầu hiện (HUGE_WAVE_BANNER_SECONDS)
    //   HUGE_WAVE_BANNER_SECONDS    : banner đó hết, "Final Wave" bắt đầu hiện (FINAL_WAVE_BANNER_SECONDS)
    //   FINAL_WAVE_BREAK_SECONDS    : banner thứ hai hết -> wave 4 bắt đầu và zombie đầu tiên xuất hiện.
    // Hai banner nối tiếp nhau, không chồng lên nhau, và không zombie wave 4 nào spawn trước khi
    // cả hai kết thúc. UI phải hiển thị mỗi banner trong thời lượng không quá slot của nó.
    static constexpr double HUGE_WAVE_BANNER_SECONDS = 4.0;
    static constexpr double FINAL_WAVE_BANNER_SECONDS = 3.0;
    static constexpr double FINAL_WAVE_BREAK_SECONDS =
        HUGE_WAVE_BANNER_SECONDS + FINAL_WAVE_BANNER_SECONDS;

    // Cấu hình từng wave: số kẻ địch, khoảng cách giữa hai lần spawn, và loại
    // Zombie thường mạnh nhất được phép (mỗi Zombie chọn ngẫu nhiên NONE..max_armor).
    // Kẻ địch đầu tiên của mỗi wave xuất hiện ngay khi wave bắt đầu.
    // Wave cuối (4) có thành phần cố định, xem build_final_wave_queue().
    struct WaveConfig {
        int enemy_count;
        double spawn_interval;
        pvz::Zombie::ArmorType max_armor;
    };

    static constexpr WaveConfig WAVES[TOTAL_WAVES] = {
        {3, 10.0, pvz::Zombie::ArmorType::NONE},    // chỉ Zombie thường
        {5, 5.0, pvz::Zombie::ArmorType::CONE},     // thường / Conehead
        {7, 5.0, pvz::Zombie::ArmorType::BUCKET},   // thường / Conehead / Buckethead
        {10, 5.0, pvz::Zombie::ArmorType::BUCKET},  // 4 thường + 3 Cone + 2 Bucket + 1 Gargantuar
    };

    static constexpr int TOTAL_ENEMIES =
        WAVES[0].enemy_count + WAVES[1].enemy_count +
        WAVES[2].enemy_count + WAVES[3].enemy_count;
    static_assert(TOTAL_ENEMIES == 25, "The four waves must contain exactly 25 enemies");

    // Thành phần cố định của wave cuối.
    static constexpr int FINAL_WAVE_REGULARS = 4;
    static constexpr int FINAL_WAVE_CONEHEADS = 3;
    static constexpr int FINAL_WAVE_BUCKETHEADS = 2;
    static constexpr int FINAL_WAVE_GARGANTUARS = 1;
    // Gargantuar xuất hiện sau chừng này Zombie thường đầu tiên của wave cuối.
    static constexpr int FINAL_WAVE_ORDINARY_BEFORE_BOSS = 3;
    static_assert(
        FINAL_WAVE_REGULARS + FINAL_WAVE_CONEHEADS + FINAL_WAVE_BUCKETHEADS +
        FINAL_WAVE_GARGANTUARS == WAVES[3].enemy_count,
        "Final wave composition must match its enemy count"
    );

    // Chỉ số Zombie thường. Tốc độ như nhau: 1 cột mỗi 4.7 giây.
    static constexpr int ZOMBIE_HEALTH = 200;
    static constexpr int ZOMBIE_DAMAGE = 10;
    static constexpr float ZOMBIE_SPEED = 1.0f / 4.7f;
    static constexpr int CONE_ARMOR = 370;      // Conehead: 370 + 200 = 570 HP
    static constexpr int BUCKET_ARMOR = 1100;   // Buckethead: 1100 + 200 = 1300 HP

    // Cột spawn: ô ngay ngoài mép phải Grid (cột 0..8), để Zombie
    // xuất hiện ngoài bãi cỏ rồi mới đi vào.
    static constexpr float SPAWN_COLUMN = 9.0f;

    // Loại kẻ địch trong hàng đợi spawn của một wave.
    enum class SpawnKind {
        REGULAR,
        CONEHEAD,
        BUCKETHEAD,
        GARGANTUAR
    };

    explicit WaveManager(GameController* game_controller);

    void spawn_regular(int row, float column);
    void spawn_conehead(int row, float column);
    void spawn_buckethead(int row, float column);
    void spawn_gargantuar(int row, float column);

    // Bắt đầu đếm ngược chuẩn bị; wave 1 bắt đầu khi hết thời gian.
    void begin_preparation(double seconds = PREPARATION_SECONDS);

    void start_wave(int wave_number);

    // Update wave timing
    void update(double delta_seconds);

    int get_current_wave() const;

    // Số giây chuẩn bị còn lại (0 khi không còn trong giai đoạn chuẩn bị).
    double get_preparation_time_left() const;

    // True chỉ khi wave cuối (TOTAL_WAVES) đã spawn hết kẻ địch.
    // Không xét kẻ địch còn sống trên sân (GameController kiểm tra riêng).
    bool is_finished() const;

    // Số kẻ địch đã spawn qua hệ thống wave (không tính Imp, không tính spawn trực tiếp).
    int get_enemies_spawned() const;

    // Số kẻ địch còn nằm trong hàng đợi của wave hiện tại.
    int get_enemies_queued() const;

    // Sự kiện trình bày, mỗi sự kiện chỉ trả về MỘT lần (đọc xong là xoá):
    //  - consume_wave_started(): số wave vừa bắt đầu, hoặc 0 nếu không có.
    //  - consume_huge_wave_warning(): true đúng một lần mỗi ván, ngay trước wave cuối.
    int consume_wave_started();
    bool consume_huge_wave_warning();
    // true đúng một lần mỗi ván: lúc banner "Final Wave" phải bắt đầu hiện.
    bool consume_final_wave_banner();

    // Dựng hàng đợi spawn của một wave (public để test kiểm tra thành phần).
    static std::vector<SpawnKind> build_queue(int wave_number);

private:
    void spawn_zombie(
        pvz::Zombie::ArmorType armor_type,
        int row,
        float column
    );

    void spawn_kind(SpawnKind kind, int row, float column);

    GameController* game_controller = nullptr;

    // Wave state
    double preparation_left = 0.0;
    int current_wave = 0;

    // Hàng đợi spawn của wave hiện tại; queue_index là phần tử kế tiếp.
    std::vector<SpawnKind> spawn_queue;
    std::size_t queue_index = 0;
    int enemies_spawned = 0;

    // Timer for next enemy
    double spawn_timer = 0.0;
    double next_spawn_delay = 0.0;

    // Timer for break between waves
    double wave_break_timer = 0.0;

    // Sự kiện chờ UI đọc.
    int wave_started_event = 0;
    bool warning_event = false;
    bool warning_fired = false;
    bool final_banner_event = false;
    bool final_banner_fired = false;
};

} // namespace godot

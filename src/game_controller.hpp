#pragma once

#include <array>
#include <memory>
#include <vector>

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>


#include "entity.hpp"
#include "grid.hpp"
#include "sun_economy.hpp"
#include "plant.hpp"
#include "zombie.hpp"
#include "lawn_mower.hpp"
#include "wave_manager.hpp"

namespace godot {

class GameController : public Node {
    GDCLASS(GameController, Node)

public:
    enum class GameState {
        SETUP,
        PLAYING,
        PAUSED,
        VICTORY,
        DEFEAT
    };
    enum PlantType {
        PEASHOOTER = 0,
        SUNFLOWER = 1,
        WALLNUT = 2,
        JALAPENO = 3,
        SQUASH = 4
    };

    // Lý do place_plant từ chối (gửi kèm signal "placement_rejected" cho UI).
    enum PlacementResult {
        PLACE_NOT_PLAYING = 1,
        PLACE_INVALID_CELL = 2,
        PLACE_OCCUPIED = 3,
        PLACE_NOT_ENOUGH_SUN = 4,
        PLACE_UNKNOWN_PLANT = 5
    };

    // Nếu UI không bao giờ gọi begin_waves() (ví dụ animation Start Text lỗi),
    // wave vẫn tự bắt đầu sau chừng này giây game time để ván không bị treo.
    static constexpr double INTRO_TIMEOUT_SECONDS = 10.0;


private:
    GameState state = GameState::SETUP;

    // GameController owns and manages all gameplay entities.
    std::vector<std::unique_ptr<pvz::Entity>> entities;

    // Entities spawned while `entities` is being iterated (e.g. bullets
    // from Peashooter::act()). Moved into `entities` by
    // flush_pending_entities() so the active loop is never invalidated.
    std::vector<std::unique_ptr<pvz::Entity>> pending_entities;
    bool is_iterating_entities = false;

    // GameController owns the game board.
    pvz::Grid grid;

    // GameController owns Sun drops on the battlefield.
    pvz::SunEconomy sun_economy;

    // GameController owns and manages zombie waves.
    WaveManager wave_manager;

    // Một Lawn Mower cho mỗi hàng; mỗi cái chỉ dùng được một lần.
    std::array<pvz::LawnMower, pvz::Grid::ROWS> mowers;

    int sun = 50;

    // Tổng Sun người chơi đã THỰC SỰ tiêu (giá cây trồng thành công). Là điểm
    // khi thắng; không tính Sun còn lại, không hoàn lại khi xúc cây.
    int sun_spent = 0;

    // Wave chỉ bắt đầu đếm sau begin_waves() (UI gọi khi Start Text xong).
    bool waves_started = false;
    double intro_timer = 0.0;

    // Số kẻ địch của hệ thống wave (không tính Imp) đã bị hạ.
    int enemies_defeated = 0;

protected:
    static void _bind_methods();


public:
    GameController();

    void _ready() override;

    // Godot game loop.
    void _process(double delta) override;

    void start_game();
    void pause_game();
    void resume_game();
    void finish_game(bool won);

    // UI gọi khi animation Start Text kết thúc: bắt đầu đếm ngược chuẩn bị / wave.
    // Gọi nhiều lần không có tác dụng thêm.
    void begin_waves();
    bool get_waves_started() const { return waves_started; }

    void add_entity(std::unique_ptr<pvz::Entity> entity);

    void spawn_bullet(
        int row,
        float start_column,
        int damage,
        float speed_cells_per_second = 5.0F
    );

    void update_entities(double delta_seconds);

    // ---- Test hooks (used by the headless integration tests; not used by the UI) ----
    // Fast-forward the simulation by `seconds` of game time in 1/60 s steps. Only
    // advances while PLAYING, exactly like _process().
    void advance_time(double seconds);
    // Spawn one enemy right now: kind 0 Regular, 1 Conehead, 2 Buckethead, 3 Gargantuar.
    void debug_spawn_enemy(int kind, int row, float column);

    int get_state() const;

    // Wave indicator data for the UI (read-only).
    int get_wave() const { return wave_manager.get_current_wave(); }
    int get_total_waves() const { return WaveManager::TOTAL_WAVES; }
    double get_preparation_time_left() const {
        return waves_started
            ? wave_manager.get_preparation_time_left()
            : WaveManager::PREPARATION_SECONDS;
    }

    // Giá Sun của một loại cây (PlantType), -1 nếu không hợp lệ. UI dùng để vẽ Seed Bank.
    int get_plant_cost(int plant_type) const;

    // Theo dõi kẻ địch (không tính Imp): đã spawn / đã hạ / tổng.
    int get_enemies_spawned() const { return wave_manager.get_enemies_spawned(); }
    int get_enemies_defeated() const { return enemies_defeated; }
    int get_total_enemies() const { return WaveManager::TOTAL_ENEMIES; }

    // ==================== PLANT ====================

    // Hàm đặt cây dùng để bind ra Godot (UI gọi trực tiếp từ GDScript)
    bool place_plant_by_type(int row, int col, int plant_type);

    // C++ core place_plant
    bool place_plant(
        pvz::GridPosition pos,
        std::unique_ptr<pvz::Plant> plant
    );

    // Xẻng: gỡ đúng cây ở ô (row, col). Ô trống / ngoài lưới / không đang chơi -> false.
    // Không hoàn Sun.
    bool shovel_plant(int row, int col);

    // ==================== UI / QUERY DATA ====================

    // Trả về danh sách Sun đang rơi để UI vẽ
    Array get_sun_drops() const;

    // Trả về danh sách Zombie, Đạn, Cây, Mower để UI vẽ lên màn hình mỗi frame
    Array get_zombies_data() const;
    Array get_bullets_data() const;
    Array get_plants_data() const;
    Array get_mowers_data() const;

    int get_sun_spent() const { return sun_spent; }


    // ==================== ZOMBIE ====================

    // Zombie Developer / Wave Manager gọi khi spawn Zombie —
    // tự gán Grid cho Zombie.
    void add_zombie(std::unique_ptr<pvz::Zombie> zombie);

    // Peashooter gọi trong act() - kiểm tra có Zombie ở cùng hàng VÀ ở phía trước cây
    bool has_zombie_in_row(int row, float min_column = 0.0f) const;


    // Jalapeno, Squash và các Plant khác cần danh sách Zombie thật
    // gọi hàm này trong act().
    std::vector<pvz::Zombie*> get_zombies_in_row(int row) const;

    // ==================== PRESENTATION EVENTS ====================

    // Jalapeno gọi đúng lúc nổ, để UI phát âm thanh / hiệu ứng lửa.
    // Chỉ phát signal "jalapeno_exploded"; không ảnh hưởng gameplay.
    void notify_jalapeno_exploded(pvz::GridPosition pos);

    // Squash gọi đúng lúc hạ cánh (không phải lúc trồng). hit_count = số Zombie bị đập.
    void notify_squash_smashed(int row, float column, int hit_count);

    // Squash gọi khi có Zombie cùng hàng tới gần (chuẩn bị) / rời đi trước khi nó nhảy.
    void notify_squash_alert(int row, int column);
    void notify_squash_alert_cancelled(int row, int column);

    // Gargantuar gọi khi ném Imp (đúng một lần mỗi Gargantuar).
    void notify_imp_thrown(int row, float from_column, float to_column);

private:
    // Báo kết quả trồng cây cho UI (âm thanh / thông báo). Không đổi luật trồng cây.
    // cost: giá của cây bị từ chối (0 nếu không có cây), để UI báo "NEED x SUN".
    void notify_placement_rejected(
        pvz::GridPosition pos,
        PlacementResult reason,
        int cost = 0
    );

public:

    // Sunflower gọi trong act().
    void add_sun(int amount);
    int get_sun() const;

    // SunEconomy interface.
    int spawn_sun(pvz::GridPosition pos, int value);
    // Sun rơi từ trên xuống (row, column liên tục) - Sunflower dùng.
    int spawn_falling_sun(int row, float column, int value, double fall_duration);
    int collect_sun(int id);
    const std::vector<pvz::SunDrop>& get_suns() const;

private:
    void resolve_bullet_collisions();
    void update_mowers(double delta_seconds);
    void cleanup_dead_entities();
    void flush_pending_entities();

    // True khi có Zombie còn sống đã đi qua mép trái Grid mà Lawn Mower của hàng
    // đó đã dùng hết (không còn gì cản) -> thua.
    bool has_zombie_breached_defense() const;

    // True when at least one live Zombie (any kind, incl. Gargantuar and Imp)
    // is on the board.
    bool has_living_zombie() const;

    // Tạo Plant theo PlantType, nullptr nếu không hợp lệ.
    static std::unique_ptr<pvz::Plant> create_plant(int plant_type, pvz::GridPosition pos);

    // PlantType code of a placed Plant, or -1 if unknown.
    static int plant_type_of(const pvz::Plant* plant);
};

} // namespace godot

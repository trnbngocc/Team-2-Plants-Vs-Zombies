#pragma once

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
        CHILI_PEPPER = 3
    };

    // Lý do place_plant từ chối (gửi kèm signal "placement_rejected" cho UI).
    enum PlacementResult {
        PLACE_NOT_PLAYING = 1,
        PLACE_INVALID_CELL = 2,
        PLACE_OCCUPIED = 3,
        PLACE_NOT_ENOUGH_SUN = 4,
        PLACE_UNKNOWN_PLANT = 5
    };


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

    int sun = 50;

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

    void add_entity(std::unique_ptr<pvz::Entity> entity);

    void spawn_bullet(
        int row,
        float start_column,
        int damage,
        float speed_cells_per_second = 5.0F
    );

    void update_entities(double delta_seconds);

    int get_state() const;

    // Wave indicator data for the UI (read-only).
    int get_wave() const { return wave_manager.get_current_wave(); }
    int get_total_waves() const { return WaveManager::TOTAL_WAVES; }
    double get_preparation_time_left() const { return wave_manager.get_preparation_time_left(); }

    // ==================== PLANT ====================

    // Hàm đặt cây dùng để bind ra Godot (UI gọi trực tiếp từ GDScript)
    bool place_plant_by_type(int row, int col, int plant_type);

    // C++ core place_plant
    bool place_plant(
        pvz::GridPosition pos,
        std::unique_ptr<pvz::Plant> plant
    );

    // ==================== UI / QUERY DATA ====================

    // Trả về danh sách Sun đang rơi để UI vẽ
    Array get_sun_drops() const;

    // Trả về danh sách Zombie, Đạn, Cây để UI vẽ lên màn hình mỗi frame
    Array get_zombies_data() const;
    Array get_bullets_data() const;
    Array get_plants_data() const;


    // ==================== ZOMBIE ====================

    // Zombie Developer / Wave Manager gọi khi spawn Zombie —
    // tự gán Grid cho Zombie.
    void add_zombie(std::unique_ptr<pvz::Zombie> zombie);

    // Peashooter gọi trong act() - kiểm tra có Zombie ở cùng hàng VÀ ở phía trước cây
    bool has_zombie_in_row(int row, float min_column = 0.0f) const;


    // ChiliPepper và các Plant khác cần danh sách Zombie thật
    // gọi hàm này trong act().
    std::vector<pvz::Zombie*> get_zombies_in_row(int row) const;

    // ==================== SUN ====================

    // ==================== PRESENTATION EVENTS ====================

    // ChiliPepper gọi đúng lúc nổ, để UI phát âm thanh / hiệu ứng lửa.
    // Chỉ phát signal "chili_exploded"; không ảnh hưởng gameplay.
    void notify_chili_exploded(pvz::GridPosition pos);

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
    int collect_sun(int id);
    const std::vector<pvz::SunDrop>& get_suns() const;

private:
    void resolve_bullet_collisions();
    void cleanup_dead_entities();
    void flush_pending_entities();

    // True when any live Zombie has walked past the left edge of the Grid
    // (Zombie::has_reached_house()).
    bool has_zombie_reached_house() const;

    // True when at least one live Zombie is on the board.
    bool has_living_zombie() const;

    // PlantType code of a placed Plant, or -1 if unknown.
    static int plant_type_of(const pvz::Plant* plant);
};

} // namespace godot
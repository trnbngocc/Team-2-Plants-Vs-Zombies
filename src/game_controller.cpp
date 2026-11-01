#include "game_controller.hpp"
#include "bullet.hpp"
#include "peashooter.hpp"
#include "sunflower.hpp"
#include "wallnut.hpp"
#include "jalapeno.hpp"
#include "squash.hpp"


#include <algorithm>
#include <climits>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

GameController::GameController()
    : wave_manager(this) {
    for (int row = 0; row < pvz::Grid::ROWS; ++row) {
        mowers[row] = pvz::LawnMower(row);
    }
}

void GameController::_bind_methods() {
    ClassDB::bind_method(
        D_METHOD("start_game"),
        &GameController::start_game
    );

    ClassDB::bind_method(
        D_METHOD("pause_game"),
        &GameController::pause_game
    );

    ClassDB::bind_method(
        D_METHOD("resume_game"),
        &GameController::resume_game
    );

    ClassDB::bind_method(
        D_METHOD("finish_game", "won"),
        &GameController::finish_game
    );

    ClassDB::bind_method(
        D_METHOD("begin_waves"),
        &GameController::begin_waves
    );

    ClassDB::bind_method(
        D_METHOD("get_waves_started"),
        &GameController::get_waves_started
    );

    ClassDB::bind_method(
        D_METHOD("shovel_plant", "row", "col"),
        &GameController::shovel_plant
    );

    ClassDB::bind_method(
        D_METHOD("advance_time", "seconds"),
        &GameController::advance_time
    );

    ClassDB::bind_method(
        D_METHOD("debug_spawn_enemy", "kind", "row", "column"),
        &GameController::debug_spawn_enemy
    );

    ClassDB::bind_method(
        D_METHOD("add_sun", "amount"),
        &GameController::add_sun
    );

    ClassDB::bind_method(
        D_METHOD("get_plant_cost", "type"),
        &GameController::get_plant_cost
    );

    ClassDB::bind_method(
        D_METHOD("get_mowers_data"),
        &GameController::get_mowers_data
    );

    ClassDB::bind_method(
        D_METHOD("get_sun_spent"),
        &GameController::get_sun_spent
    );

    ClassDB::bind_method(
        D_METHOD("get_enemies_spawned"),
        &GameController::get_enemies_spawned
    );

    ClassDB::bind_method(
        D_METHOD("get_enemies_defeated"),
        &GameController::get_enemies_defeated
    );

    ClassDB::bind_method(
        D_METHOD("get_total_enemies"),
        &GameController::get_total_enemies
    );

    ClassDB::bind_method(
        D_METHOD("get_state"),
        &GameController::get_state
    );

    ClassDB::bind_method(
        D_METHOD("get_sun"),
        &GameController::get_sun
    );
        ClassDB::bind_method(
        D_METHOD("place_plant", "row", "col", "type"),
        &GameController::place_plant_by_type
    );

    ClassDB::bind_method(
        D_METHOD("collect_sun", "id"),
        &GameController::collect_sun
    );

    ClassDB::bind_method(
        D_METHOD("get_sun_drops"),
        &GameController::get_sun_drops
    );

    ClassDB::bind_method(
        D_METHOD("get_zombies_data"),
        &GameController::get_zombies_data
    );

    ClassDB::bind_method(
        D_METHOD("get_bullets_data"),
        &GameController::get_bullets_data
    );

    ClassDB::bind_method(
        D_METHOD("get_plants_data"),
        &GameController::get_plants_data
    );

    ClassDB::bind_method(
        D_METHOD("get_wave"),
        &GameController::get_wave
    );

    ClassDB::bind_method(
        D_METHOD("get_total_waves"),
        &GameController::get_total_waves
    );

    ClassDB::bind_method(
        D_METHOD("get_preparation_time_left"),
        &GameController::get_preparation_time_left
    );

    // Presentation-only events for the UI (sound / animation / effects).
    ADD_SIGNAL(MethodInfo(
        "projectile_fired",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::FLOAT, "column")
    ));

    // Plant placement outcome (one signal per place_plant call).
    ADD_SIGNAL(MethodInfo(
        "plant_placed",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column")
    ));

    ADD_SIGNAL(MethodInfo(
        "placement_rejected",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column"),
        PropertyInfo(Variant::INT, "reason"),
        PropertyInfo(Variant::INT, "cost")
    ));

    // Emitted once per bullet, at the moment it damages a zombie.
    ADD_SIGNAL(MethodInfo(
        "projectile_hit",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::FLOAT, "column")
    ));

    ADD_SIGNAL(MethodInfo(
        "jalapeno_exploded",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column")
    ));

    // Squash hạ cánh. hit_count > 0 nghĩa là thật sự đập trúng Zombie.
    ADD_SIGNAL(MethodInfo(
        "squash_smashed",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::FLOAT, "column"),
        PropertyInfo(Variant::INT, "hit_count")
    ));

    // Squash: Zombie cùng hàng tới gần (âm thanh chuẩn bị) / rời đi trước khi nhảy.
    ADD_SIGNAL(MethodInfo(
        "squash_alert",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column")
    ));
    ADD_SIGNAL(MethodInfo(
        "squash_alert_cancelled",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column")
    ));

    // Gargantuar ném Imp (đúng một lần mỗi Gargantuar).
    ADD_SIGNAL(MethodInfo(
        "imp_thrown",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::FLOAT, "from_column"),
        PropertyInfo(Variant::FLOAT, "to_column")
    ));

    // Wave mới vừa bắt đầu (1..4); phát đúng một lần mỗi wave.
    ADD_SIGNAL(MethodInfo(
        "wave_started",
        PropertyInfo(Variant::INT, "wave")
    ));

    // "A huge wave is approaching": đúng một lần mỗi ván, trước wave cuối.
    ADD_SIGNAL(MethodInfo("huge_wave_warning"));

    // "Final Wave": phát đúng một lần, sau khi banner "A huge wave..." đã hết slot của nó
    // và trước khi zombie wave cuối bắt đầu spawn.
    ADD_SIGNAL(MethodInfo("final_wave_banner"));

    ADD_SIGNAL(MethodInfo(
        "mower_activated",
        PropertyInfo(Variant::INT, "row")
    ));

    ADD_SIGNAL(MethodInfo(
        "plant_shoveled",
        PropertyInfo(Variant::INT, "row"),
        PropertyInfo(Variant::INT, "column")
    ));

}

void GameController::_ready() {
    // GDREGISTER_CLASS also runs _ready() inside the editor.
    // Only simulate gameplay when the game is actually running.
    if (Engine::get_singleton()->is_editor_hint()) {
        set_process(false);
        return;
    }

    UtilityFunctions::print(
        "PVZ core GameController is ready."
    );

    // Start the game when the scene enters it. The preparation countdown
    // and the waves only begin on begin_waves() (after the Start Text intro).
    start_game();

    // Make sure Godot calls _process(delta).
    set_process(true);
}

void GameController::_process(double delta) {
    if (state == GameState::PLAYING) {
        update_entities(delta);
    }
}

void GameController::start_game() {
    // _ready() already starts the game; a second call from the UI
    // must not restart wave 1 in the middle of a match.
    if (state != GameState::SETUP) {
        return;
    }

    state = GameState::PLAYING;
    waves_started = false;
    intro_timer = 0.0;
}

void GameController::begin_waves() {
    if (waves_started) {
        return;
    }

    waves_started = true;

    // Preparation countdown first; WaveManager starts wave 1 when it ends.
    // It only advances in update_entities(), i.e. while PLAYING.
    wave_manager.begin_preparation();
}

void GameController::pause_game() {
    if (state == GameState::PLAYING) {
        state = GameState::PAUSED;
    }
}

void GameController::resume_game() {
    if (state == GameState::PAUSED) {
        state = GameState::PLAYING;
    }
}

void GameController::finish_game(bool won) {
    // A finished game stays finished; transition only once.
    if (state != GameState::PLAYING && state != GameState::PAUSED) {
        return;
    }

    state = won
        ? GameState::VICTORY
        : GameState::DEFEAT;

    // Bullets and Sun drops are transient effects; clear them so nothing
    // stays frozen on the end screen. Bullets are only marked dead (not
    // erased) so this is safe even if called while `entities` is in use.
    for (const auto& e : entities) {
        if (e != nullptr &&
            e->get_type() == pvz::EntityType::BULLET &&
            e->is_alive()) {

            e->take_damage(e->get_health());
        }
    }

    sun_economy.clear();

    UtilityFunctions::print(
        "GameController: game finished, won = ",
        won
    );
}

void GameController::add_entity(
    std::unique_ptr<pvz::Entity> entity
) {
    if (entity == nullptr) {
        return;
    }

    // Pushing into `entities` while it is being iterated could
    // reallocate the vector and invalidate the active loop.
    if (is_iterating_entities) {
        pending_entities.push_back(std::move(entity));
        return;
    }

    entities.push_back(std::move(entity));
}

void GameController::flush_pending_entities() {
    for (auto& entity : pending_entities) {
        entities.push_back(std::move(entity));
    }

    pending_entities.clear();
}

void GameController::spawn_bullet(
    int row,
    float start_column,
    int damage,
    float speed_cells_per_second
) {
    add_entity(
        std::make_unique<pvz::Bullet>(
            row,
            start_column,
            damage,
            speed_cells_per_second
        )
    );

    // Only Peashooters spawn bullets: lets the UI play the shot sound/animation.
    emit_signal("projectile_fired", row, start_column);
}

void GameController::notify_jalapeno_exploded(pvz::GridPosition pos) {
    emit_signal("jalapeno_exploded", pos.row, pos.column);
}

void GameController::notify_squash_alert(int row, int column) {
    emit_signal("squash_alert", row, column);
}

void GameController::notify_squash_alert_cancelled(int row, int column) {
    emit_signal("squash_alert_cancelled", row, column);
}

void GameController::notify_squash_smashed(int row, float column, int hit_count) {
    emit_signal("squash_smashed", row, column, hit_count);
}

void GameController::notify_imp_thrown(int row, float from_column, float to_column) {
    emit_signal("imp_thrown", row, from_column, to_column);
}

void GameController::update_entities(double delta_seconds) {
    // ==================== SUN ====================

    sun_economy.update(delta_seconds);

    // ==================== ZOMBIE WAVES ====================

    // Safety net: never let a missing intro animation block the match forever.
    if (!waves_started) {
        intro_timer += delta_seconds;
        if (intro_timer >= INTRO_TIMEOUT_SECONDS) {
            begin_waves();
        }
    }

    if (waves_started) {
        wave_manager.update(delta_seconds);

        // Sự kiện wave cho UI (mỗi sự kiện chỉ phát một lần).
        if (wave_manager.consume_huge_wave_warning()) {
            emit_signal("huge_wave_warning");
        }
        if (wave_manager.consume_final_wave_banner()) {
            emit_signal("final_wave_banner");
        }
        const int started = wave_manager.consume_wave_started();
        if (started > 0) {
            emit_signal("wave_started", started);
        }
    }

    // ==================== ENTITY UPDATE ====================

    // From here until flush_pending_entities(), add_entity() defers
    // new entities instead of touching `entities`.
    is_iterating_entities = true;

    for (const auto& entity : entities) {
        if (entity != nullptr && entity->is_alive()) {
            entity->tick_status_effects(delta_seconds);

            if (entity->is_alive()) {
                entity->update(delta_seconds);
            }
        }
    }

    // ==================== PLANT / BOSS ACTIONS ====================

    for (const auto& entity : entities) {
        if (entity == nullptr || !entity->is_alive()) {
            continue;
        }

        if (entity->get_type() == pvz::EntityType::PLANT) {
            static_cast<pvz::Plant*>(entity.get())->act(*this);
        }
        else if (entity->get_type() == pvz::EntityType::ZOMBIE) {
            // Only the Gargantuar acts (throws its Imp); other Zombies no-op.
            static_cast<pvz::Zombie*>(entity.get())->act(*this);
        }
    }

    is_iterating_entities = false;

    // Bullets and Imps spawned by act() join before collisions are resolved,
    // but are not updated (moved) until the next frame.
    flush_pending_entities();

    // ==================== LAWN MOWERS ====================

    update_mowers(delta_seconds);

    // ==================== BULLET COLLISIONS ====================

    resolve_bullet_collisions();

    // ==================== CLEANUP ====================

    cleanup_dead_entities();

    // ==================== DEFEAT ====================

    // A Zombie got past the end of a row whose Lawn Mower is already spent.
    if (has_zombie_breached_defense()) {
        finish_game(false);
        return;
    }

    // ==================== VICTORY ====================

    // All 25 enemies have spawned AND nothing is left alive on the board
    // (ordinary Zombies, the Gargantuar and any Imp it threw). Imps join
    // `entities` the frame they are thrown, so they always block victory.
    // Pending entities were flushed above, so `entities` is complete.
    if (waves_started &&
        wave_manager.is_finished() &&
        !has_living_zombie()) {
        finish_game(true);
    }
}

void GameController::update_mowers(double delta_seconds) {
    for (pvz::LawnMower& mower : mowers) {
        const int row = mower.get_row();

        // Trigger: any live Zombie in this row reached the mower's trigger column.
        if (mower.get_state() == pvz::LawnMower::State::READY) {
            for (pvz::Zombie* z : get_zombies_in_row(row)) {
                if (z->get_column_position() <= pvz::LawnMower::TRIGGER_COLUMN) {
                    mower.activate();
                    emit_signal("mower_activated", row);
                    break;
                }
            }
        }

        if (mower.get_state() != pvz::LawnMower::State::RUNNING) {
            continue;
        }

        mower.update(delta_seconds);

        const float x = mower.get_column();

        for (pvz::Zombie* z : get_zombies_in_row(row)) {
            const float zc = z->get_column_position();
            if (zc < x - pvz::LawnMower::HIT_BEHIND ||
                zc > x + pvz::LawnMower::HIT_AHEAD) {
                continue;
            }

            if (z->get_kind() == pvz::Zombie::Kind::GARGANTUAR) {
                // Boss is NOT one-shot: fixed damage through the normal damage
                // path (so its Imp threshold still works) + knockback, and the
                // mower is spent on the hit.
                z->take_damage(pvz::LawnMower::BOSS_DAMAGE);
                z->knock_back(pvz::LawnMower::BOSS_KNOCKBACK);
                mower.finish();
                break;
            }

            // Ordinary Zombies and Imps: armor and HP are wiped out.
            z->take_damage(INT_MAX / 2);
        }
    }
}

void GameController::advance_time(double seconds) {
    constexpr double STEP = 1.0 / 60.0;
    while (seconds > 0.0 && state == GameState::PLAYING) {
        const double dt = seconds < STEP ? seconds : STEP;
        update_entities(dt);
        seconds -= dt;
    }
}

void GameController::debug_spawn_enemy(int kind, int row, float column) {
    switch (kind) {
        case 0: wave_manager.spawn_regular(row, column); break;
        case 1: wave_manager.spawn_conehead(row, column); break;
        case 2: wave_manager.spawn_buckethead(row, column); break;
        case 3: wave_manager.spawn_gargantuar(row, column); break;
        default: break;
    }
    // Keep debug spawns out of the in-update iteration window.
    flush_pending_entities();
}

int GameController::get_state() const {
    return static_cast<int>(state);
}

bool GameController::place_plant(
    pvz::GridPosition pos,
    std::unique_ptr<pvz::Plant> plant
) {
    // Same checks in the same order as before; each refusal now also reports why.
    if (plant == nullptr) {
        notify_placement_rejected(pos, PLACE_UNKNOWN_PLANT);
        return false;
    }

    const int cost = plant->get_cost();

    if (state != GameState::PLAYING) {
        notify_placement_rejected(pos, PLACE_NOT_PLAYING, cost);
        return false;
    }

    if (!grid.is_valid(pos)) {
        notify_placement_rejected(pos, PLACE_INVALID_CELL, cost);
        return false;
    }

    if (grid.is_occupied(pos)) {
        notify_placement_rejected(pos, PLACE_OCCUPIED, cost);
        return false;
    }

    if (sun < cost) {
        notify_placement_rejected(pos, PLACE_NOT_ENOUGH_SUN, cost);
        return false;
    }

    if (!grid.place_plant(pos, plant.get())) {
        notify_placement_rejected(pos, PLACE_INVALID_CELL, cost);
        return false;
    }

    sun -= plant->get_cost();
    sun_spent += plant->get_cost();

    add_entity(std::move(plant));

    emit_signal("plant_placed", pos.row, pos.column);

    return true;
}

void GameController::notify_placement_rejected(
    pvz::GridPosition pos,
    PlacementResult reason,
    int cost
) {
    emit_signal(
        "placement_rejected",
        pos.row,
        pos.column,
        static_cast<int>(reason),
        cost
    );
}
std::unique_ptr<pvz::Plant> GameController::create_plant(
    int plant_type,
    pvz::GridPosition pos
) {
    switch (plant_type) {
        case PlantType::PEASHOOTER:
            return std::make_unique<pvz::Peashooter>(pos);
        case PlantType::SUNFLOWER:
            return std::make_unique<pvz::Sunflower>(pos);
        case PlantType::WALLNUT:
            return std::make_unique<pvz::WallNut>(pos);
        case PlantType::JALAPENO:
            return std::make_unique<pvz::Jalapeno>(pos);
        case PlantType::SQUASH:
            return std::make_unique<pvz::Squash>(pos);
        default:
            return nullptr;
    }
}

int GameController::get_plant_cost(int plant_type) const {
    const auto plant = create_plant(plant_type, pvz::GridPosition{0, 0});
    return plant != nullptr ? plant->get_cost() : -1;
}

bool GameController::place_plant_by_type(int row, int col, int plant_type) {
    pvz::GridPosition pos{row, col};
    std::unique_ptr<pvz::Plant> plant = create_plant(plant_type, pos);

    if (plant == nullptr) {
        notify_placement_rejected(pos, PLACE_UNKNOWN_PLANT);
        return false;
    }

    return place_plant(pos, std::move(plant));
}


void GameController::add_zombie(
    std::unique_ptr<pvz::Zombie> zombie
) {
    if (zombie == nullptr) {
        return;
    }

    // Zombie needs the Grid to detect Plants and attack them.
    zombie->set_grid(&grid);

    add_entity(std::move(zombie));

    UtilityFunctions::print(
        "GameController: Zombie added. Total entities = ",
        static_cast<int>(entities.size() + pending_entities.size())
    );
}

bool GameController::shovel_plant(int row, int col) {
    if (state != GameState::PLAYING) {
        return false;
    }

    const pvz::GridPosition pos{row, col};

    if (!grid.is_valid(pos)) {
        return false;
    }

    pvz::Plant* plant = grid.get_plant_at(pos);

    // Empty cell: nothing happens. Only this cell's plant is touched.
    if (plant == nullptr || !plant->is_alive()) {
        return false;
    }

    // Marked dead here, freed from the Grid by cleanup_dead_entities().
    // No Sun refund.
    plant->take_damage(plant->get_health());

    emit_signal("plant_shoveled", row, col);

    return true;
}

bool GameController::has_zombie_breached_defense() const {
    for (const auto& e : entities) {
        if (e == nullptr ||
            e->get_type() != pvz::EntityType::ZOMBIE ||
            !e->is_alive()) {

            continue;
        }

        const auto* z = static_cast<const pvz::Zombie*>(e.get());

        if (!z->has_reached_house()) {
            continue;
        }

        const int row = z->get_position().row;
        if (row < 0 || row >= pvz::Grid::ROWS) {
            continue;
        }

        // A READY / RUNNING mower still stands between this Zombie and the
        // house (it triggers at TRIGGER_COLUMN, before the Zombie crosses).
        if (mowers[row].get_state() == pvz::LawnMower::State::USED) {
            return true;
        }
    }

    return false;
}

bool GameController::has_living_zombie() const {
    for (const auto& e : entities) {
        if (e != nullptr &&
            e->get_type() == pvz::EntityType::ZOMBIE &&
            e->is_alive()) {

            return true;
        }
    }

    return false;
}

bool GameController::has_zombie_in_row(int row, float min_column) const {
    for (const auto& e : entities) {
        if (e->get_type() == pvz::EntityType::ZOMBIE &&
            e->is_alive() &&
            e->get_position().row == row &&
            static_cast<float>(e->get_position().column) >= min_column) {

            return true;
        }
    }

    return false;
}


std::vector<pvz::Zombie*> GameController::get_zombies_in_row(
    int row
) const {
    std::vector<pvz::Zombie*> result;

    for (const auto& e : entities) {
        if (e->get_type() == pvz::EntityType::ZOMBIE &&
            e->is_alive() &&
            e->get_position().row == row) {

            result.push_back(
                static_cast<pvz::Zombie*>(e.get())
            );
        }
    }

    return result;
}

void GameController::add_sun(int amount) {
    sun += amount;
}

int GameController::get_sun() const {
    return sun;
}

int GameController::spawn_sun(
    pvz::GridPosition pos,
    int value
) {
    return sun_economy.spawn_sun(pos, value);
}

int GameController::spawn_falling_sun(
    int row,
    float column,
    int value,
    double fall_duration
) {
    return sun_economy.spawn_falling_sun(row, column, value, fall_duration);
}

int GameController::collect_sun(int id) {
    if (state != GameState::PLAYING) {
        return 0;
    }

    const int value = sun_economy.collect_sun(id);

    if (value > 0) {
        sun += value;
    }

    return value;
}

const std::vector<pvz::SunDrop>&
GameController::get_suns() const {
    return sun_economy.get_suns();
}

void GameController::resolve_bullet_collisions() {
    constexpr float CELL_HIT_RADIUS = 0.5f;

    for (const auto& be : entities) {
        if (be->get_type() != pvz::EntityType::BULLET ||
            !be->is_alive()) {

            continue;
        }

        pvz::Bullet* bullet =
            static_cast<pvz::Bullet*>(be.get());

        for (const auto& ze : entities) {
            if (ze->get_type() != pvz::EntityType::ZOMBIE ||
                !ze->is_alive()) {

                continue;
            }

            if (ze->get_position().row !=
                bullet->get_position().row) {

                continue;
            }

            // Compare continuous columns so hits match what the UI draws.
            float dx =
                static_cast<pvz::Zombie*>(ze.get())->get_column_position()
                - bullet->get_column();

            if (dx < 0) {
                dx = -dx;
            }

            if (dx <= CELL_HIT_RADIUS) {
                ze->take_damage(
                    bullet->get_damage()
                );

                bullet->take_damage(
                    bullet->get_health()
                );

                // Confirmed hit: the bullet is spent, so this fires once per bullet.
                emit_signal(
                    "projectile_hit",
                    bullet->get_position().row,
                    bullet->get_column()
                );

                break;
            }
        }
    }
}

void GameController::cleanup_dead_entities() {
    // Remove dead plants from Grid first.
    for (const auto& e : entities) {
        if (!e->is_alive() &&
            e->get_type() == pvz::EntityType::PLANT) {

            grid.remove_plant(
                e->get_position()
            );
        }
    }

    // Count defeated wave enemies (Imps are extra, not part of the 25).
    for (const auto& e : entities) {
        if (!e->is_alive() &&
            e->get_type() == pvz::EntityType::ZOMBIE &&
            static_cast<const pvz::Zombie*>(e.get())->get_kind()
                != pvz::Zombie::Kind::IMP) {

            ++enemies_defeated;
        }
    }

    // Remove all dead entities from ownership vector.
    entities.erase(
        std::remove_if(
            entities.begin(),
            entities.end(),
            [](const auto& e) {
                return !e->is_alive();
            }
        ),
        entities.end()
    );
}
Array GameController::get_sun_drops() const {
    Array result;
    for (const auto& s : sun_economy.get_suns()) {
        Dictionary d;
        d["id"] = s.id;
        d["value"] = s.value;
        d["row"] = s.row;
        d["column"] = s.column;
        d["time_left"] = s.time_left;
        d["age"] = s.age;
        d["fall_duration"] = s.fall_duration;
        result.push_back(d);
    }
    return result;
}

Array GameController::get_zombies_data() const {
    Array result;
    for (const auto& e : entities) {
        if (e != nullptr && e->is_alive() && e->get_type() == pvz::EntityType::ZOMBIE) {
            auto* z = static_cast<pvz::Zombie*>(e.get());
            Dictionary d;
            d["id"] = z->get_id();
            d["row"] = z->get_position().row;
            d["column"] = z->get_column_position();
            d["eating"] = z->is_eating();
            d["health"] = z->get_health();
            d["visual_state"] = static_cast<int>(z->get_visual_state());
            d["armor"] = static_cast<int>(z->get_armor_type());
            d["armor_health"] = z->get_armor_health();
            d["armor_max"] = z->get_max_armor_health();
            d["max_health"] = z->get_max_health();
            // 0 ordinary, 1 Gargantuar, 2 Imp; action 0 normal, 1 throwing.
            d["kind"] = static_cast<int>(z->get_kind());
            d["action"] = z->get_action_state();
            result.push_back(d);
        }
    }
    return result;
}

Array GameController::get_bullets_data() const {
    Array result;
    for (const auto& e : entities) {
        if (e != nullptr && e->is_alive() && e->get_type() == pvz::EntityType::BULLET) {
            auto* b = static_cast<pvz::Bullet*>(e.get());
            Dictionary d;
            d["row"] = b->get_position().row;
            d["column"] = b->get_column();
            result.push_back(d);
        }
    }
    return result;
}

int GameController::plant_type_of(const pvz::Plant* plant) {
    if (dynamic_cast<const pvz::Peashooter*>(plant) != nullptr) {
        return PlantType::PEASHOOTER;
    }
    if (dynamic_cast<const pvz::Sunflower*>(plant) != nullptr) {
        return PlantType::SUNFLOWER;
    }
    if (dynamic_cast<const pvz::WallNut*>(plant) != nullptr) {
        return PlantType::WALLNUT;
    }
    if (dynamic_cast<const pvz::Jalapeno*>(plant) != nullptr) {
        return PlantType::JALAPENO;
    }
    if (dynamic_cast<const pvz::Squash*>(plant) != nullptr) {
        return PlantType::SQUASH;
    }
    return -1;
}

Array GameController::get_plants_data() const {
    Array result;
    for (const auto& e : entities) {
        if (e != nullptr && e->is_alive() && e->get_type() == pvz::EntityType::PLANT) {
            auto* p = static_cast<pvz::Plant*>(e.get());
            Dictionary d;
            d["row"] = p->get_position().row;
            d["column"] = p->get_position().column;
            d["health"] = p->get_health();
            d["cost"] = p->get_cost();
            // UI picks the plant texture from this PlantType code.
            d["type"] = plant_type_of(p);

            // Squash: UI draws the jump toward target_column.
            d["state"] = 0;
            d["target_column"] = 0.0f;
            if (const auto* sq = dynamic_cast<const pvz::Squash*>(p)) {
                d["state"] = sq->get_state();
                d["target_column"] = sq->get_target_column();
            }
            result.push_back(d);
        }
    }
    return result;
}

Array GameController::get_mowers_data() const {
    Array result;
    for (const pvz::LawnMower& m : mowers) {
        // 0 READY, 1 RUNNING, 2 USED (UI hides used mowers).
        Dictionary d;
        d["row"] = m.get_row();
        d["column"] = m.get_column();
        d["state"] = static_cast<int>(m.get_state());
        result.push_back(d);
    }
    return result;
}


} // namespace godot
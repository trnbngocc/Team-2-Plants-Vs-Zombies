#include "game_controller.hpp"
#include "bullet.hpp"
#include "peashooter.hpp"
#include "sunflower.hpp"
#include "wallnut.hpp"
#include "chili_pepper.hpp"


#include <algorithm>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

GameController::GameController()
    : wave_manager(this) {
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
        "chili_exploded",
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

    // Start the game (preparation countdown, then waves) when the scene
    // enters the game.
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

void GameController::notify_chili_exploded(pvz::GridPosition pos) {
    emit_signal("chili_exploded", pos.row, pos.column);
}

void GameController::update_entities(double delta_seconds) {
    // ==================== SUN ====================

    sun_economy.update(delta_seconds);

    // ==================== ZOMBIE WAVES ====================

    wave_manager.update(delta_seconds);

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

    // ==================== PLANT ACTIONS ====================

    for (const auto& entity : entities) {
        if (entity != nullptr &&
            entity->is_alive() &&
            entity->get_type() == pvz::EntityType::PLANT) {

            static_cast<pvz::Plant*>(entity.get())->act(*this);
        }
    }

    is_iterating_entities = false;

    // Bullets spawned by act() join before collisions are resolved,
    // but are not updated (moved) until the next frame.
    flush_pending_entities();

    // ==================== BULLET COLLISIONS ====================

    resolve_bullet_collisions();

    // ==================== CLEANUP ====================

    cleanup_dead_entities();

    // ==================== DEFEAT ====================

    if (has_zombie_reached_house()) {
        finish_game(false);
        return;
    }

    // ==================== VICTORY ====================

    // Every wave has finished spawning and the board is clear.
    // Pending entities were flushed above, so `entities` is complete.
    if (wave_manager.is_finished() && !has_living_zombie()) {
        finish_game(true);
    }
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
bool GameController::place_plant_by_type(int row, int col, int plant_type) {
    pvz::GridPosition pos{row, col};
    std::unique_ptr<pvz::Plant> plant;

    switch (plant_type) {
        case PlantType::PEASHOOTER:
            plant = std::make_unique<pvz::Peashooter>(pos);
            break;
        case PlantType::SUNFLOWER:
            plant = std::make_unique<pvz::Sunflower>(pos);
            break;
        case PlantType::WALLNUT:
            plant = std::make_unique<pvz::WallNut>(pos);
            break;
        case PlantType::CHILI_PEPPER:
            plant = std::make_unique<pvz::ChiliPepper>(pos);
            break;
        default:
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

bool GameController::has_zombie_reached_house() const {
    for (const auto& e : entities) {
        if (e != nullptr &&
            e->get_type() == pvz::EntityType::ZOMBIE &&
            e->is_alive() &&
            static_cast<const pvz::Zombie*>(e.get())->has_reached_house()) {

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
            d["max_health"] = z->get_max_health();
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
    if (dynamic_cast<const pvz::ChiliPepper*>(plant) != nullptr) {
        return PlantType::CHILI_PEPPER;
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
            result.push_back(d);
        }
    }
    return result;
}


} // namespace godot
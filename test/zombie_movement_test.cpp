// These tests rely on assert(): refuse to build them with NDEBUG, which would silently turn every check off.
#ifdef NDEBUG
#error "build the unit tests without NDEBUG (tools/run_core_tests.sh does)"
#endif

#include <cassert>
#include <cmath>
#include <iostream>

#include "grid.hpp"
#include "plant.hpp"
#include "zombie.hpp"

namespace {

// Plant tối giản chỉ dùng cho test: đứng yên, không act().
class DummyPlant : public pvz::Plant {
public:
    DummyPlant(pvz::GridPosition pos, int health)
        : pvz::Plant(pos, health, 0) {}

    pvz::EntityType get_type() const override {
        return pvz::EntityType::PLANT;
    }

    void update(double) override {}
};

bool near(float a, float b) {
    return std::fabs(a - b) < 1e-4f;
}

} // namespace

int main() {
    pvz::Grid grid;

    // ==========================================
    // 1. SPAWN: đúng hàng, đúng cột liên tục
    // ==========================================

    pvz::Zombie zombie({2, 8}, 200, 20, 1.0f);

    assert(zombie.get_position().row == 2);
    assert(zombie.get_position().column == 8);
    assert(near(zombie.get_column_position(), 8.0f));
    assert(!zombie.has_reached_house());

    // Chưa có Grid -> không di chuyển.
    zombie.update(0.5);
    assert(near(zombie.get_column_position(), 8.0f));

    zombie.set_grid(&grid);

    // ==========================================
    // 2. DI CHUYỂN LIÊN TỤC
    // ==========================================

    zombie.update(0.25);
    assert(near(zombie.get_column_position(), 7.75f));
    assert(zombie.get_position().column == 7);
    assert(zombie.get_position().row == 2);
    assert(!zombie.is_eating());

    // ==========================================
    // 3. DỪNG LẠI VÀ ĂN PLANT
    // ==========================================

    DummyPlant plant({2, 6}, 50);
    assert(grid.place_plant({2, 6}, &plant));

    // 7.75 -> 6.75: vào ô 6, có Plant.
    zombie.update(1.0);
    assert(zombie.get_position().column == 6);
    const float stop_column = zombie.get_column_position();

    // Đứng yên khi ăn; mỗi 1 giây gây 20 damage.
    zombie.update(0.5);
    assert(near(zombie.get_column_position(), stop_column));
    assert(plant.get_health() == 50);
    assert(zombie.is_eating());

    zombie.update(0.5);
    assert(near(zombie.get_column_position(), stop_column));
    assert(plant.get_health() == 30);

    zombie.update(1.0);
    assert(plant.get_health() == 10);

    zombie.update(1.0);
    assert(plant.get_health() == 0);
    assert(!plant.is_alive());

    // ==========================================
    // 4. PLANT CHẾT -> ĐI TIẾP
    // ==========================================

    grid.remove_plant({2, 6});

    zombie.update(0.5);
    assert(near(zombie.get_column_position(), stop_column - 0.5f));
    assert(!zombie.is_eating());

    // ==========================================
    // 5. ĐẾN NHÀ: mép trái Grid là 0.0
    // ==========================================

    pvz::Zombie walker({0, 1}, 200, 20, 1.0f);
    walker.set_grid(&grid);

    walker.update(1.0);
    assert(near(walker.get_column_position(), 0.0f));
    assert(walker.get_position().column == 0);
    assert(!walker.has_reached_house());

    // Vừa qua mép trái: ô -1 (không bị cắt về ô 0).
    walker.update(0.25);
    assert(walker.get_column_position() < 0.0f);
    assert(walker.get_position().column == -1);
    assert(walker.has_reached_house());

    // ==========================================
    // 6. ARMOR HẤP THỤ DAMAGE TRƯỚC HP
    // ==========================================

    pvz::Zombie cone(
        {1, 8},
        200,
        10,
        0.15f,
        pvz::Zombie::ArmorType::CONE,
        200
    );

    cone.take_damage(150);
    assert(cone.get_armor_health() == 50);
    assert(cone.get_health() == 200);

    // Hit larger than the remaining armor: 50 breaks the cone,
    // the excess 50 goes to body HP.
    cone.take_damage(100);
    assert(cone.get_armor_health() == 0);
    assert(!cone.has_armor());
    assert(cone.get_armor_type() == pvz::Zombie::ArmorType::NONE);
    assert(cone.get_health() == 150);

    cone.take_damage(150);
    assert(cone.get_health() == 0);
    assert(!cone.is_alive());

    // Buckethead: 300 armor + 200 HP = 500. One 900 hit kills it.
    pvz::Zombie bucket(
        {3, 8},
        200,
        10,
        0.15f,
        pvz::Zombie::ArmorType::BUCKET,
        300
    );

    bucket.take_damage(299);
    assert(bucket.get_armor_health() == 1 && bucket.get_health() == 200);
    bucket.take_damage(21);
    assert(bucket.get_armor_health() == 0 && bucket.get_health() == 180);

    pvz::Zombie bucket2({3, 8}, 200, 10, 0.15f, pvz::Zombie::ArmorType::BUCKET, 300);
    bucket2.take_damage(900);
    assert(bucket2.get_health() == 0 && !bucket2.is_alive());

    // Zombie đã chết không di chuyển.
    const float dead_column = cone.get_column_position();
    cone.set_grid(&grid);
    cone.update(1.0);
    assert(near(cone.get_column_position(), dead_column));

    // ==========================================
    // 7. ID CHO UI VÀ SPAWN NGOÀI MÉP PHẢI
    // ==========================================

    pvz::Zombie first({4, 9}, 200, 10, 1.0f);
    pvz::Zombie second({4, 9}, 200, 10, 1.0f);
    assert(first.get_id() > 0);
    assert(second.get_id() != first.get_id());
    assert(second.get_id() > cone.get_id());

    // Cột 9 nằm ngoài Grid: không có Plant, Zombie đi vào ô 8.
    first.set_grid(&grid);
    assert(first.get_position().column == 9);
    first.update(0.25);
    assert(near(first.get_column_position(), 8.75f));
    assert(first.get_position().column == 8);
    assert(!first.is_eating());

    std::cout << "Zombie movement test passed.\n";

    return 0;
}

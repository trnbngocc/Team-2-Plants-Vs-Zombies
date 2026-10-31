#pragma once

// Stub GameController cho test WaveManager ngoài Godot.
//
// GameController thật kế thừa godot::Node nên không tạo được khi
// không có engine. Stub này chỉ ghi lại các Zombie được spawn.
//
// src/wave_manager.cpp include "game_controller.hpp" bằng dấu nháy,
// nên compiler luôn tìm src/ trước. Vì vậy copy wave_manager.cpp
// ra thư mục build rồi compile bản copy:
//     cp src/wave_manager.cpp build/
//     g++ -std=c++17 -iquote test/stubs -I src
//         test/wave_manager_test.cpp build/wave_manager.cpp
//         src/zombie.cpp src/entity.cpp src/grid.cpp

#include <memory>
#include <vector>

#include "zombie.hpp"

namespace godot {

class GameController {
public:
    void add_zombie(std::unique_ptr<pvz::Zombie> zombie) {
        zombies.push_back(std::move(zombie));
    }

    std::vector<std::unique_ptr<pvz::Zombie>> zombies;
};

} // namespace godot

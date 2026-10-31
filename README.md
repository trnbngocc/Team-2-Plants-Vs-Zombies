# Team-2-Plants-Vs-Zombies

**English** · [Tiếng Việt](#tiếng-việt)

A lane-defence game inspired by *Plants vs. Zombies*, built as a university team learning project. The game rules run in **C++** (as a Godot GDExtension); **Godot 4.7** draws the game, handles input and plays audio.

> This is a student learning project. It is **not** an official PopCap / Electronic Arts product and is not affiliated with them.

---

## English

### A. Project introduction

- **Name:** Team-2-Plants-Vs-Zombies
- **Introduce:** a small *Plants vs. Zombies*-style game. You plant defenders on a 5 × 9 lawn, collect Sun, and stop three waves of zombies from reaching the house.
- **Purpose:** to practise object-oriented design and teamwork on a real, playable program. All game rules live in a C++ core. The Godot side only displays that state and sends the player's actions to it.
- **Context:** a university team coursework project.

### B. Learning objectives

Concepts you can study in this code base (all of them are actually used):

| Topic | Where to look |
|---|---|
| Classes and objects | `src/*.hpp` / `src/*.cpp`: `Entity`, `Plant`, `Zombie`, `Bullet`, `Grid`, `SunEconomy`, `WaveManager`, `GameController` |
| Inheritance | `Plant` and `Zombie` and `Bullet` derive from `Entity`; `Peashooter`, `Sunflower`, `WallNut`, `ChiliPepper` derive from `Plant` |
| Polymorphism | virtual `Entity::update()`, `Entity::get_type()`, `Entity::receive_damage()` (zombie armor overrides it), `Plant::act()` |
| Encapsulation | balance constants are private `static constexpr` members of each class |
| Ownership and memory | `GameController` owns every entity in `std::vector<std::unique_ptr<Entity>>`; entities spawned while iterating are deferred (`pending_entities`) |
| Game loop and state machine | `GameController::_process()` → `update_entities()`; states SETUP / PLAYING / PAUSED / VICTORY / DEFEAT |
| Collision and combat | `GameController::resolve_bullet_collisions()`; armor absorbing damage in `Zombie::receive_damage()`; status effects in `Entity` |
| Data structures | `Grid` (fixed 5 × 9 arrays), entity vectors, sun-drop list, wave configuration table |
| Events and UI | Godot signals emitted by the core (`plant_placed`, `placement_rejected`, `projectile_fired`, `projectile_hit`, `chili_exploded`) and handled in GDScript |
| Separation of logic and presentation | the C++ core never draws; `main_game.gd` only reads core data and calls core functions |
| Assets and tools | scripted asset preparation in `tools/` (cropping, background removal, audio conversion, procedural sprite generation) |
| Testing | stand-alone C++ unit tests in `test/` |
| Git and teamwork | individual module development and code submission for central integration |

### C. Features

- Main Menu with Play and Quit buttons.
- A 30-second preparation phase, then three waves of zombies.
- Choose a plant from the Seed Bank, then plant it on the lawn.
  - If the cell is taken, a "CANNOT PLANT HERE!" message appears.
  - If you can't afford the plant, a "NOT ENOUGH SUN! / NEED x SUN" message appears.
- Sunflowers drop Sun that you click to collect.
- Four plants: Peashooter, Sunflower, Wall-nut and Chili Pepper.
- Three zombie types: regular, Conehead and Buckethead.
  - Each zombie has idle, walk, eat, hurt and death animations.
  - A small health bar shows each zombie's body HP. Coneheads and Bucketheads show it only after their helmet is destroyed.
- Animated Peashooter: it sways, blinks and recoils when it fires. A row of fire sweeps the lane when a Chili Pepper explodes.
- Pause (Resume / Quit to menu), Victory and Game Over screens (Play Again / Quit). Each screen dims the game behind it.
- Music and sound effects:
  - menu and gameplay music;
  - button clicks, planting, sun collection, pea hits, zombie eating, Chili explosion;
  - the "zombies are coming" warning, plus victory and defeat sounds.
- The lawn scales to the window size; it has been tested at 1152 × 648, 1600 × 900 and 1024 × 768.

### D. Game mechanics

All values come from the C++ source.

**Start:** 50 Sun, then a 30 s preparation phase before the first wave.

| Plant | Cost | HP | Behaviour |
|---|---|---|---|
| Sunflower | 50 | 100 | Drops 25 Sun every 5 s. A Sun drop disappears after 10 s if you don't collect it. |
| Peashooter | 100 | 300 | Fires a pea every 1.4 s when a zombie is in its row and ahead of it. Each pea does 20 damage and travels 5 cells/s. |
| Wall-nut | 50 | 600 | Blocks zombies. "Last stand": the first time its HP drops to 25 % or below, it takes 50 % less damage for 5 s. |
| Chili Pepper | 125 | 300 | After a 2 s fuse, it explodes and deals 900 damage to every zombie in its row. |

| Zombie | Body HP | Armor | Notes |
|---|---|---|---|
| Regular | 200 | – | |
| Conehead | 200 | cone, 200 | Armor absorbs damage first; any extra damage goes to body HP. |
| Buckethead | 200 | bucket, 300 | Same rule. |

Every zombie moves one column every 4.7 s and bites the plant in its cell for 10 damage every second.

**Waves:**

| Wave | Zombies | Spawn every | Types |
|---|---|---|---|
| 1 | 3 | 10 s | Regular |
| 2 | 5 | 5 s | Regular or Conehead |
| 3 | 7 | 5 s | Regular, Conehead or Buckethead |

- There is a 3 s break between waves, for 15 zombies in total.
- Each zombie enters a random row from just outside the right edge of the lawn.

**Win and lose:**

- **Victory:** all three waves have finished spawning and no zombie is left alive.
- **Defeat:** a zombie walks past the left edge of the lawn. Defeat is checked first.

### E. Project structure

```
SConstruct                 build script for the C++ GDExtension (SCons)
extern/godot-cpp/          godot-cpp bindings (git submodule)
src/                       C++ game core
  entity.*                 base class: HP, position, status effects
  plant.*, peashooter.*, sunflower.*, wallnut.*, chili_pepper.*
  zombie.*                 movement, eating, armor
  bullet.*, grid.*, sun_economy.*, status_effect.hpp
  wave_manager.*           preparation timer, waves, spawning
  game_controller.*        the Godot node that owns and updates everything
  pvz_library_init.cpp     registers GameController with Godot
test/                      stand-alone C++ unit tests (zombie movement, armor, waves)
plants-vs-zombies/         the Godot project
  project.godot            settings; start scene = scenes/menu.tscn; autoload Audio
  scenes/menu.tscn         Main Menu        (main_menu.gd)
  scenes/main.tscn         GameController + game UI (MainGame.tscn)
  MainGame.tscn            board, HUD, pause / victory / game-over overlays (main_game.gd)
  board.tscn / board.gd    lawn image + 45 clickable cells, scaled to the window
  hud.tscn, seed_bank.tscn, sun_display.tscn, pause_button.tscn
  win_screen.tscn, lose_screen.tscn
  main_game.gd             presentation: reads core data every frame, draws plants/zombies/peas/sun
  zombie_view.gd           zombie sprite animations + health bar
  peashooter_view.gd       Peashooter assembled from part images, idle/shoot animation
  chili_fire.gd            visual-only fire for the Chili explosion
  audio.gd                 the single audio manager (music + sound effects)
  stone_button.gd, stone_title.gd   UI buttons and pixel titles
  assets/                  images, sprites and audio
  bin/pvz.gdextension      tells Godot where the compiled C++ library is
tools/                     scripts that produced the processed assets (see tools/README.md)
```

### F. Requirements

These match the project configuration; other setups have not been tested.

- **Windows x86_64.** `bin/pvz.gdextension` only lists Windows libraries.
- **Godot 4.7.** The project declares feature level 4.7 and was developed with **Godot 4.7.2-stable**.
- **To build the C++ library:**
  - Git, to fetch the `extern/godot-cpp` submodule;
  - Python 3 with **SCons**;
  - a C++17 compiler (the team used MSVC from Visual Studio Build Tools).
- **Optional, to run the unit tests:** any C++17 compiler, e.g. g++.

### G. How to run

1. Clone the repository, including the submodule:
   ```
   git clone --recurse-submodules https://github.com/trnbngocc/Team-2-Plants-Vs-Zombies.git
   cd Team-2-Plants-Vs-Zombies
   git submodule update --init
   ```
2. Build the GDExtension (from the repository root, in a terminal where SCons and the compiler are available):
   ```
   scons
   ```
   This creates `plants-vs-zombies/bin/libpvz.windows.template_debug.x86_64.dll`. Only the debug library is built, which is what the Godot editor uses.
3. Open Godot 4.7 and use **Import** to open `plants-vs-zombies/project.godot`. The first time, Godot imports the images and audio automatically.
4. Press **Run** (F5). The game starts in the Main Menu.

If Godot reports that `GameController` is unknown, the DLL from step 2 is missing. If you rebuild while the editor is open, restart the editor so it loads the new DLL.

### H. How to study the project

1. **Start with the rules in C++.**
   - Read `src/entity.hpp`, then `plant.hpp` and `zombie.hpp`, to see the class hierarchy.
   - Then read `GameController::update_entities()` in `src/game_controller.cpp`. It is one complete frame of the game: sun, waves, entity updates, plant actions, collisions, cleanup, and finally the win/lose checks.
2. **Follow one plant.**
   - `Peashooter::update()` counts down its timer.
   - `Peashooter::act()` asks `GameController::has_zombie_in_row()` and calls `spawn_bullet()`.
   - The bullet moves in `Bullet::update()`, and `resolve_bullet_collisions()` applies its damage.
3. **Follow one zombie:** `WaveManager::update()` spawns it, `Zombie::default_update()` moves it or makes it eat, and `Zombie::receive_damage()` applies armor first.
4. **Then the presentation side.**
   - `main_game.gd` calls `get_plants_data()`, `get_zombies_data()` and the other data functions every frame and draws the result.
   - It reacts to the core's signals for sounds, animations and messages.
   - The UI never changes Sun, HP or the rules itself.
5. **Experiment safely.**
   - Work on your own branch.
   - Change one balance constant at a time (they are `static constexpr` values at the top of each plant class, and in `wave_manager.hpp`), rebuild, and observe.
   - Run the unit tests in `test/` (compile notes are in `test/stubs/game_controller.hpp`).
   - Do not edit the generated files in `assets/` by hand; rerun the matching script in `tools/` instead.

### I. Team and credits

- **Team 2:**
  - **Core Architecture & C++ Game Core:** trnbngocc
  - **Plant Modules:** BunBo-0920
  - **Zombie Modules:** lehoangthaovia-code
  - **UI & Presentation (GDScript):** bolhouuu114

### J. Disclaimer

This repository is an educational, non-commercial student project. If you have any questions, please feel free to open an issue.

---

## Tiếng Việt

### A. Giới thiệu dự án

- **Tên:** Team-2-Plants-vs-Zombies
- **Giới thiệu:** một trò chơi nhỏ theo phong cách *Plants vs. Zombies*. Người chơi trồng cây trên bãi cỏ 5 × 9, thu thập Sun và ngăn ba đợt zombie tiến vào nhà.
- **Mục đích:** luyện tập thiết kế hướng đối tượng và làm việc nhóm trên một chương trình chơi được thật. Toàn bộ luật chơi nằm trong lõi C++. Phần Godot chỉ hiển thị trạng thái đó và chuyển thao tác của người chơi cho lõi xử lý.
- **Bối cảnh:** đồ án môn học theo nhóm ở bậc đại học.

> Đây là dự án học tập của sinh viên, **không** phải sản phẩm chính thức của PopCap / Electronic Arts và không liên kết với họ.

### B. Mục tiêu học tập

Các khái niệm có thể học trong mã nguồn (đều được dùng thật):

| Chủ đề | Xem ở đâu |
|---|---|
| Lớp và đối tượng | `src/*.hpp` / `src/*.cpp`: `Entity`, `Plant`, `Zombie`, `Bullet`, `Grid`, `SunEconomy`, `WaveManager`, `GameController` |
| Kế thừa | `Plant`, `Zombie` và `Bullet` kế thừa `Entity`; `Peashooter`, `Sunflower`, `WallNut`, `ChiliPepper` kế thừa `Plant` |
| Đa hình | hàm ảo `Entity::update()`, `Entity::get_type()`, `Entity::receive_damage()` (giáp của zombie ghi đè hàm này), `Plant::act()` |
| Đóng gói | các hằng số cân bằng là thành viên `static constexpr` private của từng lớp |
| Quản lý sở hữu và bộ nhớ | `GameController` sở hữu mọi thực thể trong `std::vector<std::unique_ptr<Entity>>`; thực thể sinh ra khi đang duyệt được hoãn lại (`pending_entities`) |
| Vòng lặp game và máy trạng thái | `GameController::_process()` → `update_entities()`; các trạng thái SETUP / PLAYING / PAUSED / VICTORY / DEFEAT |
| Va chạm và chiến đấu | `GameController::resolve_bullet_collisions()`; giáp hấp thụ sát thương trong `Zombie::receive_damage()`; hiệu ứng trạng thái trong `Entity` |
| Cấu trúc dữ liệu | `Grid` (mảng cố định 5 × 9), vector thực thể, danh sách Sun rơi, bảng cấu hình wave |
| Sự kiện và giao diện | signal của Godot do lõi phát ra (`plant_placed`, `placement_rejected`, `projectile_fired`, `projectile_hit`, `chili_exploded`) và được xử lý trong GDScript |
| Tách logic và hiển thị | lõi C++ không bao giờ vẽ; `main_game.gd` chỉ đọc dữ liệu và gọi hàm của lõi |
| Tài nguyên và công cụ | chuẩn bị tài nguyên bằng script trong `tools/` (cắt ảnh, xoá nền, chuyển đổi âm thanh, sinh sprite bằng code) |
| Kiểm thử | unit test C++ độc lập trong `test/` |
| Git và làm việc nhóm | tự viết code module riêng và gửi để team lead tổng hợp/up lên repository |

### C. Các tính năng

- Main Menu với nút Play và Quit.
- 30 giây chuẩn bị, sau đó là ba đợt zombie.
- Chọn cây ở Seed Bank rồi trồng lên bãi cỏ.
  - Ô đã có cây: hiện thông báo "CANNOT PLANT HERE!".
  - Không đủ Sun: hiện thông báo "NOT ENOUGH SUN! / NEED x SUN".
- Hoa hướng dương rơi Sun, bấm vào để thu thập.
- Bốn loại cây: Peashooter, Sunflower, Wall-nut và Chili Pepper.
- Ba loại zombie: thường, Conehead (đội nón) và Buckethead (đội xô).
  - Mỗi loại có hoạt ảnh idle, walk, eat, hurt và death.
  - Một thanh máu nhỏ hiện máu thân của zombie. Conehead và Buckethead chỉ hiện thanh máu sau khi mất nón / xô.
- Peashooter có hoạt ảnh: lắc lư, chớp mắt và giật lại khi bắn. Một dải lửa chạy ngang hàng khi Chili Pepper nổ.
- Màn hình Pause (Resume / Quit về menu), Victory và Game Over (Play Again / Quit). Mỗi màn hình làm tối toàn bộ trận đấu phía sau.
- Nhạc và hiệu ứng âm thanh:
  - nhạc menu và nhạc trong trận;
  - click nút, trồng cây, nhặt Sun, đạn trúng zombie, zombie ăn cây, Chili nổ;
  - cảnh báo "zombies are coming", cùng âm thanh thắng và thua.
- Bãi cỏ co giãn theo kích thước cửa sổ; đã kiểm tra ở 1152 × 648, 1600 × 900 và 1024 × 768.

### D. Cơ chế trò chơi

Mọi giá trị lấy từ mã nguồn C++.

**Bắt đầu:** 50 Sun, sau đó 30 giây chuẩn bị trước wave đầu tiên.

| Cây | Giá | Máu | Hoạt động |
|---|---|---|---|
| Sunflower | 50 | 100 | Rơi 25 Sun mỗi 5 giây. Sun không được nhặt sẽ biến mất sau 10 giây. |
| Peashooter | 100 | 300 | Bắn một viên đậu mỗi 1,4 giây khi có zombie cùng hàng ở phía trước. Mỗi viên gây 20 sát thương và bay 5 ô/giây. |
| Wall-nut | 50 | 600 | Chặn zombie. "Last stand": lần đầu máu còn 25 % trở xuống, giảm 50 % sát thương nhận vào trong 5 giây. |
| Chili Pepper | 125 | 300 | Sau 2 giây đếm ngược, nổ và gây 900 sát thương cho mọi zombie cùng hàng. |

| Zombie | Máu thân | Giáp | Ghi chú |
|---|---|---|---|
| Thường | 200 | – | |
| Conehead | 200 | nón, 200 | Giáp nhận sát thương trước; phần dư trừ vào máu thân. |
| Buckethead | 200 | xô, 300 | Quy tắc tương tự. |

Mọi zombie đi một cột mỗi 4,7 giây và cắn cây trong ô của nó 10 sát thương mỗi giây.

**Các wave:**

| Wave | Số zombie | Khoảng cách xuất hiện | Loại |
|---|---|---|---|
| 1 | 3 | 10 giây | Thường |
| 2 | 5 | 5 giây | Thường hoặc Conehead |
| 3 | 7 | 5 giây | Thường, Conehead hoặc Buckethead |

- Giữa hai wave nghỉ 3 giây; tổng cộng 15 zombie.
- Mỗi zombie vào một hàng ngẫu nhiên, xuất hiện ngay ngoài mép phải bãi cỏ.

**Thắng và thua:**

- **Thắng:** cả ba wave đã xuất hiện hết và không còn zombie nào sống.
- **Thua:** có zombie đi qua mép trái bãi cỏ. Điều kiện thua được kiểm tra trước.

### E. Cấu trúc dự án

```
SConstruct                 script build thư viện GDExtension C++ (SCons)
extern/godot-cpp/          thư viện godot-cpp (git submodule)
src/                       lõi game C++
  entity.*                 lớp cơ sở: máu, vị trí, hiệu ứng trạng thái
  plant.*, peashooter.*, sunflower.*, wallnut.*, chili_pepper.*
  zombie.*                 di chuyển, ăn cây, giáp
  bullet.*, grid.*, sun_economy.*, status_effect.hpp
  wave_manager.*           thời gian chuẩn bị, wave, sinh zombie
  game_controller.*        node Godot sở hữu và cập nhật mọi thứ
  pvz_library_init.cpp     đăng ký GameController với Godot
test/                      unit test C++ độc lập (di chuyển zombie, giáp, wave)
plants-vs-zombies/         dự án Godot
  project.godot            cấu hình; scene khởi động = scenes/menu.tscn; autoload Audio
  scenes/menu.tscn         Main Menu        (main_menu.gd)
  scenes/main.tscn         GameController + giao diện trận đấu (MainGame.tscn)
  MainGame.tscn            bãi cỏ, HUD, lớp phủ pause / victory / game over (main_game.gd)
  board.tscn / board.gd    ảnh bãi cỏ + 45 ô bấm, co giãn theo cửa sổ
  hud.tscn, seed_bank.tscn, sun_display.tscn, pause_button.tscn
  win_screen.tscn, lose_screen.tscn
  main_game.gd             hiển thị: đọc dữ liệu lõi mỗi frame, vẽ cây/zombie/đạn/Sun
  zombie_view.gd           hoạt ảnh zombie + thanh máu
  peashooter_view.gd       Peashooter ghép từ các mảnh, hoạt ảnh idle/bắn
  chili_fire.gd            hiệu ứng lửa (chỉ hình) khi Chili nổ
  audio.gd                 bộ quản lý âm thanh duy nhất (nhạc + hiệu ứng)
  stone_button.gd, stone_title.gd   nút giao diện và tiêu đề pixel
  assets/                  hình ảnh, sprite và âm thanh
  bin/pvz.gdextension      cho Godot biết vị trí thư viện C++ đã biên dịch
tools/                     các script tạo ra tài nguyên đã xử lý (xem tools/README.md)
```

### F. Yêu cầu

Phần này khớp với cấu hình dự án; các môi trường khác chưa được kiểm tra.

- **Windows x86_64.** `bin/pvz.gdextension` chỉ khai báo thư viện cho Windows.
- **Godot 4.7.** Dự án khai báo phiên bản 4.7 và được phát triển trên **Godot 4.7.2-stable**.
- **Để build thư viện C++:**
  - Git, để tải submodule `extern/godot-cpp`;
  - Python 3 và **SCons**;
  - trình biên dịch C++17 (nhóm dùng MSVC trong Visual Studio Build Tools).
- **Tuỳ chọn, để chạy unit test:** bất kỳ trình biên dịch C++17 nào, ví dụ g++.

### G. Hướng dẫn chạy

1. Clone repository kèm submodule:
   ```
   git clone --recurse-submodules https://github.com/trnbngocc/Team-2-Plants-Vs-Zombies.git
   cd Team-2-Plants-Vs-Zombies
   git submodule update --init
   ```
2. Build GDExtension (tại thư mục gốc repository, trong terminal có SCons và trình biên dịch):
   ```
   scons
   ```
   Lệnh này tạo `plants-vs-zombies/bin/libpvz.windows.template_debug.x86_64.dll`. Chỉ thư viện debug được build, đúng loại mà Godot editor dùng.
3. Mở Godot 4.7 và chọn **Import** để mở `plants-vs-zombies/project.godot`. Lần đầu, Godot sẽ tự import hình ảnh và âm thanh.
4. Bấm **Run** (F5). Trò chơi bắt đầu ở Main Menu.

Nếu Godot báo không biết `GameController`, nghĩa là thiếu file DLL ở bước 2. Nếu build lại khi editor đang mở, hãy khởi động lại editor để nạp DLL mới.

### H. Hướng dẫn sử dụng để học tập

1. **Bắt đầu từ luật chơi trong C++.**
   - Đọc `src/entity.hpp`, rồi `plant.hpp` và `zombie.hpp`, để thấy cây kế thừa.
   - Sau đó đọc `GameController::update_entities()` trong `src/game_controller.cpp`. Đây là một frame đầy đủ của trò chơi: Sun, wave, cập nhật thực thể, hành động của cây, va chạm, dọn dẹp, và cuối cùng là kiểm tra thắng/thua.
2. **Theo dõi một cây.**
   - `Peashooter::update()` đếm thời gian.
   - `Peashooter::act()` hỏi `GameController::has_zombie_in_row()` rồi gọi `spawn_bullet()`.
   - Đạn di chuyển trong `Bullet::update()`, và `resolve_bullet_collisions()` trừ sát thương.
3. **Theo dõi một zombie:** `WaveManager::update()` sinh ra zombie, `Zombie::default_update()` cho nó đi hoặc ăn cây, và `Zombie::receive_damage()` trừ giáp trước.
4. **Sau đó là phần hiển thị.**
   - `main_game.gd` gọi `get_plants_data()`, `get_zombies_data()` và các hàm dữ liệu khác mỗi frame rồi vẽ kết quả.
   - Nó phản hồi signal của lõi để phát âm thanh, hoạt ảnh và thông báo.
   - Giao diện không bao giờ tự thay đổi Sun, máu hay luật chơi.
5. **Thử nghiệm an toàn.**
   - Làm trên nhánh riêng.
   - Mỗi lần chỉ đổi một hằng số cân bằng (các giá trị `static constexpr` ở đầu mỗi lớp cây và trong `wave_manager.hpp`), build lại và quan sát.
   - Chạy unit test trong `test/` (cách biên dịch ghi trong `test/stubs/game_controller.hpp`).
   - Không sửa tay các file đã được tạo trong `assets/`; hãy chạy lại script tương ứng trong `tools/`.

### I. Thành viên và đóng góp

- **Team 2:**
  - **Lõi C++ & Kiến trúc hệ thống (Core):** trnbngocc
  - **Phát triển Cây (Plants):** BunBo-0920
  - **Phát triển Zombie:** lehoangthaovia-code
  - **Giao diện & Hiển thị (UI - GDScript):** bolhouuu114

### J. Tuyên bố

Repository này là dự án học tập phi thương mại của sinh viên. Nếu bạn có thắc mắc, vui lòng để lại issue.


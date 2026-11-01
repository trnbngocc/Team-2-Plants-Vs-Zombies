# Team-2-Plants-Vs-Zombies

**English** · [Tiếng Việt](#tiếng-việt)

A lane-defence game inspired by *Plants vs. Zombies*, built as a university team learning project. The game rules run in **C++** (as a Godot GDExtension); **Godot 4.7** draws the game, handles input and plays audio.

> This is a student learning project. It is **not** an official PopCap / Electronic Arts product and is not affiliated with them.

---

## English

### A. Project overview

- **Name:** Team-2-Plants-Vs-Zombies (Godot project name `PlantsVsZombies`).
- **Short description:** a *Plants vs. Zombies*-style lane-defence game. You plant defenders on a 9 × 5 lawn, collect Sun, and stop four waves of zombies (25 enemies in total, including a Gargantuar boss that throws an Imp) from reaching the house. A Lawn Mower in every row is the last line of defence.
- **Purpose / context:** a university team coursework project to practise object-oriented design and teamwork on a real, playable program. All game rules live in a C++ core; the Godot side only displays that state and sends the player's actions to it.
- **Main gameplay features:**
  - five plants: Sunflower, Peashooter, Wall-nut, Jalapeno, Squash, chosen from a Seed Bank, plus a shovel;
  - Regular, Conehead and Buckethead zombies, the Gargantuar boss and the Imp it throws;
  - Sun economy (falling Sun, Sunflower production), a 30 s preparation phase, a "Ready, Set, Plant!" start text, a huge-wave and a final-wave announcement;
  - one Lawn Mower per row (single use), pause, Victory and Game Over screens;
  - zombie death animations: a Regular / Conehead / Buckethead / Imp loses its head to ordinary damage (a Lawn Mower throws it farther, to the right); Jalapeno and Squash kills and the Gargantuar keep the plain fall;
  - username entry (confirmed with the on-screen Tick button): one username = one leaderboard entry = one player session, and a session-only leaderboard;
  - music and sound effects, including the Lawn Mower and the Squash cue.
- **Technologies and tools:**
  - **C++17** game core, built as a **Godot GDExtension** with **godot-cpp** (`extern/godot-cpp`, a git submodule) and **SCons**;
  - **Godot 4.7** (developed with 4.7.2-stable, GL Compatibility renderer) with **GDScript** for presentation, UI and audio;
  - **Python 3** (Pillow, NumPy, SciPy, OpenCV) in `tools/` to cut and process the art; MATLAB was used once to convert the two music tracks (see `tools/README.md`);
  - **g++** for the stand-alone C++ unit tests.
- **How to build and run:** see [F. Requirements](#f-requirements) and [G. How to run](#g-how-to-run). The submission ZIP already contains the compiled Windows library, so the game can be opened in Godot without building anything.

### B. Learning objectives

Concepts you can study in this code base (all of them are actually used):

| Topic | Where to look |
|---|---|
| Classes and objects | `src/*.hpp` / `src/*.cpp`: `Entity`, `Plant`, `Zombie`, `Bullet`, `Grid`, `SunEconomy`, `WaveManager`, `GameController` |
| Inheritance | `Plant` and `Zombie` and `Bullet` derive from `Entity`; `Peashooter`, `Sunflower`, `WallNut`, `Jalapeno` derive from `Plant` |
| Polymorphism | virtual `Entity::update()`, `Entity::get_type()`, `Entity::receive_damage()` (zombie armor overrides it), `Plant::act()` |
| Encapsulation | balance constants are private `static constexpr` members of each class |
| Ownership and memory | `GameController` owns every entity in `std::vector<std::unique_ptr<Entity>>`; entities spawned while iterating are deferred (`pending_entities`) |
| Game loop and state machine | `GameController::_process()` → `update_entities()`; states SETUP / PLAYING / PAUSED / VICTORY / DEFEAT |
| Collision and combat | `GameController::resolve_bullet_collisions()`; armor absorbing damage in `Zombie::receive_damage()`; status effects in `Entity` |
| Data structures | `Grid` (fixed 5 × 9 arrays), entity vectors, sun-drop list, wave configuration table |
| Events and UI | Godot signals emitted by the core (`plant_placed`, `placement_rejected`, `projectile_fired`, `projectile_hit`, `jalapeno_exploded`) and handled in GDScript |
| Separation of logic and presentation | the C++ core never draws; `main_game.gd` only reads core data and calls core functions |
| Assets and tools | scripted asset preparation in `tools/` (cropping, background removal, audio conversion, procedural sprite generation) |
| Testing | stand-alone C++ unit tests in `test/` |
| Git and teamwork | individual module development and code submission for central integration |

### C. Features

- Main Menu with three image buttons from `assets/ui/buttons.jpg` (cropped by `tools/ui_art/prepare_ui_assets.py`): a round **TICK** beside the username box, **PLAY** and **QUIT**. Type a name and **click TICK with the mouse** to confirm it (the keyboard Enter key does nothing); **PLAY** starts the game only after a confirmed name. The name is trimmed, 1-16 characters, and checked case-insensitively against this session's leaderboard: a name that already has an entry is rejected with "Username already exists". A valid name is accepted and a green "Username accepted" message shows. The same row has an image **LEADERBOARD** button (view of this session's results, with BACK) and **QUIT** (closes the application). All five buttons (Tick, Play, Quit, Leaderboard, and Next/Back on the other screens) come from the supplied stone sheet; Next, Back and Leaderboard are built in the same style by `tools/ui_art/make_nav_buttons.py`.
- A "Ready... Set... PLANT!" intro (bouncing text and sound). The 30-second preparation phase and the waves start only after it ends.
- Four waves of 25 enemies in total. Before the last wave: the "A huge wave of zombies is approaching!" banner (4 s), then the "Final Wave" banner (3 s), and only then do the wave-4 zombies spawn. The last wave has a **Gargantuar** boss with its own HP bar.
- Five plants in a redesigned Seed Bank (packet art, name, Sun cost, dimmed when you can't afford it, highlighted when selected): Peashooter, Sunflower, Wall-nut, Jalapeno and Squash.
  - If the cell is taken, a "CANNOT PLANT HERE!" message appears.
  - If you can't afford the plant, a "NOT ENOUGH SUN! / NEED x SUN" message appears.
- Sunflowers drop Sun that **falls from above** onto a random spot of the lawn; click it to collect.
- A **shovel** (the supplied shovel slot in the top bar; the shovel itself follows the pointer while selected) removes the plant in the clicked cell (no refund).
- One **lawn mower** per row: it runs once and wipes out the zombies in its row. A zombie that reaches the end of a row whose mower is spent ends the game.
- Squash jumps and smashes a zombie in front of it, shaking the screen briefly on impact.
- Zombies: regular, Conehead (visible cone), Buckethead (visible bucket), Gargantuar (boss) and the Imp it throws. All of them are assembled from the loose body parts in `Regular_Zombies.png` / `zombie_Gargantuar.png` (those sheets contain no animation frames, so their motion is procedural). Cones and buckets show three damage states and fly off when destroyed.
- Character art follows the classic game: `assets/references/original_pvz` holds the reference illustrations, and `python tools/character_art/build_all.py` (needs Pillow, numpy, scipy, opencv-python-headless) cuts them into rig layers in `assets/characters/` (zombie head/body/feet, cone and bucket cut from the Conehead / Buckethead art with 3 damage states each, Gargantuar parts + the Imp rider, Sunflower and Peashooter head/stem, Jalapeno, frames of the original Squash animation, the Imp, and the lawn mower body/engine/wheel). The Pea projectile and its green splat frames are the "Pea" block of `assets/projectiles/Projectiles.png`, extracted to `assets/projectiles/pea/`. `python tools/plant_art/build_assets.py` builds the Wall-nut sprites, shovel and banner crops from the supplied sheets.
- Cut-out animation (no single image is ever spun to fake walking): zombies sway, step and bite; the Gargantuar winds up and slams its pole and leans back to throw the Imp, which flies to its landing spot; Sunflower and Peashooter sway (the Peashooter recoils when it fires); the Wall-nut breathes, blinks and flinches; the Jalapeno glows and shakes as its fuse burns down; the Squash crouches, jumps and leaves a flattened splat.
- Victory and Game Over screens (the Game Over art is the supplied "The Zombies Ate Your Brains!" image) with an image **Next** button that opens the post-match **Leaderboard** (username, score, Victory / Defeat). Opened from the menu it has only **Back**. Opened after a match it has **Restart** (round-arrow button) and **Back**. **Restart** replays with the same username from a completely fresh match; when it ends, that player's *existing* entry is updated with the latest result (never a second row), so the player can keep restarting to change their rank. **Back** ends the player's session and returns to the menu; the entry stays on the board, so that username can no longer start a new game and the next player must enter a different name. **The leaderboard is session-only**: a player's entry is created in memory the moment their first match ends, is kept while the application stays open and is discarded when it quits; nothing is written to disk, so every launch starts empty.
- Pause (Resume / Quit to menu) freezes the whole screen.
- Music and sound effects, including the Lawn Mower (one sound per activation, stopped when its run ends), the Squash cue (plays when a zombie comes within about a cell of its attack range, cancelled if the zombie leaves first; never on planting) and the Start Text jingle and the Gargantuar death sound.
- The lawn scales to the window size.

### D. Game mechanics

All values come from the C++ source.

**Start:** 50 Sun, then the intro, then a 30 s preparation phase before the first wave.

| Plant | Cost | HP | Behaviour |
|---|---|---|---|
| Sunflower | 50 | 100 | Drops 25 Sun every 5 s (falling from above). A Sun drop disappears 10 s after landing if you don't collect it. |
| Peashooter | 100 | 300 | Fires a pea every 1.4 s when a zombie is in its row and ahead of it. Each pea does a flat 20 damage and travels 5 cells/s. |
| Wall-nut | 50 | 600 | Blocks zombies. "Last stand": the first time its HP drops to 25 % or below, it takes 50 % less damage for 5 s. |
| Jalapeno | 125 | 300 | After a 2 s fuse, it explodes and deals 900 damage to every zombie in its row. |
| Squash | 50 | 300 | One use. When a zombie is within about 1.5 cells ahead in its row, it jumps (0.5 s) and smashes for 1800 damage around the landing point. |

| Enemy | Armor HP | Body HP | Total |
|---|---|---|---|
| Regular | – | 200 | 200 |
| Conehead | 370 | 200 | 570 |
| Buckethead | 1100 | 200 | 1300 |
| Gargantuar (boss) | – | 2000 | 2000 |
| Imp | – | 100 | 100 |

Armor absorbs damage first; extra damage goes to the body (400 damage on a Conehead = 370 armor + 30 body). Ordinary zombies move one column every 4.7 s and bite for 10 damage every second. The Gargantuar moves one column every 9.4 s and smashes plants for 300 every 1.5 s. The Imp moves one column every 2.8 s.

**Gargantuar:** when its HP is 1000 or lower it throws **exactly one Imp** (it stands still for 1 s while throwing). Damage always goes through the normal damage path: Jalapeno (900) and Squash (1800) cannot kill a full-health Gargantuar in one hit.

**Waves (25 enemies in total):**

| Wave | Enemies | Spawn every | Types |
|---|---|---|---|
| 1 | 3 | 10 s | Regular |
| 2 | 5 | 5 s | Regular or Conehead |
| 3 | 7 | 5 s | Regular, Conehead or Buckethead |
| 4 | 10 | 5 s | exactly 4 Regular, 3 Conehead, 2 Buckethead and 1 Gargantuar: the first 3 ordinary zombies, then the Gargantuar, then the other 6 |

- There is a 3 s break between waves, and 7 s before the last wave: "A huge wave..." appears when that break starts (4 s), "Final Wave" follows (3 s), and wave 4 begins when it ends. The sequence runs on game time, so pausing freezes it.
- Each enemy enters a random row from just outside the right edge of the lawn.

**Lawn mowers:** one per row, triggered when a zombie reaches the left edge of the lawn. Ordinary zombies and Imps in the row are wiped out. The Gargantuar is not: it takes 400 damage and is knocked back 2 columns, and that mower is spent.

**Win and lose:**

- **Victory:** all 25 enemies have spawned and none is left alive (Gargantuar and Imp included).
- **Defeat:** a zombie walks past the left edge of a row whose mower is already spent. Defeat is checked first.
- **Score:** Victory = total Sun actually spent on plants during the match (remaining Sun does not count, the shovel gives no refund); Defeat = 0. The Leaderboard lists every Victory first (lower Sun spent ranks higher), then the Defeats.

### E. Project structure

Only folders and files that exist in the project are listed. Items marked *(generated)* are created by tools and are not in the source tree.

```
README.md                  this file
SConstruct                 build script of the C++ GDExtension (SCons)
.gitmodules, .gitignore    submodule definition; ignore rules
extern/godot-cpp/          godot-cpp bindings (git submodule; the ZIP carries its sources, without build output)
src/                       C++ game core (*.cpp / *.hpp)
  entity.*                 base class: HP, position, status effects
  plant.*, peashooter.*, sunflower.*, wallnut.*, jalapeno.*, squash.*
  zombie.*, gargantuar.*, imp.*   movement, eating, armor; boss and the Imp it throws
  lawn_mower.hpp           per-row mower (state + movement)
  bullet.*, grid.*, sun_economy.*, status_effect.hpp
  wave_manager.*           preparation timer, waves, spawning
  game_controller.*        the Godot node that owns and updates everything; signals to the UI
  pvz_library_init.cpp     registers GameController with Godot
test/                      stand-alone C++ unit tests
  wave_manager_test.cpp, squash_test.cpp, jalapeno_test.cpp, zombie_movement_test.cpp, zombie_visual_state_test.cpp
  stubs/game_controller.hpp   stub of the Godot-dependent controller
plants-vs-zombies/         the Godot project
  project.godot            settings; start scene = scenes/menu.tscn; autoloads Audio and Session
  bin/pvz.gdextension      tells Godot where the compiled C++ library is
  bin/libpvz.windows.template_debug.x86_64.dll   (generated by `scons`; included in the submission ZIP)
  scenes/                  menu.tscn (Main Menu), main.tscn (GameController + game UI), leaderboard.tscn
  MainGame.tscn, board.tscn, hud.tscn, seed_bank.tscn, sun_display.tscn, pause_button.tscn, win_screen.tscn, lose_screen.tscn
  main_game.gd             presentation: reads core data every frame, draws plants / zombies / peas / sun / mowers
  main_menu.gd             Main Menu: username box, Tick, Play, Quit, Leaderboard
  leaderboard.gd           Leaderboard screen (menu: Back; after a match: Restart + Back)
  session.gd               autoload: username validation + the in-memory, session-only leaderboard
  audio.gd                 autoload: the single audio manager (music, effects, per-object voices for mower / Squash)
  board.gd                 lawn image + 45 clickable cells, scaled to the window
  plant_rig.gd, peashooter_view.gd, jalapeno_fire.gd, pea_impact.gd   plant rigs, Jalapeno fire, Pea impact splat
  puppet_zombie.gd, zombie_view.gd   zombie rigs (regular, armored, Gargantuar, Imp) and their views / health bars
  stone_ui.gd, stone_button.gd, stone_title.gd   image / stone-style buttons and pixel titles
  tests/                   Godot test scripts (headless and windowed)
  assets/                  images, sprites and audio (see H. Asset classification)
  grid.jpg, menu.jpg, icon.svg
  .godot/                  (generated by Godot on first open; not packaged)
tools/                     scripts that produced the processed assets, and test runners
  README.md                what each asset tool reads and writes
  character_art/, plant_art/, lawn_art/, peashooter/, ui_art/, zombie_art/, audio/   asset scripts
  run_core_tests.sh        builds + runs the C++ unit tests (g++)
  run_godot_tests.ps1      runs every Godot test
  run_scenarios.ps1        runs the user-flow scenarios, each in its own process
build/                     (generated) local C++ test build output; not packaged
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

**From the submission ZIP (no build needed, Windows):**

1. Install **Godot 4.7.x** (the "standard", non-.NET build; 4.7.2-stable was used) from <https://godotengine.org>. No installation of the game is needed.
2. Extract the ZIP anywhere (a path without special characters is safest).
3. Start Godot, press **Import**, select `Team-2-Plants-Vs-Zombies/plants-vs-zombies/project.godot`, then **Import & Edit**. On the first open Godot imports the images and audio by itself; wait until the progress bar finishes (about a minute).
4. Press **F5** (Run Project). The game starts in the Main Menu: type a username, click the **tick**, click **Play**.
5. Command-line alternative: `Godot.exe --path <extracted>/plants-vs-zombies` (run `Godot.exe --headless --path <extracted>/plants-vs-zombies --import` once first).

The compiled library `plants-vs-zombies/bin/libpvz.windows.template_debug.x86_64.dll` is included. If Godot says `GameController` is unknown, that file is missing or blocked by antivirus; rebuild it as described below (the library is only used by the editor / `--path` runs; no exported release build is part of the project).

**Building the library yourself** is only needed if you change the C++ code. The ZIP contains `extern/godot-cpp` (sources only); from the extracted root run `scons` with a C++17 compiler and SCons installed (Python 3: `pip install scons`).

**From the Git repository (build it yourself):**

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

**Tests** (all from the repository root):

```
bash tools/run_core_tests.sh                       # C++ unit tests (g++, no Godot needed)
Godot --headless --path plants-vs-zombies --script res://tests/core_integration_test.gd   # real C++ core through the built DLL
Godot --headless --path plants-vs-zombies --script res://tests/session_test.gd            # username + leaderboard
powershell -File tools/run_godot_tests.ps1 -Godot <Godot.exe>      # every Godot test (incl. tests/audio_test.gd: mower + Squash sounds; tests/death_test.gd: death animations)
powershell -File tools/run_scenarios.ps1 -Godot <Godot.exe>        # menu Quit, menu leaderboard, TICK/PLAY vs keyboard, NEXT/BACK flows, empty after relaunch
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/projectile_test.gd -- <dir>    # pea sprite, impact splat only on real hits
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/behaviour_capture.gd -- <dir> # shake, shovel, pause, boss, seed bank (+ screenshots)
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/final_wave_sequence_test.gd -- <dir> # banner 1 -> banner 2 -> wave-4 spawn, no overlap, pause
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/throw_capture.gd -- <dir>  # Gargantuar throws its Imp (frames)
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/plants_capture.gd -- <dir>  # plant animations
```

### H. Asset classification

All game assets live under `plants-vs-zombies/assets/` (two small source images, `grid.jpg` and `menu.jpg`, also sit in `plants-vs-zombies/`). Many artwork files are **sprite sheets** or reference illustrations; the scripts in `tools/` crop them into the individual sprites, layers and animation frames that Godot loads. The sheets are never edited: *sources* are kept as supplied, the *processed* files are generated from them. Names below are the real file names; "source" = supplied sheet or image, "processed" = cut out, converted or generated by a script in `tools/`.

| Asset category | Directory | Contents / purpose |
|---|---|---|
| Plant assets | `assets/characters/{sunflower,peashooter,jalapeno,squash}/`, `assets/characters/icons/`, `assets/plants/` | **Processed (used):** layered pieces of the plants: `sunflower/{head,stem}.png`, `peashooter/{head,stem}.png`, `jalapeno/jalapeno.png`, 23 Squash animation frames `squash/f00..f59.png`; Seed Bank icons `icons/{sunflower,peashooter,wallnut,jalapeno,squash}.png`; Wall-nut damage images `plants/wall-nut/wallnut_{1,2,3}.png`. `assets/plants/peashooter/parts/` (22 pieces) with `layout.json` and `peashooter_layout.gd` is a part-by-part Peashooter. **Source sheets:** `plants/{sunflower,jalapeno,squash,wall-nut}/*.png`, `plants/peashooter/168191.png` |
| Zombie assets | `assets/characters/{zombie,gargantuar,imp}/` | **Processed (used):** Regular zombie `zombie/{head,body,feet}.png`; Conehead / Buckethead armor in three damage stages `zombie/{cone,bucket}_{1,2,3}.png`; Gargantuar `gargantuar/{body,feet,grip,hand,head,imp_rider,pole}.png`; Imp `imp/{head,body,arm,leg,shoe}.png`. They are cut out of the HD reference images in `assets/references/original_pvz/` by `tools/character_art/`. The Imp's body, arms, legs and shoes are redrawn parts, not crops (see I) |
| Projectile assets | `assets/projectiles/` | **Source:** `Projectiles.png` (sheet of many projectile types, unchanged), `shoot.jpg`. **Processed (used):** `pea/pea.png` (traveling Pea), `pea/splat_1..4.png` and `pea/dot_1..3.png` (impact effect), all taken from the "Pea" block of `Projectiles.png`. `pea_projectile.png` (older crop of `shoot.jpg`) is no longer used |
| Environment assets | `assets/lawn/`, `assets/seed_bank.jpg`, `assets/env/shovel/`, `grid.jpg` | Lawn picture and grid: `lawn/lawngrid-day.png` is the lawn used by the board (`board.tscn`); `grid.jpg` is the supplied source grid; `lawn/lawn_game.jpg` is an older generated lawn (`tools/lawn_art`, unused). Shovel: `env/shovel/Shovel.jpg` (source) and `shovel_cutout.png` (processed, used). `seed_bank.jpg` is the Seed Bank bar; `assets/sưnn.png` is the Sun sprite |
| Lawn Mower assets | `assets/env/lawn_mower/`, `assets/characters/mower/` | **Source:** `env/lawn_mower/lawn_mover_all.png` (sheet; the folder keeps the original spelling of the file name). **Processed (used):** `characters/mower/{body,engine,wheel}.png`, layers that the game assembles so the wheels can spin. `env/lawn_mower/lawn_mower.png` is an older single-image crop (unused). Size and position follow `references/original_pvz/full_lawn_grid_mower.jpg` |
| UI assets | `assets/ui/` | **Source:** `buttons.jpg` (stone button sheet). **Processed (used):** `buttons/{play,quit,pause,tick}.png` cropped from it; `buttons/{next,back,leaderboard}.png` created for this project in the same style (see I); `menu_background.jpg` (from `menu.jpg`, publisher badge removed); `Start_Text.png` ("Ready, Set, Plant!"), `huge_wave_text.png`, `final_wave_text.png` (lettering cut from `A_huge_wave_is_approaching.png` / `final-wave.png`), `Game Over Screen.png`, `seed_packet/SeedPackets.png`. Victory text is drawn in Godot (`stone_title.gd`); the leaderboard is built from Godot controls (`stone_ui.gd`) |
| Audio assets | `assets/audio/` | Music: `menu.ogg`, `gameplay_music.ogg` (converted from the `.m4a` files, which are kept as sources). Effects: `button_click`, `planting`, `peashooter` (pea hit), `sun_collect`, `zombie_eating`, `jalapeno_explosion`, `squash` (Squash cue), `lawn_mower`, `gargantuar_death`, `win`, `lose`, `plants-vs-zombies-ready-set-plant`, and `The zombies are coming Plants vs Zombies Sound Effect` (all `.mp3`). Per-event details and start offsets: `tools/README.md` |
| Reference material | `assets/references/original_pvz/` | HD reference illustrations of the characters (`*.webp`, `zombie_pose.jpg`, `squash_move.gif`) and a full lawn-with-mowers picture. They are the **sources** for the cut-out characters and the visual targets used to size the mowers; they are not loaded by the game |
| Legacy / unused | see below | Older or alternative files that remain in the working repository but are not loaded by the game |

Not loaded by the game and **not packaged in the submission ZIP** (still in the working repository): the older generated zombie sheets in `assets/zombies/`, `assets/lawn/lawn_game.jpg`, `assets/env/lawn_mower/lawn_mower.png`, loose pictures directly in `assets/` (`168191.png`, `chilli.png`, `pea.png`, `sunflower (1).png`, `wallnut (1).png`), and the audio files `brainzzz.mp3`, `choose_plant.m4a`, `zombie_falling_1.ogg`.

### I. Asset sources and credits

**Important.** The game imitates *Plants vs. Zombies* (PopCap Games / Electronic Arts). Most artwork and all sound files in this project were **supplied by the team from outside sources** and are *not* our own work. The project files do not record where each file was downloaded from or under which licence. Therefore, for every such asset the entry is **Source/license not yet verified**; nothing here claims that these assets are original or freely licensed. They are included in the submission ZIP only so the game can be assessed. Because their licence is not cleared, `.gitignore` keeps the audio, lawn, UI and projectile images out of the public Git repository (see the comment in `.gitignore`).

| Asset (directory) | Origin as far as the project shows | Status |
|---|---|---|
| Character illustrations in `assets/references/original_pvz/` (Sunflower, Peashooter, Jalapeno, Squash, Gargantuar, Imp, Conehead, Buckethead, zombie pose, Lawn Mower, `squash_move.gif`, `full_lawn_grid_mower.jpg`) | *Plants vs. Zombies* artwork supplied by the team (file names: `*_Zombie.webp`, `Lawn_Mower.webp`, ...) | **External / reference.** Source/license not yet verified |
| `assets/characters/{sunflower,peashooter,jalapeno,squash,zombie,gargantuar}`, `characters/icons` | Cropped / layered derivatives of the references above, made by `tools/character_art/` | **Cropped derivative** of unverified-licence art |
| `assets/characters/imp/{body,arm,leg,shoe}.png` | Drawn for this project with a script (`tools/character_art/imp_parts.py`) in the colours of the reference; the reference has no Imp legs. `imp/head.png` is a crop of the Gargantuar reference | **Created for this project** (body, arms, legs, shoes) + cropped head |
| `assets/plants/{sunflower,jalapeno,squash,wall-nut}`, `plants/peashooter/168191.png` | Supplied sprite sheets of the plants. `plants/wall-nut/wallnut_{1,2,3}.png` and `characters/icons/wallnut.png` are the Wall-nut art, for which there is no HD reference; `wallnut_1.png` (and the icon copy) were hand-edited by the team to remove a thin blue frame | **External.** Source/license not yet verified |
| `assets/projectiles/Projectiles.png`, `shoot.jpg` and the extracted `pea/*.png` | Supplied projectile sheet / image; `pea/*` are crops of the "Pea" block of `Projectiles.png` | **External + cropped derivative.** Source/license not yet verified |
| `assets/env/lawn_mower/lawn_mover_all.png` and `characters/mower/*` | Supplied mower sheet; the three layers are crops of its "Lawn Mower" block | **External + cropped derivative.** Source/license not yet verified |
| `assets/env/shovel/Shovel.jpg`, `shovel_cutout.png`; `assets/lawn/lawngrid-day.png`; `grid.jpg`; `assets/seed_bank.jpg`; `assets/sưnn.png` (Sun sprite) | Supplied images; `shovel_cutout.png` is a processed copy of `Shovel.jpg` | **External.** Source/license not yet verified |
| `assets/ui/buttons.jpg` and `buttons/{play,quit,pause,tick}.png` | Supplied pixel-art "stone" button sheet; the four PNGs are crops of it (`tools/ui_art/prepare_ui_assets.py`) | **External + cropped derivative.** Source/license not yet verified |
| `assets/ui/buttons/{next,back,leaderboard}.png` | Generated by `tools/ui_art/make_nav_buttons.py` from `quit.png`: the QUIT letters are painted over and new letters are drawn in the same colour and pixel grid | **Created for this project**, derived from a crop of the button sheet |
| `assets/ui/menu_background.jpg` (from `menu.jpg`), `Start_Text.png`, `Game Over Screen.png`, `A_huge_wave_is_approaching.png`, `final-wave.png`, `huge_wave_text.png`, `final_wave_text.png`, `seed_packet/SeedPackets.png` | Supplied title / banner / seed-packet pictures; `menu_background.jpg` is `menu.jpg` with the publisher badge removed; the two `*_text.png` are lettering cut out of the supplied banners | **External, partly modified.** Source/license not yet verified |
| `assets/audio/*` | Supplied sound files; the two music `.ogg` files are conversions of the supplied `.m4a` files | **External.** Source/license not yet verified |
| `assets/zombies/*` (older generated sheets, not packaged) | Drawn procedurally by `tools/zombie_art/generate_zombies.py` (its README states no game sprite was used) | **Created for this project**, but no longer used by the game |
| Code (C++ `src/`, `test/`, GDScript, `tools/`) | Written by the team; the C++ core, UI scripts and tests were extended with the help of an AI coding assistant (Claude Code) | Team project; **godot-cpp** (MIT licence, see `extern/godot-cpp/LICENSE.md`) and the **Godot Engine** (MIT) are third-party |

If you can identify the original source and licence of an asset above, replace its "Source/license not yet verified" entry.

### J. Testing and known limitations

**Automated tests that exist** (commands in [G. How to run](#g-how-to-run)):

| Test | What it covers | Last result |
|---|---|---|
| `tools/run_core_tests.sh` (5 C++ programs in `test/`) | waves and spawning, zombie movement and armor, visual state, Squash (jump, single use, alert / cancel, other rows), Jalapeno | all pass |
| `tests/core_integration_test.gd` | the real C++ core through the built DLL (economy, plants, zombies, waves, mowers, scoring, signals) | 93 checks, 0 failures |
| `tests/session_test.gd` | username validation, one entry per username, restart updates the same entry, Back keeps the name taken, ranking, no disk writes | 34 / 0 |
| `tests/behaviour_capture.gd`, `final_wave_sequence_test.gd`, `projectile_test.gd`, `throw_capture.gd`, `plants_capture.gd` (windowed) | screen shake, shovel, pause, boss; final-wave announcement order; pea sprite and impact only on real hits; Gargantuar throwing the Imp; plant animations | 31 / 13 / 10 / 3 / 4 checks, 0 failures |
| `tests/audio_test.gd` (windowed) | Lawn Mower and Squash sound start / stop / no duplicates / pause; Squash silent when planted and for other rows | 24 / 0 |
| `tests/death_test.gd` (windowed) | head-off death for Regular / Conehead / Buckethead / Imp, helmet handling, stronger Lawn Mower throw, Jalapeno / Squash / Gargantuar keep the plain fall, pause, clean-up, no Victory delay | 38 / 0 |
| `tools/run_scenarios.ps1` | real mouse and key events through the menus in separate processes: Quit, leaderboard and Back, Tick vs keyboard Enter vs Play, Victory / Game Over -> Next -> Back, two matches, empty after relaunch | 16 checks, 0 failures |

The suites were last run together on the developer's Windows machine against the Godot 4.7.2-stable editor and the debug DLL. The screenshots they save are for human inspection.

**Features checked by running the game:** menu flow, username rules, a full Victory and a Game Over, leaderboard ordering, Lawn Mower size and activation, Squash attack, pea impact, Imp throw.

**Known limitations**
- **Platform:** only Windows x86_64 and a *debug* library were built and tested; no exported/release build exists. Other operating systems are untested.
- **Audio:** the sounds were verified through the game's playback state and signals (a voice starts and stops at the right moment, no duplicates), not by listening; volume levels are estimates. The Squash cue is a short 0.4 s clip played when a zombie comes near, so it can end before a slow zombie reaches jump range.
- **Leaderboard:** it exists only while the application runs (by design); closing the game clears it. A name that already has an entry is rejected for the rest of the run, even after Back; only Restart reuses it. Quitting through Pause -> Quit before a match ends creates no entry, so that name stays free. The entry holds the *latest* result of a player's replays (a worse replay replaces a better one).
- **Art:** the Imp's arms and legs are thin simple drawings; the Wall-nut has no HD reference; the Next / Back / Leaderboard button lettering is redrawn pixel art slightly thinner than the original QUIT; hover / pressed states are tints because the sheet has one state.
- **Asset licences are not verified** (see I). Do not redistribute this package.
- Gameplay was tested at 1152 × 648 (the project window size); the menu was also checked at 960 × 540 and 1920 × 1080.
- The `.godot/` import cache is not packaged; Godot rebuilds it on first open.
- GitHub Issues: when this package was prepared, the public GitHub API reported **no Issues** (open or closed) for the repository `trnbngocc/Team-2-Plants-Vs-Zombies`, so there was nothing to update; the unresolved asset source / licence questions in section I are tracked here and should be opened as Issues by the team (no GitHub access was available to create them).

### K. How to study the project

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

### L. Team and credits

- **Team 2:**
  - **Core Architecture & C++ Game Core:** trnbngocc
  - **Plant Modules:** BunBo-0920
  - **Zombie Modules:** lehoangthaovia-code
  - **UI & Presentation (GDScript):** bolhouuu114

### M. Disclaimer

This repository is an educational, non-commercial student project. If you have any questions, please feel free to open an issue.

---

## Tiếng Việt

> **Lưu ý:** phần tiếng Anh ở trên là bản cập nhật đầy đủ và chính xác nhất (tổng quan, cấu trúc, phân loại asset, nguồn/credits, kiểm thử và hạn chế). Phần tiếng Việt dưới đây là bản gốc, một số chi tiết về menu / leaderboard đã cũ: hiện nay username được xác nhận bằng nút **Tick** trên màn hình (phím Enter không có tác dụng), nút **Play** bắt đầu ván chơi, màn Leaderboard chỉ có nút **Back**, và leaderboard chỉ tồn tại trong phiên chạy (không lưu ra đĩa).

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
| Kế thừa | `Plant`, `Zombie` và `Bullet` kế thừa `Entity`; `Peashooter`, `Sunflower`, `WallNut`, `Jalapeno` kế thừa `Plant` |
| Đa hình | hàm ảo `Entity::update()`, `Entity::get_type()`, `Entity::receive_damage()` (giáp của zombie ghi đè hàm này), `Plant::act()` |
| Đóng gói | các hằng số cân bằng là thành viên `static constexpr` private của từng lớp |
| Quản lý sở hữu và bộ nhớ | `GameController` sở hữu mọi thực thể trong `std::vector<std::unique_ptr<Entity>>`; thực thể sinh ra khi đang duyệt được hoãn lại (`pending_entities`) |
| Vòng lặp game và máy trạng thái | `GameController::_process()` → `update_entities()`; các trạng thái SETUP / PLAYING / PAUSED / VICTORY / DEFEAT |
| Va chạm và chiến đấu | `GameController::resolve_bullet_collisions()`; giáp hấp thụ sát thương trong `Zombie::receive_damage()`; hiệu ứng trạng thái trong `Entity` |
| Cấu trúc dữ liệu | `Grid` (mảng cố định 5 × 9), vector thực thể, danh sách Sun rơi, bảng cấu hình wave |
| Sự kiện và giao diện | signal của Godot do lõi phát ra (`plant_placed`, `placement_rejected`, `projectile_fired`, `projectile_hit`, `jalapeno_exploded`) và được xử lý trong GDScript |
| Tách logic và hiển thị | lõi C++ không bao giờ vẽ; `main_game.gd` chỉ đọc dữ liệu và gọi hàm của lõi |
| Tài nguyên và công cụ | chuẩn bị tài nguyên bằng script trong `tools/` (cắt ảnh, xoá nền, chuyển đổi âm thanh, sinh sprite bằng code) |
| Kiểm thử | unit test C++ độc lập trong `test/` |
| Git và làm việc nhóm | tự viết code module riêng và gửi để team lead tổng hợp/up lên repository |

### C. Các tính năng

- Main Menu có **ô nhập username và nút ENTER**: nhập tên rồi bấm nút Tick (không dùng phím Enter) để xác nhận. Tên được cắt khoảng trắng, dài 1-16 ký tự, kiểm tra trùng không phân biệt hoa thường với leaderboard ("Username already exists"). Thông báo xanh "Username accepted" xác nhận thành công; nút Play chỉ hoạt động với tên đã xác nhận.
- Màn "Ready... Set... PLANT!" (chữ nảy + âm thanh). 30 giây chuẩn bị và các wave chỉ bắt đầu sau khi màn này kết thúc.
- Bốn wave, tổng 25 kẻ địch. Trước wave cuối: biểu ngữ "A huge wave of zombies is approaching!" (4 giây), rồi biểu ngữ "Final Wave" (3 giây), và chỉ sau đó zombie wave 4 mới xuất hiện. Wave cuối có boss **Gargantuar** với thanh máu riêng.
- Năm loại cây trong Seed Bank mới (hình thẻ, tên, giá Sun, tối đi khi không đủ Sun, sáng khung khi được chọn): Peashooter, Sunflower, Wall-nut, Jalapeno và Squash.
  - Ô đã có cây: hiện thông báo "CANNOT PLANT HERE!".
  - Không đủ Sun: hiện thông báo "NOT ENOUGH SUN! / NEED x SUN".
- Hoa hướng dương tạo Sun **rơi từ trên xuống** một vị trí ngẫu nhiên trên bãi cỏ; bấm để thu thập.
- **Xẻng** (ô xẻng có sẵn ở thanh trên; cây xẻng đi theo con trỏ khi đang chọn) gỡ cây ở ô được bấm (không hoàn Sun).
- Mỗi hàng có một **máy cắt cỏ**: chạy một lần và quét sạch zombie trong hàng. Zombie tới cuối hàng khi máy cắt đã dùng sẽ kết thúc ván.
- Squash nhảy lên đập zombie phía trước và làm rung màn hình ngắn khi chạm đất.
- Zombie: thường, Conehead (có nón), Buckethead (có xô), Gargantuar (boss) và Imp do nó ném. Tất cả được ghép từ các mảnh rời trong `Regular_Zombies.png` / `zombie_Gargantuar.png` (hai sheet này không có frame hoạt ảnh nên chuyển động được tạo bằng mã). Nón và xô có ba trạng thái hư hỏng và bay ra khi bị phá.
- Hình cây lấy từ các sheet có sẵn: Sunflower ghép từ mặt, cánh hoa và lá; Wall-nut đổi sang hình nứt khi bị thương; Jalapeno dùng hình đầy đủ trong sheet (có mắt và miệng). `python tools/plant_art/build_assets.py` tạo lại mọi ảnh dẫn xuất.
- Màn Victory và Game Over (ảnh Game Over là ảnh "The Zombies Ate Your Brains!" có sẵn) với nút **Next** mở **Leaderboard** (username, điểm, Victory / Defeat; chỉ lưu trong bộ nhớ khi game đang chạy). Màn Leaderboard chỉ có nút Back (về menu).
- Pause (Resume / Quit về menu) làm đứng hình toàn bộ màn hình.
- Nhạc và hiệu ứng âm thanh, gồm tiếng Squash đập, âm Start Text và tiếng Gargantuar chết.
- Bãi cỏ co giãn theo kích thước cửa sổ.

### D. Cơ chế trò chơi

Mọi giá trị lấy từ mã nguồn C++.

**Bắt đầu:** 50 Sun, rồi màn giới thiệu, rồi 30 giây chuẩn bị trước wave đầu tiên.

| Cây | Giá | Máu | Hoạt động |
|---|---|---|---|
| Sunflower | 50 | 100 | Tạo 25 Sun mỗi 5 giây (rơi từ trên xuống). Sun không được nhặt sẽ biến mất 10 giây sau khi chạm cỏ. |
| Peashooter | 100 | 300 | Bắn một viên đậu mỗi 1,4 giây khi có zombie cùng hàng ở phía trước. Mỗi viên gây đúng 20 sát thương và bay 5 ô/giây. |
| Wall-nut | 50 | 600 | Chặn zombie. "Last stand": lần đầu máu còn 25 % trở xuống, giảm 50 % sát thương nhận vào trong 5 giây. |
| Jalapeno | 125 | 300 | Sau 2 giây đếm ngược, nổ và gây 900 sát thương cho mọi zombie cùng hàng. |
| Squash | 50 | 300 | Dùng một lần. Khi có zombie trong khoảng 1,5 ô phía trước cùng hàng, nó nhảy (0,5 giây) rồi đập 1800 sát thương quanh điểm hạ cánh. |

| Kẻ địch | Giáp | Máu thân | Tổng |
|---|---|---|---|
| Thường | – | 200 | 200 |
| Conehead | 370 | 200 | 570 |
| Buckethead | 1100 | 200 | 1300 |
| Gargantuar (boss) | – | 2000 | 2000 |
| Imp | – | 100 | 100 |

Giáp nhận sát thương trước; phần dư trừ vào máu thân (400 sát thương lên Conehead = 370 giáp + 30 máu thân). Zombie thường đi một cột mỗi 4,7 giây và cắn 10 sát thương mỗi giây. Gargantuar đi một cột mỗi 9,4 giây và đập cây 300 mỗi 1,5 giây. Imp đi một cột mỗi 2,8 giây.

**Gargantuar:** khi máu còn 1000 trở xuống nó ném **đúng một Imp** (đứng yên 1 giây khi ném). Sát thương luôn đi qua đường xử lý thông thường: Jalapeno (900) và Squash (1800) không giết được Gargantuar còn đầy máu trong một đòn.

**Các wave (tổng 25 kẻ địch):**

| Wave | Số kẻ địch | Khoảng cách xuất hiện | Loại |
|---|---|---|---|
| 1 | 3 | 10 giây | Thường |
| 2 | 5 | 5 giây | Thường hoặc Conehead |
| 3 | 7 | 5 giây | Thường, Conehead hoặc Buckethead |
| 4 | 10 | 5 giây | đúng 4 Thường, 3 Conehead, 2 Buckethead và 1 Gargantuar: 3 zombie thường đầu tiên, rồi Gargantuar, rồi 6 zombie còn lại |

- Giữa hai wave nghỉ 3 giây, và 7 giây trước wave cuối: "A huge wave..." hiện khi khoảng nghỉ này bắt đầu (4 giây), "Final Wave" nối tiếp (3 giây), rồi wave 4 bắt đầu. Chuỗi này chạy theo đồng hồ game nên Pause làm nó dừng lại.
- Mỗi kẻ địch vào một hàng ngẫu nhiên, xuất hiện ngay ngoài mép phải bãi cỏ.

**Máy cắt cỏ:** mỗi hàng một cái, kích hoạt khi zombie tới mép trái bãi cỏ. Zombie thường và Imp trong hàng bị quét sạch. Gargantuar thì không: nó nhận 400 sát thương và bị đẩy lùi 2 cột, máy cắt đó hết lượt.

**Thắng và thua:**

- **Thắng:** cả 25 kẻ địch đã xuất hiện và không còn ai sống (kể cả Gargantuar và Imp).
- **Thua:** có zombie đi qua mép trái của một hàng mà máy cắt đã dùng hết. Điều kiện thua được kiểm tra trước.
- **Điểm:** Thắng = tổng Sun đã thật sự tiêu để trồng cây trong ván (Sun còn lại không tính, xẻng không hoàn Sun); Thua = 0. Leaderboard xếp mọi ván Thắng lên trước (tiêu ít Sun hơn xếp cao hơn), rồi tới các ván Thua.

### E. Cấu trúc dự án

```
SConstruct                 script build thư viện GDExtension C++ (SCons)
extern/godot-cpp/          thư viện godot-cpp (git submodule)
src/                       lõi game C++
  entity.*                 lớp cơ sở: máu, vị trí, hiệu ứng trạng thái
  plant.*, peashooter.*, sunflower.*, wallnut.*, jalapeno.*, squash.*
  gargantuar.*, imp.*      boss và Imp do nó ném; lawn_mower.hpp = máy cắt cỏ mỗi hàng
  zombie.*                 di chuyển, ăn cây, giáp
  bullet.*, grid.*, sun_economy.*, status_effect.hpp
  wave_manager.*           thời gian chuẩn bị, wave, sinh zombie
  game_controller.*        node Godot sở hữu và cập nhật mọi thứ
  pvz_library_init.cpp     đăng ký GameController với Godot
test/                      unit test C++ độc lập (di chuyển zombie, giáp, wave, Squash, Jalapeno, máy cắt cỏ)
plants-vs-zombies/         dự án Godot
  project.godot            cấu hình; scene khởi động = scenes/menu.tscn; autoload Audio và Session
  scenes/menu.tscn         Main Menu        (main_menu.gd)
  scenes/main.tscn         GameController + giao diện trận đấu (MainGame.tscn)
  MainGame.tscn            bãi cỏ, HUD, lớp phủ pause / victory / game over (main_game.gd)
  board.tscn / board.gd    ảnh bãi cỏ + 45 ô bấm, co giãn theo cửa sổ
  hud.tscn, seed_bank.tscn, sun_display.tscn, pause_button.tscn
  win_screen.tscn, lose_screen.tscn
  main_game.gd             hiển thị: đọc dữ liệu lõi mỗi frame, vẽ cây/zombie/đạn/Sun
  zombie_view.gd           hoạt ảnh zombie + thanh máu
  peashooter_view.gd       Peashooter ghép từ các mảnh, hoạt ảnh idle/bắn
  jalapeno_fire.gd         hiệu ứng lửa (chỉ hình) khi Jalapeno nổ
  puppet_zombie.gd         Gargantuar / Imp ghép từ các mảnh rời trong assets/zombies/{gargantuar,imp}
  session.gd               autoload: kiểm tra username + leaderboard trong bộ nhớ (theo phiên)
  leaderboard.gd           màn Leaderboard (scenes/leaderboard.tscn): chỉ nút Back
  stone_ui.gd              nút / ô nhập kiểu đá dựng bằng control của Godot
  tests/                   script kiểm thử Godot (headless và có cửa sổ)
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

**Kiểm thử** (chạy từ thư mục gốc của repository):

```
bash tools/run_core_tests.sh                       # unit test C++ (g++, không cần Godot)
Godot --headless --path plants-vs-zombies --script res://tests/core_integration_test.gd   # lõi C++ thật qua DLL đã build
Godot --headless --path plants-vs-zombies --script res://tests/session_test.gd            # username + leaderboard
powershell -File tools/run_scenarios.ps1 -Godot <Godot.exe>        # luồng menu -> ván -> kết quả -> leaderboard (xem phần tiếng Anh, mục J)
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/behaviour_capture.gd -- <thư mục> # rung màn hình, xẻng, pause, boss, seed bank (+ ảnh chụp)
Godot --path plants-vs-zombies --windowed --resolution 1152x648 --script res://tests/final_wave_sequence_test.gd -- <thư mục> # banner 1 -> banner 2 -> wave 4, không chồng nhau, pause
```

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

#pragma once

namespace pvz {

// Lawn Mower: tuyến phòng thủ cuối của MỖI hàng, dùng đúng một lần.
// Chỉ chứa trạng thái + chuyển động; GameController quyết định kích hoạt và va chạm.
class LawnMower {
public:
    enum class State {
        READY,    // đang chờ ở mép trái hàng
        RUNNING,  // đang lao qua hàng
        USED      // đã dùng, không còn nữa
    };

    // ---- Thông số cân bằng (chỉnh ở đây) ----
    static constexpr float START_COLUMN   = -0.7f;  // đứng ngoài mép trái Grid (cột 0)
    static constexpr float END_COLUMN     = 10.5f;  // chạy quá mép phải thì biến mất
    static constexpr float SPEED          = 7.0f;   // cột / giây
    static constexpr float TRIGGER_COLUMN = 0.45f;  // Zombie tới cột này thì kích hoạt

    // Va chạm: Zombie bị trúng khi column nằm trong [mower - BEHIND, mower + AHEAD].
    static constexpr float HIT_BEHIND     = 1.0f;
    static constexpr float HIT_AHEAD      = 0.8f;

    // Boss không bị giết tức thì: nhận sát thương cố định + bị đẩy lùi, mower hết lượt.
    static constexpr int   BOSS_DAMAGE    = 400;
    static constexpr float BOSS_KNOCKBACK = 2.0f;   // cột

    explicit LawnMower(int row = 0) : row(row) {}

    void activate() {
        if (state == State::READY) {
            state = State::RUNNING;
        }
    }

    void finish() { state = State::USED; }

    void update(double delta_seconds) {
        if (state != State::RUNNING) {
            return;
        }
        column += SPEED * static_cast<float>(delta_seconds);
        if (column > END_COLUMN) {
            state = State::USED;
        }
    }

    State get_state() const { return state; }
    int   get_row() const { return row; }
    float get_column() const { return column; }

private:
    int   row;
    float column = START_COLUMN;
    State state = State::READY;
};

} // namespace pvz

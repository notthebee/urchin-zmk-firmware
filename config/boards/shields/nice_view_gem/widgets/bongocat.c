#include <zephyr/kernel.h>
#include <zephyr/sys/util.h>

#include "bongocat.h"
#include "../assets/bongocatart.h"

#define BONGOCAT_HEIGHT 40
// Average WPM of the last 5 samples above which the cat goes into furious mode.
#define BONGOCAT_FURIOUS_WPM 70

enum idle_frame { IDLE_INHALE, IDLE_REST_1, IDLE_EXHALE, IDLE_REST_2 };

static const lv_img_dsc_t *const idle_frames[] = {&bongo_inhale, &bongo_resting, &bongo_exhale,
                                                 &bongo_resting};

static enum idle_frame idle_frame_index;
static bool key_pressed;
static bool paw_left;
// Written from the event thread, read from the display queue: 32-bit so the read can't be torn,
// and wrap-safe comparison. ponytail: single writer, no lock needed.
static uint32_t strike_until;

static bool is_furious(const struct status_state *state) {
    int recent_wpm = 0;
    for (int i = 5; i < 10; i++) {
        recent_wpm += state->wpm[i];
    }
    return recent_wpm / 5 > BONGOCAT_FURIOUS_WPM;
}

void draw_bongocat_status(lv_obj_t *canvas, const struct status_state *state) {
    bool furious = is_furious(state);
    const lv_img_dsc_t *frame;

    if (bongocat_strike_active()) {
        if (furious) {
            frame = paw_left ? &bongo_furiousdown : &bongo_furiousup;
        } else {
            frame = paw_left ? &bongo_casualleft : &bongo_casualright;
        }
    } else {
        frame = furious ? &bongo_resting : idle_frames[idle_frame_index];
    }

    lv_draw_img_dsc_t img_dsc;
    lv_draw_img_dsc_init(&img_dsc);
    lv_canvas_draw_img(canvas, 0, (BUFFER_SIZE - BONGOCAT_HEIGHT) / 2, frame, &img_dsc);
}

void bongocat_set_key_pressed(bool pressed) {
    if (pressed && !key_pressed) {
        paw_left = !paw_left;
        strike_until = k_uptime_get_32() + BONGOCAT_STRIKE_MS;
    } else if (!pressed) {
        // Land on the resting frame, then resume the breathing cycle from there.
        idle_frame_index = IDLE_REST_1;
    }
    key_pressed = pressed;
}

bool bongocat_strike_active(void) {
    return key_pressed || (int32_t)(k_uptime_get_32() - strike_until) < 0;
}

void bongocat_idle_tick(void) {
    if (key_pressed) {
        return;
    }
    idle_frame_index = (idle_frame_index + 1) % ARRAY_SIZE(idle_frames);
}

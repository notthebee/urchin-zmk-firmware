#pragma once

#include <lvgl.h>
#include "util.h"

// Breathing cycles through one frame every BONGOCAT_IDLE_MS while no key is held.
#define BONGOCAT_IDLE_MS 750
// Minimum time a paw frame stays on screen. Redraws coalesce when typing fast, so a
// press/release pair can collapse into a single redraw; without this hold the strike
// would often never be drawn.
#define BONGOCAT_STRIKE_MS 90

struct key_status_state {
    bool pressed;
};

void draw_bongocat_status(lv_obj_t *canvas, const struct status_state *state);
void bongocat_set_key_pressed(bool pressed);
bool bongocat_strike_active(void);
void bongocat_idle_tick(void);

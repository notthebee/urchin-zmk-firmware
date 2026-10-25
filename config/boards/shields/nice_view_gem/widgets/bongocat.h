#pragma once

#include <lvgl.h>
#include "util.h"

// Breathing cycles through one frame every BONGOCAT_IDLE_MS while no key is held.
#define BONGOCAT_IDLE_MS 750

struct key_status_state {
    bool pressed;
};

void draw_bongocat_status(lv_obj_t *canvas, const struct status_state *state);
void bongocat_set_key_pressed(bool pressed);
void bongocat_idle_tick(void);

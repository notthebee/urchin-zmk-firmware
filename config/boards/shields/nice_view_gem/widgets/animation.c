#include <zephyr/kernel.h>
#include <zephyr/random/random.h>
#include <zephyr/sys/util.h>

#include "animation.h"

// Corro the sea urchin, 12 frames at 140x68 (pre-rotated for the vertical mount).
// Art from https://github.com/Merlinov/niceview-peripheral-animation
LV_IMG_DECLARE(corro01);
LV_IMG_DECLARE(corro02);
LV_IMG_DECLARE(corro03);
LV_IMG_DECLARE(corro04);
LV_IMG_DECLARE(corro05);
LV_IMG_DECLARE(corro06);
LV_IMG_DECLARE(corro07);
LV_IMG_DECLARE(corro08);
LV_IMG_DECLARE(corro09);
LV_IMG_DECLARE(corro10);
LV_IMG_DECLARE(corro11);
LV_IMG_DECLARE(corro12);

static const lv_img_dsc_t *const anim_imgs[] = {
    &corro01, &corro02, &corro03, &corro04, &corro05, &corro06,
    &corro07, &corro08, &corro09, &corro10, &corro11, &corro12,
};

void draw_animation(lv_obj_t *parent) {
    lv_obj_t *art;

#if IS_ENABLED(CONFIG_NICE_VIEW_GEM_ANIMATION)
    art = lv_animimg_create(parent);
    lv_animimg_set_src(art, (const void **)anim_imgs, ARRAY_SIZE(anim_imgs));
    lv_animimg_set_duration(art, CONFIG_NICE_VIEW_GEM_ANIMATION_MS);
    lv_animimg_set_repeat_count(art, LV_ANIM_REPEAT_INFINITE);
    lv_animimg_start(art);
#else
    art = lv_img_create(parent);
    lv_img_set_src(art, anim_imgs[sys_rand32_get() % ARRAY_SIZE(anim_imgs)]);
#endif

    // Pre-rotated art starts at the low-x end of the display; the status canvas sits at the
    // other end, so nothing overlaps.
    lv_obj_align(art, LV_ALIGN_TOP_LEFT, 0, 0);
}

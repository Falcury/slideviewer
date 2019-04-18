#pragma once
#include "common.h"


typedef struct image_t {
	u8* data;
	i32 width;
	i32 height;
	i32 pitch;
	i32 bpp;
} image_t;

typedef struct texture_t {
	u32 texture;
	i32 width;
	i32 height;
} texture_t;

typedef struct rect2i {
	i32 x, y, w, h;
} rect2i;

typedef struct v2i {
	i32 x, y;
} v2i;
#define V2i(x, y) (v2i){(x), (y)}

typedef struct v2f {
	float x, y;
} v2f;

typedef struct v3f {
	union {
		struct {float r, g, b; };
		struct {float x, y, z; };
	};
} v3f;

typedef struct v4f {
	union {
		struct {float r, g, b, a; };
		struct {float x, y, z, w; };
	};
} v4f;

typedef struct {
	bool8 down;
	u8 transition_count;
} button_state_t;

typedef struct {
	bool32 is_connected;
	bool32 is_analog;
	float x_start, y_start;
	float x_min, y_min;
	float x_max, y_max;
	float x_end, y_end; // end state
	union {
		button_state_t buttons[16];
		struct {
			button_state_t move_up;
			button_state_t move_down;
			button_state_t move_left;
			button_state_t move_right;
			button_state_t action_up;
			button_state_t action_down;
			button_state_t action_left;
			button_state_t action_right;
			button_state_t left_shoulder;
			button_state_t right_shoulder;
			button_state_t start;
			button_state_t back;
			button_state_t button_a;
			button_state_t button_b;
			button_state_t button_x;
			button_state_t button_y;

			// NOTE: add buttons above this line
			// cl complains about zero-sized arrays, so this the terminator is a full blown button now :(
			button_state_t terminator;
		};
	};
	button_state_t keys[256];
} controller_input_t;

typedef struct {
	button_state_t mouse_buttons[5];
	i32 mouse_z;
	v2i dmouse_xy;
	v2i drag_start_xy;
	v2i drag_vector;
	v2i mouse_xy;
	float delta_t;
	union {
		controller_input_t abstract_controllers[5];
		struct {
			controller_input_t keyboard;
			controller_input_t controllers[4];
		};
	};

} input_t;

#define TILE_DIM 512
#define BYTES_PER_PIXEL 4
#define TILE_PITCH (TILE_DIM * BYTES_PER_PIXEL)
#define WSI_BLOCK_SIZE (TILE_DIM * TILE_DIM * BYTES_PER_PIXEL)

typedef struct {
	i64 capacity;
	u32 capacity_in_blocks;
	u32 blocks_in_use;
	u8* data;
} slide_memory_t;

typedef struct {
	slide_memory_t slide_memory;
} viewer_t;

typedef struct {
	u32 block;
	u32 texture;
} wsi_tile_t;

typedef struct {
	i64 width;
	i64 height;
	i64 width_in_tiles;
	i64 height_in_tiles;
	i32 num_tiles;
	wsi_tile_t* tiles;
} wsi_level_t;

#define WSI_MAX_LEVELS 16

typedef struct {
	i64 width;
	i64 height;
	i64 width_pow2;
	i64 height_pow2;
	i32 num_levels;
	openslide_t* osr;
	const char* barcode;
	float mpp_x;
	float mpp_y;

	wsi_level_t levels[WSI_MAX_LEVELS];
} wsi_t;



typedef struct {
	bool32 active;
	i32 type;
	v2i pos;
	image_t* image;
} entity_t;

// globals

extern viewer_t global_viewer;

// viewer.c

void first();
void viewer_update_and_render(input_t* input, i32 client_width, i32 client_height);
void on_file_dragged(char* filename);
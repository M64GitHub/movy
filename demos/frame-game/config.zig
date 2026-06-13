//! All tuning constants in one place. Physics is in sub-pixel units
//! (SUB per pixel) so movement is smooth without floats in the hot path.

const std = @import("std");

// ---------------------------------------------------------------- view / timing
pub var view_w: i32 = 120; // logical pixels (== terminal columns); set at startup
pub const MIN_VIEW_W: i32 = 80;
pub const MAX_VIEW_W: i32 = 150;
pub const VIEW_H: i32 = 68; // logical pixel rows (34 terminal lines; 2 px/cell)
pub const HUD_H: i32 = 4; // top HUD strip, in pixels
pub const PLAY_H: i32 = VIEW_H - HUD_H; // play area height in px
pub const FPS: u64 = 60;
pub const FRAME_NS: u64 = std.time.ns_per_s / FPS;

// ---------------------------------------------------------------- world
pub const TILE: i32 = 5; // tile size in pixels
pub const SUB: i32 = 256; // sub-pixel fixed-point units per pixel

// ---------------------------------------------------------------- player physics
// (all velocities/accelerations are in sub-px units)
pub const P_W: i32 = 4; // hitbox width px
pub const P_H: i32 = 8; // hitbox height px
pub const P_ACCEL: i32 = 46; // ground acceleration
pub const P_AIR_ACCEL: i32 = 32;
pub const P_MAX_RUN: i32 = 346; // ~1.35 px/frame
pub const P_FRICTION_NUM: i32 = 210; // grounded, no input: vx *= 210/256
pub const P_AIR_DRAG_NUM: i32 = 238; // airborne drift
pub const P_JUMP_V: i32 = -616; // ~2.4 px/frame up
pub const P_GRAV_UP: i32 = 41; // gravity while rising
pub const P_GRAV_DOWN: i32 = 52; // gravity while falling (heavier = snappy)
pub const P_MAX_FALL: i32 = 717; // terminal velocity
pub const COYOTE_FRAMES: u8 = 6; // jump grace after leaving a ledge
pub const JUMP_BUFFER_FRAMES: u8 = 7; // jump grace pressed before landing
pub const STOMP_BOUNCE_V: i32 = -470; // bounce after stomping an enemy
pub const INVULN_FRAMES: u32 = 90; // i-frames after taking a hit

// ---------------------------------------------------------------- input hold-windows
// Legacy terminals send NO key-release events: a held key is a stream of
// autorepeats. We keep a key "held" for a window of frames, refreshed by each
// repeat - long on the first press (covers the OS initial-repeat delay), short
// on subsequent repeats. (With the kitty protocol we get real Press/Release.)
pub const KEY_FRESH_FRAMES: u8 = 32; // ~530ms
pub const KEY_REPEAT_FRAMES: u8 = 13; // ~215ms

// ---------------------------------------------------------------- camera
pub const SHAKE_DECAY: f32 = 0.90;

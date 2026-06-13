//! Input with two modes:
//!
//! Legacy (default): terminals report NO key releases, so each held key is a
//! stream of autorepeats. We keep a key "held" for a window of frames,
//! refreshed by each repeat - long on a fresh press (covers the OS initial-
//! repeat delay), short on repeats. "Release" = the stream simply stopping.
//!
//! Kitty (requires a kitty-keyboard-protocol terminal + movy support): real
//! Press/Repeat/Release events. Held = until Release, with a long decay as a
//! stuck-key safety net (Repeats keep refreshing it).
//!
//! The pattern: held movement uses timers (leftHeld()/etc.), one-shot actions
//! (pause/restart/confirm/quit) are booleans set on Press and cleared each
//! newFrame(), and jump uses a small buffer so a press just before landing
//! still fires.

const std = @import("std");
const movy = @import("movy");
const cfg = @import("config.zig");

const KITTY_HOLD: u8 = 255; // refreshed by repeats; decays if a release is lost

pub const Input = struct {
    kitty: bool = false,

    // held timers (frames remaining)
    left: u8 = 0,
    right: u8 = 0,
    down: u8 = 0,
    jump_hold: u8 = 0,
    action: u8 = 0,

    // edges / one-shot (consumed each frame)
    jump_buf: u8 = 0, // jump press buffer (consumed by the player)
    pause: bool = false,
    restart: bool = false,
    confirm: bool = false, // space/enter on menus
    quit: bool = false,

    /// Call once per frame BEFORE feeding this frame's events.
    pub fn newFrame(self: *Input) void {
        self.left -|= 1;
        self.right -|= 1;
        self.down -|= 1;
        self.jump_hold -|= 1;
        self.action -|= 1;
        self.jump_buf -|= 1;
        self.pause = false;
        self.restart = false;
        self.confirm = false;
        // note: do NOT clear quit here - it latches until handled
    }

    fn hold(timer: *u8) void {
        timer.* = if (timer.* > 0) cfg.KEY_REPEAT_FRAMES else cfg.KEY_FRESH_FRAMES;
    }

    fn holdKey(self: *Input, timer: *u8, release: bool) void {
        if (self.kitty) {
            timer.* = if (release) 0 else KITTY_HOLD;
        } else {
            hold(timer);
        }
    }

    fn jumpKey(self: *Input, release: bool, press: bool) void {
        if (self.kitty) {
            if (release) {
                self.jump_hold = 0;
                return;
            }
            if (press) self.jump_buf = cfg.JUMP_BUFFER_FRAMES;
            self.jump_hold = KITTY_HOLD;
        } else {
            if (self.jump_hold == 0) self.jump_buf = cfg.JUMP_BUFFER_FRAMES;
            hold(&self.jump_hold);
        }
    }

    pub fn feed(self: *Input, ev: movy.input.InputEvent) void {
        switch (ev) {
            .key => |key| {
                // legacy input is always a Press; kitty distinguishes events
                const press = !self.kitty or key.event == .Press;
                const release = self.kitty and key.event == .Release;

                switch (key.type) {
                    .Escape, .CtrlC => if (press) {
                        self.quit = true;
                    },
                    .Left => self.holdKey(&self.left, release),
                    .Right => self.holdKey(&self.right, release),
                    .Down => self.holdKey(&self.down, release),
                    .Up => self.jumpKey(release, press),
                    .Enter => if (press) {
                        self.confirm = true;
                    },
                    .Char => {
                        if (key.sequence.len == 0) return;
                        switch (key.sequence[0]) {
                            'a', 'A' => self.holdKey(&self.left, release),
                            'd', 'D' => self.holdKey(&self.right, release),
                            's', 'S' => self.holdKey(&self.down, release),
                            'w', 'W', 'k', 'K' => self.jumpKey(release, press),
                            ' ' => {
                                self.jumpKey(release, press);
                                if (press) self.confirm = true;
                            },
                            'j', 'J' => self.holdKey(&self.action, release),
                            'p', 'P' => if (press) {
                                self.pause = true;
                            },
                            'r', 'R' => if (press) {
                                self.restart = true;
                            },
                            'q', 'Q' => if (press) {
                                self.quit = true;
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            },
            .mouse => {},
        }
    }

    pub inline fn leftHeld(self: *const Input) bool {
        return self.left > 0;
    }
    pub inline fn rightHeld(self: *const Input) bool {
        return self.right > 0;
    }
    pub inline fn downHeld(self: *const Input) bool {
        return self.down > 0;
    }
    pub inline fn actionHeld(self: *const Input) bool {
        return self.action > 0;
    }
};

const std = @import("std");

pub const GameStateManager = struct {
    state: GameState = .FadeIn,
    frame_counter: u32 = 0,
    just_transitioned: bool = true,

    pub const GameState = enum {
        FadeIn,
        StartingInvincible,
        AlmostVulnerable,
        Playing,
        FadingToPause,
        Paused,
        FadingFromPause,
        Dying,
        Respawning,
        FadeToGameOver,
        GameOver,
        FadingRestart,
    };

    pub fn init() GameStateManager {
        return GameStateManager{
            .state = .FadeIn,
            .frame_counter = 0,
        };
    }

    /// Called every frame, with the global game frame counter.
    pub fn update(self: *GameStateManager, global_frame: usize) void {
        _ = global_frame;

        if (!self.just_transitioned) {
            self.frame_counter += 1;
        } else {
            self.just_transitioned = false;
        }

        switch (self.state) {
            .FadeIn => {
                if (self.frame_counter > 100) {
                    self.transitionTo(.StartingInvincible);
                }
            },
            .StartingInvincible => {
                if (self.frame_counter > 100) {
                    self.transitionTo(.AlmostVulnerable);
                }
            },
            .AlmostVulnerable => {
                if (self.frame_counter > 100) {
                    self.transitionTo(.Playing);
                }
            },
            .FadingToPause => {
                if (self.frame_counter > 20) {
                    self.transitionTo(.Paused);
                }
            },
            .FadingFromPause => {
                if (self.frame_counter > 20) {
                    self.transitionTo(.Playing);
                }
            },
            .Dying => {
                if (self.frame_counter > 50) {
                    self.transitionTo(.Respawning);
                }
            },
            .Respawning => {
                if (self.frame_counter > 90) {
                    self.transitionTo(.FadeIn);
                }
            },
            .FadeToGameOver => {
                if (self.frame_counter > 100) {
                    self.transitionTo(.GameOver);
                }
            },
            .FadingRestart => {
                if (self.frame_counter > 45) {
                    self.transitionTo(.FadeIn);
                }
            },
            else => {}, // Playing, Paused, GameOver — wait for user input
        }
    }

    pub fn transitionTo(self: *GameStateManager, new_state: GameState) void {
        self.state = new_state;
        self.frame_counter = 0;
        self.just_transitioned = true;
    }

    /// Returns whether game logic should update (ship, obstacles, etc.)
    pub fn isGameRunning(self: *GameStateManager) bool {
        return switch (self.state) {
            .Playing, .StartingInvincible, .AlmostVulnerable => true,
            else => false,
        };
    }

    /// Returns whether player is invincible (can’t collide)
    pub fn isPlayerInvincible(self: *GameStateManager) bool {
        return switch (self.state) {
            .StartingInvincible, .AlmostVulnerable => true,
            else => false,
        };
    }

    /// Returns whether game is paused (to dim or show pause screen)
    pub fn isPaused(self: *GameStateManager) bool {
        return switch (self.state) {
            .Paused => true,
            else => false,
        };
    }

    /// Returns whether we’re in a visual-only transition (e.g., fading)
    pub fn isTransitioning(self: *GameStateManager) bool {
        return switch (self.state) {
            .FadeIn,
            .FadingToPause,
            .FadingFromPause,
            .FadeToGameOver,
            .FadingRestart,
            => true,
            else => false,
        };
    }

    pub fn justTransitioned(self: *GameStateManager) bool {
        return self.frame_counter == 0;
    }
};

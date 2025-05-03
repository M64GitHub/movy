const movy = @import("movy");
const Ship = @import("Ship.zig").Ship;

pub const ShipController = struct {
    ship: *Ship,
    movement_state: MovementState = .Idle,
    animation_state: AnimationState = .Idle,
    fire_state: FireState = .NotFiring,
    fire_bump_timer: i32 = 0,
    screen: *movy.Screen,

    pub const FireBump = 5;
    pub const BumpOffset = 2;

    const MovementState = enum {
        Idle,
        MoveLeft,
        MoveRight,
    };

    const AnimationState = enum {
        Idle,
        TurningLeft,
        HoldingLeft,
        ReturningFromLeft,
        TurningRight,
        HoldingRight,
        ReturningFromRight,
    };

    const FireState = enum {
        NotFiring,
        StartBump,
        Bumping,
        RestoreBump,
    };

    pub fn init(ship: *Ship, screen: *movy.Screen) ShipController {
        return ShipController{
            .ship = ship,
            .screen = screen,
        };
    }

    pub fn reset(self: *ShipController) void {
        self.movement_state = .Idle;
        self.animation_state = .Idle;
        self.ship.sprite_ship.startAnimation("idle") catch {};
    }

    pub fn onKeyDown(self: *ShipController, key: movy.input.Key) void {
        switch (key.type) {
            .Left => self.movement_state = MovementState.MoveLeft,
            .Right => self.movement_state = MovementState.MoveRight,
            .Char => {
                const c = key.sequence[0];
                if (c == ' ') {
                    if (self.fire_state == FireState.NotFiring) {
                        self.fire_state = FireState.StartBump;
                    }
                }
            },
            else => {},
        }
    }

    pub fn onKeyUp(self: *ShipController, key: movy.input.Key) void {
        switch (key.type) {
            .Left, .Right => self.movement_state = MovementState.Idle,

            .Char => {
                const c = key.sequence[0];
                if (c == ' ') {
                    //   self.movement_state = MovementState.Idle;
                }
            },
            else => {},
        }
    }

    pub fn updateState(self: *ShipController) !void {
        var ship = self.ship;

        // --- Movement animation state machine ---
        switch (self.animation_state) {
            .Idle => {
                if (self.movement_state == .MoveLeft) {
                    try ship.sprite_ship.startAnimation("left");
                    self.animation_state = AnimationState.TurningLeft;
                } else if (self.movement_state == .MoveRight) {
                    try ship.sprite_ship.startAnimation("right");
                    self.animation_state = AnimationState.TurningRight;
                }
            },
            .TurningLeft => if (ship.sprite_ship.finishedActiveAnimation()) {
                self.animation_state = AnimationState.HoldingLeft;
            },
            .HoldingLeft => {
                if (self.movement_state == .Idle) {
                    try ship.sprite_ship.startAnimation("left_rev");
                    self.animation_state = AnimationState.ReturningFromLeft;
                } else if (self.movement_state == .MoveRight) {
                    try ship.sprite_ship.startAnimation("left_rev");
                    self.animation_state = AnimationState.ReturningFromLeft;
                }
            },
            .ReturningFromLeft => if (ship.sprite_ship.finishedActiveAnimation()) {
                if (self.movement_state == .MoveRight) {
                    try ship.sprite_ship.startAnimation("right");
                    self.animation_state = AnimationState.TurningRight;
                } else {
                    self.animation_state = AnimationState.Idle;
                    try ship.sprite_ship.startAnimation("idle");
                }
            },
            .TurningRight => if (ship.sprite_ship.finishedActiveAnimation()) {
                self.animation_state = AnimationState.HoldingRight;
            },
            .HoldingRight => {
                if (self.movement_state == .Idle) {
                    try ship.sprite_ship.startAnimation("right_rev");
                    self.animation_state = AnimationState.ReturningFromRight;
                } else if (self.movement_state == .MoveLeft) {
                    try ship.sprite_ship.startAnimation("right_rev");
                    self.animation_state = AnimationState.ReturningFromRight;
                }
            },
            .ReturningFromRight => if (ship.sprite_ship.finishedActiveAnimation()) {
                if (self.movement_state == .MoveLeft) {
                    try ship.sprite_ship.startAnimation("left");
                    self.animation_state = AnimationState.TurningLeft;
                } else {
                    self.animation_state = AnimationState.Idle;
                    try ship.sprite_ship.startAnimation("idle");
                }
            },
        }

        // --- Fire bump logic ---
        switch (self.fire_state) {
            .StartBump => {
                self.fire_bump_timer = FireBump;
                self.fire_state = FireState.Bumping;
                // WeaponManager.tryFire();
            },
            .Bumping => {
                self.fire_bump_timer -= 1;
                if (self.fire_bump_timer <= 0) {
                    self.fire_state = FireState.RestoreBump;
                }
            },
            .RestoreBump => self.fire_state = FireState.NotFiring,
            else => {},
        }
    }

    pub fn handleState(self: *ShipController) void {
        const ship = self.ship;
        var x = ship.x;
        const y = ship.y;

        // --- Horizontal movement ---
        switch (self.movement_state) {
            .MoveLeft => {
                if (x >= ship.speed) x -= ship.speed;
            },
            .MoveRight => {
                if (x <
                    @as(i32, @intCast(self.screen.w)) -
                        @as(i32, @intCast(self.ship.sprite_ship.w)))
                    x += ship.speed;
            },

            else => {},
        }

        // --- Fire bump ---
        switch (ship.orientation) {
            .Up => {
                ship.base_y = switch (self.fire_state) {
                    .Bumping => BumpOffset,
                    else => 0,
                };
            },
            .Down => {
                ship.base_y = switch (self.fire_state) {
                    .Bumping => -BumpOffset,
                    else => 0,
                };
            },
            .Left, .Right => {},
        }

        ship.setXY(x, y);
    }
};

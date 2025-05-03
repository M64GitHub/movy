const std = @import("std");
const movy = @import("movy");
const DefaultWeapon = @import("DefaultWeapon.zig").DefaultWeapon;
const SpreadWeapon = @import("SpreadWeapon.zig").SpreadWeapon;

pub const WeaponManager = struct {
    default_weapon: *DefaultWeapon,
    spread_weapon: *SpreadWeapon,
    just_fired: bool = false,
    // beam_weapon: BeamWeapon,
    // bomb_weapon: BombWeapon,

    active_weapon: WeaponType = .Default,

    pub const WeaponType = enum {
        Default,
        // Beam,
        // Bomb,
        Spread,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*WeaponManager {
        const wm = try allocator.create(WeaponManager);
        wm.* = WeaponManager{
            .default_weapon = try DefaultWeapon.init(allocator, screen),
            .spread_weapon = try SpreadWeapon.init(allocator, screen),
            .active_weapon = .Spread,
        };

        return wm;
    }

    pub fn deinit(self: *WeaponManager, allocator: std.mem.Allocator) void {
        self.default_weapon.deinit(allocator);
        allocator.destroy(self.default_weapon);
        self.spread_weapon.deinit(allocator);
        allocator.destroy(self.spread_weapon);
        allocator.destroy(self);
    }

    pub fn tryFire(self: *WeaponManager, x: i32, y: i32) void {
        self.just_fired = false;
        switch (self.active_weapon) {
            .Default => self.just_fired = self.default_weapon.tryFire(x, y),
            .Spread => {
                self.just_fired = self.spread_weapon.tryFire(x, y);
                if (!self.just_fired) {
                    self.active_weapon = .Default;
                    self.just_fired = self.default_weapon.tryFire(x, y);
                }
            },
        }
    }

    pub fn update(self: *WeaponManager) !void {
        self.just_fired = false;
        try self.default_weapon.update();
        try self.spread_weapon.update();
    }

    pub fn addRenderSurfaces(self: *WeaponManager) !void {
        try self.default_weapon.addRenderSurfaces();
        try self.spread_weapon.addRenderSurfaces();
    }

    pub fn switchWeapon(self: *WeaponManager, new_weapon: WeaponType) void {
        self.active_weapon = new_weapon;

        const ammo = switch (self.active_weapon) {
            .Default => DefaultWeapon.DefaultAmmo,
            .Spread => SpreadWeapon.DefaultAmmo,
        };
        self.setAmmo(ammo);
    }

    pub fn getWeaponName(self: *WeaponManager) []const u8 {
        const wpn_name = switch (self.active_weapon) {
            .Default => "Default",
            .Spread => "Spread",
        };

        return wpn_name;
    }

    pub fn getAmmo(self: *WeaponManager) usize {
        const ammo = switch (self.active_weapon) {
            .Default => self.default_weapon.ammo,
            .Spread => self.spread_weapon.ammo,
        };

        return ammo;
    }

    pub fn setAmmo(self: *WeaponManager, ammo: usize) void {
        switch (self.active_weapon) {
            .Default => self.default_weapon.ammo = ammo,
            .Spread => self.spread_weapon.ammo = ammo,
        }
    }
};

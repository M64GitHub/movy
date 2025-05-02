const std = @import("std");
const movy = @import("movy");
const DefaultShield = @import("DefaultShield.zig").DefaultShield;
const SpecialShield = @import("SpecialShield.zig").SpecialShield;

pub const ShieldManager = struct {
    default_shield: *DefaultShield,
    special_shield: *SpecialShield,
    active_shield: ShieldType = .Default,

    pub const ShieldType = enum {
        Default,
        Special,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*ShieldManager {
        const shield_mgr = try allocator.create(ShieldManager);
        shield_mgr.* = ShieldManager{
            .default_shield = try DefaultShield.init(allocator, screen),
            .special_shield = try SpecialShield.init(allocator, screen),
            .active_shield = .Special,
        };

        return shield_mgr;
    }

    pub fn deinit(self: *ShieldManager, allocator: std.mem.Allocator) void {
        self.default_shield.deinit(allocator);
        allocator.destroy(self.default_shield);
        self.special_shield.deinit(allocator);
        allocator.destroy(self.special_shield);
        allocator.destroy(self);
    }

    pub fn tryFire(self: *ShieldManager, x: i32, y: i32) void {
        self.just_fired = false;
        switch (self.active_shield) {
            .Default => self.just_fired = self.default_shield.tryFire(x, y),
            .Special => {
                self.just_fired = self.special_shield.tryFire(x, y);
                if (!self.just_fired) {
                    self.active_shield = .Default;
                    self.just_fired = self.default_shield.tryFire(x, y);
                }
            },
        }
    }

    pub fn update(self: *ShieldManager) !void {
        self.just_fired = false;
        try self.default_shield.update();
        try self.special_shield.update();
    }

    pub fn addRendersurfaces(self: *ShieldManager) !void {
        try self.default_shield.addRenderSurfaces();
        try self.special_shield.addRenderSurfaces();
    }

    pub fn switchShield(self: *ShieldManager, new_shield: ShieldType) void {
        self.active_shield = new_shield;
    }

    pub fn getShieldName(self: *ShieldManager) []const u8 {
        const wpn_name = switch (self.active_shield) {
            .Default => "Default",
            .Special => "Special",
        };

        return wpn_name;
    }

    pub fn getAmmo(self: *ShieldManager) usize {
        const ammo = switch (self.active_shield) {
            .Default => self.default_shield.ammo,
            .Special => self.special_shield.ammo,
        };

        return ammo;
    }
};

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
        None,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) !*ShieldManager {
        const shield_mgr = try allocator.create(ShieldManager);
        shield_mgr.* = ShieldManager{
            .default_shield = try DefaultShield.init(allocator, screen),
            .special_shield = try SpecialShield.init(allocator, screen),
            .active_shield = .None,
        };

        shield_mgr.reset();

        return shield_mgr;
    }

    pub fn deinit(self: *ShieldManager, allocator: std.mem.Allocator) void {
        self.default_shield.deinit(allocator);
        allocator.destroy(self.default_shield);
        self.special_shield.deinit(allocator);
        allocator.destroy(self.special_shield);
        allocator.destroy(self);
    }

    pub fn reset(self: *ShieldManager) void {
        self.default_shield.active = false;
        self.special_shield.active = false;
        self.active_shield = .None;
    }

    pub fn activate(self: *ShieldManager, shield_type: ShieldType) void {
        self.active_shield = shield_type;
        // deactivate others
        self.default_shield.reset();
        self.special_shield.reset();
        switch (shield_type) {
            .Default => {
                self.default_shield.active = true;
            },
            .Special => {
                self.special_shield.active = true;
            },
            .None => {},
        }
    }

    pub fn update(self: *ShieldManager, x: i32, y: i32) !void {
        self.default_shield.update(x, y - 4);
        self.special_shield.update(x, y - 4);

        if (self.active_shield == .Default) {
            if (!self.default_shield.active) {
                self.activate(.None);
            }
        }
        if (self.active_shield == .Special) {
            if (!self.special_shield.active) {
                self.activate(.None);
            }
        }
    }

    pub fn addRenderSurfaces(self: *ShieldManager) !void {
        try self.default_shield.addRenderSurfaces();
        try self.special_shield.addRenderSurfaces();
    }

    pub fn getCooldown(self: *ShieldManager) usize {
        const cooldown = switch (self.active_shield) {
            .Default => self.default_shield.cooldown_ctr,
            .Special => self.special_shield.cooldown_ctr,
            .None => 0,
        };

        return cooldown;
    }
};

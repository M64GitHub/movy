const std = @import("std");
const movy = @import("../movy.zig");

/// Represents an entry in the SpritePool: a sprite and its usage state.
const SpriteEntry = struct {
    sprite: *movy.graphic.Sprite,
    in_use: bool,
};

/// SpritePool manages a pool of reusable sprites with usage tracking.
/// Sprites are marked in-use when fetched with `get()` and released with `release()`.
pub const SpritePool = struct {
    entries: std.ArrayList(SpriteEntry),

    /// Initializes an empty SpritePool.
    pub fn init() SpritePool {
        return SpritePool{
            .entries = .{},
        };
    }

    /// Deinitializes the pool and all contained sprites.
    pub fn deinit(self: *SpritePool, allocator: std.mem.Allocator) void {
        for (self.entries.items) |entry| {
            entry.sprite.deinit(allocator);
        }
        self.entries.deinit(allocator);
    }

    /// Adds a sprite to the pool. Must be heap allocated and ready to use.
    pub fn addSprite(
        self: *SpritePool,
        allocator: std.mem.Allocator,
        sprite: *movy.graphic.Sprite,
    ) !void {
        try self.entries.append(allocator, .{
            .sprite = sprite,
            .in_use = false,
        });
    }

    /// Gets a free sprite from the pool and marks it as in-use.
    pub fn get(self: *SpritePool) ?*movy.graphic.Sprite {
        for (self.entries.items) |*entry| {
            if (!entry.in_use) {
                entry.in_use = true;
                return entry.sprite;
            }
        }
        return null;
    }

    /// Releases a sprite, marking it as no longer in use.
    pub fn release(self: *SpritePool, sprite: *movy.graphic.Sprite) void {
        for (self.entries.items) |*entry| {
            if (entry.sprite == sprite) {
                entry.in_use = false;
                return;
            }
        }
    }

    /// Counts how many sprites are currently free.
    pub fn countFree(self: *SpritePool) usize {
        var count: usize = 0;
        for (self.entries.items) |entry| {
            if (!entry.in_use) count += 1;
        }
        return count;
    }

    /// Returns the total number of sprites in the pool.
    pub fn totalCount(self: *SpritePool) usize {
        return self.entries.items.len;
    }

    /// Gives you an iterator of all used sprites.
    pub fn usedSprites(self: *SpritePool) []SpriteEntry {
        return self.entries.items;
    }
};

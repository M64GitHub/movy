//! Non-UI renderable graphics components.
//!
//! This module provides Sprite (frame-based animation), SpritePool
//! (efficient sprite instance management), and BlockLine (line drawing
//! primitives for terminal graphics).

pub const Sprite = @import("Sprite.zig").Sprite;
pub const SpritePool = @import("SpritePool.zig").SpritePool;
pub const BlockLine = @import("BlockLine.zig").BlockLine;

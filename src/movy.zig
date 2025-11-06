//! movy - Terminal graphics rendering, animation, and effects engine.
//!
//! This library transforms terminals into graphical canvases using ANSI
//! half-blocks for double vertical resolution. Supports sprite rendering,
//! alpha blending, z-index layering, and programmable rendering pipelines.

const std = @import("std");

pub const movy = @This();

pub const Version = "0.0.0";

// Top-level re-exports for convenience
pub const Sprite = @import("graphic/Sprite.zig").Sprite;
pub const SpritePool = @import("graphic/SpritePool.zig").SpritePool;
pub const BlockLine = @import("graphic/BlockLine.zig").BlockLine;
pub const RenderSurface = @import("core/RenderSurface.zig").RenderSurface;

// Core submodules — foundational elements for movy
pub const core = @import("core/core.zig");

// Utility submodules — supporting functionality
pub const utils = @import("utils/utils.zig");

// Rendering submodules — tools for composing terminal visuals
pub const render = @import("render/render.zig");

// Animation submodules — tools for animations and transitions
pub const animation = @import("animation/animation.zig");

// Graphics submodules — non-UI renderable components for visuals
pub const graphic = @import("graphic/graphic.zig");

// Display surface—top-level rendering canvas, and output to terminal
pub const Screen = @import("screen/Screen.zig").Screen;

// Top level utility submodules — supporting functionality
pub const color = @import("core/colors.zig");
pub const input = @import("input/input.zig");
pub const terminal = @import("terminal/terminal.zig");

// UI submodules (experimental)
pub const ui = @import("ui/ui.zig");

// Test references - pull in tests from individual modules
test {
    _ = @import("core/RenderSurface.zig");
    _ = @import("graphic/Sprite.zig");
    _ = @import("animation/IndexAnimator.zig");
    _ = @import("render/RenderEngine.zig");
}

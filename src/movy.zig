/// movy - Terminal rendering, animation and effects engine.
/// A lightweight, modular framework for crafting vibrant terminal UIs
/// with sprites, animations, windows, and styled text.
const std = @import("std");

pub const movy = @This();

pub const Version = "0.0.0";

// maybe move to toplevel: graphic, RenderSurface
pub const Sprite = @import("graphic/Sprite.zig").Sprite;
pub const SpritePool = @import("graphic/SpritePool.zig").SpritePool;
pub const BlockLine = @import("graphic/BlockLine.zig").BlockLine;
pub const RenderSurface = @import("core/RenderSurface.zig").RenderSurface;

// -- original structure

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

// -- ui

pub const ui = @import("ui/ui.zig");

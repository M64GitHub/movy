//! Core rendering primitives and type definitions.
//!
//! This module exports fundamental types (Rgb, Pixel2D, Coords2D, etc.)
//! and the RenderSurface, which provides 2D pixel/char grids for
//! terminal rendering.

pub const types = @import("types.zig");
pub const RenderSurface = @import("RenderSurface.zig").RenderSurface;

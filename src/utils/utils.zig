//! Utility modules for ANSI parsing and terminal operations.
//!
//! Currently provides ansi_parser for parsing catimg-style ANSI
//! escape sequences into RenderSurface pixel data.

pub const ansi_parser = @import("ansi_parser.zig");

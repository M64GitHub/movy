//! Palette - your project's colors in one place.
//!
//! The linear-float color TYPE and math live in movy now (`movy.color.V3`,
//! `movy.color.v3`, `.add/.scale/.mul/.lerp/.toRgb`). This file just re-exports
//! them for convenience and defines the named colors. Work in V3 while drawing
//! and accumulating light; `movy.Frame.composite()` clamps + converts to the u8
//! `Rgb` the terminal wants (values may exceed 1.0 mid-accumulation - that's
//! how additive glow blooms).

const movy = @import("movy");

pub const Rgb = movy.core.types.Rgb;
pub const V3 = movy.color.V3;
pub const v3 = movy.color.v3;
pub const WHITE = movy.color.WHITE_F;
pub const BLACK = movy.color.BLACK_F;

// ------------------------------------------------------------ movy-fx palette
// The original logo is pure grayscale on black: white walls, gray frame, a
// gray heat-strip. INK draws the bitmap; GLOW is the additive bloom color
// (cool/blue tint - the requested color flavor without losing the white walls).
pub const INK = v3(1.00, 1.00, 1.00); // the logo ink (white, scaled per-pixel)
pub const GLOW = v3(0.55, 0.80, 1.00); // bloom tint - cool cyan/blue

// neon particle colors - a cool spread the flying particles pick from by index.
pub const P_CYAN = v3(0.30, 0.95, 1.00);
pub const P_BLUE = v3(0.35, 0.55, 1.00);
pub const P_AZURE = v3(0.55, 0.85, 1.00);
pub const P_VIOLET = v3(0.70, 0.45, 1.00);

// morph demo - the S.M.B. boss accent (ROTO_BEAM): a hot magenta for the
// "occasional purple" reassembly beat (flash + ring).
pub const P_MAGENTA = v3(1.00, 0.30, 0.72);

// morph4 - a warm "scorch" glow that lingers on each wall just after the beam
// re-forms it (a hot trail behind the cool beam).
pub const SCORCH = v3(1.00, 0.55, 0.20);

// flare / energize demo - beam, anamorphic streak, shockwave, burst flash.
pub const FLARE_BEAM = v3(0.85, 0.95, 1.00); // the sweeping light beam (near white)
pub const FLARE_STREAK = v3(0.40, 0.80, 1.00); // horizontal anamorphic streak
pub const FLARE_RING = v3(0.60, 0.90, 1.00); // expanding shockwave rings
pub const FLASH_COL = v3(0.90, 0.96, 1.00); // full-screen burst flash color

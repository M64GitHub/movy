//! Palette - all colors in one place. The linear-float color TYPE and math
//! live in movy now (`movy.color.V3` / `movy.color.v3`); this re-exports them
//! and defines the named game colors. See the movy-render skill for notes.

const movy = @import("movy");

pub const Rgb = movy.core.types.Rgb;
pub const V3 = movy.color.V3;
pub const v3 = movy.color.v3;
pub const WHITE = movy.color.WHITE_F;
pub const BLACK = movy.color.BLACK_F;

// ---------------------------------------------------------------- world
pub const BG_TOP = v3(0.008, 0.016, 0.045);
pub const BG_BOT = v3(0.030, 0.075, 0.130);
pub const TILE_BODY = v3(0.014, 0.105, 0.135);
pub const TILE_DARK = v3(0.008, 0.062, 0.082);
pub const TILE_TOP = v3(0.55, 0.95, 1.00); // walkable top edge (neon ribbon)
pub const TILE_TOP_GLOW = v3(0.05, 0.26, 0.32);

// ---------------------------------------------------------------- player (friendly = cyan)
pub const PLAYER_BODY = v3(0.10, 0.78, 0.92);
pub const PLAYER_DARK = v3(0.03, 0.30, 0.40);
pub const PLAYER_CORE = v3(0.92, 1.00, 1.00);
pub const PLAYER_GLOW = v3(0.05, 0.27, 0.34);

// ---------------------------------------------------------------- enemy (hostile = orange)
pub const ENEMY_BODY = v3(0.95, 0.52, 0.08);
pub const ENEMY_CORE = v3(1.00, 0.85, 0.55);
pub const ENEMY_GLOW = v3(0.30, 0.12, 0.01);

const std = @import("std");

/// Defines style classes for UI elements—maps to characters for rendering.
pub const ZuiStyleClass = enum {
    WindowUpperLeftCorner,
    WindowUpperRightCorner,
    WindowLowerLeftCorner,
    WindowLowerRightCorner,
    WindowVerticalBorder,
    WindowHorizontalBorder,
    WindowTitleLeft,
    WindowTitleRight,
};

/// Manages character-based styling for UI elements—maps ZuiStyleClass to u21.
pub const ZuiStyle = struct {
    name: []const u8, // Style name—e.g., "Default", "ThinBorders"
    chars: std.EnumArray(ZuiStyleClass, u21), // Fixed mapping for fast lookups

    /// Initializes a default style with classic ASCII window characters.
    pub fn initDefault() ZuiStyle {
        var style = ZuiStyle{
            .name = "Default",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╔');
        style.chars.set(.WindowUpperRightCorner, '╗');
        style.chars.set(.WindowLowerLeftCorner, '╚');
        style.chars.set(.WindowLowerRightCorner, '╝');
        style.chars.set(.WindowVerticalBorder, '║');
        style.chars.set(.WindowHorizontalBorder, '═');
        style.chars.set(.WindowTitleLeft, '╡');
        style.chars.set(.WindowTitleRight, '╞');
        return style;
    }

    /// Initializes a style with thin, single-line ANSI border characters.
    pub fn initThinBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "ThinBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '┌');
        style.chars.set(.WindowUpperRightCorner, '┐');
        style.chars.set(.WindowLowerLeftCorner, '└');
        style.chars.set(.WindowLowerRightCorner, '┘');
        style.chars.set(.WindowVerticalBorder, '│');
        style.chars.set(.WindowHorizontalBorder, '─');
        style.chars.set(.WindowTitleLeft, '┤');
        style.chars.set(.WindowTitleRight, '├');
        return style;
    }

    /// Initializes a style with full and shaded block characters for a bold,
    /// pixelated look.
    pub fn initFullBlockBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "FullBlockBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '█');
        style.chars.set(.WindowUpperRightCorner, '█');
        style.chars.set(.WindowLowerLeftCorner, '█');
        style.chars.set(.WindowLowerRightCorner, '█');
        style.chars.set(.WindowVerticalBorder, '█');
        style.chars.set(.WindowHorizontalBorder, '█');
        style.chars.set(.WindowTitleLeft, '▒');
        style.chars.set(.WindowTitleRight, '▒');
        return style;
    }

    /// Initializes a style with shaded block characters for a soft,
    /// textured look.
    pub fn initShadedBlockBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "ShadedBlockBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '▒');
        style.chars.set(.WindowUpperRightCorner, '▒');
        style.chars.set(.WindowLowerLeftCorner, '▒');
        style.chars.set(.WindowLowerRightCorner, '▒');
        style.chars.set(.WindowVerticalBorder, '░');
        style.chars.set(.WindowHorizontalBorder, '░');
        style.chars.set(.WindowTitleLeft, '▓');
        style.chars.set(.WindowTitleRight, '▓');
        return style;
    }

    /// Initializes a style with dotted and dashed characters for a playful,
    /// whimsical look.
    pub fn initDottedBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "DottedBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '·');
        style.chars.set(.WindowUpperRightCorner, '·');
        style.chars.set(.WindowLowerLeftCorner, '·');
        style.chars.set(.WindowLowerRightCorner, '·');
        style.chars.set(.WindowVerticalBorder, '|');
        style.chars.set(.WindowHorizontalBorder, '-');
        style.chars.set(.WindowTitleLeft, '◄');
        style.chars.set(.WindowTitleRight, '►');
        return style;
    }

    /// Initializes a style with star-like characters for a celestial,
    /// sparkling look.
    pub fn initStarBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "StarBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '★');
        style.chars.set(.WindowUpperRightCorner, '★');
        style.chars.set(.WindowLowerLeftCorner, '★');
        style.chars.set(.WindowLowerRightCorner, '★');
        style.chars.set(.WindowVerticalBorder, '☆');
        style.chars.set(.WindowHorizontalBorder, '☆');
        style.chars.set(.WindowTitleLeft, '☆');
        style.chars.set(.WindowTitleRight, '☆');
        return style;
    }

    /// Initializes a style with star-like characters for a celestial,
    /// sparkling look.
    pub fn initInvertedStarBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "InvertedStarBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '☆');
        style.chars.set(.WindowUpperRightCorner, '☆');
        style.chars.set(.WindowLowerLeftCorner, '☆');
        style.chars.set(.WindowLowerRightCorner, '☆');
        style.chars.set(.WindowVerticalBorder, '★');
        style.chars.set(.WindowHorizontalBorder, '★');
        style.chars.set(.WindowTitleLeft, '☆');
        style.chars.set(.WindowTitleRight, '☆');
        return style;
    }

    /// Initializes a style with circuit-like characters for a futuristic,
    /// techy look.
    pub fn initCircuitBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "CircuitBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╠');
        style.chars.set(.WindowUpperRightCorner, '╣');
        style.chars.set(.WindowLowerLeftCorner, '╠');
        style.chars.set(.WindowLowerRightCorner, '╣');
        style.chars.set(.WindowVerticalBorder, '║');
        style.chars.set(.WindowHorizontalBorder, '═');
        style.chars.set(.WindowTitleLeft, '╬');
        style.chars.set(.WindowTitleRight, '╬');
        return style;
    }

    /// Initializes a style with heart characters for a cute, romantic look.
    pub fn initHeartBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "HeartBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '♥');
        style.chars.set(.WindowUpperRightCorner, '♥');
        style.chars.set(.WindowLowerLeftCorner, '♥');
        style.chars.set(.WindowLowerRightCorner, '♥');
        style.chars.set(.WindowVerticalBorder, '·');
        style.chars.set(.WindowHorizontalBorder, '·');
        style.chars.set(.WindowTitleLeft, '♡');
        style.chars.set(.WindowTitleRight, '♡');
        return style;
    }

    /// Initializes a style with block characters for a retro pixel-art look.
    pub fn initPixelArtBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "PixelArtBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '■');
        style.chars.set(.WindowUpperRightCorner, '■');
        style.chars.set(.WindowLowerLeftCorner, '■');
        style.chars.set(.WindowLowerRightCorner, '■');
        style.chars.set(.WindowVerticalBorder, '│');
        style.chars.set(.WindowHorizontalBorder, '─');
        style.chars.set(.WindowTitleLeft, '□');
        style.chars.set(.WindowTitleRight, '□');
        return style;
    }

    /// Initializes a style with neon-like characters for a glowing,
    /// cyberpunk look.
    pub fn initNeonGlowBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "NeonGlowBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '◢');
        style.chars.set(.WindowUpperRightCorner, '◣');
        style.chars.set(.WindowLowerLeftCorner, '◥');
        style.chars.set(.WindowLowerRightCorner, '◤');
        style.chars.set(.WindowVerticalBorder, '┃');
        style.chars.set(.WindowHorizontalBorder, '━');
        style.chars.set(.WindowTitleLeft, '✸');
        style.chars.set(.WindowTitleRight, '✸');
        return style;
    }

    /// Initializes a style with glitchy characters for a distorted,
    /// digital look.
    pub fn initGlitchBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "GlitchBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '█');
        style.chars.set(.WindowUpperRightCorner, '▌');
        style.chars.set(.WindowLowerLeftCorner, '▐');
        style.chars.set(.WindowLowerRightCorner, '█');
        style.chars.set(.WindowVerticalBorder, '≈');
        style.chars.set(.WindowHorizontalBorder, '~');
        style.chars.set(.WindowTitleLeft, '✖');
        style.chars.set(.WindowTitleRight, '✖');
        return style;
    }

    /// Initializes a style with diamond-like characters for a luxurious,
    /// gemstone look.
    pub fn initDiamondBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "DiamondBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '◆');
        style.chars.set(.WindowUpperRightCorner, '◆');
        style.chars.set(.WindowLowerLeftCorner, '◆');
        style.chars.set(.WindowLowerRightCorner, '◆');
        style.chars.set(.WindowVerticalBorder, '✧');
        style.chars.set(.WindowHorizontalBorder, '✧');
        style.chars.set(.WindowTitleLeft, '❖');
        style.chars.set(.WindowTitleRight, '❖');
        return style;
    }

    /// Initializes a style with binary look.
    pub fn initBinary() ZuiStyle {
        var style = ZuiStyle{
            .name = "Binary",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '1');
        style.chars.set(.WindowUpperRightCorner, '0');
        style.chars.set(.WindowLowerLeftCorner, '0');
        style.chars.set(.WindowLowerRightCorner, '1');
        style.chars.set(.WindowVerticalBorder, '1');
        style.chars.set(.WindowHorizontalBorder, '0');
        style.chars.set(.WindowTitleLeft, '#');
        style.chars.set(.WindowTitleRight, '#');
        return style;
    }

    /// Initializes a style with wavy, cosmic characters for a pulsing,
    /// otherworldly look.
    pub fn initCosmicWaveBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "CosmicWaveBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '✦');
        style.chars.set(.WindowUpperRightCorner, '✦');
        style.chars.set(.WindowLowerLeftCorner, '✦');
        style.chars.set(.WindowLowerRightCorner, '✦');
        style.chars.set(.WindowVerticalBorder, '~');
        style.chars.set(.WindowHorizontalBorder, '~');
        style.chars.set(.WindowTitleLeft, '✧');
        style.chars.set(.WindowTitleRight, '✧');
        return style;
    }

    /// Initializes a style with flame-like characters for a fiery, digital
    /// blaze look.
    pub fn initRectoidBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "RectoidBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '🜂');
        style.chars.set(.WindowUpperRightCorner, '🜂');
        style.chars.set(.WindowLowerLeftCorner, '🜁');
        style.chars.set(.WindowLowerRightCorner, '🜁');
        style.chars.set(.WindowVerticalBorder, '⁑');
        style.chars.set(.WindowHorizontalBorder, '⁕');
        style.chars.set(.WindowTitleLeft, '🜃');
        style.chars.set(.WindowTitleRight, '🜃');
        return style;
    }

    /// Initializes a style with grid-like characters for a quantum
    /// computing look.
    pub fn initQuantumGridBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "QuantumGridBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '⚛');
        style.chars.set(.WindowUpperRightCorner, '⚛');
        style.chars.set(.WindowLowerLeftCorner, '⚛');
        style.chars.set(.WindowLowerRightCorner, '⚛');
        style.chars.set(.WindowVerticalBorder, '╫');
        style.chars.set(.WindowHorizontalBorder, '╪');
        style.chars.set(.WindowTitleLeft, '⚙');
        style.chars.set(.WindowTitleRight, '⚙');
        return style;
    }

    /// Initializes a style with fractal-like characters for a holographic,
    /// sci-fi look.
    pub fn initHoloFractalBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "HoloFractalBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '❉');
        style.chars.set(.WindowUpperRightCorner, '❉');
        style.chars.set(.WindowLowerLeftCorner, '❉');
        style.chars.set(.WindowLowerRightCorner, '❉');
        style.chars.set(.WindowVerticalBorder, '❈');
        style.chars.set(.WindowHorizontalBorder, '❈');
        style.chars.set(.WindowTitleLeft, '✺');
        style.chars.set(.WindowTitleRight, '✹');
        return style;
    }

    /// Initializes a style with ethereal characters for a mystical,
    /// floating look.
    pub fn initAetherialBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AetherialBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '☁');
        style.chars.set(.WindowUpperRightCorner, '☁');
        style.chars.set(.WindowLowerLeftCorner, '☁');
        style.chars.set(.WindowLowerRightCorner, '☁');
        style.chars.set(.WindowVerticalBorder, '⚛');
        style.chars.set(.WindowHorizontalBorder, '♪');
        style.chars.set(.WindowTitleLeft, '♫');
        style.chars.set(.WindowTitleRight, '♫');
        return style;
    }

    /// Initializes a style with wavy line characters for a flowing, wobbly look.
    pub fn initWavyLineBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "WavyLineBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '┃');
        style.chars.set(.WindowHorizontalBorder, '~');
        style.chars.set(.WindowTitleLeft, '≈');
        style.chars.set(.WindowTitleRight, '≋');
        return style;
    }

    /// Rounded borders with boxes
    pub fn initRoundedBoxBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "RoundedBoxBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '┃');
        style.chars.set(.WindowHorizontalBorder, '─');
        style.chars.set(.WindowTitleLeft, '□');
        style.chars.set(.WindowTitleRight, '□');
        return style;
    }

    /// Initializes a style with neovim look
    pub fn initNeoVim() ZuiStyle {
        var style = ZuiStyle{
            .name = "NeoVim",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '┃');
        style.chars.set(.WindowHorizontalBorder, '─');
        style.chars.set(.WindowTitleLeft, '─');
        style.chars.set(.WindowTitleRight, '─');
        return style;
    }

    /// Initializes a style with rounded corners and dashed lines for an elegant
    /// look.
    pub fn initRoundedDashBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "RoundedDashBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '┆');
        style.chars.set(.WindowHorizontalBorder, '┄');
        style.chars.set(.WindowTitleLeft, '◦');
        style.chars.set(.WindowTitleRight, '◦');
        return style;
    }

    /// Initializes a style with curved lines for a dynamic, flowing look.
    pub fn initCurvedFlowBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "CurvedFlowBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '╱');
        style.chars.set(.WindowHorizontalBorder, '╲');
        style.chars.set(.WindowTitleLeft, '∽');
        style.chars.set(.WindowTitleRight, '∽');
        return style;
    }

    /// Initializes a style with zig-zag lines for an energetic, dynamic look.
    pub fn initZigZagBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "ZigZagBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╳');
        style.chars.set(.WindowUpperRightCorner, '╳');
        style.chars.set(.WindowLowerLeftCorner, '╳');
        style.chars.set(.WindowLowerRightCorner, '╳');
        style.chars.set(.WindowVerticalBorder, '╱');
        style.chars.set(.WindowHorizontalBorder, '╲');
        style.chars.set(.WindowTitleLeft, '⌁');
        style.chars.set(.WindowTitleRight, '⌁');
        return style;
    }

    /// Initializes a style with soft wave lines for a gentle, rippling look.
    pub fn initSoftWaveBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "SoftWaveBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╭');
        style.chars.set(.WindowUpperRightCorner, '╮');
        style.chars.set(.WindowLowerLeftCorner, '╰');
        style.chars.set(.WindowLowerRightCorner, '╯');
        style.chars.set(.WindowVerticalBorder, '≈');
        style.chars.set(.WindowHorizontalBorder, '∿');
        style.chars.set(.WindowTitleLeft, '∾');
        style.chars.set(.WindowTitleRight, '∾');
        return style;
    }

    /// Initializes a style with dashed lines for a fully dashed frame look.
    pub fn initDashedFrameBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "DashedFrameBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '┌');
        style.chars.set(.WindowUpperRightCorner, '┐');
        style.chars.set(.WindowLowerLeftCorner, '└');
        style.chars.set(.WindowLowerRightCorner, '┘');
        style.chars.set(.WindowVerticalBorder, '┆');
        style.chars.set(.WindowHorizontalBorder, '┄');
        style.chars.set(.WindowTitleLeft, '·');
        style.chars.set(.WindowTitleRight, '·');
        return style;
    }

    /// Initializes a style with double-dashed lines for a rhythmic, closed look.
    pub fn initDoubleDashBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "DoubleDashBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╒');
        style.chars.set(.WindowUpperRightCorner, '╕');
        style.chars.set(.WindowLowerLeftCorner, '╘');
        style.chars.set(.WindowLowerRightCorner, '╛');
        style.chars.set(.WindowVerticalBorder, '╎');
        style.chars.set(.WindowHorizontalBorder, '╌');
        style.chars.set(.WindowTitleLeft, '╳');
        style.chars.set(.WindowTitleRight, '╳');
        return style;
    }

    /// Initializes a style with heavy arc corners for a bold, rounded, closed look.
    pub fn initHeavyArcBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "HeavyArcBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '┏');
        style.chars.set(.WindowUpperRightCorner, '┓');
        style.chars.set(.WindowLowerLeftCorner, '┗');
        style.chars.set(.WindowLowerRightCorner, '┛');
        style.chars.set(.WindowVerticalBorder, '┃');
        style.chars.set(.WindowHorizontalBorder, '━');
        style.chars.set(.WindowTitleLeft, '╋');
        style.chars.set(.WindowTitleRight, '╋');
        return style;
    }

    /// Initializes a style with mixed-weight lines for a dynamic, closed look.
    pub fn initMixedWeightBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "MixedWeightBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '┍');
        style.chars.set(.WindowUpperRightCorner, '┒');
        style.chars.set(.WindowLowerLeftCorner, '┕');
        style.chars.set(.WindowLowerRightCorner, '┙');
        style.chars.set(.WindowVerticalBorder, '╽');
        style.chars.set(.WindowHorizontalBorder, '╼');
        style.chars.set(.WindowTitleLeft, '┿');
        style.chars.set(.WindowTitleRight, '┿');
        return style;
    }

    /// Initializes a style with quad-dashed lines for an intricate, closed look.
    pub fn initQuadDashBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "QuadDashBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '┌');
        style.chars.set(.WindowUpperRightCorner, '┐');
        style.chars.set(.WindowLowerLeftCorner, '└');
        style.chars.set(.WindowLowerRightCorner, '┘');
        style.chars.set(.WindowVerticalBorder, '┇');
        style.chars.set(.WindowHorizontalBorder, '┅');
        style.chars.set(.WindowTitleLeft, '·');
        style.chars.set(.WindowTitleRight, '·');
        return style;
    }

    /// Initializes a style with cross-patterned lines for a delicate, closed look.
    pub fn initLightCrossBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "LightCrossBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '├');
        style.chars.set(.WindowUpperRightCorner, '┤');
        style.chars.set(.WindowLowerLeftCorner, '┴');
        style.chars.set(.WindowLowerRightCorner, '┴');
        style.chars.set(.WindowVerticalBorder, '┼');
        style.chars.set(.WindowHorizontalBorder, '┼');
        style.chars.set(.WindowTitleLeft, '╀');
        style.chars.set(.WindowTitleRight, '╀');
        return style;
    }

    /// Initializes a style with heavy cross-patterned lines for a bold, closed look.
    pub fn initHeavyCrossBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "HeavyCrossBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '╠');
        style.chars.set(.WindowUpperRightCorner, '╣');
        style.chars.set(.WindowLowerLeftCorner, '╩');
        style.chars.set(.WindowLowerRightCorner, '╩');
        style.chars.set(.WindowVerticalBorder, '╋');
        style.chars.set(.WindowHorizontalBorder, '╋');
        style.chars.set(.WindowTitleLeft, '●');
        style.chars.set(.WindowTitleRight, '●');
        return style;
    }

    /// Initializes a style with ASCII plus and dash lines, with a star for the title.
    pub fn initAsciiPlusBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiPlusBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '+');
        style.chars.set(.WindowUpperRightCorner, '+');
        style.chars.set(.WindowLowerLeftCorner, '+');
        style.chars.set(.WindowLowerRightCorner, '+');
        style.chars.set(.WindowVerticalBorder, '|');
        style.chars.set(.WindowHorizontalBorder, '-');
        style.chars.set(.WindowTitleLeft, '★');
        style.chars.set(.WindowTitleRight, '★');
        return style;
    }

    /// Initializes a style with ASCII stars, with a diamond for the title.
    pub fn initAsciiStarBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiStarBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '*');
        style.chars.set(.WindowUpperRightCorner, '*');
        style.chars.set(.WindowLowerLeftCorner, '*');
        style.chars.set(.WindowLowerRightCorner, '*');
        style.chars.set(.WindowVerticalBorder, '*');
        style.chars.set(.WindowHorizontalBorder, '*');
        style.chars.set(.WindowTitleLeft, '◇');
        style.chars.set(.WindowTitleRight, '◇');
        return style;
    }

    /// Initializes a style with ASCII hashes, with a cross for the title.
    pub fn initAsciiHashBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiHashBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '#');
        style.chars.set(.WindowUpperRightCorner, '#');
        style.chars.set(.WindowLowerLeftCorner, '#');
        style.chars.set(.WindowLowerRightCorner, '#');
        style.chars.set(.WindowVerticalBorder, '#');
        style.chars.set(.WindowHorizontalBorder, '#');
        style.chars.set(.WindowTitleLeft, '✖');
        style.chars.set(.WindowTitleRight, '✖');
        return style;
    }

    /// Initializes a style with ASCII angle brackets, with a spade for the title.
    pub fn initAsciiAngleBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiAngleBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '<');
        style.chars.set(.WindowUpperRightCorner, '>');
        style.chars.set(.WindowLowerLeftCorner, '<');
        style.chars.set(.WindowLowerRightCorner, '>');
        style.chars.set(.WindowVerticalBorder, '|');
        style.chars.set(.WindowHorizontalBorder, '=');
        style.chars.set(.WindowTitleLeft, '♠');
        style.chars.set(.WindowTitleRight, '♠');
        return style;
    }

    /// Initializes a style with ASCII dots and dashes, with a four-pointed star for the title.
    pub fn initAsciiDotDashBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiDotDashBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '.');
        style.chars.set(.WindowUpperRightCorner, '.');
        style.chars.set(.WindowLowerLeftCorner, '.');
        style.chars.set(.WindowLowerRightCorner, '.');
        style.chars.set(.WindowVerticalBorder, ':');
        style.chars.set(.WindowHorizontalBorder, '-');
        style.chars.set(.WindowTitleLeft, '✦');
        style.chars.set(.WindowTitleRight, '✦');
        return style;
    }

    /// Initializes a style with ASCII brackets, with musical notes for the title.
    pub fn initAsciiBracketBorders() ZuiStyle {
        var style = ZuiStyle{
            .name = "AsciiBracketBorders",
            .chars = std.EnumArray(ZuiStyleClass, u21).initUndefined(),
        };
        style.chars.set(.WindowUpperLeftCorner, '[');
        style.chars.set(.WindowUpperRightCorner, ']');
        style.chars.set(.WindowLowerLeftCorner, '[');
        style.chars.set(.WindowLowerRightCorner, ']');
        style.chars.set(.WindowVerticalBorder, '|');
        style.chars.set(.WindowHorizontalBorder, '-');
        style.chars.set(.WindowTitleLeft, '♫');
        style.chars.set(.WindowTitleRight, '♫');
        return style;
    }

    /// Retrieves the character for a given style class—simple and efficient.
    pub fn getChar(self: *const ZuiStyle, class: ZuiStyleClass) u21 {
        return self.chars.get(class);
    }

    /// Updates the character for a given style class—flexible customization.
    pub fn setChar(self: *ZuiStyle, class: ZuiStyleClass, char: u21) void {
        self.chars.set(class, char);
    }

    /// Gathers all available styles into an ArrayList.
    pub fn getAllStyles(allocator: std.mem.Allocator) !std.ArrayList(*const ZuiStyle) {
        var styles = std.ArrayList(*const ZuiStyle).init(allocator);

        // Allocate, append, and initialize each style
        const style_default = try allocator.create(ZuiStyle);
        style_default.* = ZuiStyle.initDefault();
        try styles.append(style_default);

        const style_thin = try allocator.create(ZuiStyle);
        style_thin.* = ZuiStyle.initThinBorders();
        try styles.append(style_thin);

        const style_full_block = try allocator.create(ZuiStyle);
        style_full_block.* = ZuiStyle.initFullBlockBorders();
        try styles.append(style_full_block);

        const style_shaded_block = try allocator.create(ZuiStyle);
        style_shaded_block.* = ZuiStyle.initShadedBlockBorders();
        try styles.append(style_shaded_block);

        const style_dotted = try allocator.create(ZuiStyle);
        style_dotted.* = ZuiStyle.initDottedBorders();
        try styles.append(style_dotted);

        const style_star = try allocator.create(ZuiStyle);
        style_star.* = ZuiStyle.initStarBorders();
        try styles.append(style_star);

        const style_inverted_star = try allocator.create(ZuiStyle);
        style_inverted_star.* = ZuiStyle.initInvertedStarBorders();
        try styles.append(style_inverted_star);

        const style_circuit = try allocator.create(ZuiStyle);
        style_circuit.* = ZuiStyle.initCircuitBorders();
        try styles.append(style_circuit);

        const style_heart = try allocator.create(ZuiStyle);
        style_heart.* = ZuiStyle.initHeartBorders();
        try styles.append(style_heart);

        const style_pixel_art = try allocator.create(ZuiStyle);
        style_pixel_art.* = ZuiStyle.initPixelArtBorders();
        try styles.append(style_pixel_art);

        const style_neon_glow = try allocator.create(ZuiStyle);
        style_neon_glow.* = ZuiStyle.initNeonGlowBorders();
        try styles.append(style_neon_glow);

        const style_glitch = try allocator.create(ZuiStyle);
        style_glitch.* = ZuiStyle.initGlitchBorders();
        try styles.append(style_glitch);

        const style_diamond = try allocator.create(ZuiStyle);
        style_diamond.* = ZuiStyle.initDiamondBorders();
        try styles.append(style_diamond);

        const style_binary = try allocator.create(ZuiStyle);
        style_binary.* = ZuiStyle.initBinary();
        try styles.append(style_binary);

        const style_cosmic_wave = try allocator.create(ZuiStyle);
        style_cosmic_wave.* = ZuiStyle.initCosmicWaveBorders();
        try styles.append(style_cosmic_wave);

        const style_rectoid = try allocator.create(ZuiStyle);
        style_rectoid.* = ZuiStyle.initRectoidBorders();
        try styles.append(style_rectoid);

        const style_quantum_grid = try allocator.create(ZuiStyle);
        style_quantum_grid.* = ZuiStyle.initQuantumGridBorders();
        try styles.append(style_quantum_grid);

        const style_holo_fractal = try allocator.create(ZuiStyle);
        style_holo_fractal.* = ZuiStyle.initHoloFractalBorders();
        try styles.append(style_holo_fractal);

        const style_aetherial = try allocator.create(ZuiStyle);
        style_aetherial.* = ZuiStyle.initAetherialBorders();
        try styles.append(style_aetherial);

        const style_wavy_line = try allocator.create(ZuiStyle);
        style_wavy_line.* = ZuiStyle.initWavyLineBorders();
        try styles.append(style_wavy_line);

        const style_rounded_box = try allocator.create(ZuiStyle);
        style_rounded_box.* = ZuiStyle.initRoundedBoxBorders();
        try styles.append(style_rounded_box);

        const style_neovim = try allocator.create(ZuiStyle);
        style_neovim.* = ZuiStyle.initNeoVim();
        try styles.append(style_neovim);

        const style_rounded_dash = try allocator.create(ZuiStyle);
        style_rounded_dash.* = ZuiStyle.initRoundedDashBorders();
        try styles.append(style_rounded_dash);

        const style_curved_flow = try allocator.create(ZuiStyle);
        style_curved_flow.* = ZuiStyle.initCurvedFlowBorders();
        try styles.append(style_curved_flow);

        const style_zig_zag = try allocator.create(ZuiStyle);
        style_zig_zag.* = ZuiStyle.initZigZagBorders();
        try styles.append(style_zig_zag);

        const style_soft_wave = try allocator.create(ZuiStyle);
        style_soft_wave.* = ZuiStyle.initSoftWaveBorders();
        try styles.append(style_soft_wave);

        const style_dashed_frame = try allocator.create(ZuiStyle);
        style_dashed_frame.* = ZuiStyle.initDashedFrameBorders();
        try styles.append(style_dashed_frame);

        const style_double_dash = try allocator.create(ZuiStyle);
        style_double_dash.* = ZuiStyle.initDoubleDashBorders();
        try styles.append(style_double_dash);

        const style_heavy_arc = try allocator.create(ZuiStyle);
        style_heavy_arc.* = ZuiStyle.initHeavyArcBorders();
        try styles.append(style_heavy_arc);

        const style_mixed_weight = try allocator.create(ZuiStyle);
        style_mixed_weight.* = ZuiStyle.initMixedWeightBorders();
        try styles.append(style_mixed_weight);

        const style_quad_dash = try allocator.create(ZuiStyle);
        style_quad_dash.* = ZuiStyle.initQuadDashBorders();
        try styles.append(style_quad_dash);

        const style_light_cross = try allocator.create(ZuiStyle);
        style_light_cross.* = ZuiStyle.initLightCrossBorders();
        try styles.append(style_light_cross);

        const style_heavy_cross = try allocator.create(ZuiStyle);
        style_heavy_cross.* = ZuiStyle.initHeavyCrossBorders();
        try styles.append(style_heavy_cross);

        const style_ascii_plus = try allocator.create(ZuiStyle);
        style_ascii_plus.* = ZuiStyle.initAsciiPlusBorders();
        try styles.append(style_ascii_plus);

        const style_ascii_star = try allocator.create(ZuiStyle);
        style_ascii_star.* = ZuiStyle.initAsciiStarBorders();
        try styles.append(style_ascii_star);

        const style_ascii_hash = try allocator.create(ZuiStyle);
        style_ascii_hash.* = ZuiStyle.initAsciiHashBorders();
        try styles.append(style_ascii_hash);

        const style_ascii_angle = try allocator.create(ZuiStyle);
        style_ascii_angle.* = ZuiStyle.initAsciiAngleBorders();
        try styles.append(style_ascii_angle);

        const style_ascii_dot_dash = try allocator.create(ZuiStyle);
        style_ascii_dot_dash.* = ZuiStyle.initAsciiDotDashBorders();
        try styles.append(style_ascii_dot_dash);

        const style_ascii_bracket = try allocator.create(ZuiStyle);
        style_ascii_bracket.* = ZuiStyle.initAsciiBracketBorders();
        try styles.append(style_ascii_bracket);

        return styles;
    }
};

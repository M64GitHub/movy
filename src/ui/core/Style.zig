const std = @import("std");

/// Defines style classes for UI elements—maps to characters for rendering.
pub const StyleClass = enum {
    WindowUpperLeftCorner,
    WindowUpperRightCorner,
    WindowLowerLeftCorner,
    WindowLowerRightCorner,
    WindowVerticalBorder,
    WindowHorizontalBorder,
    WindowTitleLeft,
    WindowTitleRight,
};

/// Manages character-based styling for UI elements—maps StyleClass to u21.
pub const Style = struct {
    name: []const u8, // Style name—e.g., "Default", "ThinBorders"
    chars: std.EnumArray(StyleClass, u21), // Fixed mapping for fast lookups

    /// Initializes a default style with classic ASCII window characters.
    pub fn initDefault() Style {
        var style = Style{
            .name = "Default",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initThinBorders() Style {
        var style = Style{
            .name = "ThinBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initFullBlockBorders() Style {
        var style = Style{
            .name = "FullBlockBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initShadedBlockBorders() Style {
        var style = Style{
            .name = "ShadedBlockBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initDottedBorders() Style {
        var style = Style{
            .name = "DottedBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initStarBorders() Style {
        var style = Style{
            .name = "StarBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initInvertedStarBorders() Style {
        var style = Style{
            .name = "InvertedStarBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initCircuitBorders() Style {
        var style = Style{
            .name = "CircuitBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initHeartBorders() Style {
        var style = Style{
            .name = "HeartBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initPixelArtBorders() Style {
        var style = Style{
            .name = "PixelArtBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initNeonGlowBorders() Style {
        var style = Style{
            .name = "NeonGlowBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initGlitchBorders() Style {
        var style = Style{
            .name = "GlitchBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initDiamondBorders() Style {
        var style = Style{
            .name = "DiamondBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initBinary() Style {
        var style = Style{
            .name = "Binary",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initCosmicWaveBorders() Style {
        var style = Style{
            .name = "CosmicWaveBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initRectoidBorders() Style {
        var style = Style{
            .name = "RectoidBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initQuantumGridBorders() Style {
        var style = Style{
            .name = "QuantumGridBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initHoloFractalBorders() Style {
        var style = Style{
            .name = "HoloFractalBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAetherialBorders() Style {
        var style = Style{
            .name = "AetherialBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initWavyLineBorders() Style {
        var style = Style{
            .name = "WavyLineBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initRoundedBoxBorders() Style {
        var style = Style{
            .name = "RoundedBoxBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initNeoVim() Style {
        var style = Style{
            .name = "NeoVim",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initRoundedDashBorders() Style {
        var style = Style{
            .name = "RoundedDashBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initCurvedFlowBorders() Style {
        var style = Style{
            .name = "CurvedFlowBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initZigZagBorders() Style {
        var style = Style{
            .name = "ZigZagBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initSoftWaveBorders() Style {
        var style = Style{
            .name = "SoftWaveBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initDashedFrameBorders() Style {
        var style = Style{
            .name = "DashedFrameBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initDoubleDashBorders() Style {
        var style = Style{
            .name = "DoubleDashBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initHeavyArcBorders() Style {
        var style = Style{
            .name = "HeavyArcBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initMixedWeightBorders() Style {
        var style = Style{
            .name = "MixedWeightBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initQuadDashBorders() Style {
        var style = Style{
            .name = "QuadDashBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initLightCrossBorders() Style {
        var style = Style{
            .name = "LightCrossBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initHeavyCrossBorders() Style {
        var style = Style{
            .name = "HeavyCrossBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiPlusBorders() Style {
        var style = Style{
            .name = "AsciiPlusBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiStarBorders() Style {
        var style = Style{
            .name = "AsciiStarBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiHashBorders() Style {
        var style = Style{
            .name = "AsciiHashBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiAngleBorders() Style {
        var style = Style{
            .name = "AsciiAngleBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiDotDashBorders() Style {
        var style = Style{
            .name = "AsciiDotDashBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn initAsciiBracketBorders() Style {
        var style = Style{
            .name = "AsciiBracketBorders",
            .chars = std.EnumArray(StyleClass, u21).initUndefined(),
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
    pub fn getChar(self: *const Style, class: StyleClass) u21 {
        return self.chars.get(class);
    }

    /// Updates the character for a given style class—flexible customization.
    pub fn setChar(self: *Style, class: StyleClass, char: u21) void {
        self.chars.set(class, char);
    }

    /// Gathers all available styles into an ArrayList.
    pub fn getAllStyles(allocator: std.mem.Allocator) !std.ArrayList(*const Style) {
        var styles = std.ArrayList(*const Style).init(allocator);

        // Allocate, append, and initialize each style
        const style_default = try allocator.create(Style);
        style_default.* = Style.initDefault();
        try styles.append(style_default);

        const style_thin = try allocator.create(Style);
        style_thin.* = Style.initThinBorders();
        try styles.append(style_thin);

        const style_full_block = try allocator.create(Style);
        style_full_block.* = Style.initFullBlockBorders();
        try styles.append(style_full_block);

        const style_shaded_block = try allocator.create(Style);
        style_shaded_block.* = Style.initShadedBlockBorders();
        try styles.append(style_shaded_block);

        const style_dotted = try allocator.create(Style);
        style_dotted.* = Style.initDottedBorders();
        try styles.append(style_dotted);

        const style_star = try allocator.create(Style);
        style_star.* = Style.initStarBorders();
        try styles.append(style_star);

        const style_inverted_star = try allocator.create(Style);
        style_inverted_star.* = Style.initInvertedStarBorders();
        try styles.append(style_inverted_star);

        const style_circuit = try allocator.create(Style);
        style_circuit.* = Style.initCircuitBorders();
        try styles.append(style_circuit);

        const style_heart = try allocator.create(Style);
        style_heart.* = Style.initHeartBorders();
        try styles.append(style_heart);

        const style_pixel_art = try allocator.create(Style);
        style_pixel_art.* = Style.initPixelArtBorders();
        try styles.append(style_pixel_art);

        const style_neon_glow = try allocator.create(Style);
        style_neon_glow.* = Style.initNeonGlowBorders();
        try styles.append(style_neon_glow);

        const style_glitch = try allocator.create(Style);
        style_glitch.* = Style.initGlitchBorders();
        try styles.append(style_glitch);

        const style_diamond = try allocator.create(Style);
        style_diamond.* = Style.initDiamondBorders();
        try styles.append(style_diamond);

        const style_binary = try allocator.create(Style);
        style_binary.* = Style.initBinary();
        try styles.append(style_binary);

        const style_cosmic_wave = try allocator.create(Style);
        style_cosmic_wave.* = Style.initCosmicWaveBorders();
        try styles.append(style_cosmic_wave);

        const style_rectoid = try allocator.create(Style);
        style_rectoid.* = Style.initRectoidBorders();
        try styles.append(style_rectoid);

        const style_quantum_grid = try allocator.create(Style);
        style_quantum_grid.* = Style.initQuantumGridBorders();
        try styles.append(style_quantum_grid);

        const style_holo_fractal = try allocator.create(Style);
        style_holo_fractal.* = Style.initHoloFractalBorders();
        try styles.append(style_holo_fractal);

        const style_aetherial = try allocator.create(Style);
        style_aetherial.* = Style.initAetherialBorders();
        try styles.append(style_aetherial);

        const style_wavy_line = try allocator.create(Style);
        style_wavy_line.* = Style.initWavyLineBorders();
        try styles.append(style_wavy_line);

        const style_rounded_box = try allocator.create(Style);
        style_rounded_box.* = Style.initRoundedBoxBorders();
        try styles.append(style_rounded_box);

        const style_neovim = try allocator.create(Style);
        style_neovim.* = Style.initNeoVim();
        try styles.append(style_neovim);

        const style_rounded_dash = try allocator.create(Style);
        style_rounded_dash.* = Style.initRoundedDashBorders();
        try styles.append(style_rounded_dash);

        const style_curved_flow = try allocator.create(Style);
        style_curved_flow.* = Style.initCurvedFlowBorders();
        try styles.append(style_curved_flow);

        const style_zig_zag = try allocator.create(Style);
        style_zig_zag.* = Style.initZigZagBorders();
        try styles.append(style_zig_zag);

        const style_soft_wave = try allocator.create(Style);
        style_soft_wave.* = Style.initSoftWaveBorders();
        try styles.append(style_soft_wave);

        const style_dashed_frame = try allocator.create(Style);
        style_dashed_frame.* = Style.initDashedFrameBorders();
        try styles.append(style_dashed_frame);

        const style_double_dash = try allocator.create(Style);
        style_double_dash.* = Style.initDoubleDashBorders();
        try styles.append(style_double_dash);

        const style_heavy_arc = try allocator.create(Style);
        style_heavy_arc.* = Style.initHeavyArcBorders();
        try styles.append(style_heavy_arc);

        const style_mixed_weight = try allocator.create(Style);
        style_mixed_weight.* = Style.initMixedWeightBorders();
        try styles.append(style_mixed_weight);

        const style_quad_dash = try allocator.create(Style);
        style_quad_dash.* = Style.initQuadDashBorders();
        try styles.append(style_quad_dash);

        const style_light_cross = try allocator.create(Style);
        style_light_cross.* = Style.initLightCrossBorders();
        try styles.append(style_light_cross);

        const style_heavy_cross = try allocator.create(Style);
        style_heavy_cross.* = Style.initHeavyCrossBorders();
        try styles.append(style_heavy_cross);

        const style_ascii_plus = try allocator.create(Style);
        style_ascii_plus.* = Style.initAsciiPlusBorders();
        try styles.append(style_ascii_plus);

        const style_ascii_star = try allocator.create(Style);
        style_ascii_star.* = Style.initAsciiStarBorders();
        try styles.append(style_ascii_star);

        const style_ascii_hash = try allocator.create(Style);
        style_ascii_hash.* = Style.initAsciiHashBorders();
        try styles.append(style_ascii_hash);

        const style_ascii_angle = try allocator.create(Style);
        style_ascii_angle.* = Style.initAsciiAngleBorders();
        try styles.append(style_ascii_angle);

        const style_ascii_dot_dash = try allocator.create(Style);
        style_ascii_dot_dash.* = Style.initAsciiDotDashBorders();
        try styles.append(style_ascii_dot_dash);

        const style_ascii_bracket = try allocator.create(Style);
        style_ascii_bracket.* = Style.initAsciiBracketBorders();
        try styles.append(style_ascii_bracket);

        return styles;
    }
};

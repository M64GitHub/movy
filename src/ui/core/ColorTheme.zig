const std = @import("std");
const movy = @import("../../movy.zig");

/// Defines color classes for theming
pub const ColorClass = enum {
    WindowBorder, // Standard window border color
    WindowCorner, // Custom color for window corners
    WindowTitle, // Color for window titles
    WindowInnerBorder, // Inner border for nested elements
    BackgroundColor, // General background color
    TextColor, // Standard text color
    Heading1, // # Bright headline
    Heading2, // ## Subtle headline
    Heading3, // ### Deeper headline
    Hyperlink, // Clickable links
    CodeText, // Code block text
    CodeBackground, // Code block background
    ButtonText, // Text on buttons
    ButtonBackground, // Button background
    Highlight, // Highlighted or selected elements
    Keyword, // Keywords, HTML elements, regex symbols
    Constant, // Number/boolean constants
    Parameter, // Function parameters
    String, // Strings, CSS class names
    ObjectKey, // Object literal keys, Markdown links
    RegexString, // Regex literal strings
    SupportFunction, // Language support functions, CSS HTML elements
    Property, // Object properties, regex quantifiers
    Comment, // Code comments
    Foreground, // Editor foreground
    MarkdownText, // Markdown plain text
    TerminalBlack, // Terminal black
};

/// Manages color assignments for UI elements—maps ColorClass to Rgb
/// with a name.
pub const ColorTheme = struct {
    name: []const u8, // Theme name—e.g., "TokyoNight-Storm"
    // Fixed mapping for fast lookups
    colors: std.EnumArray(ColorClass, movy.core.types.Rgb),

    /// Initializes a TokyoNight-Storm theme—dark, vibrant, and inspired by
    /// TokyoNight.
    pub fn initTokyoNightStorm() ColorTheme {
        var theme = ColorTheme{
            .name = "TokyoNight-Storm",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Grayish blue
        theme.colors.set(.WindowBorder, .{ .r = 108, .g = 112, .b = 134 });
        // Warm orange
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 184, .b = 108 });
        // Soft purple
        theme.colors.set(.WindowTitle, .{ .r = 180, .g = 142, .b = 173 });
        // Darker gray-blue
        theme.colors.set(.WindowInnerBorder, .{ .r = 88, .g = 92, .b = 112 });
        // Deep blue-gray (Storm bg)
        theme.colors.set(.BackgroundColor, .{ .r = 36, .g = 40, .b = 59 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 201, .g = 209, .b = 232 });
        // Near-white pinkish
        theme.colors.set(.Heading1, .{ .r = 245, .g = 224, .b = 220 });
        // Peachy orange
        theme.colors.set(.Heading2, .{ .r = 250, .g = 179, .b = 135 });
        // Sky blue
        theme.colors.set(.Heading3, .{ .r = 137, .g = 180, .b = 250 });
        // Teal
        theme.colors.set(.Hyperlink, .{ .r = 148, .g = 226, .b = 213 });
        // Lime yellow
        theme.colors.set(.CodeText, .{ .r = 241, .g = 250, .b = 140 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 58, .g = 62, .b = 81 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 201, .g = 209, .b = 232 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 66, .g = 71, .b = 92 });
        // Warm orange
        theme.colors.set(.Highlight, .{ .r = 255, .g = 184, .b = 108 });
        // Red-pink
        theme.colors.set(.Keyword, .{ .r = 247, .g = 118, .b = 142 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 255, .g = 158, .b = 100 });
        // Light grayish
        theme.colors.set(.Parameter, .{ .r = 207, .g = 201, .b = 194 });
        // Green
        theme.colors.set(.String, .{ .r = 158, .g = 206, .b = 106 });
        // Teal-green
        theme.colors.set(.ObjectKey, .{ .r = 115, .g = 218, .b = 202 });
        // Cyan
        theme.colors.set(.RegexString, .{ .r = 180, .g = 249, .b = 248 });
        // Bright teal
        theme.colors.set(.SupportFunction, .{ .r = 42, .g = 195, .b = 222 });
        // Light blue
        theme.colors.set(.Property, .{ .r = 125, .g = 207, .b = 255 });
        // Dark blue-gray
        theme.colors.set(.Comment, .{ .r = 86, .g = 95, .b = 137 });
        // Mid gray-blue
        theme.colors.set(.Foreground, .{ .r = 169, .g = 177, .b = 214 });
        // Light blue-gray
        theme.colors.set(.MarkdownText, .{ .r = 154, .g = 165, .b = 206 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 65, .g = 72, .b = 104 });
        return theme;
    }

    /// Initializes a Gruvbox theme—warm, retro, and easy on the eyes.
    pub fn initGruvbox() ColorTheme {
        var theme = ColorTheme{
            .name = "Gruvbox",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark gray-brown
        theme.colors.set(.WindowBorder, .{ .r = 88, .g = 81, .b = 71 });
        // Warm orange
        theme.colors.set(.WindowCorner, .{ .r = 214, .g = 134, .b = 48 });
        // Light beige
        theme.colors.set(.WindowTitle, .{ .r = 235, .g = 219, .b = 178 });
        // Darker gray-brown
        theme.colors.set(.WindowInnerBorder, .{ .r = 66, .g = 60, .b = 53 });
        // Deep brown background
        theme.colors.set(.BackgroundColor, .{ .r = 40, .g = 37, .b = 32 });
        // Light beige text
        theme.colors.set(.TextColor, .{ .r = 235, .g = 219, .b = 178 });
        // Bright orange
        theme.colors.set(.Heading1, .{ .r = 254, .g = 128, .b = 25 });
        // Soft yellow
        theme.colors.set(.Heading2, .{ .r = 223, .g = 175, .b = 72 });
        // Pale green
        theme.colors.set(.Heading3, .{ .r = 166, .g = 216, .b = 104 });
        // Aqua
        theme.colors.set(.Hyperlink, .{ .r = 104, .g = 157, .b = 106 });
        // Bright yellow
        theme.colors.set(.CodeText, .{ .r = 250, .g = 189, .b = 47 });
        // Dark gray
        theme.colors.set(.CodeBackground, .{ .r = 60, .g = 56, .b = 49 });
        // Light beige
        theme.colors.set(.ButtonText, .{ .r = 235, .g = 219, .b = 178 });
        // Darker gray
        theme.colors.set(.ButtonBackground, .{ .r = 80, .g = 73, .b = 64 });
        // Warm orange
        theme.colors.set(.Highlight, .{ .r = 214, .g = 134, .b = 48 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 204, .g = 36, .b = 29 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 214, .g = 93, .b = 14 });
        // Light beige
        theme.colors.set(.Parameter, .{ .r = 235, .g = 219, .b = 178 });
        // Green
        theme.colors.set(.String, .{ .r = 152, .g = 151, .b = 26 });
        // Aqua
        theme.colors.set(.ObjectKey, .{ .r = 104, .g = 157, .b = 106 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 131, .g = 165, .b = 152 });
        // Purple
        theme.colors.set(.SupportFunction, .{ .r = 211, .g = 134, .b = 155 });
        // Light gray
        theme.colors.set(.Property, .{ .r = 189, .g = 174, .b = 147 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 102, .g = 92, .b = 84 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 168, .g = 153, .b = 132 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 189, .g = 174, .b = 147 });
        // Dark brown
        theme.colors.set(.TerminalBlack, .{ .r = 50, .g = 46, .b = 40 });
        return theme;
    }

    /// Initializes a Catppuccin Mocha theme—warm, muted, and elegant.
    pub fn initCatppuccinMocha() ColorTheme {
        var theme = ColorTheme{
            .name = "Catppuccin-Mocha",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark mauve
        theme.colors.set(.WindowBorder, .{ .r = 108, .g = 92, .b = 131 });
        // Soft peach
        theme.colors.set(.WindowCorner, .{ .r = 242, .g = 205, .b = 205 });
        // Light lavender
        theme.colors.set(.WindowTitle, .{ .r = 180, .g = 169, .b = 211 });
        // Darker mauve
        theme.colors.set(.WindowInnerBorder, .{ .r = 88, .g = 74, .b = 105 });
        // Deep mocha background
        theme.colors.set(.BackgroundColor, .{ .r = 30, .g = 30, .b = 46 });
        // Light beige
        theme.colors.set(.TextColor, .{ .r = 205, .g = 214, .b = 244 });
        // Bright pink
        theme.colors.set(.Heading1, .{ .r = 243, .g = 166, .b = 182 });
        // Soft peach
        theme.colors.set(.Heading2, .{ .r = 242, .g = 205, .b = 205 });
        // Pale yellow
        theme.colors.set(.Heading3, .{ .r = 249, .g = 226, .b = 175 });
        // Teal
        theme.colors.set(.Hyperlink, .{ .r = 148, .g = 226, .b = 213 });
        // Green
        theme.colors.set(.CodeText, .{ .r = 166, .g = 227, .b = 161 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 49, .g = 50, .b = 68 });
        // Light beige
        theme.colors.set(.ButtonText, .{ .r = 205, .g = 214, .b = 244 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 69, .g = 71, .b = 90 });
        // Warm peach
        theme.colors.set(.Highlight, .{ .r = 242, .g = 205, .b = 205 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 243, .g = 139, .b = 168 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 250, .g = 179, .b = 135 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 186, .g = 194, .b = 222 });
        // Green
        theme.colors.set(.String, .{ .r = 166, .g = 227, .b = 161 });
        // Teal
        theme.colors.set(.ObjectKey, .{ .r = 148, .g = 226, .b = 213 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 137, .g = 220, .b = 235 });
        // Blue
        theme.colors.set(.SupportFunction, .{ .r = 116, .g = 199, .b = 236 });
        // Light purple
        theme.colors.set(.Property, .{ .r = 180, .g = 190, .b = 254 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 108, .g = 112, .b = 134 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 147, .g = 153, .b = 178 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 166, .g = 173, .b = 200 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 69, .g = 71, .b = 90 });
        return theme;
    }

    /// Initializes a Dracula theme—dark, vibrant, and modern.
    pub fn initDracula() ColorTheme {
        var theme = ColorTheme{
            .name = "Dracula",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark purple
        theme.colors.set(.WindowBorder, .{ .r = 98, .g = 114, .b = 164 });
        // Bright pink
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 85, .b = 85 });
        // Light purple
        theme.colors.set(.WindowTitle, .{ .r = 189, .g = 147, .b = 249 });
        // Darker purple
        theme.colors.set(.WindowInnerBorder, .{ .r = 78, .g = 91, .b = 131 });
        // Deep gray background
        theme.colors.set(.BackgroundColor, .{ .r = 40, .g = 42, .b = 54 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 248, .g = 248, .b = 242 });
        // Bright pink
        theme.colors.set(.Heading1, .{ .r = 255, .g = 85, .b = 85 });
        // Light purple
        theme.colors.set(.Heading2, .{ .r = 189, .g = 147, .b = 249 });
        // Cyan
        theme.colors.set(.Heading3, .{ .r = 139, .g = 233, .b = 253 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 80, .g = 250, .b = 123 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 241, .g = 250, .b = 140 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 68, .g = 71, .b = 90 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 248, .g = 248, .b = 242 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 88, .g = 91, .b = 112 });
        // Bright pink
        theme.colors.set(.Highlight, .{ .r = 255, .g = 85, .b = 85 });
        // Pink
        theme.colors.set(.Keyword, .{ .r = 255, .g = 85, .b = 85 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 255, .g = 184, .b = 108 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 248, .g = 248, .b = 242 });
        // Green
        theme.colors.set(.String, .{ .r = 80, .g = 250, .b = 123 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 139, .g = 233, .b = 253 });
        // Light purple
        theme.colors.set(.RegexString, .{ .r = 189, .g = 147, .b = 249 });
        // Purple
        theme.colors.set(.SupportFunction, .{ .r = 189, .g = 147, .b = 249 });
        // Light blue
        theme.colors.set(.Property, .{ .r = 139, .g = 233, .b = 253 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 98, .g = 114, .b = 164 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 178, .g = 190, .b = 235 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 158, .g = 173, .b = 211 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 68, .g = 71, .b = 90 });
        return theme;
    }

    /// Initializes a Nord theme—cool, arctic, and minimalist.
    pub fn initNord() ColorTheme {
        var theme = ColorTheme{
            .name = "Nord",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark blue-gray
        theme.colors.set(.WindowBorder, .{ .r = 94, .g = 129, .b = 172 });
        // Frosty blue
        theme.colors.set(.WindowCorner, .{ .r = 136, .g = 192, .b = 208 });
        // Light blue
        theme.colors.set(.WindowTitle, .{ .r = 163, .g = 190, .b = 230 });
        // Darker blue-gray
        theme.colors.set(.WindowInnerBorder, .{ .r = 74, .g = 103, .b = 138 });
        // Deep nordic background
        theme.colors.set(.BackgroundColor, .{ .r = 46, .g = 52, .b = 64 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 216, .g = 222, .b = 233 });
        // Snow white
        theme.colors.set(.Heading1, .{ .r = 236, .g = 239, .b = 244 });
        // Frosty blue
        theme.colors.set(.Heading2, .{ .r = 136, .g = 192, .b = 208 });
        // Pale blue
        theme.colors.set(.Heading3, .{ .r = 129, .g = 161, .b = 193 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 163, .g = 190, .b = 140 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 208, .g = 191, .b = 140 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 59, .g = 66, .b = 82 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 216, .g = 222, .b = 233 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 76, .g = 86, .b = 106 });
        // Frosty blue
        theme.colors.set(.Highlight, .{ .r = 136, .g = 192, .b = 208 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 191, .g = 97, .b = 106 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 208, .g = 135, .b = 112 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 216, .g = 222, .b = 233 });
        // Green
        theme.colors.set(.String, .{ .r = 163, .g = 190, .b = 140 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 136, .g = 192, .b = 208 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 129, .g = 161, .b = 193 });
        // Blue
        theme.colors.set(.SupportFunction, .{ .r = 94, .g = 129, .b = 172 });
        // Light blue
        theme.colors.set(.Property, .{ .r = 129, .g = 161, .b = 193 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 106, .g = 120, .b = 148 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 143, .g = 160, .b = 193 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 163, .g = 179, .b = 211 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 59, .g = 66, .b = 82 });
        return theme;
    }

    /// Initializes a Monokai theme—classic, vibrant, and high-contrast.
    pub fn initMonokai() ColorTheme {
        var theme = ColorTheme{
            .name = "Monokai",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark gray
        theme.colors.set(.WindowBorder, .{ .r = 64, .g = 64, .b = 64 });
        // Neon orange
        theme.colors.set(.WindowCorner, .{ .r = 253, .g = 151, .b = 31 });
        // Bright purple
        theme.colors.set(.WindowTitle, .{ .r = 174, .g = 129, .b = 255 });
        // Darker gray
        theme.colors.set(.WindowInnerBorder, .{ .r = 48, .g = 48, .b = 48 });
        // Deep charcoal background
        theme.colors.set(.BackgroundColor, .{ .r = 39, .g = 40, .b = 34 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 248, .g = 248, .b = 242 });
        // Neon yellow
        theme.colors.set(.Heading1, .{ .r = 255, .g = 255, .b = 141 });
        // Bright orange
        theme.colors.set(.Heading2, .{ .r = 253, .g = 151, .b = 31 });
        // Light purple
        theme.colors.set(.Heading3, .{ .r = 174, .g = 129, .b = 255 });
        // Neon green
        theme.colors.set(.Hyperlink, .{ .r = 166, .g = 226, .b = 46 });
        // Bright yellow
        theme.colors.set(.CodeText, .{ .r = 255, .g = 255, .b = 141 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 60, .g = 61, .b = 55 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 248, .g = 248, .b = 242 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 80, .g = 81, .b = 75 });
        // Neon orange
        theme.colors.set(.Highlight, .{ .r = 253, .g = 151, .b = 31 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 249, .g = 38, .b = 114 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 253, .g = 151, .b = 31 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 248, .g = 248, .b = 242 });
        // Neon green
        theme.colors.set(.String, .{ .r = 166, .g = 226, .b = 46 });
        // Purple
        theme.colors.set(.ObjectKey, .{ .r = 174, .g = 129, .b = 255 });
        // Light purple
        theme.colors.set(.RegexString, .{ .r = 174, .g = 129, .b = 255 });
        // Cyan
        theme.colors.set(.SupportFunction, .{ .r = 102, .g = 217, .b = 239 });
        // Light blue
        theme.colors.set(.Property, .{ .r = 102, .g = 217, .b = 239 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 117, .g = 113, .b = 94 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 188, .g = 188, .b = 182 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 168, .g = 168, .b = 162 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 60, .g = 61, .b = 55 });
        return theme;
    }

    /// Initializes a Sublime Text Mariana theme—balanced, modern, and vibrant.
    pub fn initSublimeMariana() ColorTheme {
        var theme = ColorTheme{
            .name = "Sublime-Mariana",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark teal
        theme.colors.set(.WindowBorder, .{ .r = 68, .g = 85, .b = 104 });
        // Soft coral
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 128, .b = 128 });
        // Light blue
        theme.colors.set(.WindowTitle, .{ .r = 135, .g = 188, .b = 255 });
        // Darker teal
        theme.colors.set(.WindowInnerBorder, .{ .r = 54, .g = 68, .b = 83 });
        // Deep blue-gray background
        theme.colors.set(.BackgroundColor, .{ .r = 40, .g = 44, .b = 52 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 220, .g = 220, .b = 220 });
        // Bright pink
        theme.colors.set(.Heading1, .{ .r = 255, .g = 128, .b = 128 });
        // Soft yellow
        theme.colors.set(.Heading2, .{ .r = 255, .g = 204, .b = 102 });
        // Pale blue
        theme.colors.set(.Heading3, .{ .r = 135, .g = 188, .b = 255 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 153, .g = 204, .b = 153 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 255, .g = 204, .b = 102 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 60, .g = 66, .b = 78 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 220, .g = 220, .b = 220 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 80, .g = 88, .b = 104 });
        // Soft coral
        theme.colors.set(.Highlight, .{ .r = 255, .g = 128, .b = 128 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 255, .g = 97, .b = 136 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 255, .g = 160, .b = 122 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 220, .g = 220, .b = 220 });
        // Green
        theme.colors.set(.String, .{ .r = 153, .g = 204, .b = 153 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 102, .g = 217, .b = 239 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 135, .g = 188, .b = 255 });
        // Blue
        theme.colors.set(.SupportFunction, .{ .r = 102, .g = 217, .b = 239 });
        // Light purple
        theme.colors.set(.Property, .{ .r = 135, .g = 188, .b = 255 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 92, .g = 99, .b = 112 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 160, .g = 172, .b = 196 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 140, .g = 152, .b = 176 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 60, .g = 66, .b = 78 });
        return theme;
    }

    /// Initializes a Solarized Dark theme—balanced, scientific, and eye-friendly.
    pub fn initSolarizedDark() ColorTheme {
        var theme = ColorTheme{
            .name = "Solarized-Dark",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Base1 (dark gray-blue)
        theme.colors.set(.WindowBorder, .{ .r = 88, .g = 110, .b = 117 });
        // Yellow
        theme.colors.set(.WindowCorner, .{ .r = 181, .g = 137, .b = 0 });
        // Cyan
        theme.colors.set(.WindowTitle, .{ .r = 42, .g = 161, .b = 152 });
        // Base02 (darker gray)
        theme.colors.set(.WindowInnerBorder, .{ .r = 7, .g = 54, .b = 66 });
        // Base03 (dark background)
        theme.colors.set(.BackgroundColor, .{ .r = 0, .g = 43, .b = 54 });
        // Base0 (light gray)
        theme.colors.set(.TextColor, .{ .r = 131, .g = 148, .b = 150 });
        // Orange
        theme.colors.set(.Heading1, .{ .r = 203, .g = 75, .b = 22 });
        // Yellow
        theme.colors.set(.Heading2, .{ .r = 181, .g = 137, .b = 0 });
        // Cyan
        theme.colors.set(.Heading3, .{ .r = 42, .g = 161, .b = 152 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 133, .g = 153, .b = 0 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 181, .g = 137, .b = 0 });
        // Base02 (darker gray)
        theme.colors.set(.CodeBackground, .{ .r = 7, .g = 54, .b = 66 });
        // Base0 (light gray)
        theme.colors.set(.ButtonText, .{ .r = 131, .g = 148, .b = 150 });
        // Base01 (mid gray)
        theme.colors.set(.ButtonBackground, .{ .r = 88, .g = 110, .b = 117 });
        // Orange
        theme.colors.set(.Highlight, .{ .r = 203, .g = 75, .b = 22 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 220, .g = 50, .b = 47 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 203, .g = 75, .b = 22 });
        // Base0 (light gray)
        theme.colors.set(.Parameter, .{ .r = 131, .g = 148, .b = 150 });
        // Green
        theme.colors.set(.String, .{ .r = 133, .g = 153, .b = 0 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 42, .g = 161, .b = 152 });
        // Blue
        theme.colors.set(.RegexString, .{ .r = 38, .g = 139, .b = 210 });
        // Violet
        theme.colors.set(.SupportFunction, .{ .r = 108, .g = 113, .b = 196 });
        // Blue
        theme.colors.set(.Property, .{ .r = 38, .g = 139, .b = 210 });
        // Base1 (dark gray-blue)
        theme.colors.set(.Comment, .{ .r = 88, .g = 110, .b = 117 });
        // Base0 (light gray)
        theme.colors.set(.Foreground, .{ .r = 131, .g = 148, .b = 150 });
        // Base0 (light gray)
        theme.colors.set(.MarkdownText, .{ .r = 131, .g = 148, .b = 150 });
        // Base02 (darker gray)
        theme.colors.set(.TerminalBlack, .{ .r = 7, .g = 54, .b = 66 });
        return theme;
    }

    /// Initializes a Tomorrow Night theme—soft, calming, and readable.
    pub fn initTomorrowNight() ColorTheme {
        var theme = ColorTheme{
            .name = "Tomorrow-Night",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark gray
        theme.colors.set(.WindowBorder, .{ .r = 92, .g = 99, .b = 112 });
        // Soft orange
        theme.colors.set(.WindowCorner, .{ .r = 209, .g = 103, .b = 85 });
        // Light blue
        theme.colors.set(.WindowTitle, .{ .r = 102, .g = 144, .b = 199 });
        // Darker gray
        theme.colors.set(.WindowInnerBorder, .{ .r = 72, .g = 79, .b = 92 });
        // Deep gray background
        theme.colors.set(.BackgroundColor, .{ .r = 44, .g = 49, .b = 55 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 197, .g = 200, .b = 198 });
        // Bright red
        theme.colors.set(.Heading1, .{ .r = 209, .g = 103, .b = 85 });
        // Soft yellow
        theme.colors.set(.Heading2, .{ .r = 197, .g = 165, .b = 88 });
        // Pale blue
        theme.colors.set(.Heading3, .{ .r = 102, .g = 144, .b = 199 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 127, .g = 162, .b = 104 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 197, .g = 165, .b = 88 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 64, .g = 69, .b = 75 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 197, .g = 200, .b = 198 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 84, .g = 89, .b = 95 });
        // Soft orange
        theme.colors.set(.Highlight, .{ .r = 209, .g = 103, .b = 85 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 209, .g = 103, .b = 85 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 197, .g = 165, .b = 88 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 197, .g = 200, .b = 198 });
        // Green
        theme.colors.set(.String, .{ .r = 127, .g = 162, .b = 104 });
        // Blue
        theme.colors.set(.ObjectKey, .{ .r = 102, .g = 144, .b = 199 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 102, .g = 144, .b = 199 });
        // Purple
        theme.colors.set(.SupportFunction, .{ .r = 148, .g = 127, .b = 162 });
        // Light purple
        theme.colors.set(.Property, .{ .r = 148, .g = 127, .b = 162 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 92, .g = 99, .b = 112 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 147, .g = 150, .b = 148 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 167, .g = 170, .b = 168 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 64, .g = 69, .b = 75 });
        return theme;
    }

    /// Initializes a Shades of Purple theme—bold, vibrant, and purple-heavy.
    pub fn initShadesOfPurple() ColorTheme {
        var theme = ColorTheme{
            .name = "Shades-of-Purple",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark purple
        theme.colors.set(.WindowBorder, .{ .r = 98, .g = 77, .b = 149 });
        // Bright orange
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 184, .b = 108 });
        // Light purple
        theme.colors.set(.WindowTitle, .{ .r = 165, .g = 141, .b = 215 });
        // Darker purple
        theme.colors.set(.WindowInnerBorder, .{ .r = 78, .g = 61, .b = 119 });
        // Deep purple background
        theme.colors.set(.BackgroundColor, .{ .r = 48, .g = 38, .b = 74 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 220, .g = 220, .b = 220 });
        // Neon yellow
        theme.colors.set(.Heading1, .{ .r = 255, .g = 255, .b = 141 });
        // Bright orange
        theme.colors.set(.Heading2, .{ .r = 255, .g = 184, .b = 108 });
        // Light purple
        theme.colors.set(.Heading3, .{ .r = 165, .g = 141, .b = 215 });
        // Neon green
        theme.colors.set(.Hyperlink, .{ .r = 166, .g = 226, .b = 46 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 255, .g = 255, .b = 141 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 68, .g = 58, .b = 94 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 220, .g = 220, .b = 220 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 88, .g = 78, .b = 114 });
        // Bright orange
        theme.colors.set(.Highlight, .{ .r = 255, .g = 184, .b = 108 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 255, .g = 85, .b = 85 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 255, .g = 184, .b = 108 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 220, .g = 220, .b = 220 });
        // Green
        theme.colors.set(.String, .{ .r = 166, .g = 226, .b = 46 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 102, .g = 217, .b = 239 });
        // Light purple
        theme.colors.set(.RegexString, .{ .r = 165, .g = 141, .b = 215 });
        // Purple
        theme.colors.set(.SupportFunction, .{ .r = 165, .g = 141, .b = 215 });
        // Light blue
        theme.colors.set(.Property, .{ .r = 102, .g = 217, .b = 239 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 98, .g = 77, .b = 149 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 178, .g = 157, .b = 209 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 158, .g = 137, .b = 189 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 68, .g = 58, .b = 94 });
        return theme;
    }

    /// Initializes a Night Owl theme—night-friendly, accessible, and muted.
    pub fn initNightOwl() ColorTheme {
        var theme = ColorTheme{
            .name = "Night-Owl",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark blue-gray
        theme.colors.set(.WindowBorder, .{ .r = 68, .g = 85, .b = 104 });
        // Soft orange
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 160, .b = 122 });
        // Light purple
        theme.colors.set(.WindowTitle, .{ .r = 149, .g = 141, .b = 255 });
        // Darker blue-gray
        theme.colors.set(.WindowInnerBorder, .{ .r = 54, .g = 68, .b = 83 });
        // Deep blue background
        theme.colors.set(.BackgroundColor, .{ .r = 1, .g = 22, .b = 39 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 205, .g = 219, .b = 232 });
        // Bright pink
        theme.colors.set(.Heading1, .{ .r = 255, .g = 128, .b = 128 });
        // Soft yellow
        theme.colors.set(.Heading2, .{ .r = 255, .g = 204, .b = 102 });
        // Pale blue
        theme.colors.set(.Heading3, .{ .r = 135, .g = 188, .b = 255 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 153, .g = 204, .b = 153 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 255, .g = 204, .b = 102 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 21, .g = 42, .b = 59 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 205, .g = 219, .b = 232 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 81, .g = 102, .b = 125 });
        // Soft orange
        theme.colors.set(.Highlight, .{ .r = 255, .g = 160, .b = 122 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 255, .g = 97, .b = 136 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 255, .g = 160, .b = 122 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 205, .g = 219, .b = 232 });
        // Green
        theme.colors.set(.String, .{ .r = 153, .g = 204, .b = 153 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 102, .g = 217, .b = 239 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 135, .g = 188, .b = 255 });
        // Blue
        theme.colors.set(.SupportFunction, .{ .r = 102, .g = 217, .b = 239 });
        // Light purple
        theme.colors.set(.Property, .{ .r = 149, .g = 141, .b = 255 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 92, .g = 99, .b = 112 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 155, .g = 169, .b = 182 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 135, .g = 149, .b = 162 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 21, .g = 42, .b = 59 });
        return theme;
    }

    /// Initializes an MS-DOS theme—retro, bold, and terminal-inspired.
    pub fn initMSDOS() ColorTheme {
        var theme = ColorTheme{
            .name = "MS-DOS",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark gray (Argent-inspired)
        theme.colors.set(.WindowBorder, .{ .r = 192, .g = 192, .b = 192 });
        // Red (logo color)
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 0, .b = 0 });
        // Blue (logo color, used for prompts)
        theme.colors.set(.WindowTitle, .{ .r = 0, .g = 0, .b = 255 });
        // Black (default background)
        theme.colors.set(.WindowInnerBorder, .{ .r = 0, .g = 0, .b = 0 });
        // Black background
        theme.colors.set(.BackgroundColor, .{ .r = 0, .g = 0, .b = 0 });
        // White (default text color)
        theme.colors.set(.TextColor, .{ .r = 255, .g = 255, .b = 255 });
        // Yellow (logo color)
        theme.colors.set(.Heading1, .{ .r = 255, .g = 255, .b = 0 });
        // Fuchsia (logo color)
        theme.colors.set(.Heading2, .{ .r = 255, .g = 0, .b = 255 });
        // Cyan (VGA palette)
        theme.colors.set(.Heading3, .{ .r = 0, .g = 255, .b = 255 });
        // Green (VGA palette)
        theme.colors.set(.Hyperlink, .{ .r = 0, .g = 255, .b = 0 });
        // Yellow (for code text)
        theme.colors.set(.CodeText, .{ .r = 255, .g = 255, .b = 0 });
        // Dark gray (Argent-inspired)
        theme.colors.set(.CodeBackground, .{ .r = 192, .g = 192, .b = 192 });
        // White
        theme.colors.set(.ButtonText, .{ .r = 255, .g = 255, .b = 255 });
        // Black
        theme.colors.set(.ButtonBackground, .{ .r = 0, .g = 0, .b = 0 });
        // Red (logo color)
        theme.colors.set(.Highlight, .{ .r = 255, .g = 0, .b = 0 });
        // Red (VGA palette)
        theme.colors.set(.Keyword, .{ .r = 255, .g = 0, .b = 0 });
        // Yellow (VGA palette)
        theme.colors.set(.Constant, .{ .r = 255, .g = 255, .b = 0 });
        // Light gray (Argent)
        theme.colors.set(.Parameter, .{ .r = 192, .g = 192, .b = 192 });
        // Green (VGA palette)
        theme.colors.set(.String, .{ .r = 0, .g = 255, .b = 0 });
        // Cyan (VGA palette)
        theme.colors.set(.ObjectKey, .{ .r = 0, .g = 255, .b = 255 });
        // Blue (VGA palette)
        theme.colors.set(.RegexString, .{ .r = 0, .g = 0, .b = 255 });
        // Fuchsia (VGA palette)
        theme.colors.set(.SupportFunction, .{ .r = 255, .g = 0, .b = 255 });
        // Light gray (Argent)
        theme.colors.set(.Property, .{ .r = 192, .g = 192, .b = 192 });
        // Dark gray (for comments)
        theme.colors.set(.Comment, .{ .r = 128, .g = 128, .b = 128 });
        // Light gray (Argent)
        theme.colors.set(.Foreground, .{ .r = 192, .g = 192, .b = 192 });
        // White
        theme.colors.set(.MarkdownText, .{ .r = 255, .g = 255, .b = 255 });
        // Black
        theme.colors.set(.TerminalBlack, .{ .r = 0, .g = 0, .b = 0 });
        return theme;
    }

    /// Initializes a Turbo Vision theme—classic Borland TUI-inspired, updated for accuracy.
    pub fn initTurboVision() ColorTheme {
        var theme = ColorTheme{
            .name = "Turbo-Vision",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Light gray (window borders)
        theme.colors.set(.WindowBorder, .{ .r = 192, .g = 192, .b = 192 });
        // White (window corner highlights)
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 255, .b = 255 });
        // White (title text on blue background)
        theme.colors.set(.WindowTitle, .{ .r = 255, .g = 255, .b = 255 });
        // Light gray (window background)
        theme.colors.set(.WindowInnerBorder, .{ .r = 192, .g = 192, .b = 192 });
        // Blue (screen background)
        theme.colors.set(.BackgroundColor, .{ .r = 0, .g = 0, .b = 170 });
        // Black (text on gray windows)
        theme.colors.set(.TextColor, .{ .r = 255, .g = 255, .b = 0 });
        // Yellow (highlight headings)
        theme.colors.set(.Heading1, .{ .r = 255, .g = 255, .b = 0 });
        // Green (secondary headings)
        theme.colors.set(.Heading2, .{ .r = 0, .g = 255, .b = 0 });
        // Cyan (tertiary headings)
        theme.colors.set(.Heading3, .{ .r = 0, .g = 255, .b = 255 });
        // Blue (links, often used in menus)
        theme.colors.set(.Hyperlink, .{ .r = 0, .g = 0, .b = 255 });
        // Green (code text, like in the "Find" input)
        theme.colors.set(.CodeText, .{ .r = 0, .g = 255, .b = 0 });
        // Blue (code background, like in the "Find" input)
        theme.colors.set(.CodeBackground, .{ .r = 0, .g = 0, .b = 255 });
        // Green (button text, like "OK" and "Cancel")
        theme.colors.set(.ButtonText, .{ .r = 0, .g = 255, .b = 0 });
        // Light gray (button background)
        theme.colors.set(.ButtonBackground, .{ .r = 192, .g = 192, .b = 192 });
        // Yellow (highlight color, like in checkboxes)
        theme.colors.set(.Highlight, .{ .r = 255, .g = 255, .b = 0 });
        // Red (keywords, for emphasis)
        theme.colors.set(.Keyword, .{ .r = 255, .g = 0, .b = 0 });
        // Yellow (constants)
        theme.colors.set(.Constant, .{ .r = 255, .g = 255, .b = 0 });
        // Black (parameters on gray)
        theme.colors.set(.Parameter, .{ .r = 0, .g = 0, .b = 0 });
        // Green (strings)
        theme.colors.set(.String, .{ .r = 0, .g = 255, .b = 0 });
        // Cyan (object keys)
        theme.colors.set(.ObjectKey, .{ .r = 0, .g = 255, .b = 255 });
        // Blue (regex strings)
        theme.colors.set(.RegexString, .{ .r = 0, .g = 0, .b = 255 });
        // White (support functions)
        theme.colors.set(.SupportFunction, .{ .r = 255, .g = 255, .b = 255 });
        // Black (properties on gray)
        theme.colors.set(.Property, .{ .r = 0, .g = 0, .b = 0 });
        // Dark gray (comments)
        theme.colors.set(.Comment, .{ .r = 128, .g = 128, .b = 128 });
        // White (foreground, like status bar text)
        theme.colors.set(.Foreground, .{ .r = 255, .g = 255, .b = 255 });
        // Black (markdown text on gray)
        theme.colors.set(.MarkdownText, .{ .r = 0, .g = 0, .b = 0 });
        // Black (terminal black)
        theme.colors.set(.TerminalBlack, .{ .r = 0, .g = 0, .b = 0 });
        return theme;
    }

    /// Initializes a One Dark theme—modern, balanced, and professional.
    pub fn initOneDark() ColorTheme {
        var theme = ColorTheme{
            .name = "One-Dark",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Dark gray-blue
        theme.colors.set(.WindowBorder, .{ .r = 85, .g = 87, .b = 96 });
        // Soft orange
        theme.colors.set(.WindowCorner, .{ .r = 202, .g = 128, .b = 92 });
        // Light blue
        theme.colors.set(.WindowTitle, .{ .r = 97, .g = 175, .b = 239 });
        // Darker gray-blue
        theme.colors.set(.WindowInnerBorder, .{ .r = 65, .g = 67, .b = 76 });
        // Deep gray background
        theme.colors.set(.BackgroundColor, .{ .r = 40, .g = 44, .b = 52 });
        // Light gray
        theme.colors.set(.TextColor, .{ .r = 171, .g = 178, .b = 191 });
        // Bright red
        theme.colors.set(.Heading1, .{ .r = 224, .g = 108, .b = 117 });
        // Soft yellow
        theme.colors.set(.Heading2, .{ .r = 229, .g = 192, .b = 123 });
        // Pale blue
        theme.colors.set(.Heading3, .{ .r = 97, .g = 175, .b = 239 });
        // Green
        theme.colors.set(.Hyperlink, .{ .r = 152, .g = 195, .b = 121 });
        // Yellow
        theme.colors.set(.CodeText, .{ .r = 229, .g = 192, .b = 123 });
        // Dark slate
        theme.colors.set(.CodeBackground, .{ .r = 60, .g = 64, .b = 72 });
        // Light gray
        theme.colors.set(.ButtonText, .{ .r = 171, .g = 178, .b = 191 });
        // Darker slate
        theme.colors.set(.ButtonBackground, .{ .r = 80, .g = 84, .b = 92 });
        // Soft orange
        theme.colors.set(.Highlight, .{ .r = 202, .g = 128, .b = 92 });
        // Red
        theme.colors.set(.Keyword, .{ .r = 224, .g = 108, .b = 117 });
        // Orange
        theme.colors.set(.Constant, .{ .r = 202, .g = 128, .b = 92 });
        // Light gray
        theme.colors.set(.Parameter, .{ .r = 171, .g = 178, .b = 191 });
        // Green
        theme.colors.set(.String, .{ .r = 152, .g = 195, .b = 121 });
        // Cyan
        theme.colors.set(.ObjectKey, .{ .r = 86, .g = 182, .b = 194 });
        // Light blue
        theme.colors.set(.RegexString, .{ .r = 97, .g = 175, .b = 239 });
        // Purple
        theme.colors.set(.SupportFunction, .{ .r = 198, .g = 120, .b = 221 });
        // Light purple
        theme.colors.set(.Property, .{ .r = 198, .g = 120, .b = 221 });
        // Dark gray
        theme.colors.set(.Comment, .{ .r = 85, .g = 87, .b = 96 });
        // Mid gray
        theme.colors.set(.Foreground, .{ .r = 131, .g = 138, .b = 151 });
        // Light gray
        theme.colors.set(.MarkdownText, .{ .r = 151, .g = 158, .b = 171 });
        // Dark slate
        theme.colors.set(.TerminalBlack, .{ .r = 60, .g = 64, .b = 72 });
        return theme;
    }

    /// Initializes a Commodore 64 theme—light blue on dark blue with retro accents.
    pub fn initCommodore64() ColorTheme {
        var theme = ColorTheme{
            .name = "Commodore-64",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Light blue (C64 border color)
        theme.colors.set(.WindowBorder, .{ .r = 106, .g = 183, .b = 245 });
        // White (for window corners)
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 255, .b = 255 });
        // Light blue (text color)
        theme.colors.set(.WindowTitle, .{ .r = 106, .g = 183, .b = 245 });
        // Dark blue (window background)
        theme.colors.set(.WindowInnerBorder, .{ .r = 64, .g = 49, .b = 141 });
        // Dark blue (screen background)
        theme.colors.set(.BackgroundColor, .{ .r = 64, .g = 49, .b = 141 });
        // Light blue (default text color)
        theme.colors.set(.TextColor, .{ .r = 106, .g = 183, .b = 245 });
        // Yellow (C64 palette)
        theme.colors.set(.Heading1, .{ .r = 191, .g = 191, .b = 0 });
        // Red (C64 palette)
        theme.colors.set(.Heading2, .{ .r = 136, .g = 0, .b = 0 });
        // Cyan (C64 palette)
        theme.colors.set(.Heading3, .{ .r = 170, .g = 255, .b = 238 });
        // Green (C64 palette)
        theme.colors.set(.Hyperlink, .{ .r = 68, .g = 136, .b = 0 });
        // Yellow (code text)
        theme.colors.set(.CodeText, .{ .r = 191, .g = 191, .b = 0 });
        // Black (code background)
        theme.colors.set(.CodeBackground, .{ .r = 0, .g = 0, .b = 0 });
        // Light blue (button text)
        theme.colors.set(.ButtonText, .{ .r = 106, .g = 183, .b = 245 });
        // Dark blue (button background)
        theme.colors.set(.ButtonBackground, .{ .r = 64, .g = 49, .b = 141 });
        // Red (highlight color)
        theme.colors.set(.Highlight, .{ .r = 136, .g = 0, .b = 0 });
        // Purple (C64 palette)
        theme.colors.set(.Keyword, .{ .r = 102, .g = 0, .b = 102 });
        // Orange (C64 palette)
        theme.colors.set(.Constant, .{ .r = 170, .g = 85, .b = 0 });
        // Light gray (C64 palette)
        theme.colors.set(.Parameter, .{ .r = 170, .g = 170, .b = 170 });
        // Green (C64 palette)
        theme.colors.set(.String, .{ .r = 68, .g = 136, .b = 0 });
        // Cyan (C64 palette)
        theme.colors.set(.ObjectKey, .{ .r = 170, .g = 255, .b = 238 });
        // Light red (C64 palette)
        theme.colors.set(.RegexString, .{ .r = 255, .g = 119, .b = 119 });
        // Light green (C64 palette)
        theme.colors.set(.SupportFunction, .{ .r = 187, .g = 255, .b = 136 });
        // Medium gray (C64 palette)
        theme.colors.set(.Property, .{ .r = 119, .g = 119, .b = 119 });
        // Dark gray (C64 palette)
        theme.colors.set(.Comment, .{ .r = 85, .g = 85, .b = 85 });
        // Light gray (C64 palette)
        theme.colors.set(.Foreground, .{ .r = 170, .g = 170, .b = 170 });
        // Light blue (markdown text)
        theme.colors.set(.MarkdownText, .{ .r = 106, .g = 183, .b = 245 });
        // Black (C64 palette)
        theme.colors.set(.TerminalBlack, .{ .r = 0, .g = 0, .b = 0 });
        return theme;
    }

    /// Initializes a Commodore 128 theme—light green on dark gray with retro accents.
    pub fn initCommodore128() ColorTheme {
        var theme = ColorTheme{
            .name = "Commodore-128",
            .colors = std.EnumArray(
                ColorClass,
                movy.core.types.Rgb,
            ).initUndefined(),
        };

        // Light gray (C128 palette)
        theme.colors.set(.WindowBorder, .{ .r = 170, .g = 170, .b = 170 });
        // White (for window corners)
        theme.colors.set(.WindowCorner, .{ .r = 255, .g = 255, .b = 255 });
        // Light green (text color)
        theme.colors.set(.WindowTitle, .{ .r = 0, .g = 255, .b = 0 });
        // Dark gray (window background)
        theme.colors.set(.WindowInnerBorder, .{ .r = 51, .g = 51, .b = 51 });
        // Dark gray (screen background)
        theme.colors.set(.BackgroundColor, .{ .r = 51, .g = 51, .b = 51 });
        // Light green (default text color)
        theme.colors.set(.TextColor, .{ .r = 0, .g = 255, .b = 0 });
        // Yellow (C128 palette)
        theme.colors.set(.Heading1, .{ .r = 191, .g = 191, .b = 0 });
        // Light red (C128 palette)
        theme.colors.set(.Heading2, .{ .r = 255, .g = 119, .b = 119 });
        // Cyan (C128 palette)
        theme.colors.set(.Heading3, .{ .r = 170, .g = 255, .b = 238 });
        // Light green (C128 palette)
        theme.colors.set(.Hyperlink, .{ .r = 187, .g = 255, .b = 136 });
        // Yellow (code text)
        theme.colors.set(.CodeText, .{ .r = 191, .g = 191, .b = 0 });
        // Black (code background)
        theme.colors.set(.CodeBackground, .{ .r = 0, .g = 0, .b = 0 });
        // Light green (button text)
        theme.colors.set(.ButtonText, .{ .r = 0, .g = 255, .b = 0 });
        // Dark gray (button background)
        theme.colors.set(.ButtonBackground, .{ .r = 51, .g = 51, .b = 51 });
        // Light red (highlight color)
        theme.colors.set(.Highlight, .{ .r = 255, .g = 119, .b = 119 });
        // Purple (C128 palette)
        theme.colors.set(.Keyword, .{ .r = 102, .g = 0, .b = 102 });
        // Orange (C128 palette)
        theme.colors.set(.Constant, .{ .r = 170, .g = 85, .b = 0 });
        // Light gray (C128 palette)
        theme.colors.set(.Parameter, .{ .r = 170, .g = 170, .b = 170 });
        // Green (C128 palette)
        theme.colors.set(.String, .{ .r = 68, .g = 136, .b = 0 });
        // Cyan (C128 palette)
        theme.colors.set(.ObjectKey, .{ .r = 170, .g = 255, .b = 238 });
        // Light blue (C128 palette)
        theme.colors.set(.RegexString, .{ .r = 106, .g = 183, .b = 245 });
        // White (C128 palette)
        theme.colors.set(.SupportFunction, .{ .r = 255, .g = 255, .b = 255 });
        // Medium gray (C128 palette)
        theme.colors.set(.Property, .{ .r = 119, .g = 119, .b = 119 });
        // Dark gray (C128 palette)
        theme.colors.set(.Comment, .{ .r = 85, .g = 85, .b = 85 });
        // Light gray (C128 palette)
        theme.colors.set(.Foreground, .{ .r = 170, .g = 170, .b = 170 });
        // Light green (markdown text)
        theme.colors.set(.MarkdownText, .{ .r = 0, .g = 255, .b = 0 });
        // Black (C128 palette)
        theme.colors.set(.TerminalBlack, .{ .r = 0, .g = 0, .b = 0 });
        return theme;
    }

    /// Gathers all available themes into an ArrayList.
    pub fn getAllThemes(
        allocator: std.mem.Allocator,
    ) !std.ArrayList(*const ColorTheme) {
        var themes = std.ArrayList(*const ColorTheme).init(allocator);

        // Allocate, append, and initialize each theme
        const theme_tokyo_night = try allocator.create(ColorTheme);
        theme_tokyo_night.* = ColorTheme.initTokyoNightStorm();
        try themes.append(theme_tokyo_night);

        const theme_gruvbox = try allocator.create(ColorTheme);
        theme_gruvbox.* = ColorTheme.initGruvbox();
        try themes.append(theme_gruvbox);

        const theme_catppuccin = try allocator.create(ColorTheme);
        theme_catppuccin.* = ColorTheme.initCatppuccinMocha();
        try themes.append(theme_catppuccin);

        const theme_dracula = try allocator.create(ColorTheme);
        theme_dracula.* = ColorTheme.initDracula();
        try themes.append(theme_dracula);

        const theme_nord = try allocator.create(ColorTheme);
        theme_nord.* = ColorTheme.initNord();
        try themes.append(theme_nord);

        const theme_monokai = try allocator.create(ColorTheme);
        theme_monokai.* = ColorTheme.initMonokai();
        try themes.append(theme_monokai);

        const theme_sublime_mariana = try allocator.create(ColorTheme);
        theme_sublime_mariana.* = ColorTheme.initSublimeMariana();
        try themes.append(theme_sublime_mariana);

        const theme_solarized_dark = try allocator.create(ColorTheme);
        theme_solarized_dark.* = ColorTheme.initSolarizedDark();
        try themes.append(theme_solarized_dark);

        const theme_tomorrow_night = try allocator.create(ColorTheme);
        theme_tomorrow_night.* = ColorTheme.initTomorrowNight();
        try themes.append(theme_tomorrow_night);

        const theme_shades_of_purple = try allocator.create(ColorTheme);
        theme_shades_of_purple.* = ColorTheme.initShadesOfPurple();
        try themes.append(theme_shades_of_purple);

        const theme_night_owl = try allocator.create(ColorTheme);
        theme_night_owl.* = ColorTheme.initNightOwl();
        try themes.append(theme_night_owl);

        const theme_ms_dos = try allocator.create(ColorTheme);
        theme_ms_dos.* = ColorTheme.initMSDOS();
        try themes.append(theme_ms_dos);

        const theme_turbo_vision = try allocator.create(ColorTheme);
        theme_turbo_vision.* = ColorTheme.initTurboVision();
        try themes.append(theme_turbo_vision);

        const theme_one_dark = try allocator.create(ColorTheme);
        theme_one_dark.* = ColorTheme.initOneDark();
        try themes.append(theme_one_dark);

        const theme_commodore_64 = try allocator.create(ColorTheme);
        theme_commodore_64.* = ColorTheme.initCommodore64();
        try themes.append(theme_commodore_64);

        const theme_commodore_128 = try allocator.create(ColorTheme);
        theme_commodore_128.* = ColorTheme.initCommodore128();
        try themes.append(theme_commodore_128);

        return themes;
    }

    /// Stub for loading a theme from JSON—placeholder for future flexibility.
    pub fn initFromJson(
        allocator: std.mem.Allocator,
        json_data: []const u8,
    ) !ColorTheme {
        // TODO: Parse JSON into colors—e.g., {"WindowBorder": "#6c7086", ...}
        _ = allocator;
        _ = json_data;
        return initTokyoNightStorm(); // Stub—replace with real parsing later
    }

    /// Retrieves the color for a given class—simple and efficient.
    pub fn getColor(
        self: *const ColorTheme,
        class: ColorClass,
    ) movy.core.types.Rgb {
        return self.colors.get(class);
    }

    /// Updates the color for a given class—flexible customization.
    pub fn setColor(
        self: *ColorTheme,
        class: ColorClass,
        color: movy.core.types.Rgb,
    ) void {
        self.colors.set(class, color);
    }
};

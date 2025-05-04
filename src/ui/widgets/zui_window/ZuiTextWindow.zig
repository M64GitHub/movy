const std = @import("std");
const tzui = @import("../../../tzui.zig");

// Defines a text window—extends a titled window with a text content area.
pub const ZuiTextWindow = struct {
    base: *tzui.ui.ZuiTitleWindow,
    base_widget: *tzui.ui.ZuiWidget,
    styled_text: tzui.ui.StyledTextBuffer,

    /// Initializes a heap allocated text window, sets up base with
    /// title and text.
    pub fn init(
        allocator: std.mem.Allocator,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        styled_text: []const u8,
        theme: *const tzui.ui.ZuiColorTheme,
        style: *const tzui.ui.ZuiStyle,
    ) !*ZuiTextWindow {
        var self = try allocator.create(ZuiTextWindow);

        self.* = .{
            .base = try tzui.ui.ZuiTitleWindow.init(
                allocator,
                x,
                y,
                w,
                h,
                window_title,
                theme,
                style,
            ),
            .styled_text = try tzui.ui.StyledTextBuffer.init(allocator, 1024),
            .base_widget = undefined,
        };
        self.base_widget = self.base.base_widget;
        self.setPosition(x, y);
        try self.styled_text.setTextFromAscii(styled_text);
        return self;
    }

    /// Frees the text window’s base resources—caller manages title and text
    /// memory.
    pub fn deinit(self: *ZuiTextWindow, allocator: std.mem.Allocator) void {
        self.styled_text.deinit(allocator);
        self.base.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn getWidgetInfo(self: *ZuiTextWindow) tzui.ui.ZuiWidgetInfo {
        return .{
            .ptr = self.base_widget,
            .widget_type = .TextWindow,
        };
    }

    pub fn setActive(self: *ZuiTextWindow, active: bool) void {
        self.base_widget.is_active = active;
    }

    pub fn isActive(self: *ZuiTextWindow) bool {
        return self.base_widget.is_active;
    }

    /// Handle input events
    pub fn handleInputEvent(
        self: *ZuiTextWindow,
        event: tzui.input.InputEvent,
    ) void {
        switch (event) {
            .key => |key| {
                if (key.type == .Char) {
                    if (self.styled_text.cursorAtInsertPos() == true) {
                        self.styled_text.appendChar(key.sequence[0]);
                    } else {
                        self.styled_text.insertChar(key.sequence[0]);
                    }
                }
                if (key.type == .Enter) {
                    if (self.styled_text.cursorAtInsertPos() == true) {
                        self.styled_text.appendChar('\n');
                    } else {
                        self.styled_text.insertChar('\n');
                    }
                }
                if (key.type == .Backspace) {
                    self.styled_text.backSpace();
                }
                if (key.type == .Left) {
                    self.styled_text.cursorLeft();
                }
                if (key.type == .Right) {
                    self.styled_text.cursorRight();
                }
                if (key.type == .Up) {
                    self.styled_text.cursorUp();
                }
                if (key.type == .Down) {
                    self.styled_text.cursorDown();
                }
                if (key.type == .CtrlLeft) {
                    self.styled_text.cursorWordLeft();
                }
                if (key.type == .CtrlRight) {
                    self.styled_text.cursorWordRight();
                }
                if (key.type == .ShiftLeft) {
                    self.styled_text.cursorShiftLeft();
                }
                if (key.type == .ShiftRight) {
                    self.styled_text.cursorShiftRight();
                }
                if (key.type == .Home) {
                    self.styled_text.cursorToLineStart();
                }
                if (key.type == .End) {
                    self.styled_text.cursorToLineEnd();
                }
                if (key.type == .Tab) {
                    self.styled_text.insertTab();
                }

                if (key.type == .Other) {
                    if (key.sequence.len > 1) {
                        for (0..key.sequence.len - 1) |i| {
                            if (self.styled_text.cursorAtInsertPos() == true) {
                                self.styled_text.appendChar(key.sequence[i]);
                            } else {
                                self.styled_text.insertChar(key.sequence[i]);
                            }
                        }
                    }
                }
                if (key.type != .ShiftRight and key.type != .ShiftLeft)
                    self.styled_text.selection =
                        tzui.ui.StyledTextBuffer.SelectionState{ .None = {} };

                self.styleMarkDown();
                self.visualizeSelection();
            },
            .mouse => {},
        }
    }

    pub fn styleMarkDown(self: *ZuiTextWindow) void {
        self.styled_text.clearStyles();

        self.styled_text.highlightKeyword(
            "highlight",
            self.base.getTheme().getColor(.Highlight),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightKeyword(
            "keyword",
            self.base.getTheme().getColor(.Keyword),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightKeyword(
            "constant",
            self.base.getTheme().getColor(.Constant),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightKeyword(
            "parameter",
            self.base.getTheme().getColor(.Parameter),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightKeyword(
            "string",
            self.base.getTheme().getColor(.String),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightBetweenKeywords(
            "'",
            "'",
            self.base.getTheme().getColor(.String),
            self.base.getTheme().getColor(.CodeBackground),
            true,
            true,
        );

        self.styled_text.highlightInlineBacktickCode(self.base.getTheme().*);

        self.styled_text.styleLineStartingWith(
            "#",
            self.base.getTheme().getColor(.Heading1),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.styleLineStartingWith(
            "##",
            self.base.getTheme().getColor(.Heading2),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.styleLineStartingWith(
            ">",
            self.base.getTheme().getColor(.MarkdownText),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightBetweenKeywords(
            "*",
            "*",
            self.base.getTheme().getColor(.Highlight),
            self.base.getTheme().getColor(.BackgroundColor),
            true,
            true,
        );

        self.styled_text.highlightBetweenKeywords(
            "**",
            "**",
            self.base.getTheme().getColor(.Keyword),
            self.base.getTheme().getColor(.CodeBackground),
            true,
            true,
        );

        self.styled_text.styleLineStartingWith(
            "###",
            self.base.getTheme().getColor(.Heading3),
            self.base.getTheme().getColor(.BackgroundColor),
        );

        self.styled_text.highlightLanguageBlock(
            "```",
            "```",
            self.base.getTheme().*,
            tzui.ui.StyledTextBuffer.highlightGenericCodeSlice,
        );

        self.styled_text.highlightLanguageBlock(
            "```zig",
            "```",
            self.base.getTheme().*,
            tzui.ui.StyledTextBuffer.highlightZigSlice,
        );

        self.styled_text.highlightLanguageBlock(
            "```c",
            "```",
            self.base.getTheme().*,
            tzui.ui.StyledTextBuffer.highlightCSlice,
        );

        self.styled_text.highlightLanguageBlock(
            "```cpp",
            "```",
            self.base.getTheme().*,
            tzui.ui.StyledTextBuffer.highlightCppSlice,
        );
    }

    pub fn visualizeSelection(self: *ZuiTextWindow) void {
        switch (self.styled_text.selection) {
            .None => {},
            .Selecting => |start| {
                // maybe draw selection from start to current cursor
                self.styled_text.styleRange(
                    start,
                    start,
                    self.base.getTheme().getColor(.Highlight),
                    self.base.getTheme().getColor(.CodeBackground),
                );
            },
            .Selected => |sel| {
                const start = @min(sel.start, sel.end);
                const end = @max(sel.start, sel.end);

                self.styled_text.styleRange(
                    start,
                    end,
                    tzui.color.DARK_BLUE,
                    tzui.color.LIGHT_BLUE,
                );
            },
        }
    }

    /// Sets a new theme for the window—propagates to base.
    pub fn setTheme(
        self: *ZuiTextWindow,
        theme: *const tzui.ui.ZuiColorTheme,
    ) void {
        self.base.setTheme(theme);
    }

    /// Retrieves the current theme from the base.
    pub fn getTheme(self: *const ZuiTextWindow) *const tzui.ui.ZuiColorTheme {
        return self.base.getTheme();
    }

    /// Sets a new style for the window—propagates to base.
    pub fn setStyle(self: *ZuiTextWindow, style: *const tzui.ui.ZuiStyle) void {
        self.base.setStyle(style);
    }

    /// Retrieves the current style from the base.
    pub fn getStyle(self: *const ZuiTextWindow) *const tzui.ui.ZuiStyle {
        return self.base.getStyle();
    }

    /// Sets the window’s position—propagates to base.
    pub fn setPosition(self: *ZuiTextWindow, x: i32, y: i32) void {
        self.base.setPosition(x, y);
    }

    /// Retrieves the window’s position—passes through to base.
    pub fn getPosition(self: *const ZuiTextWindow) tzui.ui.ZuiPosition2D {
        return self.base.getPosition();
    }

    /// Resizes the window—updates base dimensions.
    pub fn resize(
        self: *ZuiTextWindow,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        try self.base.resize(allocator, w, h);
    }

    /// Retrieves the window’s size—passes through to base.
    pub fn getSize(self: *const ZuiTextWindow) tzui.ui.ZuiSize {
        return self.base.getSize();
    }

    /// Sets the window title—propagates to base.
    pub fn setTitle(self: *ZuiTextWindow, title: []const u8) void {
        self.base.setTitle(title);
    }

    /// Retrieves the current window title from the base.
    pub fn getTitle(self: *const ZuiTextWindow) []const u8 {
        return self.base.getTitle();
    }

    /// Sets the window text—updates the displayed content.
    pub fn setText(self: *ZuiTextWindow, text: []const u8) !void {
        try self.styled_text.setTextFromAscii(text);
    }

    /// Retrieves the current window text.
    pub fn getText(self: *const ZuiTextWindow) []const u8 {
        return self.styled_text;
    }

    /// Checks if the given coordinates are within the window's bounds
    /// uses absolute coordinates.
    pub fn isInBounds(self: *const ZuiTextWindow, x: i32, y: i32) bool {
        return self.base.isInBounds(x, y);
    }

    /// Checks if the given coordinates are within the window's title bounds
    /// (first row).
    pub fn isInTitleBounds(self: *const ZuiTextWindow, x: i32, y: i32) bool {
        return self.base.isInTitleBounds(x, y);
    }

    /// Renders the text window—composites base, title, and text content,
    /// returns the final surface.
    pub fn render(self: *ZuiTextWindow) *tzui.core.RenderSurface {
        const surface = self.base.render(); // Render base (bg, border, title)
        var cursor_idx: usize = 0;

        if (self.styled_text.is_empty) {
            cursor_idx = surface.putStrXY(
                " ",
                1,
                1,
                self.base.getTheme().getColor(.TextColor),
                self.base.getTheme().getColor(.BackgroundColor),
            ) - 1;
        } else {
            cursor_idx = surface.putStyledTextXY(
                self.styled_text,
                1,
                1,
                self.base.getTheme().getColor(.TextColor),
                self.base.getTheme().getColor(.BackgroundColor),
            );
        }

        if (self.base_widget.is_active == true) {
            if (self.styled_text.cursorAtInsertPos()) {
                // show APPEND cursor
                self.base.base.base.output_surface.color_map[cursor_idx] =
                    tzui.color.BRIGHT_LIGHT_YELLOW;
                // cursor is 2 half blocks high!
                self.base.base.base.output_surface.color_map[
                    cursor_idx +
                        self.base.base.base.w
                ] =
                    tzui.color.BRIGHT_LIGHT_YELLOW;
            } else {
                // show IN TEXT cursor
                if (self.styled_text.getCharUnderCursor() == '\n') {
                    self.base.base.base.output_surface.color_map[cursor_idx] =
                        tzui.color.BRIGHT_LIGHT_YELLOW;
                } else {
                    // on bright cursor, text "below" gets black
                    self.base.base.base.output_surface.color_map[cursor_idx] =
                        tzui.color.BLACK;
                }
                self.base.base.base.output_surface.color_map[
                    cursor_idx +
                        self.base.base.base.w
                ] =
                    tzui.color.BRIGHT_LIGHT_YELLOW;
            }
        }

        return self.base.base.base.output_surface;
    }
};

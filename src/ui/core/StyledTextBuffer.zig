const std = @import("std");
const movy = @import("../../movy.zig");
const Rgb = movy.core.types.Rgb;

/// Represents a styled character with optional foreground and background colors.
pub const StyledChar = struct {
    char: u21,
    fg: ?Rgb = null,
    bg: ?Rgb = null,
};

/// Styled text buffer with cursor-, editing, and highlighting functionality.
pub const StyledTextBuffer = struct {
    text: []StyledChar = undefined,
    cursor_idx: usize,
    last_char_idx: usize,
    is_empty: bool = true,
    preferred_column: ?usize = null,
    tab_width: usize = 4,
    selection: SelectionState = .None,

    pub const SelectionState = union(enum) {
        None, // No selection
        Selecting: usize, // In progress — from this start index to cursor
        Selected: struct {
            start: usize,
            end: usize,
        },
    };

    /// Initializes a new styled text buffer with the given maximum length.
    pub fn init(
        allocator: std.mem.Allocator,
        max_len: usize,
    ) !StyledTextBuffer {
        return StyledTextBuffer{
            .cursor_idx = 0,
            .last_char_idx = 0,
            .text = try allocator.alloc(StyledChar, max_len),
        };
    }

    /// Frees allocated memory.
    pub fn deinit(self: *StyledTextBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }

    /// Clears the buffer.
    pub fn clear(self: *StyledTextBuffer) void {
        self.last_char_idx = 0;
        self.cursor_idx = 0;
        self.is_empty = true;
        self.preferred_column = null;
    }

    /// Sets the content from a slice of ASCII characters (u8).
    pub fn setTextFromAscii(self: *StyledTextBuffer, text: []const u8) !void {
        if (text.len > self.text.len) return error.TextTooLong;
        if (text.len == 0) {
            self.clear();
            return;
        }
        for (text, 0..) |c, i| {
            self.text[i] = StyledChar{ .char = c, .fg = null, .bg = null };
        }
        self.last_char_idx = text.len - 1;
        self.cursor_idx = text.len;
        self.is_empty = false;
        self.preferred_column = null;
    }

    /// Sets the content from a slice of Unicode characters (u21).
    pub fn setText(self: *StyledTextBuffer, text: []const u21) !void {
        if (text.len > self.text.len) return error.TextTooLong;
        if (text.len == 0) {
            self.clear();
            return;
        }
        for (text, 0..) |c, i| {
            self.text[i] = StyledChar{ .char = c, .fg = null, .bg = null };
        }
        self.last_char_idx = text.len - 1;
        self.cursor_idx = text.len;
        self.is_empty = false;
        self.preferred_column = null;
    }

    pub fn fromFile(
        self: *StyledTextBuffer,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_chars: usize,
    ) !void {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        _ = try file.readAll(buffer);

        allocator.free(self.text);
        const text_u21 = try utf8ToUtf21(allocator, buffer);
        defer allocator.free(text_u21);
        const alloc_len = @max(max_chars, text_u21.len);
        self.text = try allocator.alloc(StyledChar, alloc_len);
        try self.setText(text_u21);
    }

    pub fn utf8ToUtf21(
        allocator: std.mem.Allocator,
        input: []const u8,
    ) ![]u21 {
        var utf8_stream = std.unicode.Utf8Iterator{
            .bytes = input,
            .i = 0,
        };

        var result = std.ArrayList(u21).init(allocator);

        while (utf8_stream.nextCodepoint()) |cp| {
            try result.append(cp);
        }

        return result.toOwnedSlice();
    }

    /// Returns a slice of the StyledChar array containing the current text.
    pub fn getText(self: *StyledTextBuffer) []const StyledChar {
        if (self.is_empty) return &[_]StyledChar{};
        return self.text[0 .. self.last_char_idx + 1];
    }

    /// Returns true if the cursor is at the insert position
    /// (after last character).
    pub fn cursorAtInsertPos(self: *StyledTextBuffer) bool {
        return self.cursor_idx > self.last_char_idx;
    }

    /// Returns the character under the cursor.
    pub fn getCharUnderCursor(self: *StyledTextBuffer) u21 {
        if (self.cursorAtInsertPos()) return 0;
        return self.text[self.cursor_idx].char;
    }

    /// Sets the character at the cursor position.
    pub fn setChar(self: *StyledTextBuffer, c: u21) void {
        if (self.cursor_idx >= self.text.len) return;
        if (self.is_empty) return;
        self.text[self.cursor_idx].char = c;
    }

    /// Appends a character at the end.
    pub fn appendChar(self: *StyledTextBuffer, c: u21) void {
        if (self.is_empty) {
            self.text[0] = StyledChar{ .char = c };
            self.cursor_idx = 1;
            self.is_empty = false;
            self.preferred_column = null;
            return;
        }
        if (self.last_char_idx >= self.text.len - 1) return;
        self.last_char_idx += 1;
        self.text[self.last_char_idx] = StyledChar{ .char = c };
        self.cursor_idx = self.last_char_idx + 1;
        self.is_empty = false;
        self.preferred_column = null;
    }

    /// Inserts a character at the cursor position.
    pub fn insertChar(self: *StyledTextBuffer, c: u21) void {
        if (self.last_char_idx >= self.text.len - 1) return;
        if (self.is_empty) {
            self.appendChar(c);
            return;
        }
        if (self.cursor_idx == self.last_char_idx + 1) {
            self.appendChar(c);
            return;
        }
        for (0..(self.last_char_idx - self.cursor_idx + 1)) |idx| {
            self.text[self.last_char_idx - idx + 1] =
                self.text[self.last_char_idx - idx];
        }
        self.text[self.cursor_idx] = StyledChar{ .char = c };
        self.cursor_idx += 1;
        self.last_char_idx += 1;
        self.is_empty = false;
        self.preferred_column = null;
    }

    /// Deletes the character before the cursor.
    pub fn backSpace(self: *StyledTextBuffer) void {
        if (self.cursor_idx == 0) return;
        if (self.last_char_idx == 0 and self.cursor_idx == 1) {
            self.cursor_idx = 0;
            self.is_empty = true;
            self.preferred_column = null;
            return;
        }
        if (self.cursor_idx == self.last_char_idx + 1) {
            if (self.last_char_idx > 0) self.last_char_idx -= 1;
            if (self.cursor_idx > 0) self.cursor_idx -= 1;
            if (self.last_char_idx == 0 and self.cursor_idx == 0)
                self.is_empty = true;
            self.preferred_column = null;
            return;
        }
        for (0..self.last_char_idx - self.cursor_idx + 1) |idx| {
            self.text[self.cursor_idx + idx - 1] =
                self.text[self.cursor_idx + idx];
        }
        self.last_char_idx -= 1;
        self.cursor_idx -= 1;
        self.preferred_column = null;
    }

    /// Moves the cursor one character to the left.
    pub fn cursorLeft(self: *StyledTextBuffer) void {
        if (self.cursor_idx > 0) {
            self.cursor_idx -= 1;
            self.preferred_column = null;
        }
    }

    /// Moves the cursor one character to the right.
    pub fn cursorRight(self: *StyledTextBuffer) void {
        if (self.cursor_idx < self.last_char_idx + 1) {
            self.cursor_idx += 1;
            self.preferred_column = null;
        }
    }

    /// Moves the cursor to the start of the current line.
    pub fn cursorToLineStart(self: *StyledTextBuffer) void {
        var i = self.cursor_idx;
        while (i > 0) : (i -= 1) {
            if (self.text[i - 1].char == '\n') break;
        }
        self.cursor_idx = i;
        self.preferred_column = null;
    }

    /// Moves the cursor to the end of the current line.
    pub fn cursorToLineEnd(self: *StyledTextBuffer) void {
        var i = self.cursor_idx;
        while (i <= self.last_char_idx) : (i += 1) {
            if (self.text[i].char == '\n') break;
        }
        self.cursor_idx = i;
        self.preferred_column = null;
    }

    /// Moves the cursor to the beginning of the previous word.
    pub fn cursorWordLeft(self: *StyledTextBuffer) void {
        if (self.cursor_idx == 0) return;
        while (self.cursor_idx > 0 and
            std.ascii.isWhitespace(@intCast(
                self.text[self.cursor_idx - 1].char,
            )))
        {
            self.cursor_idx -= 1;
        }
        while (self.cursor_idx > 0 and
            !std.ascii.isWhitespace(@intCast(
                self.text[self.cursor_idx - 1].char,
            )))
        {
            self.cursor_idx -= 1;
        }
        self.preferred_column = null;
    }

    /// Moves the cursor to the beginning of the next word.
    pub fn cursorWordRight(self: *StyledTextBuffer) void {
        if (self.cursor_idx > self.last_char_idx) return;
        while (self.cursor_idx <= self.last_char_idx and
            !std.ascii.isWhitespace(@intCast(self.text[self.cursor_idx].char)))
        {
            self.cursor_idx += 1;
        }
        while (self.cursor_idx <= self.last_char_idx and
            std.ascii.isWhitespace(@intCast(self.text[self.cursor_idx].char)))
        {
            self.cursor_idx += 1;
        }
        self.preferred_column = null;
    }

    /// Moves the cursor one line up.
    pub fn cursorUp(self: *StyledTextBuffer) void {
        if (self.cursor_idx == 0) return;
        if (self.preferred_column == null) {
            var col: usize = 0;
            var i = self.cursor_idx;
            while (i > 0 and self.text[i - 1].char != '\n') : (i -= 1) col += 1;
            self.preferred_column = col;
        }
        var i = self.cursor_idx;
        while (i > 0 and self.text[i - 1].char != '\n') : (i -= 1) {}
        if (i == 0) return;
        i -= 1;
        const end = i;
        while (i > 0 and self.text[i - 1].char != '\n') : (i -= 1) {}
        const start = i;
        const len = end - start + 1;
        const col = self.preferred_column.?;
        const new_col = if (col < len) col else len - 1;
        self.cursor_idx = start + new_col;
    }

    /// Moves the cursor one line down.
    pub fn cursorDown(self: *StyledTextBuffer) void {
        var i = self.cursor_idx;
        while (i <= self.last_char_idx and
            self.text[i].char != '\n') : (i += 1)
        {}
        if (i > self.last_char_idx) return;
        i += 1;
        const start = i;
        while (i <= self.last_char_idx and
            self.text[i].char != '\n') : (i += 1)
        {}
        const end = if (i > self.last_char_idx) self.last_char_idx else i - 1;
        const len = if (end >= start) end - start + 1 else 0;
        if (self.preferred_column == null) {
            var col: usize = 0;
            var j = self.cursor_idx;
            while (j > 0 and self.text[j - 1].char != '\n') : (j -= 1) col += 1;
            self.preferred_column = col;
        }
        const col = self.preferred_column.?;
        const new_col = if (len == 0) 0 else if (col < len) col else len - 1;
        self.cursor_idx = start + new_col;
    }

    /// Inserts a tab character as spaces, depending on configured tab width.
    pub fn insertTab(self: *StyledTextBuffer) void {
        var line_start: usize = 0;
        if (self.cursor_idx > 0) {
            var i = self.cursor_idx;
            while (i > 0) : (i -= 1) {
                if (self.text[i - 1].char == '\n') {
                    line_start = i;
                    break;
                }
            }
        }
        const column = self.cursor_idx - line_start;
        const spaces = self.tab_width - (column % self.tab_width);
        for (0..spaces) |_| self.insertChar(' ');
    }

    /// Moves the cursor one position to the left (if possible), while updating
    /// selection state.
    /// If no selection is active, this begins a new selection anchored at the
    /// current cursor index. The cursor is then moved left, and a `Selected`
    /// region is created spanning from the anchor to the new cursor position.
    /// This function keeps the anchor fixed and updates the cursor end of the
    /// selection, allowing continuous selection expansion as the user holds
    /// Shift.
    pub fn cursorShiftLeft(self: *StyledTextBuffer) void {
        var anchor: usize = undefined;

        switch (self.selection) {
            .None => {
                // First time shift is held — start selecting
                self.selection = SelectionState{ .Selecting = self.cursor_idx };
                anchor = self.cursor_idx;
            },
            .Selecting => |a| {
                anchor = a;
            },
            .Selected => |sel| {
                anchor = sel.start;
            },
        }

        // Move the cursor to the left
        self.cursorLeft();

        // Promote to Selected (if not already) and update selection to
        // anchor ↔ cursor
        self.selection = SelectionState{ .Selected = .{
            .start = anchor,
            .end = self.cursor_idx,
        } };
    }

    /// Moves the cursor one position to the right (if possible), while updating
    /// selection state.
    /// If no selection is active, this begins a new selection anchored at the
    /// current cursor index. The cursor is then moved left, and a `Selected`
    /// region is created spanning from the anchor to the new cursor position.
    /// This function keeps the anchor fixed and updates the cursor end of the
    /// selection, allowing continuous selection expansion as the user holds
    /// Shift.
    pub fn cursorShiftRight(self: *StyledTextBuffer) void {
        var anchor: usize = undefined;

        switch (self.selection) {
            .None => {
                // First time shift is held — start selecting
                self.selection = SelectionState{ .Selecting = self.cursor_idx };
                anchor = self.cursor_idx;
            },
            .Selecting => |a| {
                anchor = a;
            },
            .Selected => |sel| {
                anchor = sel.start;
            },
        }

        // Move the cursor to the left
        self.cursorRight();

        // Promote to Selected (if not already) and update selection to
        // anchor ↔ cursor
        self.selection = SelectionState{ .Selected = .{
            .start = anchor,
            .end = self.cursor_idx,
        } };
    }

    /// Highlights all exact occurrences of a keyword by applying
    /// the given fg and bg color to the matched characters.
    pub fn highlightKeyword(
        self: *StyledTextBuffer,
        keyword: []const u8,
        fg: movy.core.types.Rgb,
        bg: movy.core.types.Rgb,
    ) void {
        if (self.is_empty) return;

        const keyword_len = keyword.len;
        const text_len = self.last_char_idx + 1;
        if (keyword_len == 0 or text_len < keyword_len) return;

        const text = self.text;

        var i: usize = 0;

        while (i <= text_len - keyword_len) {
            var matched = true;

            // Check character-by-character for match
            for (0..keyword_len) |j| {
                //                 if (text[i + j].char != @as(u21, keyword[j])) {
                if (text[i + j].char != keyword[j]) {
                    matched = false;
                    break;
                }
            }

            if (matched) {
                // Apply styles
                for (0..keyword_len) |j| {
                    self.text[i + j].fg = fg;
                    self.text[i + j].bg = bg;
                }
                i += keyword_len; // Skip ahead after match
            } else {
                i += 1;
            }
        }
    }

    /// Highlights all isolated occurrences of a keyword (not inside other words),
    /// by applying the given fg and bg color to the matched characters.
    pub fn highlightKeywordIsolated(
        self: *StyledTextBuffer,
        keyword: []const u8,
        fg: movy.core.types.Rgb,
        bg: movy.core.types.Rgb,
    ) void {
        if (self.is_empty) return;

        const keyword_len = keyword.len;
        const text_len = self.last_char_idx + 1;
        if (keyword_len == 0 or text_len < keyword_len) return;

        const text = self.text;

        var i: usize = 0;

        while (i <= text_len - keyword_len) {
            var matched = true;

            // Check character-by-character for match
            for (0..keyword_len) |j| {
                if (text[i + j].char != keyword[j]) {
                    matched = false;
                    break;
                }
            }

            if (matched) {
                const before_ok = i == 0 or isBoundaryChar(text[i - 1].char);
                const after_pos = i + keyword_len;
                const after_ok = after_pos >= text_len or isBoundaryChar(text[after_pos].char);

                if (before_ok and after_ok) {
                    for (0..keyword_len) |j| {
                        self.text[i + j].fg = fg;
                        self.text[i + j].bg = bg;
                    }
                    i += keyword_len;
                    continue;
                }
            }

            i += 1;
        }
    }

    /// Clears style from all exact occurrences of a keyword by removing
    /// the fg and bg color to the matched characters.
    pub fn clearStyleKeyword(
        self: *StyledTextBuffer,
        keyword: []const u8,
    ) void {
        if (self.is_empty) return;

        const keyword_len = keyword.len;
        const text_len = self.last_char_idx + 1;
        if (keyword_len == 0 or text_len < keyword_len) return;

        const text = self.text;

        var i: usize = 0;

        while (i <= text_len - keyword_len) {
            var matched = true;

            // Check character-by-character for match
            for (0..keyword_len) |j| {
                if (text[i + j].char != keyword[j]) {
                    matched = false;
                    break;
                }
            }

            if (matched) {
                // Apply styles
                for (0..keyword_len) |j| {
                    self.text[i + j].fg = null;
                    self.text[i + j].bg = null;
                }
                i += keyword_len; // Skip ahead after match
            } else {
                i += 1;
            }
        }
    }

    /// Highlights all text between a start and end keyword using the given
    /// fg/bg color.
    /// - If `include_keywords` is true, includes start/end markers in the
    ///   highlight.
    /// - If `require_end_keyword` is true, highlights only if both keywords
    ///   are found.
    pub fn highlightBetweenKeywords(
        self: *StyledTextBuffer,
        start_keyword: []const u8,
        end_keyword: []const u8,
        fg: movy.core.types.Rgb,
        bg: movy.core.types.Rgb,
        include_keywords: bool,
        require_end_keyword: bool,
    ) void {
        if (self.is_empty) return;
        if (start_keyword.len == 0) return;
        if (self.text.len < start_keyword.len) return;

        const max_index = self.last_char_idx;
        var i: usize = 0;

        while (i <= max_index - start_keyword.len + 1) {
            // Look for the start keyword
            if (i + start_keyword.len > self.text.len) break;

            var found_start = true;
            for (0..start_keyword.len) |j| {
                if (self.text[i + j].char != start_keyword[j]) {
                    found_start = false;
                    break;
                }
            }

            if (!found_start) {
                i += 1;
                continue;
            }

            const start_idx = i;
            const start_len = start_keyword.len;
            i = start_idx + start_len;

            // Search for end keyword
            var found_end: bool = false;
            var end_idx: usize = 0;

            while (i <= max_index - end_keyword.len + 1) {
                if (i + end_keyword.len > self.text.len) break;

                found_end = true;
                for (0..end_keyword.len) |j| {
                    if (self.text[i + j].char != end_keyword[j]) {
                        found_end = false;
                        break;
                    }
                }

                if (found_end) {
                    end_idx = i;
                    break;
                }

                i += 1;
            }

            if (require_end_keyword and !found_end) {
                // Skip over this match entirely, move forward by 1
                i = start_idx + 1;
                continue;
            }

            const highlight_start = if (include_keywords)
                start_idx
            else
                start_idx + start_len;
            const highlight_end = if (found_end)
                (if (include_keywords) end_idx + end_keyword.len else end_idx)
            else
                max_index + 1;

            // do the actual highlighting
            for (highlight_start..highlight_end) |k| {
                if (k < self.text.len) {
                    self.text[k].fg = fg;
                    self.text[k].bg = bg;
                }
            }

            // Advance after the section we just styled
            i = highlight_end;
            if (!include_keywords) i += end_keyword.len;

            // debug visual end mark indicator
            // self.text[i].fg = bg;
            // self.text[i].bg = fg;
        }

        if (!require_end_keyword and !include_keywords)
            self.clearStyleKeyword(end_keyword);
    }

    /// Styles all lines starting with a given keyword (e.g. "//") until the
    /// end of line.
    /// The keyword is always included in the styled range, and the '\n' is
    /// excluded.
    pub fn styleUntilLineEnd(
        self: *StyledTextBuffer,
        keyword: []const u8,
        fg: Rgb,
        bg: Rgb,
    ) void {
        const keyword_len = keyword.len;

        // Guard against edge cases
        if (self.is_empty or keyword_len == 0 or
            self.text.len < keyword_len) return;

        var i: usize = 0;

        while (i <= self.last_char_idx - keyword_len + 1) {
            // Make sure we have enough space left to match the keyword
            if (i + keyword_len > self.text.len) break;

            var matched = true;
            for (0..keyword_len) |j| {
                if (self.text[i + j].char != keyword[j]) {
                    matched = false;
                    break;
                }
            }

            if (matched) {
                var j = i;
                while (j <= self.last_char_idx and
                    self.text[j].char != '\n') : (j += 1)
                {
                    self.text[j].fg = fg;
                    self.text[j].bg = bg;
                }
                i = j + 1;
            } else {
                i += 1;
            }
        }
    }

    /// Styles only lines that start with the given keyword, applying fg/bg
    /// color from the first character to the end of the line (excluding '\n').
    pub fn styleLineStartingWith(
        self: *StyledTextBuffer,
        keyword: []const u8,
        fg: Rgb,
        bg: Rgb,
    ) void {
        const keyword_len = keyword.len;

        if (self.is_empty or keyword_len == 0 or
            self.text.len < keyword_len) return;

        var i: usize = 0;

        while (i <= self.last_char_idx - keyword_len + 1) {
            // Start of line?
            const is_line_start = i == 0 or self.text[i - 1].char == '\n';

            if (!is_line_start) {
                // Move to next potential line start
                while (i <= self.last_char_idx and
                    self.text[i].char != '\n') : (i += 1)
                {}
                i += 1;
                continue;
            }

            // Enough space for keyword?
            if (i + keyword_len > self.text.len) break;

            // Match keyword
            var matched = true;
            for (0..keyword_len) |j| {
                if (self.text[i + j].char != keyword[j]) {
                    matched = false;
                    break;
                }
            }

            if (matched) {
                var j = i;
                while (j <= self.last_char_idx and
                    self.text[j].char != '\n') : (j += 1)
                {
                    self.text[j].fg = fg;
                    self.text[j].bg = bg;
                }
                i = j + 1; // move to next line
            } else {
                // Skip to next line
                while (i <= self.last_char_idx and
                    self.text[i].char != '\n') : (i += 1)
                {}
                i += 1;
            }
        }
    }

    // Style a range with the given colors
    pub fn styleRange(
        self: *StyledTextBuffer,
        start: usize,
        end: usize,
        fg: Rgb,
        bg: Rgb,
    ) void {
        if (start >= self.text.len) return;
        if (end >= self.text.len) return;
        if (start >= end) return;

        for (start..end + 1) |i| {
            self.text[i].fg = fg;
            self.text[i].bg = bg;
        }
    }

    pub fn highlightLanguageBlock(
        self: *StyledTextBuffer,
        start_keyword: []const u8,
        end_keyword: []const u8,
        theme: movy.ui.ColorTheme,
        highlight_fn: fn (
            *StyledTextBuffer,
            usize,
            usize,
            movy.ui.ColorTheme,
        ) void,
    ) void {
        if (self.is_empty) return;
        if (start_keyword.len == 0 or self.text.len < start_keyword.len) return;

        const max_index = self.last_char_idx;
        var i: usize = 0;

        while (i <= max_index - start_keyword.len + 1) {
            // Look for start keyword
            if (i + start_keyword.len > self.text.len) break;

            var found_start = true;
            for (0..start_keyword.len) |j| {
                if (self.text[i + j].char != @as(u21, start_keyword[j])) {
                    found_start = false;
                    break;
                }
            }

            if (!found_start) {
                i += 1;
                continue;
            }

            const start_idx = i + start_keyword.len; // skip start marker
            i = start_idx;

            // Look for end keyword
            var found_end = false;
            var end_idx: usize = 0;

            while (i <= max_index - end_keyword.len + 1) {
                if (i + end_keyword.len > self.text.len) break;

                found_end = true;
                for (0..end_keyword.len) |j| {
                    if (self.text[i + j].char != @as(u21, end_keyword[j])) {
                        found_end = false;
                        break;
                    }
                }

                if (found_end) {
                    end_idx = i;
                    break;
                }

                i += 1;
            }

            if (found_end) {
                // Call the custom highlight function
                highlight_fn(self, start_idx, end_idx, theme);

                i = end_idx + end_keyword.len;
            } else {
                // No closing marker, skip ahead
                break;
            }
        }
    }

    /// Highlight a given array of characters. Used for code symbols like
    /// '{', '.', ...
    pub fn highlightSymbols(
        self: *StyledTextBuffer,
        symbols: []const u21,
        fg: Rgb,
        bg: Rgb,
        start: usize,
        end: usize,
    ) void {
        for (start..end) |i| {
            for (symbols) |s| {
                if (self.text[i].char == s) {
                    self.text[i].fg = fg;
                    self.text[i].bg = bg;
                    break;
                }
            }
        }
    }

    /// Basic highlighting for zig
    pub fn highlightZigSlice(
        self: *StyledTextBuffer,
        start: usize,
        end: usize,
        theme: movy.ui.ColorTheme,
    ) void {
        const keywords = [_][]const u8{
            "const",  "var",            "fn",     "return",   "if",
            "else",   "while",          "for",    "pub",      "struct",
            "enum",   "switch",         "break",  "continue", "comptime",
            "inline", "true",           "false",  "null",     "anytype",
            "export", "usingnamespace", "extern", "defer",    "errdefer",
            "try",    "catch",          "orelse", "async",    "await",
        };

        const types = [_][]const u8{
            "u8",       "u16",      "u32", "u64",  "usize",
            "i8",       "i16",      "i32", "i64",  "isize",
            "f16",      "f32",      "f64", "bool", "void",
            "noreturn", "anyerror",
        };

        for (keywords) |kw| {
            self.highlightKeywordIsolated(
                kw,
                theme.colors.get(.Keyword),
                theme.colors.get(.CodeBackground),
            );
        }

        for (types) |ty| {
            self.highlightKeywordIsolated(
                ty,
                theme.colors.get(.Constant), // Differentiate from general keywords
                theme.colors.get(.CodeBackground),
            );
        }

        // Comments
        self.styleUntilLineEnd(
            "//",
            theme.colors.get(.Comment),
            theme.colors.get(.CodeBackground),
        );

        // Strings
        self.highlightBetweenKeywords(
            "\"",
            "\"",
            theme.colors.get(.String),
            theme.colors.get(.CodeBackground),
            true,
            true,
        );

        // Symbols
        self.highlightSymbols(
            &[_]u21{
                '{',
                '}',
                '(',
                ')',
                '[',
                ']',
                '=',
                ',',
                ';',
                ':',
                '-',
                '>',
                '.',
            },
            theme.colors.get(.Keyword),
            theme.colors.get(.CodeBackground),
            start,
            end,
        );

        self.highlightFunctionNames(theme, start, end);
        self.highlightFunctionParameters(theme, start, end);
    }

    /// Basic highlighting for C
    pub fn highlightCSlice(
        self: *StyledTextBuffer,
        start: usize,
        end: usize,
        theme: movy.ui.ColorTheme,
    ) void {
        const keywords = [_][]const u8{
            "int",    "char",     "float",   "double", "void",     "return",
            "if",     "else",     "while",   "for",    "break",    "continue",
            "switch", "case",     "default", "struct", "typedef",  "enum",
            "const",  "volatile", "static",  "extern", "unsigned", "signed",
            "sizeof", "do",
        };

        const types = [_][]const u8{
            "uint8_t", "uint16_t", "uint32_t",  "uint64_t",
            "int8_t",  "int16_t",  "int32_t",   "int64_t",
            "bool",    "size_t",   "uintptr_t",
        };

        // Style C keywords
        for (keywords) |kw| {
            self.highlightKeywordIsolated(
                kw,
                theme.colors.get(.Keyword),
                theme.colors.get(.CodeBackground),
            );
        }

        // Style type aliases
        for (types) |ty| {
            self.highlightKeywordIsolated(
                ty,
                theme.colors.get(.Constant),
                theme.colors.get(.CodeBackground),
            );
        }

        // Single-line comments
        self.styleUntilLineEnd(
            "//",
            theme.colors.get(.Comment),
            theme.colors.get(.CodeBackground),
        );

        // Multi-line block comments: /* ... */
        self.highlightBetweenKeywords(
            "/*",
            "*/",
            theme.colors.get(.Comment),
            theme.colors.get(.CodeBackground),
            true,
            true,
        );

        // Strings
        self.highlightBetweenKeywords(
            "\"",
            "\"",
            theme.colors.get(.String),
            theme.colors.get(.CodeBackground),
            true,
            true,
        );

        // Char literals
        self.highlightBetweenKeywords(
            "'",
            "'",
            theme.colors.get(.String),
            theme.colors.get(.CodeBackground),
            true,
            true,
        );

        // Symbols and operators
        self.highlightSymbols(
            &[_]u21{
                '{',
                '}',
                '(',
                ')',
                '[',
                ']',
                '=',
                ',',
                ';',
                ':',
                '-',
                '>',
                '.',
                '+',
                '-',
                '*',
                '/',
                '&',
                '|',
                '^',
                '~',
                '!',
                '<',
                '>',
            },
            theme.colors.get(.Keyword),
            theme.colors.get(.CodeBackground),
            start,
            end,
        );

        self.highlightFunctionNames(theme, start, end);
        self.highlightFunctionParameters(theme, start, end);
    }

    pub fn highlightCppSlice(
        self: *StyledTextBuffer,
        start: usize,
        end: usize,
        theme: movy.ui.ColorTheme,
    ) void {
        self.highlightCSlice(start, end, theme); // base it on C first

        const cpp_keywords = [_][]const u8{
            "namespace", "class",    "public", "private", "protected",
            "template",  "typename", "this",   "new",     "delete",
            "try",       "catch",    "throw",  "nullptr", "using",
            "operator",  "override", "final",  "virtual",
        };

        for (cpp_keywords) |kw| {
            self.highlightKeywordIsolated(
                kw,
                theme.colors.get(.Keyword),
                theme.colors.get(.CodeBackground),
            );
        }

        self.highlightFunctionNames(theme, start, end);
        self.highlightFunctionParameters(theme, start, end);
    }

    pub fn highlightGenericCodeSlice(
        self: *StyledTextBuffer,
        start: usize,
        end: usize,
        theme: movy.ui.ColorTheme,
    ) void {
        // 1. Style everything with default code text/background color
        for (start..end) |i| {
            self.text[i].fg = theme.colors.get(.CodeText);
            self.text[i].bg = theme.colors.get(.CodeBackground);
        }

        // 2. Highlight single-line comments starting with "//"
        self.styleUntilLineEnd(
            "//",
            theme.colors.get(.Comment),
            theme.colors.get(.CodeBackground),
        );

        // 3. Highlight symbols (optional — just to give it structure)
        self.highlightSymbols(
            &[_]u21{
                '{',
                '}',
                '(',
                ')',
                '[',
                ']',
                '=',
                ',',
                ';',
                ':',
                '-',
                '>',
                '.',
                '+',
                '-',
                '*',
                '/',
                '&',
                '|',
                '^',
                '~',
                '!',
                '<',
                '>',
            },
            theme.colors.get(.Keyword),
            theme.colors.get(.CodeBackground),
            start,
            end,
        );
    }

    /// Clears all foreground and background styles from the buffer,
    /// preserving the text content and cursor position.
    pub fn clearStyles(self: *StyledTextBuffer) void {
        for (0..self.last_char_idx + 1) |i| {
            self.text[i].fg = null;
            self.text[i].bg = null;
        }
    }

    pub fn highlightFunctionNames(
        self: *StyledTextBuffer,
        theme: movy.ui.ColorTheme,
        start: usize,
        end: usize,
    ) void {
        var i = start;

        while (i < end - 2) {
            // Look for a function declaration pattern: fn|type ...name...(
            const is_fn = i + 1 < end and self.text[i].char == 'f' and
                self.text[i + 1].char == 'n';
            const is_type_start = is_fn or isReturnTypeKeyword(self, i, end);

            if (!is_type_start) {
                i += 1;
                continue;
            }

            // Move to function name (skip keyword and whitespace)
            var j = i;
            while (j < end and !isIdentifierStartChar(self.text[j].char)) : (j += 1) {}
            while (j < end and isIdentifierChar(self.text[j].char)) : (j += 1) {}

            // We are now at the function name
            // const name_start = j;
            while (j < end and isWhitespace(self.text[j].char)) : (j += 1) {}

            const fn_name_start = j;
            while (j < end and isIdentifierChar(self.text[j].char)) : (j += 1) {}
            const fn_name_end = j;

            if (j < end and self.text[j].char == '(') {
                for (fn_name_start..fn_name_end) |k| {
                    self.text[k].fg = theme.colors.get(.SupportFunction);
                    self.text[k].bg = theme.colors.get(.CodeBackground);
                }
            }

            i = j + 1;
        }
    }

    pub fn highlightFunctionParameters(
        self: *StyledTextBuffer,
        theme: movy.ui.ColorTheme,
        start: usize,
        end: usize,
    ) void {
        var i = start;

        while (i < end - 1) {
            // Look for a `(` following an identifier = function name
            if (self.text[i].char == '(') {
                var j = i + 1;
                var depth: usize = 1;

                while (j < end and depth > 0) {
                    const c = self.text[j].char;

                    if (c == '(') {
                        depth += 1;
                        j += 1;
                        continue;
                    } else if (c == ')') {
                        depth -= 1;
                        j += 1;
                        continue;
                    }

                    // Possible identifier start
                    if (isIdentifierStartChar(c)) {
                        const id_start = j;
                        var id_end = j;

                        while (id_end < end and isIdentifierChar(
                            self.text[id_end].char,
                        )) : (id_end += 1) {}

                        const slice_len = id_end - id_start;
                        if (slice_len > 0) {
                            const word = self.text[id_start..id_end];

                            // Check if the word is NOT a known type
                            if (!isTypeKeyword(word)) {
                                // Highlight as parameter
                                for (id_start..id_end) |k| {
                                    self.text[k].fg =
                                        theme.colors.get(.Parameter);
                                    self.text[k].bg =
                                        theme.colors.get(.CodeBackground);
                                }
                            }
                        }

                        j = id_end;
                    } else {
                        j += 1;
                    }
                }

                i = j;
            } else {
                i += 1;
            }
        }
    }

    pub fn highlightInlineBacktickCode(
        self: *StyledTextBuffer,
        theme: movy.ui.ColorTheme,
    ) void {
        const text = self.text;
        const max_index = self.last_char_idx;
        var i: usize = 0;

        while (i <= max_index) {
            // Look for a single backtick
            if (text[i].char == '`') {
                const start = i;
                i += 1;

                // Skip triple backtick code block accidentally
                if (i + 1 < text.len and text[i].char == '`' and
                    text[i + 1].char == '`')
                {
                    i += 2;
                    continue;
                }

                var end = i;
                while (end <= max_index and text[end].char !=
                    '`') : (end += 1)
                {}

                if (end <= max_index) {
                    // We found a closing `
                    for (start..end + 1) |j| {
                        self.text[j].fg = theme.colors.get(.CodeText);
                        self.text[j].bg = theme.colors.get(.CodeBackground);
                    }
                    i = end + 1;
                } else {
                    break; // No closing backtick
                }
            } else {
                i += 1;
            }
        }
    }

    fn isWhitespace(c: u21) bool {
        return c == ' ' or c == '\t' or c == '\n' or c == '\r';
    }

    fn isIdentifierStartChar(c: u21) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
    }

    fn isIdentifierChar(c: u21) bool {
        return isIdentifierStartChar(c) or (c >= '0' and c <= '9');
    }

    fn isReturnTypeKeyword(self: *StyledTextBuffer, i: usize, end: usize) bool {
        const types = [_][]const u8{
            // Zig
            "void",     "u8",     "u16",     "u32",      "u64",      "usize",
            "i8",       "i16",    "i32",     "i64",      "isize",    "f16",
            "f32",      "f64",    "bool",    "noreturn", "anyerror",

            // C/C++
            "int",
            "char",     "float",  "double",  "long",     "short",    "signed",
            "unsigned", "size_t", "uint8_t", "int32_t",  "auto",     "struct",
            "class",
        };

        for (types) |ty| {
            const len = ty.len;
            if (i + len < end) {
                var matched = true;
                for (0..len) |j| {
                    if (self.text[i + j].char != ty[j]) {
                        matched = false;
                        break;
                    }
                }
                // Ensure the word ends
                if (matched and (i + len >= end or
                    isWhitespace(self.text[i + len].char)))
                {
                    return true;
                }
            }
        }
        return false;
    }

    fn isTypeKeyword(word: []const StyledChar) bool {
        const known_types = [_][]const u8{
            "int",      "char",     "float",    "double",  "void",   "bool",
            "u8",       "u32",      "usize",    "i32",     "i64",    "f32",
            "f64",      "size_t",   "uint8_t",  "int32_t", "struct", "class",
            "anytype",  "noreturn", "anyerror", "short",   "long",   "signed",
            "unsigned",
        };

        for (known_types) |ty| {
            if (word.len != ty.len) continue;
            var matched = true;
            for (0..ty.len) |j| {
                if (word[j].char != ty[j]) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }

        return false;
    }

    fn isBoundaryChar(c: u21) bool {
        return switch (c) {
            ' ',
            '\t',
            '\n',
            '\r',
            ',',
            ';',
            ':',
            '.',
            '(',
            ')',
            '{',
            '}',
            '[',
            ']',
            '<',
            '>',
            '=',
            '+',
            '-',
            '*',
            '/',
            '\\',
            '|',
            '&',
            '^',
            '%',
            '!',
            '?',
            '\'',
            '"',
            => true,
            else => false,
        };
    }
};

const std = @import("std");
const movy = @import("../../movy.zig");

/// Manages collections of widgets and windows—creates, tracks,
/// and renders them.
pub const Manager = struct {
    allocator: std.mem.Allocator,
    // tracked ui items
    widgets: std.ArrayList(*movy.ui.Widget),
    bordered_windows: std.ArrayList(*movy.ui.BorderedWindow),
    title_windows: std.ArrayList(*movy.ui.TitleWindow),
    text_windows: std.ArrayList(*movy.ui.TextWindow),
    windows: std.ArrayList(*movy.ui.Window),
    sprites: std.ArrayList(*movy.graphic.Sprite),
    // managed screen
    screen: *movy.Screen,

    // state
    active_widget: ?movy.ui.WidgetInfo = null,
    input_event: ?movy.input.InputEvent,
    drag: DragContext = .{},

    const DragContext = struct {
        state: enum {
            None,
            Dragging,
        } = .None,
        target: ?*movy.ui.Widget = null,
        offset: movy.ui.Position2D = .{ .x = 0, .y = 0 },
    };

    /// Initializes the manager with a screen—starts with empty lists
    /// for all widget types.
    pub fn init(
        allocator: std.mem.Allocator,
        screen: *movy.Screen,
    ) movy.ui.Manager {
        return Manager{
            .widgets = std.ArrayList(*movy.ui.Widget).init(allocator),
            .bordered_windows = std.ArrayList(*movy.ui.BorderedWindow).init(
                allocator,
            ),
            .title_windows = std.ArrayList(*movy.ui.TitleWindow).init(
                allocator,
            ),
            .text_windows = std.ArrayList(*movy.ui.TextWindow).init(
                allocator,
            ),
            .windows = std.ArrayList(*movy.ui.Window).init(allocator),
            .sprites = std.ArrayList(*movy.graphic.Sprite).init(allocator),
            .active_widget = null,
            .screen = screen,
            .allocator = allocator,
            .input_event = null,
        };
    }

    /// Frees all managed widgets and windows—cleans up all resources owned by
    /// the manager.
    pub fn deinit(self: *Manager) void {
        for (self.widgets.items) |widget| {
            widget.deinit(self.allocator);
        }
        self.widgets.deinit();
        for (self.bordered_windows.items) |window| {
            window.deinit(self.allocator);
        }
        self.bordered_windows.deinit();
        for (self.title_windows.items) |window| {
            window.deinit(self.allocator);
        }
        self.title_windows.deinit();
        for (self.windows.items) |window| {
            window.deinit(self.allocator);
        }
        for (self.text_windows.items) |window| {
            window.deinit(self.allocator);
        }
        self.text_windows.deinit();
        self.windows.deinit();

        for (self.sprites.items) |sprite| {
            sprite.deinit(self.allocator);
        }
        self.sprites.deinit();
    }

    /// Adjusts absolute mouse coordinates to screen-relative coordinates.
    pub fn getPositionInScreen(
        self: *const Manager,
        x: i32,
        y: i32,
    ) movy.ui.Position2D {
        return movy.ui.Position2D{
            .x = x - self.screen.x,
            .y = y - self.screen.y,
        };
    }

    /// Creates a new widget—adds it to the widget list and returns its pointer.
    pub fn createWidget(
        self: *Manager,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*movy.ui.Widget {
        const widget = try movy.ui.Widget.init(
            self.allocator,
            x,
            y,
            w,
            h,
            theme,
            style,
        );
        try self.widgets.append(widget);
        return widget;
    }

    /// Removes a widget from the manager—frees it and updates active_widget
    /// if needed.
    pub fn removeWidget(self: *Manager, widget: *movy.ui.Widget) void {
        for (self.widgets.items, 0..) |w, i| {
            if (w == widget) {
                _ = self.widgets.orderedRemove(i);
                widget.deinit(self.allocator);
                return;
            }
        }
    }

    /// Creates a new bordered window—adds it to the bordered window list and
    /// returns its pointer.
    pub fn createBorderedWindow(
        self: *Manager,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*movy.ui.BorderedWindow {
        const window = try movy.ui.BorderedWindow.init(
            self.allocator,
            x,
            y,
            w,
            h,
            theme,
            style,
        );
        try self.bordered_windows.append(window);
        return window;
    }

    /// Removes a bordered window from the manager—frees it.
    pub fn removeBorderedWindow(
        self: *Manager,
        window: *movy.ui.BorderedWindow,
    ) void {
        for (self.bordered_windows.items, 0..) |w, i| {
            if (w == window) {
                _ = self.bordered_windows.orderedRemove(i);
                window.deinit(self.allocator);
                return;
            }
        }
    }

    /// Creates a new title window—adds it to the title window list and
    /// returns its pointer.
    pub fn createTitleWindow(
        self: *Manager,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*movy.ui.TitleWindow {
        const window = try movy.ui.TitleWindow.init(
            self.allocator,
            x,
            y,
            w,
            h,
            window_title,
            theme,
            style,
        );
        try self.title_windows.append(window);
        return window;
    }

    /// Removes a title window from the manager
    pub fn removeTitleWindow(
        self: *Manager,
        window: *movy.ui.TitleWindow,
    ) void {
        for (self.title_windows.items, 0..) |w, i| {
            if (w == window) {
                _ = self.title_windows.orderedRemove(i);
                window.deinit(self.allocator);
                return;
            }
        }
    }

    /// Creates a new text window—adds it to the text window list and
    /// returns its pointer.
    pub fn createTextWindow(
        self: *Manager,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        window_text: []const u8,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*movy.ui.TextWindow {
        const window = try movy.ui.TextWindow.init(
            self.allocator,
            x,
            y,
            w,
            h,
            window_title,
            window_text,
            theme,
            style,
        );
        try self.text_windows.append(window);
        return window;
    }

    /// Removes a text window from the manager
    pub fn removeTextWindow(
        self: *Manager,
        window: *movy.ui.TextWindow,
    ) void {
        for (self.text_windows.items, 0..) |w, i| {
            if (w == window) {
                _ = self.text_windows.orderedRemove(i);
                window.deinit(self.allocator);
                return;
            }
        }
    }

    /// Creates a new top-level window—adds it to the window list and
    /// returns its pointer.
    pub fn createWindow(
        self: *Manager,
        x: i32,
        y: i32,
        w: usize,
        h: usize,
        window_title: []const u8,
        theme: *const movy.ui.ColorTheme,
        style: *const movy.ui.Style,
    ) !*movy.ui.Window {
        const window = try movy.ui.Window.init(
            self.allocator,
            x,
            y,
            w,
            h,
            window_title,
            theme,
            style,
        );
        window.setPosition(x, y);
        try self.windows.append(window);
        return window;
    }

    /// Removes a top-level window from the manager
    pub fn removeWindow(self: *Manager, window: *movy.ui.Window) void {
        for (self.windows.items, 0..) |w, i| {
            if (w == window) {
                _ = self.windows.orderedRemove(i);
                window.deinit(self.allocator);
                return;
            }
        }
    }

    pub fn addSprite(self: *Manager, sprite: *movy.graphic.Sprite) !void {
        try self.sprites.append(sprite);
    }

    /// Sets the active widget—focuses it for input handling.
    pub fn setActiveWidget(self: *Manager, widget: movy.ui.WidgetInfo) void {
        // inactivate current active widget
        if (self.active_widget) |active| {
            switch (active.widget_type) {
                .TextWindow => {
                    for (self.text_windows.items) |w| {
                        if (w.base_widget == active.ptr) {
                            w.base_widget.is_active = false;
                            break;
                        }
                    }
                },
                // .TitleWindow => {
                //     for (self.title_windows.items) |w| {
                //         if (w.base_widget == active.ptr) {
                //         }
                //     }
                // },
                // .BorderedWindow => {
                //     for (self.bordered_windows.items) |w| {
                //         if (w.base_widget == active.ptr) {
                //         }
                //     }
                // },
                // .Widget => {
                //     for (self.widgets.items) |w| {
                //         if (w == active.ptr) {
                //         }
                //     }
                // },
                else => {},
            }
        }

        self.active_widget = widget;

        const active = widget;
        switch (active.widget_type) {
            .TextWindow => {
                for (self.text_windows.items) |w| {
                    if (w.base_widget == active.ptr) {
                        w.base_widget.is_active = true;
                        break;
                    }
                }
            },
            // .TitleWindow => {
            //     for (self.title_windows.items) |w| {
            //         if (w.base_widget == active.ptr) {
            //         }
            //     }
            // },
            // .BorderedWindow => {
            //     for (self.bordered_windows.items) |w| {
            //         if (w.base_widget == active.ptr) {
            //         }
            //     }
            // },
            // .Widget => {
            //     for (self.widgets.items) |w| {
            //         if (w == active.ptr) {
            //         }
            //     }
            // },
            else => {},
        }
    }

    /// Gets the currently active widget—null if none.
    pub fn getActiveWidget(self: *const Manager) ?*movy.ui.Widget {
        return self.active_widget;
    }

    /// Renders all widgets and windows to the screen—composites
    /// output_surfaces.
    pub fn render(self: *Manager) !void {
        self.screen.output_surfaces.clearRetainingCapacity();
        for (self.widgets.items) |widget| {
            try self.screen.addRenderSurface(widget.render());
        }
        for (self.bordered_windows.items) |window| {
            try self.screen.addRenderSurface(window.render());
        }
        for (self.title_windows.items) |window| {
            try self.screen.addRenderSurface(window.render());
        }
        for (self.windows.items) |window| {
            try self.screen.addRenderSurface(window.render());
        }
        for (self.text_windows.items) |window| {
            try self.screen.addRenderSurface(window.render());
        }

        for (self.sprites.items) |sprite| {
            try self.screen.addRenderSurface(
                // try sprite.getCurrentFrameSurface(),
                sprite.output_surface,
            );
        }

        self.screen.render();
    }

    /// Clears all widgets and windows—resets their output_surfaces to
    /// background color.
    pub fn clearAll(self: *Manager) void {
        for (self.widgets.items) |widget| {
            widget.clear();
        }
        for (self.bordered_windows.items) |window| {
            window.base.clear();
        }
        for (self.title_windows.items) |window| {
            window.base.base.clear();
        }
        for (self.windows.items) |window| {
            window.base.base.base.clear();
        }
        for (self.text_windows.items) |window| {
            window.base.base.base.clear();
        }
    }

    /// Get the x and y position as Position2D for the topleft corner of a
    /// rectangle (window, sprite, ...) of dimensions widht and height.
    pub fn getCenterCoords(
        self: *Manager,
        width: usize,
        height: usize,
    ) movy.ui.Position2D {
        const center_x: i32 =
            @divTrunc(@as(i32, @intCast(self.screen.width() - width)), 2);

        const center_y: i32 =
            @divTrunc(@as(i32, @intCast(self.screen.height() - height)), 2);

        return movy.ui.Position2D{
            .x = center_x,
            .y = center_y,
        };
    }

    /// Handles and routes input events within the UI system.
    ///
    /// Dispatches the event to the currently active widget, if one is set,
    /// transforming mouse coordinates into local space. If the widget
    /// consumes the event, no further processing is done.
    ///
    /// If the event is not consumed, manager-level logic handles window
    /// focus and drag behavior.
    ///
    /// Returns `true` if the event was consumed, `false` otherwise.
    pub fn handleInputEvent(
        self: *Manager,
        event: movy.input.InputEvent,
    ) bool {
        // Route to active widget first
        if (self.active_widget) |active| {
            switch (active.widget_type) {
                .TextWindow => {
                    for (self.text_windows.items) |w| {
                        if (w.base_widget == active.ptr) {
                            // clean mouse coordinates
                            const new_event: movy.input.InputEvent = switch (event) {
                                .mouse => |mouse| .{ .mouse = .{
                                    .event = mouse.event,
                                    .x = mouse.x - self.screen.x - w.base_widget.x,
                                    .y = mouse.y - self.screen.y - w.base_widget.y,
                                    .button = mouse.button,
                                    .sequence = mouse.sequence,
                                } },
                                .key => event,
                            };
                            w.handleInputEvent(new_event);
                            //  TODO: make return type bool, and indicate
                            //        event consumed. When consumed, return.
                            //        Consumed must mean an action has been
                            //        triggered from it, to abort further
                            //        evaluation on manager level.
                            //        this way, mouse input can be handled in
                            //        window, and not be processed as ie drag
                            //        event on manager level.
                            //        Also, when event is not consumed, it can
                            //        be used on manager level to set active
                            //        widget, or drag widget.
                            break;
                            // return true;
                        }
                    }
                },
                // .TitleWindow => {
                //     for (self.title_windows.items) |w| {
                //         if (w.base_widget == active.ptr) {
                //             return w.handleInputEvent(event);
                //         }
                //     }
                // },
                // .BorderedWindow => {
                //     for (self.bordered_windows.items) |w| {
                //         if (w.base_widget == active.ptr) {
                //             return w.handleInputEvent(event);
                //         }
                //     }
                // },
                // .Widget => {
                //     for (self.widgets.items) |w| {
                //         if (w == active.ptr) {
                //             return w.handleInputEvent(event);
                //         }
                //     }
                // },
                else => {},
            }
        }

        // Manager-level input handling
        switch (event) {
            .mouse => |mouse| {
                const mouse_x = mouse.x - self.screen.x;
                const mouse_y = mouse.y * 2 - self.screen.y;

                switch (mouse.event) {
                    .Down => {
                        for (self.text_windows.items) |w| {
                            if (w.isInTitleBounds(mouse_x, mouse_y)) {
                                self.drag.state = .Dragging;
                                self.drag.target = w.base_widget;
                                const pos = w.getPosition();
                                self.drag.offset = .{
                                    .x = mouse_x - pos.x,
                                    .y = mouse_y - pos.y,
                                };
                                break;
                            } else if (w.isInBounds(mouse_x, mouse_y)) {
                                self.setActiveWidget(w.getWidgetInfo());
                                return true;
                            }
                        }
                    },
                    .Up => {
                        self.drag.state = .None;
                        self.drag.target = null;
                    },
                    .Move => {
                        if (self.drag.state == .Dragging) {
                            if (self.drag.target) |widget| {
                                // find win and reposition
                                for (self.text_windows.items) |win| {
                                    if (win.base_widget == widget) {
                                        win.setPosition(
                                            mouse_x - self.drag.offset.x,
                                            mouse_y - self.drag.offset.y,
                                        );
                                        return true;
                                    }
                                }
                            }
                        }
                    },
                    else => {},
                }
            },
            else => {},
        }

        return false;
    }
};

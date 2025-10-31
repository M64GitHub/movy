const std = @import("std");
const movy = @import("../movy.zig");

const SpriteError = Sprite.SpriteError;

pub const SpriteFrame = struct {
    x_rel: i32 = 0,
    y_rel: i32 = 0,
    w: usize = 0,
    h: usize = 0,
    data_surface: *movy.core.RenderSurface,
    output_surface: *movy.core.RenderSurface,

    /// Initializes a SpriteFrame with given width and height
    pub fn init(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !*SpriteFrame {
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const data_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(data_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = w,
            .h = h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }

    /// Deinitializes a SpriteFrame, freeing all its allocated resources
    pub fn deinit(self: *SpriteFrame, allocator: std.mem.Allocator) void {
        self.data_surface.deinit(allocator);
        self.output_surface.deinit(allocator);
        allocator.destroy(self);
    }

    /// Initializes a SpriteFrame from a .png file
    pub fn initFromPng(
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        const data_surface =
            try movy.core.RenderSurface.createFromPng(allocator, file_path);
        errdefer allocator.destroy(data_surface);

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            data_surface.w,
            data_surface.h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        try output_surface.copy(data_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = data_surface.w,
            .h = data_surface.h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }

    /// Creates a new SpriteFrame from an ANSI string
    pub fn initFromAnsiStr(
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
    ) !*SpriteFrame {
        const data_surface =
            try movy.core.RenderSurface.createFromAnsi(allocator, img_str);
        errdefer allocator.destroy(data_surface);

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            data_surface.w,
            data_surface.h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const frame = try allocator.create(SpriteFrame);
        errdefer allocator.destroy(frame);

        frame.* = SpriteFrame{
            .w = data_surface.w,
            .h = data_surface.h,
            .data_surface = data_surface,
            .output_surface = output_surface,
        };

        return frame;
    }
};

pub const SpriteFrameSet = struct {
    frames: std.ArrayList(*SpriteFrame),
    frame_idx: usize = 0,

    /// Initializes a SpriteFrameSet with a given number of frames,
    /// all with w and h
    pub fn init(
        allocator: std.mem.Allocator,
        frame_count: usize,
        w: usize,
        h: usize,
    ) !SpriteFrameSet {
        var frames = std.ArrayList(*SpriteFrame){};
        errdefer frames.deinit(allocator);

        try frames.ensureTotalCapacity(allocator, frame_count); // Pre-allocate space
        for (0..frame_count) |_| {
            const frame = try SpriteFrame.init(allocator, w, h);
            try frames.append(allocator, frame);
        }

        return SpriteFrameSet{
            .frames = frames,
            .frame_idx = 0,
        };
    }

    /// Deinitializes a SpriteFrameSet, freeing all frames and the list
    pub fn deinit(self: *SpriteFrameSet, allocator: std.mem.Allocator) void {
        for (self.frames.items) |frame| {
            frame.deinit(allocator);
        }
        self.frames.deinit(allocator);
    }

    /// Adds a new SpriteFrame with given width and height to the frameset
    pub fn addSpriteFrame(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
    ) !void {
        const new_frame = try SpriteFrame.init(allocator, w, h);
        try self.frames.append(allocator, new_frame);
    }

    /// Adds a new SpriteFrame from a .png file, and returns a pointer to it
    pub fn addFrameFromPng(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        const new_frame = try SpriteFrame.initFromPng(allocator, file_path);
        try self.frames.append(allocator, new_frame);
        return new_frame;
    }

    /// Adds a new SpriteFrame from an ANSI string to the frameset
    pub fn addFrameFromAnsiStr(
        self: *SpriteFrameSet,
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
    ) !*SpriteFrame {
        const new_frame = try SpriteFrame.initFromAnsiStr(allocator, img_str);
        try self.frames.append(allocator, new_frame);
        return new_frame;
    }
};

pub const Sprite = struct {
    name: []u8 = &[_]u8{},
    w: usize = 0,
    h: usize = 0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    frame_set: SpriteFrameSet,
    animations: std.StringHashMap(FrameAnimation),
    active_animation: ?[]const u8 = null,
    output_surface: *movy.core.RenderSurface,
    effect_ctx: movy.render.Effect.RenderEffectContext,

    pub const SpriteError = error{
        AnimationNotFound,
        // ...
    };

    // Error set for frame surface functions
    pub const FrameError = error{
        EmptyFrameSet, // No frames in the set
        InvalidFrameIndex, // Index out of bounds
    };

    pub const FrameAnimation = struct {
        animator: movy.animation.IndexAnimator,
        just_started: bool = true,
        speed: usize = 1,
        speed_ctr: usize = 0,

        pub fn init(
            start: usize,
            end: usize,
            mode: movy.animation.IndexAnimator.LoopMode,
            speed: usize,
        ) FrameAnimation {
            return .{
                .animator = movy.animation.IndexAnimator.init(
                    start,
                    end,
                    mode,
                ),
                .speed = speed,
                .speed_ctr = speed,
            };
        }

        /// Advances the animation and updates the sprite's frame index
        pub fn step(self: *FrameAnimation, sprite: *Sprite) void {
            if (self.speed_ctr > 0) {
                // wait
                self.speed_ctr -= 1;
            } else {
                self.speed_ctr = self.speed;
                if (self.just_started) {
                    self.just_started = false;
                    return;
                }
                const index = self.animator.step();
                sprite.frame_set.frame_idx = index;
            }
        }

        pub fn finished(self: *FrameAnimation) bool {
            return self.animator.once_finished;
        }
    };

    /// Initializes a Sprite with a single frame of given width and height
    pub fn init(
        allocator: std.mem.Allocator,
        w: usize,
        h: usize,
        name: []const u8,
    ) !*Sprite {
        const frame_set = try SpriteFrameSet.init(allocator, 1, w, h);
        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);
        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = frame_set.frames.items[0].data_surface,
            .output_surface = output_surface,
        };

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const sprite = try allocator.create(Sprite);

        sprite.* = Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };

        return sprite;
    }

    /// Deinitializes a Sprite, freeing all its allocated resources
    pub fn deinit(self: *Sprite, allocator: std.mem.Allocator) void {
        self.frame_set.deinit(allocator);
        self.output_surface.deinit(allocator);
        if (self.name.len > 0) allocator.free(self.name);
        self.animations.deinit();
        allocator.destroy(self);
    }

    /// Sets the current active frame by index.
    ///
    /// This updates both the visible frame index and the input surface used by
    /// the sprite’s internal RenderEffectContext, ensuring effects target the
    /// correct frame data when rendering.
    ///
    /// Returns an error if the index is out of bounds.
    pub fn setFrameIndex(self: *Sprite, idx: usize) !void {
        if (idx > self.frame_set.frames.items.len - 1) {
            return error.InvalidFrameIndex;
        }
        self.frame_set.frame_idx = idx;
        self.effect_ctx.input_surface = try self.getCurrentFrameSurface();
    }

    /// Returns the data_surface of the current frame based on frame_idx
    pub fn getCurrentFrameSurface(
        self: *Sprite,
    ) FrameError!*movy.core.RenderSurface {
        if (self.frame_set.frames.items.len == 0) {
            return error.EmptyFrameSet;
        }
        const idx = self.frame_set.frame_idx;
        return self.frame_set.frames.items[idx].data_surface;
    }

    /// Returns the data_surface of the SpriteFrame at the given index
    pub fn getFrameSurface(
        self: *Sprite,
        index: usize,
    ) FrameError!*movy.core.RenderSurface {
        if (self.frame_set.frames.items.len == 0) {
            return error.EmptyFrameSet;
        }
        if (index >= self.frame_set.frames.items.len) {
            return error.InvalidFrameIndex;
        }
        return self.frame_set.frames.items[index].data_surface;
    }

    /// Adds new frames to the sprite with given width and height,
    /// returns pointer to the first new frame
    pub fn addFrames(
        self: *Sprite,
        allocator: std.mem.Allocator,
        n: usize,
        width: usize,
        height: usize,
    ) !*SpriteFrame {
        const start_idx = self.frame_set.frames.items.len;
        try self.frame_set.frames.ensureTotalCapacity(allocator, start_idx + n);

        for (0..n) |_| {
            const new_frame = try SpriteFrame.init(allocator, width, height);
            try self.frame_set.frames.append(allocator, new_frame);
        }

        return self.frame_set.frames.items[start_idx]; // First new frame
    }

    /// Adds a new frame to the sprite loaded from a PNG file,
    /// returns pointer to the new frame
    pub fn addFrameFromPng(
        self: *Sprite,
        allocator: std.mem.Allocator,
        file_path: []const u8,
    ) !*SpriteFrame {
        return try self.frame_set.addFrameFromPng(allocator, file_path);
    }

    /// Adds a named animation to the sprite's animation map.
    /// This simplifies external usage by handling allocation and insertion
    /// internally.
    ///
    /// Example:
    /// ```zig
    /// try sprite.addAnimation(allocator, "up",
    ///     try FrameAnimation.init("up", 0, 3, .loop));
    /// ```
    pub fn addAnimation(
        self: *Sprite,
        allocator: std.mem.Allocator,
        name: []const u8,
        anim: FrameAnimation,
    ) !void {
        const myname = try allocator.dupe(u8, name);
        try self.animations.put(myname, anim);
    }

    /// Sets the currently active animation by name. If the animation does not
    /// exist, returns `SpriteError.AnimationNotFound`.
    ///
    /// After calling this, the sprite will update its frame each time
    /// `stepActiveAnimation()` is called.
    pub fn startAnimation(
        self: *Sprite,
        name: []const u8,
    ) Sprite.SpriteError!void {
        if (!self.animations.contains(name)) {
            std.debug.print(
                "Animation not found: '{s}'\nAvailable animations:\n",
                .{name},
            );

            var it = self.animations.iterator();
            while (it.next()) |entry| {
                std.debug.print("- {s}\n", .{entry.key_ptr.*});
            }

            return Sprite.SpriteError.AnimationNotFound;
        }

        self.active_animation = name;

        if (self.animations.getPtr(name)) |anim_ptr| {
            anim_ptr.animator.current = anim_ptr.animator.start;
            anim_ptr.animator.once_finished = false;
            anim_ptr.just_started = true;
            anim_ptr.speed_ctr = anim_ptr.speed;
            self.frame_set.frame_idx = anim_ptr.animator.start;
        }
    }

    /// Advances the currently active animation, if one is set, and updates the
    /// sprite's current frame index accordingly.
    ///
    /// This should be called once per frame update to animate the sprite.
    /// It is safe to call even when no active animation is set.
    pub fn stepActiveAnimation(self: *Sprite) void {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                anim_ptr.step(self);
            }
        }
    }

    /// Resets the active animation to its initial frame index,
    /// if any is active.
    /// Useful when restarting an animation manually.
    pub fn resetActiveAnimation(self: *Sprite) void {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                anim_ptr.animator.current = anim_ptr.animator.start;
                anim_ptr.step(self);
            }
        }
    }

    /// Resets the active animation to its initial frame index,
    /// if any is active.
    /// Useful when restarting an animation manually.
    pub fn finishedActiveAnimation(self: *Sprite) bool {
        if (self.active_animation) |name| {
            if (self.animations.getPtr(name)) |anim_ptr| {
                return anim_ptr.finished();
            }
        }
        return false;
    }

    /// Initializes a Sprite with a single frame loaded from a PNG file
    pub fn initFromPng(
        allocator: std.mem.Allocator,
        file_path: []const u8,
        name: []const u8,
    ) !*Sprite {
        var frame_set = SpriteFrameSet{
            .frames = std.ArrayList(*SpriteFrame){},
        };
        try frame_set.frames.ensureTotalCapacity(allocator, 4);
        errdefer frame_set.deinit(allocator);

        // Add the first frame from PNG directly to frame_set
        const frame = try frame_set.addFrameFromPng(allocator, file_path);
        const w = frame.w;
        const h = frame.h;

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        const data_surface =
            frame_set.frames.items[0].data_surface;

        try output_surface.copy(data_surface);

        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = data_surface,
            .output_surface = output_surface,
        };

        const sprite = try allocator.create(Sprite);
        sprite.* = Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };

        return sprite;
    }

    /// Initializes a Sprite with a single frame loaded from an ANSI string
    pub fn initFromAnsiStr(
        allocator: std.mem.Allocator,
        img_str: [:0]const u8,
        name: []const u8,
    ) !Sprite {
        var frame_set = SpriteFrameSet{
            .frames = std.ArrayList(*SpriteFrame){},
        };
        try frame_set.frames.ensureTotalCapacity(allocator, 4);
        errdefer frame_set.deinit(allocator);

        const frame = try frame_set.addFrameFromAnsiStr(allocator, img_str);
        const w = frame.w;
        const h = frame.h;

        const output_surface = try movy.core.RenderSurface.init(
            allocator,
            w,
            h,
            movy.core.types.Rgb{ .r = 0, .g = 0, .b = 0 },
        );
        errdefer allocator.destroy(output_surface);

        const name_copy = try allocator.dupe(u8, name);
        errdefer allocator.free(name_copy);

        try output_surface.copy(frame.data_surface);

        const effect_ctx = movy.render.Effect.RenderEffectContext{
            .input_surface = frame_set.frames.items[0].data_surface,
            .output_surface = output_surface,
        };

        return Sprite{
            .w = w,
            .h = h,
            .frame_set = frame_set,
            .output_surface = output_surface,
            .effect_ctx = effect_ctx,
            .name = name_copy,
            .animations = std.StringHashMap(FrameAnimation).init(allocator),
        };
    }

    pub fn applyCurrentFrame(self: *Sprite) !void {
        try self.output_surface.copy(try self.getCurrentFrameSurface());
    }

    /// Renders the current frame's data_surface to an ANSI string
    pub fn toAnsi(self: *Sprite) ![]u8 {
        const current_frame =
            self.frame_set.frames.items[self.frame_set.frame_idx];
        return try current_frame.data_surface.toAnsi();
    }

    /// Sets sprite position
    pub fn setXY(self: *Sprite, x: i32, y: i32) void {
        self.x = x;
        self.y = y;
        self.output_surface.x = x;
        self.output_surface.y = y;
        const data_surface: ?*movy.core.RenderSurface =
            self.getCurrentFrameSurface() catch null;
        if (data_surface) |surface| {
            surface.x = x;
            surface.y = y;
        }
    }

    /// Splits the first frame's data_surface horizontally into equal-width
    /// frames, copying each region manually by slicing the color_map,
    /// shadow_map, and char_map.
    pub fn splitByWidth(
        self: *Sprite,
        allocator: std.mem.Allocator,
        split_width: usize,
    ) !void {
        const full_frame = self.frame_set.frames.items[0];
        const src = full_frame.data_surface;
        const h = src.h;
        const w = src.w;

        if (w == 0 or h == 0 or split_width == 0 or w % split_width != 0) {
            return error.InvalidDimensions;
        }

        const num_frames = w / split_width;

        for (0..num_frames) |i| {
            const new_frame = try SpriteFrame.init(allocator, split_width, h);
            try self.frame_set.frames.append(allocator, new_frame);
            const dst = new_frame.data_surface;

            for (0..h) |y| {
                const src_row_start = y * w + (i * split_width);
                const dst_row_start = y * split_width;

                // Copy RGB
                @memcpy(
                    dst.color_map[dst_row_start .. dst_row_start + split_width],
                    src.color_map[src_row_start .. src_row_start + split_width],
                );

                // Copy shadow map
                @memcpy(
                    dst.shadow_map[dst_row_start .. dst_row_start + split_width],
                    src.shadow_map[src_row_start .. src_row_start + split_width],
                );

                // Copy char map
                @memcpy(
                    dst.char_map[dst_row_start .. dst_row_start + split_width],
                    src.char_map[src_row_start .. src_row_start + split_width],
                );
            }

            // Copy to output surface for display
            try new_frame.output_surface.copy(dst);
        }

        self.frame_set.frame_idx = 1;
        self.w = split_width;

        // Optional not sure yet: remove the original full-sized frame
        // full_frame.deinit(allocator);
        // _ = self.frame_set.frames.orderedRemove(0);
    }

    /// Print the sprite without rendering in full blocks,
    /// verifying correct import
    pub fn debugRender(self: *Sprite) !void {
        const stdout = std.io.getStdOut().writer();
        if (self.frame_set.frames.items.len == 0) return;
        for (0..self.h) |y| {
            for (0..self.w) |x| {
                const idx = x + y * self.w;
                const color =
                    self.frame_set.frames.items[0].data_surface.color_map[idx];
                const shadow =
                    self.frame_set.frames.items[0].data_surface.shadow_map[idx];
                if (shadow == 0) {
                    try stdout.print(
                        "\x1b[38;2;{d};{d};{d}m█",
                        .{ 40, 40, 80 },
                    );
                } else {
                    try stdout.print(
                        "\x1b[38;2;{};{};{}m█",
                        .{ color.r, color.g, color.b },
                    );
                }
            }
            try stdout.writeAll("\n");
        }
        try stdout.writeAll("\x1b[m");
    }
};
